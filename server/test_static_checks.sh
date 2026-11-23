#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

bash -n server/install.sh
bash -n server/hy2.sh
python3 - <<'PY'
import re
from pathlib import Path

optimize_path = Path("optimize_hihy.py")
compile(optimize_path.read_text(), str(optimize_path), "exec")

hy2_text = Path("server/hy2.sh").read_text()
readme_text = Path("README.md").read_text()
release_version = Path("VERSION").read_text().strip()

hy2_version = re.search(r'^hihyV="(ver([0-9]+)\.([0-9]+))"$', hy2_text, re.M)
readme_version = re.search(r'当前脚本版本：`([0-9]+)\.([0-9]+)\.([0-9]+)`', readme_text)

if not hy2_version or not readme_version:
    raise SystemExit("ASSERT FAILED: could not parse script version from README.md or server/hy2.sh")

if release_version != hy2_version.group(1):
    raise SystemExit(
        "ASSERT FAILED: VERSION and server/hy2.sh hihyV are inconsistent: "
        f"VERSION={release_version} hy2={hy2_version.group(1)}"
    )

normalized_hy2_version = (int(hy2_version.group(2)), 0, int(hy2_version.group(3)))
normalized_readme_version = tuple(int(part) for part in readme_version.groups())

if normalized_hy2_version != normalized_readme_version:
    raise SystemExit(
        "ASSERT FAILED: README.md version and server/hy2.sh hihyV are inconsistent: "
        f"README={readme_version.group(0)} hy2={hy2_version.group(0)}"
    )
PY

if git grep -nE 'empty[s]uns|git[.]io/hysteria[.]sh' -- '*.sh' '*.py' '.github/workflows/*'; then
    printf 'ASSERT FAILED: legacy upstream reference in scripts or workflows\n' >&2
    exit 1
else
    status=$?
    [ "$status" -eq 1 ] || exit "$status"
fi

printf 'All static checks passed.\n'
