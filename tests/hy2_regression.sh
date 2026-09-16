#!/usr/bin/env bash
# No root access or network required. All services and releases are isolated fixtures.
set -euo pipefail
cd "$(dirname "$0")/.."
scratch=$(mktemp -d)
export HIHY_ROOT_DIR="$scratch/root" HIHY_PID_FILE="$scratch/service.pid"
export HIHY_SERVICE_FILE="$scratch/hihy.service" HIHY_INIT_SERVICE="$scratch/init-hihy"
export HIHY_LEGACY_SERVICE="$scratch/service"
source server/hy2.sh
cleanup() {
    if [ -f "$scratch/service.pid" ]; then
        kill "$(cat "$scratch/service.pid")" 2>/dev/null || true
    fi
    rm -rf "$scratch"
}
trap cleanup EXIT
export HIHY_ROOT_DIR="$scratch/root" HIHY_PID_FILE="$scratch/service.pid"
HIHY_VERSION_STATUS_FILE="$scratch/version.state"
mkdir -p "$HIHY_ROOT_DIR/bin" "$scratch/releases"
fail() { echo "FAIL: $*" >&2; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "expected '$2', got '$1'"; }

# Follow redirects (including a repository move), accept encoded tags, reject junk.
(
    fetchRemoteBodyFromSources() { printf '%s' '{"tag_name":"app/v2.12.3"}'; }
    assert_eq "$(getLatestHysteriaVersion)" app/v2.12.3
    fetchRemoteBodyFromSources() { return 1; }
    curl() {
        [[ "$*" == *-fsSIL* ]] || return 1
        printf 'HTTP/2 301\r\nlocation: https://github.com/HyNetworks/hysteria/releases/latest\r\nHTTP/2 302\r\nLocation: https://github.com/HyNetworks/hysteria/releases/tag/app%%2Fv2.12.3\r\n'
    }
    assert_eq "$(getLatestHysteriaVersion)" app/v2.12.3
    curl() { printf 'HTTP/2 200\r\n'; }
    if getLatestHysteriaVersion; then fail 'empty tag accepted'; fi
    curl() { printf 'location: https://github.com/HyNetworks/hysteria/releases/tag/app/v2.12.4-beta\n'; }
    if getLatestHysteriaVersion; then fail 'prerelease accepted'; fi
)
assert_eq "$(getHysteriaAssetName arm64)" hysteria-linux-arm64
assert_eq "$(getHysteriaAssetName armv7l)" hysteria-linux-arm
assert_eq "$(getHysteriaAssetName riscv64)" hysteria-linux-riscv64
(
    od() { echo 2; }
    if getHysteriaAssetName mips64 >/dev/null 2>&1; then fail 'incorrect endian mapping accepted'; fi
    od() { echo 1; }
    assert_eq "$(getHysteriaAssetName mips)" hysteria-linux-mipsle
)
assert_eq "$(getHysteriaAssetName armv5l)" hysteria-linux-armv5

make_core() {
    local file="$1" version="$2" broken="${3:-false}"
    cat > "$file" <<CORE
#!/bin/bash
if [ "\${1:-}" = version ]; then
    echo 'Version: $version'
    exit 0
fi
if $broken; then sleep 2; exit 1; fi
exec sleep 120
CORE
    chmod +x "$file"
}
asset=$(getHysteriaAssetName)
make_core "$HIHY_ROOT_DIR/bin/appS" v2.12.2
make_release() {
    make_core "$scratch/releases/$asset" "${1:-v2.12.3}" "${2:-false}"
    printf '%s  build/%s\n' "$(sha256sum "$scratch/releases/$asset" | cut -d ' ' -f1)" "$asset" > "$scratch/releases/hashes.txt"
}
cat > "$scratch/service" <<'SERVICE'
#!/bin/bash
start() {
    "$HIHY_ROOT_DIR/bin/appS" server >/dev/null 2>&1 &
    echo $! > "$HIHY_PID_FILE"
}
stop() {
    if [ -f "$HIHY_PID_FILE" ]; then
        kill "$(cat "$HIHY_PID_FILE")" 2>/dev/null || true
        rm -f "$HIHY_PID_FILE"
    fi
}
case "$1" in
    start) start ;;
    stop) stop ;;
    restart) stop; start ;;
    # Version 1.07 returned zero for both stopped and running states.
    status) echo 'hihy is not running'; exit 0 ;;
esac
SERVICE
chmod +x "$scratch/service"
detectServiceManager() { echo sysv; }
getLatestHysteriaVersion() { echo app/v2.12.3; }
getHysteriaReleaseAsset() { return 1; }
downloadToFile() {
    if [ "${HASHES_UNAVAILABLE:-false}" = true ] && [ "${1##*/}" = hashes.txt ]; then return 1; fi
    cp "$scratch/releases/${1##*/}" "$2"
}

# A stopped installation can update without starting.
make_release
updateHysteriaCore
assert_eq "$(getLocalHysteriaVersion)" app/v2.12.3
assert_eq "$(getLocalHysteriaVersion "$HIHY_ROOT_DIR/bin/appS.rollback")" app/v2.12.2
if serviceIsActive; then fail 'stopped service was started'; fi

# An invalid artifact must not stop the running service or replace its binary.
cp "$HIHY_ROOT_DIR/bin/appS.rollback" "$HIHY_ROOT_DIR/bin/appS"
"$scratch/service" start
pid_before=$(cat "$HIHY_PID_FILE")
printf '\n# corrupt\n' >> "$scratch/releases/$asset"
if updateHysteriaCore; then fail 'corrupt artifact accepted'; fi
serviceIsActive || fail 'download failure stopped service'
assert_eq "$(cat "$HIHY_PID_FILE")" "$pid_before"
assert_eq "$(getLocalHysteriaVersion)" app/v2.12.2
make_release v2.12.1
if updateHysteriaCore; then fail 'wrong version accepted'; fi
assert_eq "$(cat "$HIHY_PID_FILE")" "$pid_before"

# Network/version lookup failure must leave the existing process untouched.
(
    getLatestHysteriaVersion() { return 1; }
    if updateHysteriaCore; then fail 'failed version lookup reported success'; fi
)
assert_eq "$(cat "$HIHY_PID_FILE")" "$pid_before"
(
    downloadToFile() { return 1; }
    if updateHysteriaCore; then fail 'failed download reported success'; fi
)
assert_eq "$(cat "$HIHY_PID_FILE")" "$pid_before"

# API unavailable AND missing hashes must fail closed, preserving the service.
if HASHES_UNAVAILABLE=true updateHysteriaCore; then fail 'unverified download accepted'; fi
assert_eq "$(cat "$HIHY_PID_FILE")" "$pid_before"

# The primary GitHub digest path does not require fetching hashes.txt.
make_release
(
    getHysteriaReleaseAsset() {
        printf '{"digest":"sha256:%s","browser_download_url":"https://example.invalid/%s"}' \
            "$(sha256sum "$scratch/releases/$asset" | cut -d ' ' -f1)" "$asset"
    }
    HASHES_UNAVAILABLE=true downloadHysteriaCore app/v2.12.3 "$scratch/verified"
    assert_eq "$(getLocalHysteriaVersion "$scratch/verified")" app/v2.12.3
)

# A new binary that exits after startup must roll back and restart the old one.
make_release v2.12.3 true
if updateHysteriaCore; then fail 'failed startup reported success'; fi
assert_eq "$(getLocalHysteriaVersion)" app/v2.12.2
serviceIsActive || fail 'old service not restored'

# A healthy release restarts the previously running service and invalidates cache.
make_release
touch "$HIHY_VERSION_STATUS_FILE"
updateHysteriaCore
assert_eq "$(getLocalHysteriaVersion)" app/v2.12.3
serviceIsActive || fail 'new service not running'
[ ! -e "$HIHY_VERSION_STATUS_FILE" ] || fail 'stale version cache'
pid_before=$(cat "$HIHY_PID_FILE")
updateHysteriaCore
assert_eq "$(cat "$HIHY_PID_FILE")" "$pid_before"
[ ! -e "$HIHY_ROOT_DIR/bin/.core-update.lock" ] || fail 'update lock leaked'

# ECH public extraction, URI escaping, disabled default, retention and export.
cat > "$scratch/ech.pem" <<'PEM'
-----BEGIN ECH KEYS-----
PRIVATE-DO-NOT-EXPORT
-----END ECH KEYS-----
-----BEGIN ECH CONFIGS-----
YWJj
-----END ECH CONFIGS-----
PEM
assert_eq "$(getECHConfigList "$scratch/ech.pem")" YWJj
assert_eq "$(encodeECHQuery 'a+/==')" 'a%2B%2F%3D%3D'
ech_key_path=unexpected
prepareECH '' <<< ''
assert_eq "$ech_key_path" ''
prepareECH "$scratch/ech.pem" <<< ''
assert_eq "$ech_key_path" "$scratch/ech.pem"
assert_eq "$(stat -c %a "$scratch/ech.pem")" 600
prepareECH "$scratch/ech.pem" <<< 2
assert_eq "$ech_key_path" ''
[ -f "$scratch/ech.pem" ] || fail 'disabled ECH deleted keys'
if prepareECH "$scratch/missing.pem" <<< ''; then fail 'missing old key accepted'; fi
if prepareECH relative.pem <<< ''; then fail 'relative key path accepted'; fi
if getECHConfigList /dev/null; then fail 'empty key accepted'; fi
printf 'ech:\n  keyPath: %s\n' "$scratch/ech.pem" > "$scratch/server.yaml"
printf '{}\n' > "$scratch/client.yaml"
exportClientECH "$scratch/server.yaml" "$scratch/client.yaml"
assert_eq "$(yq '.tls.ech' "$scratch/client.yaml")" YWJj
if grep -q PRIVATE "$scratch/client.yaml"; then fail 'private key exported'; fi
printf '{}\n' > "$scratch/server.yaml"
exportClientECH "$scratch/server.yaml" "$scratch/client.yaml"
assert_eq "$(yq '.tls.ech' "$scratch/client.yaml")" null
# Installation must stop before configuration when core download fails.
(
    classifyInstallState() { echo not-installed; }
    checkSystemForUpdate() { return 0; }
    downloadHysteriaCore() { return 1; }
    setHysteriaConfig() { touch "$scratch/unexpected-config"; return 0; }
    installHihyService() { return 1; }
    if install; then fail 'failed installation reported success'; fi
    [ ! -e "$scratch/unexpected-config" ] || fail 'configured after failed download'
)

# Exercise service-manager dispatch without touching host services.
(
    touch "$HIHY_SERVICE_FILE"
    detectServiceManager() { echo systemd; }
    systemctl() {
        case "$1" in
            is-active) hihyProcessAlive "$(cat "$HIHY_PID_FILE")" ;;
            show) cat "$HIHY_PID_FILE" ;;
            *) fail 'unexpected systemctl operation' ;;
        esac
    }
    serviceIsActive || fail 'systemd status dispatch failed'
    assert_eq "$(getHihyServicePID)" "$(cat "$HIHY_PID_FILE")"
    # Simulate a manager restarting the process during the health window.
    getHihyServicePID() { echo "$pid_before"; }
    serviceIsActive() { return 1; }
    if waitHihyServiceHealthy; then fail 'unstable systemd service accepted'; fi
)

# Explicit YAML strings must round-trip quotes, backslashes and line breaks.
literal=$'path/"quoted"/\\value\nsecond line'
addOrUpdateYaml "$scratch/strings.yaml" value "$literal" string
assert_eq "$(yq -r '.value' "$scratch/strings.yaml")" "$literal"

# Run full exporters against the isolated installation, including BBR and ECH.
mkdir -p "$scratch/exports" "$HIHY_ROOT_DIR/conf"
cat > "$HIHY_BACKUP_FILE" <<'YAML'
remarks: regression
serverAddress: 127.0.0.1
domain: real.example.com
insecure: true
masquerade_tcp: false
realmMode: false
portHoppingStatus: false
congestionMode: bbr
congestionType: bbr
congestionBbrProfile: standard
YAML
cat > "$HIHY_CONFIG_FILE" <<'YAML'
listen: :44443
auth:
  type: password
  password: local-test
YAML
generate_qr() { return 0; }
cd "$scratch/exports"
generate_client_config > "$scratch/export.log"
assert_eq "$(yq '.proxies[0].up' Hy2-regression-ClashMeta.yaml)" null
assert_eq "$(yq '.proxies[0].down' Hy2-regression-ClashMeta.yaml)" null
addOrUpdateYaml "$HIHY_CONFIG_FILE" bandwidth.up '100 mbps' string
addOrUpdateYaml "$HIHY_CONFIG_FILE" bandwidth.down '20 mbps' string
generateMetaYaml > /dev/null
assert_eq "$(yq '.proxies[0].up' Hy2-regression-ClashMeta.yaml)" '20 Mbps'
assert_eq "$(yq '.proxies[0].down' Hy2-regression-ClashMeta.yaml)" '100 Mbps'
addOrUpdateYaml "$HIHY_CONFIG_FILE" ech.keyPath "$scratch/ech.pem" string
addOrUpdateYaml "$HIHY_BACKUP_FILE" remarks ech-test string
generate_client_config > "$scratch/ech-export.log"
assert_eq "$(yq '.tls.ech' Hy2-ech-test-v2rayN.yaml)" YWJj
[[ "$url" == *'&ech=YWJj&'* ]] || fail 'ECH missing from full URI export'
[ ! -e Hy2-ech-test-ClashMeta.yaml ] || fail 'unsupported ECH Meta export produced'
printf 'PASS: releases, mandatory checksums, legacy/systemd status, rollback, YAML strings, full BBR/ECH export\n'

