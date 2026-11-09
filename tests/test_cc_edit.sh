#!/usr/bin/env bash
# Tests for bin/cc-edit. Every editor is replaced by a stub that logs its
# arguments and appends a line to the file, so no GUI is needed.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cc_edit="$repo_root/bin/cc-edit"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

stubs="$test_root/stubs"
log="$test_root/editor.log"
mkdir -p "$stubs" "$test_root/remote-cli"

# make_stub PATH NAME: an editor that logs "NAME args" and edits its last arg.
make_stub() {
    # shellcheck disable=SC2016  # $* and $f belong to the stub, not to us
    printf '#!/usr/bin/env bash\necho "%s $*" >> "%s"\nfor f; do :; done\necho "edited by %s" >> "$f"\n' \
        "$2" "$log" "$2" > "$1"
    chmod +x "$1"
}
for name in code vim gedit mvim; do
    make_stub "$stubs/$name" "$name"
done
make_stub "$test_root/remote-cli/code-server" remote-cli
make_stub "$test_root/editor" EDITOR
# open(1) stub: the file is the argument after "-a TextEdit".
# shellcheck disable=SC2016  # $1 and $2 belong to the stub
printf '#!/usr/bin/env bash\necho "open $*" >> "%s"\nwhile [ "$1" != TextEdit ]; do shift; done\necho "edited by textedit" >> "$2"\n' \
    "$log" > "$stubs/open"
chmod +x "$stubs/open"

fail() { echo "FAIL: $*" >&2; exit 1; }

# run [VAR=VALUE...] -- ARGS...: run cc-edit in a clean environment.
run() {
    local envs=()
    while [ "$1" != -- ]; do envs+=("$1"); shift; done
    shift
    env -i HOME="$test_root/home" PATH="$stubs:/usr/bin:/bin" EDITOR="$test_root/editor" \
        ${envs[@]+"${envs[@]}"} "$cc_edit" "$@"
}

# edit_with [VAR=VALUE...]: edit a fresh prompt; print the editor log line.
edit_with() {
    : > "$log"
    printf 'edit me\n' > "$test_root/prompt.md"
    run "$@" -- "$test_root/prompt.md" 2> "$test_root/stderr" || fail "cc-edit exited $?: $(cat "$test_root/stderr")"
    cat "$log"
}

expect() {   # expect DESCRIPTION ACTUAL PATTERN
    # shellcheck disable=SC2254  # PATTERN is a glob on purpose
    case "$2" in
        $3) echo "ok   $1" ;;
        *)  fail "$1: got '$2', want '$3'" ;;
    esac
}

conf="$test_root/home/.config/cc-edit/config"
drafts="$test_root/home/.claude-prompts"

# Default: VS Code, new window, scratch profile; draft kept; edit written back.
out=$(edit_with)
expect "default is code" "$out" "code --new-window --wait --profile scratch $drafts/*.md"
expect "edit written back" "$(tail -n 1 "$test_root/prompt.md")" "edited by code"
draft=$(ls "$drafts"/*.md)
cmp -s "$draft" "$test_root/prompt.md" || fail "draft differs from the written-back file"
echo "ok   draft persisted"

# --config KEY=VALUE validates and saves.
run -- --config editor=vim > /dev/null
expect "config saved" "$(cat "$conf")" "*editor=vim*"
expect "editor=vim" "$(edit_with)" "vim $drafts/*.md"
run -- --config editor=vim > /dev/null
expect "config keeps one line per key" "$(grep -c '^editor=' "$conf")" "1"
if run -- --config editor=textedit > /dev/null 2>&1; then fail "textedit accepted on Linux"; fi
if run -- --config editor=nano > /dev/null 2>&1; then fail "unknown editor accepted"; fi
if run -- --config color=red > /dev/null 2>&1; then fail "unknown key accepted"; fi
expect "rejected values leave config alone" "$(grep '^editor=' "$conf")" "editor=vim"
echo "ok   invalid --config values rejected"

# The env var overrides the config file.
expect "CC_EDIT_EDITOR override" "$(edit_with CC_EDIT_EDITOR=code)" "code *"

# gedit needs a display; without one cc-edit falls back to $EDITOR.
run -- --config editor=gedit > /dev/null
expect "gedit with a display" "$(edit_with DISPLAY=:0)" "gedit --standalone --wait $drafts/*.md"
expect "gedit without a display" "$(edit_with)" "EDITOR $drafts/*.md"
grep -q "gedit is not available here" "$test_root/stderr" || fail "no fallback warning"
echo "ok   fallback warning"

# A hand-edited, invalid value falls back to code with a warning.
printf 'editor=textedit\n' > "$conf"
expect "invalid config value" "$(edit_with)" "code *"
grep -q "unknown editor 'textedit'" "$test_root/stderr" || fail "no invalid-value warning"

# macOS editors (CC_EDIT_OS simulates macOS).
expect "textedit on macOS" "$(edit_with CC_EDIT_OS=Darwin)" "open -W -n -a TextEdit $drafts/*.md --args *"
expect "textedit edit written back" "$(tail -n 1 "$test_root/prompt.md")" "edited by textedit"
printf 'editor=macvim\n' > "$conf"
expect "macvim on macOS" "$(edit_with CC_EDIT_OS=Darwin)" "mvim -f $drafts/*.md"
rm -f "$stubs/mvim"
expect "macvim missing" "$(edit_with CC_EDIT_OS=Darwin)" "EDITOR *"
make_stub "$stubs/mvim" mvim

# VS Code server terminal: the remote CLI opens a tab, unless remote_editor=vim.
rm -f "$conf"
python3 -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$test_root/ipc.sock"
remote=(PATH="$test_root/remote-cli:$stubs:/usr/bin:/bin" VSCODE_IPC_HOOK_CLI="$test_root/ipc.sock")
expect "remote tab" "$(edit_with "${remote[@]}")" "remote-cli --wait $drafts/*.md"
run -- --config remote_editor=vim > /dev/null
expect "remote_editor=vim" "$(edit_with "${remote[@]}")" "vim $drafts/*.md"
expect "stale socket uses editor" "$(edit_with "${remote[@]/ipc.sock/gone.sock}")" "code *"

# A failing editor: exit status propagates and the prompt is left untouched.
printf '#!/usr/bin/env bash\nexit 3\n' > "$stubs/code"
printf 'keep\n' > "$test_root/prompt.md"
status=0
run -- "$test_root/prompt.md" 2> /dev/null || status=$?
expect "editor exit status" "$status" "3"
expect "prompt untouched" "$(cat "$test_root/prompt.md")" "keep"
make_stub "$stubs/code" code

# Drafts older than the retention period are pruned.
touch -t 202001010000 "$drafts/old.md"
edit_with > /dev/null
[ ! -e "$drafts/old.md" ] || fail "old draft not pruned"
echo "ok   old drafts pruned"

# --show reports the settings and the editor this terminal would use.
show=$(run CC_EDIT_EDITOR=vim -- --show)
expect "--show" "$show" "*editor=vim*[from CC_EDIT_EDITOR]*this terminal uses: vim*"

# Interactive --config needs a terminal.
if run -- --config < /dev/null > /dev/null 2>&1; then fail "interactive --config without a tty"; fi
echo "ok   interactive --config refuses without a terminal"

# Interactive --config with a terminal (needs script(1) from util-linux).
if script -qc true /dev/null > /dev/null 2>&1; then
    rm -f "$conf"
    printf '3\n2\n' | env -i HOME="$test_root/home" PATH="$stubs:/usr/bin:/bin" \
        script -qc "$cc_edit --config" /dev/null > "$test_root/menu" 2>&1
    expect "menu choice saved" "$(grep -E '^(editor|remote_editor)=' "$conf" | tr '\n' ' ')" "editor=vim remote_editor=vim "
    grep -q "1) code" "$test_root/menu" || fail "menu not shown"
fi

echo "PASS: cc-edit"
