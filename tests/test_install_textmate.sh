#!/usr/bin/env bash
# Tests for install_textmate in inc/install.sh. No network and no real
# /Applications: the download is a file:// tarball and the app directories are
# temp directories.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

# shellcheck disable=SC1091
source "$repo_root/inc/install.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

export HOME="$test_root/home"
mkdir -p "$HOME"
system_apps="$test_root/system-apps"
user_apps="$test_root/user-apps"
export TEXTMATE_SYSTEM_APPS="$system_apps" TEXTMATE_USER_APPS="$user_apps"

if [ "$(uname)" != Darwin ]; then
    out=$(install_textmate)
    [ -z "$out" ] || fail "output on a non-macOS system: $out"
    echo "PASS: install_textmate (non-macOS: silent no-op; the rest needs macOS)"
    exit 0
fi

# Fixture: a tarball holding TextMate.app, like the real download.
fixture="$test_root/fixture"
mkdir -p "$fixture/TextMate.app/Contents/MacOS"
echo fake > "$fixture/TextMate.app/Contents/MacOS/mate"
chmod +x "$fixture/TextMate.app/Contents/MacOS/mate"
tar -cjf "$test_root/TextMate.tbz" -C "$fixture" TextMate.app

reset() { rm -rf "$system_apps" "$user_apps"; mkdir -p "$system_apps"; }

# Already installed (either app directory): skip, no download.
reset
mkdir -p "$user_apps/TextMate.app"
export TEXTMATE_URL="file://$test_root/missing.tbz"
out=$(install_textmate)
case "$out" in *"TextMate is already installed, skipping"*) ;; *) fail "no skip message: $out" ;; esac
echo "ok   already installed is skipped"

# Download failure: returns 0, installs nothing.
reset
status=0
out=$(install_textmate) || status=$?
[ "$status" = 0 ] || fail "download failure returned $status"
case "$out" in *"Could not download TextMate (offline?)"*) ;; *) fail "no offline message: $out" ;; esac
[ -z "$(ls -A "$system_apps")" ] || fail "installed something after a failed download"
[ ! -e "$user_apps/TextMate.app" ] || fail "installed to the user dir after a failed download"
echo "ok   download failure installs nothing and returns 0"

# Fixture download: the app lands in the system apps dir when writable.
reset
export TEXTMATE_URL="file://$test_root/TextMate.tbz"
install_textmate > "$test_root/out"
[ -x "$system_apps/TextMate.app/Contents/MacOS/mate" ] || fail "app not installed: $(cat "$test_root/out")"
grep -qF "$system_apps/TextMate.app" "$test_root/out" || fail "install location not printed"
echo "ok   installed to the system apps dir"

# System dir not writable: the app lands in the user apps dir.
reset
chmod 555 "$system_apps"
if [ -w "$system_apps" ]; then
    echo "skip user apps dir: the system dir is writable (running as root?)"
else
    install_textmate > "$test_root/out"
    [ -x "$user_apps/TextMate.app/Contents/MacOS/mate" ] || fail "app not installed to the user dir"
    [ -z "$(ls -A "$system_apps")" ] || fail "wrote to the read-only dir"
    echo "ok   installed to the user apps dir"
fi
chmod 755 "$system_apps"

echo "PASS: install_textmate"
