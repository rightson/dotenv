#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

export ENV_ROOT="$repo_root"
source "$repo_root/inc/aliases.sh"

mkdir -p "$test_root/create/bin"
printf '#!/usr/bin/env bash\nmkdir -p "$3/bin"\nprintf "#!/usr/bin/env bash\\nexit 0\\n" > "$3/bin/pip"\nchmod +x "$3/bin/pip"\n' > "$test_root/create/bin/python3"
chmod +x "$test_root/create/bin/python3"
(
    cd "$test_root/create"
    PATH="$test_root/create/bin:$PATH" _project_venv_create
    test -x .venv/bin/pip
)

mkdir -p "$test_root/legacy/venv/bin"
printf 'export VIRTUAL_ENV="legacy-venv"\n' > "$test_root/legacy/venv/bin/activate"
legacy_output=$(
    (
        cd "$test_root/legacy"
        _project_venv_activate
        test "$VIRTUAL_ENV" = "legacy-venv"
    ) 2>&1
)
case "$legacy_output" in
    *"Run venv.migrate"*) ;;
    *) echo "legacy activation warning was not emitted" >&2; exit 1 ;;
esac

mkdir -p "$test_root/preferred/.venv/bin" "$test_root/preferred/venv/bin"
printf 'export VIRTUAL_ENV="preferred-dot-venv"\n' > "$test_root/preferred/.venv/bin/activate"
printf 'export VIRTUAL_ENV="legacy-venv"\n' > "$test_root/preferred/venv/bin/activate"
(
    cd "$test_root/preferred"
    _project_venv_activate
    test "$VIRTUAL_ENV" = "preferred-dot-venv"
)

mkdir -p "$test_root/migrate"
(
    cd "$test_root/migrate"
    python3 -m venv venv
    python3 "$repo_root/bin/venv-migrate.py"
    test ! -e venv
    test ! -e venv.migrated-backup
    test -f .venv/bin/activate
    .venv/bin/python -c 'import sys; assert sys.prefix.endswith(".venv")'
)

echo "venv helper tests passed"
