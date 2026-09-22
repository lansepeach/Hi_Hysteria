#!/usr/bin/env bash
# Regression coverage for the v2.12.3 review; host operations stay mocked.
set -euo pipefail
cd "$(dirname "$0")/.."
repo=$PWD
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export HIHY_ROOT_DIR="$scratch/root" HIHY_BIN_LINK="$scratch/hihy"
source server/hy2.sh
fail() { echo "FAIL: $*" >&2; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "expected '$2', got '$1'"; }
for unsafe in systemctl rc-service rc-update nft iptables ip6tables sysctl curl wget crontab ssh; do
    eval "$unsafe() { fail 'unexpected host command: $unsafe'; }"
done
ensureHihyDirectories

# Accepted low-bandwidth input must stay within the core's legal window range.
calculateBrutalWindows 10 1
[ "$SRW" -ge 16384 ] && [ "$CRW" -ge "$SRW" ] || fail 'invalid low-bandwidth window'
[ "$max_SRW" -ge "$SRW" ] && [ "$max_CRW" -ge "$max_SRW" ] || fail 'invalid maximum window'
calculateBrutalWindows 200 1100
assert_eq "$CRW" 55000000 # 2 * 0.2 seconds * 1.1 Gbit/s / 8
calculateBrutalWindows 60000 1100000 2>/dev/null
[ "$max_CRW" -le 100663296 ] || fail 'unbounded receive window'
if calculateBrutalWindows 0 1; then fail 'zero delay accepted'; fi

cat > "$HIHY_CONFIG_FILE" <<'YAML'
listen: :44443
auth: {type: password, password: proxy-password}
trafficStats: {listen: '0.0.0.0:32123', secret: proxy-password}
outbounds: [{name: hihy, type: direct}]
YAML
cat > "$HIHY_BACKUP_FILE" <<'YAML'
remarks: compatibility
serverAddress: '::1'
domain: example.com
insecure: false
realmMode: false
portHoppingStatus: true
portHoppingStart: 47000
portHoppingEnd: 48000
portHoppingIntervalMode: random
portHoppingMinHopInterval: 15s
portHoppingMaxHopInterval: 45s
congestionMode: bbr
congestionType: bbr
congestionBbrProfile: aggressive
YAML
echo stopped > "$scratch/service-state"
serviceIsActive() { [ "$(cat "$scratch/service-state")" = running ]; }
serviceRestart() { echo restart >> "$scratch/restarts"; }
waitHihyServiceHealthy() { serviceIsActive; }

# Existing installations migrate without changing proxy credentials or auth mode.
configureRealtimeMonitor secure > /dev/null
assert_eq "$(yq '.trafficStats.listen' "$HIHY_CONFIG_FILE")" 127.0.0.1:32123
secret=$(yq '.trafficStats.secret' "$HIHY_CONFIG_FILE")
[[ "$secret" =~ ^[0-9a-f]{64}$ ]] || fail 'management secret is not independent random data'
assert_eq "$(yq '.auth.password' "$HIHY_CONFIG_FILE")" proxy-password
[ ! -e "$scratch/restarts" ] || fail 'secure started a stopped server'
configureRealtimeMonitor secure > /dev/null
assert_eq "$(yq '.trafficStats.secret' "$HIHY_CONFIG_FILE")" "$secret"
[ ! -e "$scratch/restarts" ] || fail 'idempotent migration restarted a server'
addOrUpdateYaml "$HIHY_CONFIG_FILE" trafficStats.secret proxy-password string
echo running > "$scratch/service-state"
cp "$HIHY_CONFIG_FILE" "$scratch/before-failure"
(
    serviceRestart() { return 1; }
    if configureRealtimeMonitor secure > /dev/null; then fail 'failed migration reported success'; fi
)
cmp "$HIHY_CONFIG_FILE" "$scratch/before-failure" || fail 'API migration failed to roll back'
configureRealtimeMonitor secure > /dev/null
assert_eq "$(wc -l < "$scratch/restarts")" 1
configureRealtimeMonitor secure > /dev/null
assert_eq "$(wc -l < "$scratch/restarts")" 1

# The API-only command must not replace custom authentication.
addOrUpdateYaml "$HIHY_CONFIG_FILE" auth.type userpass string
addOrUpdateYaml "$HIHY_CONFIG_FILE" auth.userpass.alice private-password string
configureRealtimeMonitor secure > /dev/null
assert_eq "$(yq '.auth.type' "$HIHY_CONFIG_FILE")" userpass
assert_eq "$(yq '.auth.userpass.alice' "$HIHY_CONFIG_FILE")" private-password

# Reconfiguration preserves custom rules while toggling only the wizard rule.
printf '# custom rules\ncustom(suffix:example.com)\nreject(all, udp/443)\nreject(10.0.0.0/8)\n' > "$HIHY_ACL_FILE"
addOrUpdateYaml "$HIHY_CONFIG_FILE" acl.file "$HIHY_ACL_FILE" string
prepareConfigurationACL "$HIHY_CONFIG_FILE" "$scratch/acl" false
grep -qx 'custom(suffix:example.com)' "$scratch/acl" || fail 'custom outbound rule lost'
grep -qx 'reject(10.0.0.0/8)' "$scratch/acl" || fail 'custom IP rule lost'
if grep -q 'udp/443' "$scratch/acl"; then fail 'HTTP/3 switch did not remove old rule'; fi
prepareConfigurationACL "$HIHY_CONFIG_FILE" "$scratch/acl" true
assert_eq "$(head -1 "$scratch/acl")" 'reject(all, udp/443)'
assert_eq "$(grep -c 'udp/443' "$scratch/acl")" 1

# All service/config writers reject a concurrent operation, before taking snapshots.
mkdir "${HIHY_ROOT_DIR}.operation.lock"
for invocation in 'changeServerConfig' 'configureRealtimeMonitor secure' 'configureSocks5Outbound remove' \
                  'configureOutboundIPMode 46' 'updateACLRule add example.com reject' \
                  'updateHysteriaCore' 'renewAndDeployCertificates' 'start' 'stop' 'restart'; do
    if $invocation > /dev/null; then fail "concurrent operation accepted: $invocation"; fi
done
rmdir "${HIHY_ROOT_DIR}.operation.lock"

# Native and third-party exports retain their supported transport parameters.
printf '#!/bin/sh\necho "Version: v2.12.3"\n' > "$HIHY_ROOT_DIR/bin/appS"
chmod +x "$HIHY_ROOT_DIR/bin/appS"
addOrUpdateYaml "$HIHY_CONFIG_FILE" auth.type password string
generate_qr() { return 0; }
cd "$scratch"
generate_client_config > export.log
meta=./Hy2-compatibility-ClashMeta.yaml
assert_eq "$(yq '.proxies[0].hop-interval' "$meta")" 15-45
assert_eq "$(yq '.proxies[0].bbr-profile' "$meta")" aggressive
assert_eq "$(yq '.allow-lan' "$meta")" false
assert_eq "$(yq '.dns.listen' "$meta")" 127.0.0.1:1053
if grep -Fq "$(yq '.trafficStats.secret' "$HIHY_CONFIG_FILE")" "$client_configfile" "$meta" export.log; then
    fail 'management secret leaked into client export'
fi
[[ "$native_url" == 'hy2://proxy-password@[::1]:44443,47000-48000/'* ]] || fail 'native URI lost hop range'
[[ "$url" == *'mport=47000-48000'* ]] || fail 'third-party URI lost mport'
addOrUpdateYaml "$HIHY_BACKUP_FILE" portHoppingIntervalMode fixed string
addOrUpdateYaml "$HIHY_BACKUP_FILE" portHoppingHopInterval 75s string
generateMetaYaml > /dev/null
assert_eq "$(yq '.proxies[0].hop-interval' "$meta")" 75
addOrUpdateYaml "$HIHY_BACKUP_FILE" congestionMode reno string
addOrUpdateYaml "$HIHY_BACKUP_FILE" congestionType reno string
generate_client_config > export.log
grep -q '客户端上行仍为 BBR' export.log || fail 'Reno downgrade was silent'
assert_eq "$(yq '.congestion.type' "$client_configfile")" reno

printf 'PASS: bounded QUIC windows, local API migration/rollback, shared locks, ACL retention and client exports\n'
