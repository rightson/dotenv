#!/bin/tcsh -f

set test_root = "$1"
setenv ENV_ROOT "$2"
set prompt = "% "
cd "$test_root"

source "$ENV_ROOT/inc/tcsh/venv-activate.csh"
if ( "$VIRTUAL_ENV" != "$test_root/venv" ) then
    echo "tcsh legacy venv activation failed"
    exit 1
endif

echo "tcsh venv helper test passed"
