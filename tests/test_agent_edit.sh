#!/usr/bin/env bash
# Tests for bin/agent-edit. Every editor is replaced by a stub that logs its
# arguments and appends a line to the file, so no GUI is needed. Runs on
# Linux and macOS (bash 3.2+); the platform is simulated with AGENT_EDIT_OS.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
agent_edit="$repo_root/bin/agent-edit"
test_root=$(mktemp -d)
listener=""
trap '[ -z "$listener" ] || kill "$listener" 2>/dev/null; rm -rf "$test_root"' EXIT

home="$test_root/home"
stubs="$test_root/stubs"
remote_cli="$test_root/server/bin/remote-cli"
tools="$test_root/tools"
log="$test_root/editor.log"
conf="$home/.config/agent-edit/config"
drafts="$home/.agent-prompts"
mkdir -p "$home" "$stubs" "$remote_cli" "$tools"

# agent-edit sees only these system tools, so an editor installed on this
# machine (a real vim, subl, ...) cannot stand in for a stub that a test removed.
for name in bash env sed tail grep mkdir dirname basename mv cp date find cat; do
    ln -s "$(command -v "$name")" "$tools/$name"
done

# make_stub PATH NAME [STATUS]: an editor that logs "NAME args", appends
# "edited by NAME" to its last argument, and exits with STATUS.
make_stub() {
    mkdir -p "$(dirname "$1")"
    # shellcheck disable=SC2016  # $* and $f belong to the stub, not to us
    printf '#!/usr/bin/env bash\necho "%s $*" >> "%s"\nfor f; do :; done\necho "edited by %s" >> "$f"\nexit %s\n' \
        "$2" "$log" "$2" "${3:-0}" > "$1"
    chmod +x "$1"
}
for name in code vim gedit subl gvim mvim mate; do
    make_stub "$stubs/$name" "$name"
done
make_stub "$test_root/editor" EDITOR
make_stub "$remote_cli/code-server" remote-cli

fail() { echo "FAIL: $*" >&2; exit 1; }

# run [VAR=VALUE...] -- ARGS...: run agent-edit in a clean environment that looks
# like a Linux desktop; the VAR=VALUE arguments override it.
run() {
    local envs=()
    while [ "$1" != -- ]; do envs+=("$1"); shift; done
    shift
    env -i HOME="$home" PATH="$stubs:$tools" EDITOR="$test_root/editor" \
        AGENT_EDIT_OS=Linux DISPLAY=:0 ${envs[@]+"${envs[@]}"} "$agent_edit" "$@"
}

# edit_with [VAR=VALUE...]: edit a fresh prompt; print the editor log.
edit_with() {
    : > "$log"
    printf 'edit me\n' > "$test_root/prompt.md"
    run "$@" -- "$test_root/prompt.md" 2> "$test_root/stderr" ||
        fail "agent-edit exited $?: $(cat "$test_root/stderr")"
    cat "$log"
}

# expect DESCRIPTION ACTUAL PATTERN: PATTERN is a glob; escape literal [ ] * ?.
expect() {
    # shellcheck disable=SC2254  # PATTERN is a glob on purpose
    case "$2" in
        $3) echo "ok   $1" ;;
        *)  fail "$1: got '$2', want '$3'" ;;
    esac
}

# tried: the editors the last run started, in order, e.g. "gedit subl ".
tried() { cut -d' ' -f1 "$log" | tr '\n' ' '; }

stderr_has() {   # stderr_has DESCRIPTION TEXT: the last run warned TEXT
    grep -qF "$2" "$test_root/stderr" || fail "$1: no '$2' in: $(cat "$test_root/stderr")"
    echo "ok   $1"
}

# --- local editors ------------------------------------------------------------

# Default on Linux: gedit; draft kept; edit written back.
expect "default is gedit" "$(edit_with)" "gedit --standalone $drafts/*.md"
expect "edit written back" "$(tail -n 1 "$test_root/prompt.md")" "edited by gedit"
draft=$(ls "$drafts"/*.md)
cmp -s "$draft" "$test_root/prompt.md" || fail "draft differs from the written-back file"
echo "ok   draft persisted"

# --config KEY=VALUE validates and saves.
run -- --config editor=vim > /dev/null
expect "config saved" "$(cat "$conf")" "*editor=vim*"
expect "editor=vim" "$(edit_with)" "vim $drafts/*.md"
run -- --config editor=vim > /dev/null
expect "config keeps one line per key" "$(grep -c '^editor=' "$conf")" "1"
for bad in editor=textedit editor=textmate editor=macvim editor=nano color=red editor; do
    if run -- --config "$bad" > /dev/null 2>&1; then fail "--config $bad accepted on Linux"; fi
done
if run -- --config editor=code remote_editor=tab > /dev/null 2>&1; then fail "remote_editor=tab accepted"; fi
expect "rejected values save nothing" "$(grep '^editor=' "$conf")" "editor=vim"
run -- --config editor=subl > /dev/null
expect "editor=subl" "$(edit_with)" "subl --new-window --wait $drafts/*.md"
run -- --config editor=gvim > /dev/null
expect "editor=gvim" "$(edit_with)" "gvim -f $drafts/*.md"
run -- --config editor=vim > /dev/null

# VS Code is selected through the config file or the env var.
run -- --config editor=code > /dev/null
expect "editor=code" "$(edit_with)" "code --new-window --wait --profile scratch $drafts/*.md"
run -- --config editor=vim > /dev/null

# The env var overrides the config file.
expect "AGENT_EDIT_EDITOR override" "$(edit_with AGENT_EDIT_EDITOR=code)" "code *"

# GUI editors need a display on Linux; without one, agent-edit ends up in vim,
# which repeats the first cause on its message line.
rm -f "$conf"
expect "gedit without a display" "$(edit_with DISPLAY=)" \
    "vim -c autocmd VimEnter \\* echomsg 'agent-edit: gedit needs a display' $drafts/*.md"
stderr_has "first skip explained" "gedit needs a display; trying subl"
stderr_has "last skip explained" "gvim needs a display; trying vim"
run -- --config editor=code > /dev/null 2>&1
expect "code without a display" "$(edit_with DISPLAY=)" "vim *"
expect "code under WSL needs no display" "$(edit_with DISPLAY= WSL_DISTRO_NAME=Ubuntu)" "code *"

# Without vim, the end of the line is $EDITOR; vim and nvim repeat the notice.
make_stub "$test_root/nvim/nvim" nvim
expect "notice inside nvim" "$(edit_with DISPLAY= PATH="$tools" EDITOR="$test_root/nvim/nvim")" \
    "nvim -c autocmd VimEnter \\* echomsg 'agent-edit: code needs a display' $drafts/*.md"
stderr_has "vim missing explained" "vim is not installed; trying $test_root/nvim/nvim"
expect "no vim: \$EDITOR" "$(edit_with DISPLAY= PATH="$tools")" "EDITOR $drafts/*.md"

# A hand-edited, invalid value falls back to the platform default with a warning.
printf 'editor=textedit\n' > "$conf"
expect "invalid config value" "$(edit_with)" "gedit *"
stderr_has "invalid value warning" "unknown editor 'textedit' (choose from: gedit subl code gvim vim); using gedit"

# --- macOS editors (AGENT_EDIT_OS=Darwin) -----------------------------------------

mac=(AGENT_EDIT_OS=Darwin DISPLAY=)
have_mate=""
for m in /Applications/TextMate.app "$HOME/Applications/TextMate.app"; do
    [ -d "$m" ] && have_mate=1
done
rm -f "$conf"
expect "macOS default is textmate" "$(edit_with "${mac[@]}")" "mate -w $drafts/*.md"
expect "textmate edit written back" "$(tail -n 1 "$test_root/prompt.md")" "edited by mate"
stderr_has "textmate notice" "opened in TextMate; save, then close the window to return"
expect "textmate over SSH" "$(edit_with "${mac[@]}" SSH_CONNECTION='1.2.3.4 5 6.7.8.9 22')" "vim *"
stderr_has "textmate over SSH reason" "textmate cannot open a window in an SSH session; trying subl"
if [ -n "$have_mate" ]; then
    echo "skip textmate missing: TextMate is installed on this machine"
else
    rm -f "$stubs/mate"
    expect "textmate missing" "$(edit_with "${mac[@]}")" "subl *"
    stderr_has "textmate missing reason" "textmate is not installed (run: dotenv patch to install TextMate); trying subl"
    make_stub "$stubs/mate" mate
fi
printf 'editor=textedit\n' > "$conf"
expect "textedit is invalid on macOS" "$(edit_with "${mac[@]}")" "mate *"
stderr_has "textedit warning" "unknown editor 'textedit' (choose from: textmate subl code macvim vim); using textmate"
for bad in editor=textedit editor=gedit editor=gvim; do
    if run "${mac[@]}" -- --config "$bad" > /dev/null 2>&1; then fail "--config $bad accepted on macOS"; fi
done
rm -f "$conf"
expect "--show on macOS" "$(run "${mac[@]}" -- --show)" "*editor=textmate  (options: textmate subl code macvim vim)*this terminal uses: textmate"
printf 'editor=macvim\n' > "$conf"
expect "macvim" "$(edit_with "${mac[@]}")" "mvim -f $drafts/*.md"
if [ -x /opt/homebrew/bin/mvim ] || [ -x /usr/local/bin/mvim ] || [ -x /Applications/MacVim.app/Contents/bin/mvim ]; then
    echo "skip macvim missing: MacVim is installed on this machine"
else
    rm -f "$stubs/mvim"
    expect "macvim missing" "$(edit_with "${mac[@]}")" "mate *"
    make_stub "$stubs/mvim" mvim
fi
if [ -d "/Applications/Visual Studio Code.app" ]; then
    echo "skip VS Code app bundle: VS Code is installed on this machine"
else
    printf 'editor=code\n' > "$conf"
    rm -f "$stubs/code"
    make_stub "$home/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" bundle-code
    expect "VS Code app bundle" "$(edit_with "${mac[@]}")" "bundle-code --new-window --wait --profile scratch *"
    rm -rf "$home/Applications"
    make_stub "$stubs/code" code
fi

printf 'editor=textedit\n' > "$conf"
expect "--show flags an invalid value" "$(run "${mac[@]}" -- --show)" "*editor=textedit*\\[invalid; textmate is used\\]*"

# --- VS Code server terminals (code-server, Remote-SSH, WSL) -------------------

rm -f "$conf"
python3 -c '
import os, socket, sys
s = socket.socket(socket.AF_UNIX)
s.bind(sys.argv[1])
s.listen(1)
os.close(1)
sys.stdin.read()
' "$test_root/ipc.sock" < /dev/zero > /dev/null &
listener=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -S "$test_root/ipc.sock" ] && break; sleep 0.2; done
server=(PATH="$remote_cli:$stubs:$tools" VSCODE_IPC_HOOK_CLI="$test_root/ipc.sock" DISPLAY=)
expect "remote tab" "$(edit_with "${server[@]}")" "remote-cli --wait $drafts/*.md"
printf 'remote_editor=tab\n' > "$conf"
expect "invalid remote_editor uses the tab" "$(edit_with "${server[@]}")" "remote-cli --wait *"
stderr_has "invalid remote_editor warning" "unknown remote_editor 'tab'"
run -- --config remote_editor=vim > /dev/null 2>&1
expect "remote_editor=vim" "$(edit_with "${server[@]}")" "vim $drafts/*.md"
rm -f "$conf"

# Remote-SSH and WSL name the server CLI "code".
mv "$remote_cli/code-server" "$remote_cli/code"
expect "remote-cli/code" "$(edit_with "${server[@]}")" "remote-cli --wait *"
# Stale terminal (socket gone): the server CLI must not be used as desktop code.
expect "stale terminal" "$(edit_with "${server[@]/ipc.sock/gone.sock}")" "vim *"
stderr_has "stale terminal warning" "gedit needs a display"
mv "$remote_cli/code" "$remote_cli/code-server"

# Server unreachable (the CLI fails): fall back to vim on the same draft.
make_stub "$remote_cli/code-server" remote-cli 1
expect "unreachable server" "$(edit_with "${server[@]}")" "remote-cli --wait *vim *"
stderr_has "unreachable server warning" "the VS Code server of this terminal is not reachable; trying vim"
expect "fallback edit written back" "$(tail -n 1 "$test_root/prompt.md")" "edited by vim"
make_stub "$remote_cli/code-server" remote-cli

# Desktop VS Code terminal: a live socket, but code is not a server CLI.
printf 'editor=code\n' > "$conf"
expect "desktop VS Code terminal" "$(edit_with VSCODE_IPC_HOOK_CLI="$test_root/ipc.sock")" "code --new-window *"
rm -f "$conf"

# --- fallback chain: an editor that fails hands the same draft to the next -------

# A GUI editor that exits non-zero (gedit 41 segfaults: 139) is replaced by
# the next one, on the same draft, and the run still succeeds.
make_stub "$stubs/gedit" gedit 139
expect "crashed gedit: subl takes over" "$(edit_with)" \
    "gedit --standalone $drafts/*.md
subl --new-window --wait $drafts/*.md"
stderr_has "crash explained" "gedit exited with status 139; trying subl"
expect "one draft for every editor" "$(sed 's/.* //' "$log" | sort -u | wc -l | tr -d ' ')" "1"
expect "text saved before the crash is kept" "$(tr '\n' '|' < "$test_root/prompt.md")" \
    "edit me|edited by gedit|edited by subl|"

# Editors that are not installed are skipped, each with its own line.
rm -f "$stubs/subl" "$stubs/gvim"
edit_with > /dev/null
expect "uninstalled editors are skipped" "$(tried)" "gedit code "
stderr_has "skip explained" "subl is not installed; trying code"

# When every GUI editor fails, vim in the terminal is the end of the line.
make_stub "$stubs/subl" subl 1
make_stub "$stubs/code" code 1
make_stub "$stubs/gvim" gvim 2
edit_with > /dev/null
expect "Linux order" "$(tried)" "gedit subl code gvim vim "
expect "vim shows the first cause" "$(tail -n 1 "$log")" \
    "vim -c autocmd VimEnter \\* echomsg 'agent-edit: gedit exited with status 139' $drafts/*.md"
expect "vim edit written back" "$(tail -n 1 "$test_root/prompt.md")" "edited by vim"

# The configured editor goes first; the others follow in the fixed order.
edit_with AGENT_EDIT_EDITOR=code > /dev/null
expect "order starting from code" "$(tried)" "code gedit subl gvim vim "

# macOS: textmate, subl, code, macvim, vim.
make_stub "$stubs/mate" mate 1
make_stub "$stubs/mvim" mvim 1
edit_with "${mac[@]}" > /dev/null
expect "macOS order" "$(tried)" "mate subl code mvim vim "
for name in gedit subl code gvim mate mvim; do make_stub "$stubs/$name" "$name"; done

# vim is the end of the line: its failure (e.g. :cq) is the user's abort. The
# status propagates, nothing else opens and the prompt is not overwritten.
make_stub "$stubs/vim" vim 3
: > "$log"
printf 'keep\n' > "$test_root/prompt.md"
status=0
run AGENT_EDIT_EDITOR=vim -- "$test_root/prompt.md" 2> /dev/null || status=$?
expect "vim exit status" "$status" "3"
expect "nothing after vim" "$(tried)" "vim "
expect "prompt untouched" "$(cat "$test_root/prompt.md")" "keep"
make_stub "$stubs/vim" vim

# --- retention, --show, interactive --config -------------------------------------

# Drafts older than the retention period are pruned; a bad period prunes nothing.
touch -t 202001010000 "$drafts/old.md"
edit_with AGENT_EDIT_KEEP=forever > /dev/null
[ -e "$drafts/old.md" ] || fail "AGENT_EDIT_KEEP=forever pruned a draft"
stderr_has "bad AGENT_EDIT_KEEP warning" "AGENT_EDIT_KEEP='forever' is not a number"
edit_with > /dev/null
[ ! -e "$drafts/old.md" ] || fail "old draft not pruned"
echo "ok   old drafts pruned"

# --show reports the settings and the editor this terminal would use.
expect "--show" "$(run AGENT_EDIT_EDITOR=vim -- --show)" \
    "*editor=vim*\\[from AGENT_EDIT_EDITOR\\]*this terminal uses: vim"
expect "--show fallback" "$(run DISPLAY= -- --show)" \
    "*this terminal uses: vim (fallback: gedit needs a display)"
expect "--show order" "$(run AGENT_EDIT_EDITOR=code -- --show)" "*tries in order: code gedit subl gvim vim*"

# Interactive --config needs a terminal.
if run -- --config < /dev/null > /dev/null 2>&1; then fail "interactive --config without a tty"; fi
echo "ok   interactive --config refuses without a terminal"

# Interactive --config with a terminal (needs util-linux script(1)).
if script -qc true /dev/null > /dev/null 2>&1; then
    menu() {   # menu INPUT: answer the --config menu with INPUT
        printf '%b' "$1" | env -i HOME="$home" PATH="$stubs:/usr/bin:/bin" AGENT_EDIT_OS=Linux DISPLAY=:0 \
            script -qc "$agent_edit --config" /dev/null > "$test_root/menu" 2>&1
    }
    rm -f "$conf"
    menu '5\n2\n'
    expect "menu choice saved" "$(grep -E '^(editor|remote_editor)=' "$conf" | tr '\n' ' ')" "editor=vim remote_editor=vim "
    grep -q "1) gedit" "$test_root/menu" || fail "menu not shown"
    printf 'editor=textedit\n' > "$conf"
    menu '\n\n'
    expect "Enter replaces an invalid saved value with the default" "$(grep '^editor=' "$conf")" "editor=gedit"
    grep -q "saved editor 'textedit' is not valid here" "$test_root/menu" || fail "no invalid-value note"
else
    echo "skip interactive --config: no util-linux script(1)"
fi

# --- drafts folder migration (~/.claude-prompts -> ~/.agent-prompts) -------------

old_drafts="$home/.claude-prompts"
reset_drafts() { rm -rf "$drafts" "$old_drafts" "$test_root/custom"; }

reset_drafts
mkdir "$old_drafts" && echo old > "$old_drafts/kept.md"
edit_with > /dev/null
[ -f "$drafts/kept.md" ] && [ ! -e "$old_drafts" ] || fail "old drafts folder not migrated"
stderr_has "migration notice" "moved $old_drafts to $drafts"

reset_drafts
mkdir "$old_drafts" && echo old > "$old_drafts/kept.md"
edit_with AGENT_EDIT_DIR="$test_root/custom" > /dev/null
[ -f "$old_drafts/kept.md" ] && [ ! -e "$drafts" ] || fail "migrated although AGENT_EDIT_DIR is set"
[ ! -e "$test_root/custom/kept.md" ] || fail "AGENT_EDIT_DIR received the old drafts"
echo "ok   no migration with AGENT_EDIT_DIR"

reset_drafts
mkdir "$old_drafts" "$drafts" && echo old > "$old_drafts/kept.md"
edit_with > /dev/null
[ -f "$old_drafts/kept.md" ] && [ ! -e "$drafts/kept.md" ] || fail "migrated onto an existing new folder"
echo "ok   no migration when the new folder exists"

echo "PASS: agent-edit"
