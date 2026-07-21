#!/bin/tcsh -f
# Standalone test for the tcsh venv.activate helper. Run with: tcsh -f tests/test_venv_tcsh.csh

set script_dir = `dirname "$0"`
setenv ENV_ROOT `cd "$script_dir/.." && pwd`
set test_root = `mktemp -d`
set prompt = "% "

# Fixtures: a legacy ./venv and a named ./myenv environment.
mkdir -p "$test_root/legacy/venv/bin"
echo 'setenv VIRTUAL_ENV "'"$test_root"'/legacy/venv"' > "$test_root/legacy/venv/bin/activate.csh"
mkdir -p "$test_root/named/myenv/bin"
echo 'setenv VIRTUAL_ENV "'"$test_root"'/named/myenv"' > "$test_root/named/myenv/bin/activate.csh"

# Default (.venv) with only a legacy ./venv present activates it with a warning.
cd "$test_root/legacy"
set argv = ()
source "$ENV_ROOT/inc/tcsh/venv-activate.csh"
if ( "$VIRTUAL_ENV" != "$test_root/legacy/venv" ) then
    echo "tcsh legacy venv activation failed"
    rm -rf "$test_root"
    exit 1
endif

# An explicit name activates that environment (no legacy fallback).
cd "$test_root/named"
set argv = ()
source "$ENV_ROOT/inc/tcsh/venv-activate.csh" myenv
if ( "$VIRTUAL_ENV" != "$test_root/named/myenv" ) then
    echo "tcsh named venv activation failed"
    rm -rf "$test_root"
    exit 1
endif

rm -rf "$test_root"
echo "tcsh venv helper test passed"
