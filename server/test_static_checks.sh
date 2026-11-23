#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

assert_contains() {
    local file="$1"
    local expected="$2"
    local message="$3"

    if ! grep -Fq "$expected" "$file"; then
        printf 'ASSERT FAILED: %s\nMissing text: %s\nFile: %s\n' "$message" "$expected" "$file" >&2
        exit 1
    fi
}

assert_not_contains() {
    local file="$1"
    local unexpected="$2"
    local message="$3"

    if grep -Fq "$unexpected" "$file"; then
        printf 'ASSERT FAILED: %s\nUnexpected text: %s\nFile: %s\n' "$message" "$unexpected" "$file" >&2
        exit 1
    fi
}

bash -n server/install.sh
bash -n server/hy2.sh
python3 - <<'PY'
import re
from pathlib import Path

optimize_path = Path("optimize_hihy.py")
compile(optimize_path.read_text(), str(optimize_path), "exec")

hy2_text = Path("server/hy2.sh").read_text()
readme_text = Path("README.md").read_text()

hy2_version = re.search(r'^hihyV="ver([0-9]+)\.([0-9]+)"', hy2_text, re.M)
readme_version = re.search(r'当前脚本版本：`([0-9]+)\.([0-9]+)\.([0-9]+)`', readme_text)

if not hy2_version or not readme_version:
    raise SystemExit("ASSERT FAILED: could not parse script version from README.md or server/hy2.sh")

normalized_hy2_version = (int(hy2_version.group(1)), 0, int(hy2_version.group(2)))
normalized_readme_version = tuple(int(part) for part in readme_version.groups())

if normalized_hy2_version != normalized_readme_version:
    raise SystemExit(
        "ASSERT FAILED: README.md version and server/hy2.sh hihyV are inconsistent: "
        f"README={readme_version.group(0)} hy2={hy2_version.group(0)}"
    )
PY

assert_contains server/install.sh 'HIHY_MIRROR_URL=' 'bootstrap installer should have a mirror fallback'
assert_contains server/install.sh 'mktemp' 'bootstrap installer should download to a temporary file first'
assert_contains server/install.sh 'mv "$tmp_output" "$output"' 'bootstrap installer should atomically replace the launcher'

assert_contains server/hy2.sh 'was_running="false"' 'core update should track whether service was running'
assert_contains server/hy2.sh 'Hysteria core update aborted: process did not stop cleanly.' 'core update should abort if the old process cannot stop'
assert_contains server/hy2.sh 'msg=$(/etc/rc.d/hihy status 2>/dev/null || true)' 'core update should tolerate stopped rc.d services'
assert_contains server/hy2.sh 'downloadHysteriaCore' 'core update should download the core outside the running-service branch'
assert_contains server/hy2.sh 'realm.ipMode' 'ver1.09 Realm ipMode support should be present'
assert_contains server/hy2.sh 'realm.portMapping.enabled' 'ver1.09 Realm port mapping support should be present'
assert_contains server/hy2.sh 'addOrUpdateYaml "$client_configfile" "lazy" "false"' 'ver1.09 client lazy default should be false'
assert_contains server/hy2.sh 'tls.pinSHA256' 'self-signed certificate pinSHA256 support should be present'
assert_contains server/hy2.sh 'proxies[0].fingerprint' 'ClashMeta fingerprint support should be present'
assert_contains server/hy2.sh 'realmShare=$(echo "${realmURI}"' 'Realm share link generation should be present'
assert_contains server/hy2.sh 'tls.sniGuard" "disable"' 'Realm mode should disable sniGuard when needed'
assert_not_contains server/hy2.sh 'version:v${hihy_remote}' 'hihy update notice should not add a second v prefix'

for forbidden in \
    "empty""suns" \
    "github.com/empty""suns" \
    "raw.githubusercontent.com/empty""suns" \
    "cdn.jsdelivr.net/gh/empty""suns" \
    "git"".io/hysteria.sh"; do
    if git grep -n "$forbidden" -- . >/tmp/hihy-forbidden-grep.$$ 2>/dev/null; then
        printf 'ASSERT FAILED: forbidden legacy reference remains: %s\n' "$forbidden" >&2
        cat /tmp/hihy-forbidden-grep.$$ >&2
        rm -f /tmp/hihy-forbidden-grep.$$
        exit 1
    fi
    rm -f /tmp/hihy-forbidden-grep.$$
done

printf 'All static checks passed.\n'
