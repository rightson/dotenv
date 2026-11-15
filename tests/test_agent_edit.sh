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
log="$test_root/editor.log"
conf="$home/.config/agent-edit/config"
drafts="$home/.agent-prompts"
mkdir -p "$home" "$stubs" "$remote_cli"

# make_stub PATH NAME [STATUS]: an editor that logs "NAME args", appends
# "edited by NAME" to its last argument, and exits with STATUS.
make_stub() {
    mkdir -p "$(dirname "$1")"
    # shellcheck disable=SC2016  # $* and $f belong to the stub, not to us
    printf '#!/usr/bin/env bash\necho "%s $*" >> "%s"\nfor f; do :; done\necho "edited by %s" >> "$f"\nexit %s\n' \
        "$2" "$log" "$2" "${3:-0}" > "$1"
    chmod +x "$1"
}
for name in code vim gedit mvim mate; do
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
    env -i HOME="$home" PATH="$stubs:/usr/bin:/bin" EDITOR="$test_root/editor" \
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

stderr_has() {   # stderr_has DESCRIPTION TEXT: the last run warned TEXT
    grep -qF "$2" "$test_root/stderr" || fail "$1: no '$2' in: $(cat "$test_root/stderr")"
    echo "ok   $1"
}

# --- local editors ------------------------------------------------------------

# Default on Linux: gedit; draft kept; edit written back.
expect "default is gedit" "$(edit_with)" "gedit --standalone --wait $drafts/*.md"
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
for bad in editor=textedit editor=textmate editor=nano color=red editor; do
    if run -- --config "$bad" > /dev/null 2>&1; then fail "--config $bad accepted on Linux"; fi
done
if run -- --config editor=code remote_editor=tab > /dev/null 2>&1; then fail "remote_editor=tab accepted"; fi
expect "rejected values save nothing" "$(grep '^editor=' "$conf")" "editor=vim"

# VS Code is selected through the config file or the env var.
run -- --config editor=code > /dev/null
expect "editor=code" "$(edit_with)" "code --new-window --wait --profile scratch $drafts/*.md"
run -- --config editor=vim > /dev/null

# The env var overrides the config file.
expect "AGENT_EDIT_EDITOR override" "$(edit_with AGENT_EDIT_EDITOR=code)" "code *"

# GUI editors need a display on Linux; then agent-edit falls back to $EDITOR.
rm -f "$conf"
expect "gedit without a display" "$(edit_with DISPLAY=)" "EDITOR $drafts/*.md"
stderr_has "fallback warning" "gedit is not available here; using $test_root/editor"
run -- --config editor=code > /dev/null 2>&1
expect "code without a display" "$(edit_with DISPLAY=)" "EDITOR *"
expect "code under WSL needs no display" "$(edit_with DISPLAY= WSL_DISTRO_NAME=Ubuntu)" "code *"

# A vim or nvim fallback repeats the notice on its message line.
make_stub "$stubs/nvim" nvim
expect "notice inside nvim" "$(edit_with DISPLAY= EDITOR="$stubs/nvim")" \
    "nvim -c autocmd VimEnter \\* echomsg 'agent-edit: code is not available here' $drafts/*.md"

# A hand-edited, invalid value falls back to the platform default with a warning.
printf 'editor=textedit\n' > "$conf"
expect "invalid config value" "$(edit_with)" "gedit *"
stderr_has "invalid value warning" "unknown editor 'textedit' (choose from: gedit code vim); using gedit"

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
expect "textmate over SSH" "$(edit_with "${mac[@]}" SSH_CONNECTION='1.2.3.4 5 6.7.8.9 22')" "EDITOR *"
stderr_has "textmate fallback reason" "textmate is not available here (run: dotenv patch to install TextMate)"
if [ -n "$have_mate" ]; then
    echo "skip textmate missing: TextMate is installed on this machine"
else
    rm -f "$stubs/mate"
    expect "textmate missing" "$(edit_with "${mac[@]}")" "EDITOR *"
    stderr_has "textmate missing reason" "textmate is not available here (run: dotenv patch to install TextMate)"
    make_stub "$stubs/mate" mate
fi
printf 'editor=textedit\n' > "$conf"
expect "textedit is invalid on macOS" "$(edit_with "${mac[@]}")" "mate *"
stderr_has "textedit warning" "unknown editor 'textedit' (choose from: textmate code macvim vim); using textmate"
if run "${mac[@]}" -- --config editor=textedit > /dev/null 2>&1; then fail "--config editor=textedit accepted on macOS"; fi
rm -f "$conf"
expect "--show on macOS" "$(run "${mac[@]}" -- --show)" "*editor=textmate  (options: textmate code macvim vim)*this terminal uses: textmate"
printf 'editor=macvim\n' > "$conf"
expect "macvim" "$(edit_with "${mac[@]}")" "mvim -f $drafts/*.md"
if [ -x /opt/homebrew/bin/mvim ] || [ -x /usr/local/bin/mvim ] || [ -x /Applications/MacVim.app/Contents/bin/mvim ]; then
    echo "skip macvim missing: MacVim is installed on this machine"
else
    rm -f "$stubs/mvim"
    expect "macvim missing" "$(edit_with "${mac[@]}")" "EDITOR *"
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
server=(PATH="$remote_cli:$stubs:/usr/bin:/bin" VSCODE_IPC_HOOK_CLI="$test_root/ipc.sock" DISPLAY=)
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
expect "stale terminal" "$(edit_with "${server[@]/ipc.sock/gone.sock}")" "EDITOR *"
stderr_has "stale terminal warning" "gedit is not available here"
mv "$remote_cli/code" "$remote_cli/code-server"

# Server unreachable (the CLI fails): fall back to $EDITOR on the same draft.
make_stub "$remote_cli/code-server" remote-cli 1
expect "unreachable server" "$(edit_with "${server[@]}")" "remote-cli --wait *EDITOR *"
stderr_has "unreachable server warning" "VS Code server of this terminal is not reachable"
expect "fallback edit written back" "$(tail -n 1 "$test_root/prompt.md")" "edited by EDITOR"
make_stub "$remote_cli/code-server" remote-cli

# Desktop VS Code terminal: a live socket, but code is not a server CLI.
printf 'editor=code\n' > "$conf"
expect "desktop VS Code terminal" "$(edit_with VSCODE_IPC_HOOK_CLI="$test_root/ipc.sock")" "code --new-window *"
rm -f "$conf"

# --- failure handling, retention, --show, interactive --config -----------------

# A failing editor: its status propagates and its edit is not copied back.
make_stub "$stubs/gedit" gedit 3
printf 'keep\n' > "$test_root/prompt.md"
status=0
run -- "$test_root/prompt.md" 2> /dev/null || status=$?
expect "editor exit status" "$status" "3"
expect "prompt untouched" "$(cat "$test_root/prompt.md")" "keep"
make_stub "$stubs/gedit" gedit

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
    "*this terminal uses: $test_root/editor (fallback: gedit is not available here)"

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
    menu '3\n2\n'
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
