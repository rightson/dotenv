#!/usr/bin/env bash
# Tests for bin/wt-relocate. Everything lives in a temp directory: throwaway
# repositories and a fake Claude Code config dir ($CLAUDE_CONFIG_DIR).
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tool="$repo_root/bin/wt-relocate"
test_root=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$test_root"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { echo "ok   $*"; }

export CLAUDE_CONFIG_DIR="$test_root/claude"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com
export GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
projects="$CLAUDE_CONFIG_DIR/projects"
ws="$test_root/ws"

encode() { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }

# A session file as Claude Code writes it, for a session started in <cwd>.
make_session() {
    local cwd=$1 id=$2 dir
    dir="$projects/$(encode "$cwd")"
    mkdir -p "$dir"
    {
        printf '{"type":"user","cwd":"%s","message":{"content":"see \\"cwd\\":\\"%s\\""}}\n' "$cwd" "$cwd"
        printf '{"type":"worktree-state","worktreeSession":{"originalCwd":"%s/sub","worktreePath":"%s"}}\n' "$cwd" "$cwd"
    } > "$dir/$id.jsonl"
    touch -t 202001010000 "$dir/$id.jsonl"
}

mkdir -p "$ws"
git init -q "$ws/repo"
git -C "$ws/repo" commit -q --allow-empty -m init
git -C "$ws/repo" worktree add -q "$ws/repo.wt-claude-feat" -b feat
git -C "$ws/repo" worktree add -q "$ws/repo.wt/claude-fix" -b fix
git -C "$ws/repo" worktree add -q "$ws/repo/.claude/worktrees/placed" -b placed
git -C "$ws/repo" worktree add -q "$ws/repo.wt/locked" -b locked
git -C "$ws/repo" worktree lock "$ws/repo.wt/locked"
make_session "$ws/repo.wt-claude-feat" aaaa
make_session "$ws/repo.wt-claude-feat/sub" bbbb
make_session "$ws/repo.wt-claude-feature-other" cccc   # similar name, another path
make_session "$ws/repo" dddd

# Dry run: prints the plan, changes nothing.
out=$("$tool" "$ws") && fail "dry run with a skipped worktree should exit 1"
echo "$out" | grep -q "Dry run: 2 to move, 1 skipped, 1 already in place" || fail "dry-run summary: $out"
echo "$out" | grep -q "(2 Claude Code sessions)" || fail "dry-run session count: $out"
[ -d "$ws/repo.wt-claude-feat" ] && [ -d "$projects/$(encode "$ws/repo.wt-claude-feat")" ] \
    || fail "dry run moved something"
ok "dry run changes nothing"

# Apply.
out=$("$tool" --apply "$ws") || true
dest="$ws/repo/.claude/worktrees"
[ -d "$dest/claude-feat" ] && [ ! -e "$ws/repo.wt-claude-feat" ] || fail "repo.wt-claude-feat not moved: $out"
[ -d "$dest/claude-fix" ] && [ ! -e "$ws/repo.wt/claude-fix" ] || fail "repo.wt/claude-fix not moved"
[ "$(git -C "$dest/claude-feat" rev-parse --abbrev-ref HEAD)" = feat ] || fail "moved worktree is broken"
git -C "$ws/repo" worktree list | grep -q "$dest/claude-fix " || fail "git does not list the new path"
[ -z "$(git -C "$ws/repo" status --porcelain)" ] || fail "main checkout status is not clean"
ok "worktrees moved, git still works, main checkout stays clean"

[ -d "$ws/repo.wt/locked" ] || fail "locked worktree was moved without --force"
echo "$out" | grep -q "locked" || fail "no reason printed for the locked worktree"
ok "locked worktree left alone"

new="$projects/$(encode "$dest/claude-feat")"
[ -f "$new/aaaa.jsonl" ] && [ -f "$new-sub/bbbb.jsonl" ] || fail "sessions did not follow the worktree"
[ ! -e "$projects/$(encode "$ws/repo.wt-claude-feat")" ] || fail "old project folder still there"
grep -q "\"cwd\":\"$dest/claude-feat\"" "$new/aaaa.jsonl" || fail "cwd not rewritten"
grep -q "\"originalCwd\":\"$dest/claude-feat/sub\",\"worktreePath\":\"$dest/claude-feat\"" "$new/aaaa.jsonl" \
    || fail "worktree-state paths not rewritten"
grep -q "\"cwd\":\"$dest/claude-feat/sub\"" "$new-sub/bbbb.jsonl" || fail "subfolder cwd not rewritten"
grep -qF "\\\"cwd\\\":\\\"$ws/repo.wt-claude-feat\\\"" "$new/aaaa.jsonl" || fail "message text was rewritten"
[ "$(date -r "$new/aaaa.jsonl" +%Y)" = 2020 ] || fail "session mtime not preserved"
python3 -c 'import json,sys; [json.loads(l) for l in open(sys.argv[1])]' "$new/aaaa.jsonl" || fail "invalid JSON"
ok "sessions follow: folder renamed, cwd fields rewritten, text and mtime kept"

[ -f "$projects/$(encode "$ws/repo.wt-claude-feature-other")/cccc.jsonl" ] || fail "moved another path's sessions"
[ -f "$projects/$(encode "$ws/repo")/dddd.jsonl" ] || fail "moved the main checkout's sessions"
ok "unrelated sessions untouched"

# --force moves the locked one; the emptied repo.wt folder is removed. Run again: nothing to do.
"$tool" --apply --force "$ws/repo.wt" > /dev/null || fail "--force run failed"
[ -d "$dest/locked" ] && [ ! -e "$ws/repo.wt" ] || fail "--force did not move the locked worktree"
out=$("$tool" --apply "$ws") || fail "second run should exit 0: $out"
echo "$out" | grep -q "0 moved, 0 skipped, 4 already in place" || fail "second run: $out"
ok "--force, emptied folder removed, second run is a no-op"

# Existing destination: skip.
git -C "$ws/repo" worktree add -q "$ws/repo.wt-placed" -b placed2
out=$("$tool" --apply "$ws/repo.wt-placed") && fail "existing destination should exit 1"
echo "$out" | grep -q "destination exists" && [ -d "$ws/repo.wt-placed" ] || fail "existing destination: $out"
ok "existing destination skipped"

# In use: a process whose working directory is inside the worktree.
if command -v lsof > /dev/null || [ -d /proc/self ]; then
    git -C "$ws/repo" worktree add -q "$ws/repo.wt-busy" -b busy
    (cd "$ws/repo.wt-busy" && exec sleep 30) &
    sleeper=$!
    sleep 1
    out=$("$tool" --apply "$ws/repo.wt-busy") || true
    { kill "$sleeper" && wait "$sleeper"; } 2> /dev/null || true
    echo "$out" | grep -q "in use by sleep" && [ -d "$ws/repo.wt-busy" ] || fail "busy worktree: $out"
    ok "worktree in use left alone"
fi

# A worktree with a submodule (git refuses to move those).
git init -q "$test_root/lib"
git -C "$test_root/lib" commit -q --allow-empty -m lib
git -C "$ws/repo" -c protocol.file.allow=always submodule add -q "$test_root/lib" lib
git -C "$ws/repo" commit -q -m "add submodule"
git -C "$ws/repo" worktree add -q "$ws/repo.wt-sub" -b sub
git -C "$ws/repo.wt-sub" -c protocol.file.allow=always submodule update -q --init
"$tool" --apply "$ws/repo.wt-sub" > /dev/null || fail "submodule worktree not moved"
git -C "$dest/sub" status > /dev/null || fail "moved worktree with a submodule is broken"
[ "$(git -C "$dest/sub/lib" rev-parse --show-toplevel)" = "$dest/sub/lib" ] || fail "submodule is broken"
[ -z "$(git -C "$dest/sub" status --porcelain)" ] || fail "submodule worktree status is not clean"
ok "worktree with a submodule moved"

echo "PASS: wt-relocate"
