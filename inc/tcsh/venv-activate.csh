# Activate a project virtual environment (defaults to ./.venv).
# Mirrors the bash `venv.activate` helper: an explicit name skips the legacy
# ./venv fallback, which only applies to the default ./.venv.

set _venv_name = ".venv"
if ( $#argv > 0 ) then
    if ( "$argv[1]" != "" ) then
        set _venv_name = "$argv[1]"
    endif
endif

# Precompute legacy eligibility so the branches below never unset a variable
# that a later `else if` condition still needs to read.
set _venv_default = 0
if ( "$_venv_name" == ".venv" ) set _venv_default = 1

if ( -f "$_venv_name/bin/activate.csh" ) then
    source "$_venv_name/bin/activate.csh"
else if ( $_venv_default && -f venv/bin/activate.csh ) then
    echo "[venv.activate] Warning: legacy ./venv detected; activating it for compatibility."
    echo "[venv.activate] Run venv.migrate, then rerun venv.activate. New environments use ./.venv."
    source venv/bin/activate.csh
else
    echo "[venv.activate] Virtual environment $_venv_name was not found. Run venv.create first."
    false
endif

unset _venv_name _venv_default
