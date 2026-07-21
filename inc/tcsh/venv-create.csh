# Create a project virtual environment (defaults to ./.venv).
# Mirrors the bash `venv.create` helper; an explicit name is honored.

set _venv_name = ".venv"
if ( $#argv > 0 ) then
    if ( "$argv[1]" != "" ) then
        set _venv_name = "$argv[1]"
    endif
endif

python3 -m venv "$_venv_name" && "$_venv_name/bin/pip" install --upgrade pip
unset _venv_name
