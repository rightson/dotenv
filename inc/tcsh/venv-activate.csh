if ( -f .venv/bin/activate.csh ) then
    source .venv/bin/activate.csh
else if ( -f venv/bin/activate.csh ) then
    echo "[venv.activate] Warning: legacy ./venv detected; activating it for compatibility."
    echo "[venv.activate] Run venv.migrate, then rerun venv.activate. New environments use ./.venv."
    source venv/bin/activate.csh
else
    echo "[venv.activate] Virtual environment .venv was not found. Run venv.create first."
    false
endif
