#!/usr/bin/env bash
# Files, services, ACME and SSH are isolated fixtures; no root or network required.
set -euo pipefail
cd "$(dirname "$0")/.."
repo=$PWD
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export HIHY_ROOT_DIR="$scratch/root" HIHY_BIN_LINK="$scratch/hihy"
export HIHY_SERVICE_FILE="$scratch/hihy.service" HIHY_LEGACY_SERVICE="$scratch/service"
export HIHY_INIT_SERVICE="$scratch/init" HIHY_RC_LOCAL="$scratch/rc.local"
source server/hy2.sh
fail() { echo "FAIL: $*" >&2; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "expected '$2', got '$1'"; }

assert_eq "$(formatURIHost '[fe80::1%eth0]')" '[fe80::1%25eth0]'
assert_eq "$(formatURIHost '[fe80::1%eth0]' native)" '[fe80::1%eth0]'
assert_eq "$(formatURIHost 'example.com')" 'example.com'

# Port ownership must match the whole record, including range endpoints.
(
    ensureHihyDirectories
    recordOwnedFirewallRule nft udp 4433
    if firewallRuleExists nft udp 443; then fail '4433 matched 443'; fi
    recordOwnedFirewallRule nft udp 443
    firewallRuleExists nft udp 443 || fail '443 ownership missing'
    recordOwnedFirewallRule nft udp 443
    assert_eq "$(wc -l < "$HIHY_FIREWALL_STATE_FILE")" 2
    recordOwnedFirewallRule nft udp 100:2000
    if firewallRuleExists nft udp 100:200; then fail 'range prefix matched'; fi
    recordOwnedFirewallRule nft udp 100:200
    firewallRuleExists nft udp 100:200 || fail 'range ownership missing'
    if firewallRuleExists nft tcp 443; then fail 'UDP ownership matched TCP'; fi
    rm -f "$HIHY_FIREWALL_STATE_FILE"
)

# Use real certificates: only a complete wildcard DNS SAN may authorize publication.
(
    cert="$scratch/bundle.crt"; key="$scratch/bundle.key"
    openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$key" 2>/dev/null
    for san in 'DNS:*.example.com.evil.test' 'DNS:*.sub.example.com' 'DNS:example.com' 'DNS:*.example.com'; do
        openssl req -x509 -key "$key" -out "$cert" -subj '/CN=*.example.com' \
            -addext "subjectAltName=DNS:unrelated.test,$san,DNS:last.test" -days 3 2>/dev/null
        if [ "$san" = 'DNS:*.example.com' ]; then
            validateCertificateBundle "$cert" "$key" example.com || fail 'valid wildcard SAN rejected'
            validateCertificateBundle "$cert" "$key" EXAMPLE.COM || fail 'case-insensitive DNS rejected'
        elif validateCertificateBundle "$cert" "$key" example.com; then
            fail "wrong SAN accepted: $san"
        fi
    done
    openssl req -x509 -key "$key" -out "$cert" -subj '/CN=*.example.com' -days 3 2>/dev/null
    if validateCertificateBundle "$cert" "$key" example.com; then fail 'CN-only certificate accepted'; fi
)

# ARMv5 must not receive an incompatible ARMv6 binary; endian mapping is explicit.
(
    uname() { echo armv6l; }; assert_eq "$(getArchitecture)" arm
    uname() { echo armv5l; }; if getArchitecture; then fail 'ARMv5 accepted incompatible yq'; fi
    uname() { echo mips; }; od() { echo 1; }; assert_eq "$(getArchitecture)" mipsle
    uname() { echo mips64; }; assert_eq "$(getArchitecture)" mips64le
    od() { echo 2; }; assert_eq "$(getArchitecture)" mips64
)

run_reconfigure_case() (
    local scenario="$1" initial="$2"
    HIHY_ROOT_DIR="$scratch/$scenario-$initial"
    HIHY_CONFIG_FILE="$HIHY_ROOT_DIR/conf/config.yaml"
    HIHY_BACKUP_FILE="$HIHY_ROOT_DIR/conf/backup.yaml"
    HIHY_ACL_FILE="$HIHY_ROOT_DIR/acl/acl.txt"
    HIHY_FIREWALL_STATE_FILE="$HIHY_ROOT_DIR/result/firewall-owned.state"
    mkdir -p "$HIHY_ROOT_DIR"/{conf,result,acl,cert}
    printf 'phase: old\n' > "$HIHY_CONFIG_FILE"
    cat > "$HIHY_BACKUP_FILE" <<'YAML'
serverPort: 443
realmMode: false
portHoppingStatus: true
portHoppingStart: 47000
portHoppingEnd: 48000
masquerade_tcp: true
YAML
    echo old-acl > "$HIHY_ACL_FILE"
    echo old-key > "$HIHY_ROOT_DIR/cert/server.key"
    printf '%s\n' "$initial" > "$HIHY_ROOT_DIR/service-state"
    if [ "$scenario" != legacy ]; then
        printf '%s\n' 'backend=nft|protocol=udp|port=443' 'backend=nft|protocol=udp|port=47000:48000' 'backend=nft|protocol=tcp|port=443' > "$HIHY_FIREWALL_STATE_FILE"
    fi
    classifyInstallState() { echo installed; }
    prepareECH() { ech_key_path=''; }
    serviceIsActive() { [ "$(cat "$HIHY_ROOT_DIR/service-state")" = running ]; }
    serviceStop() { echo stopped > "$HIHY_ROOT_DIR/service-state"; }
    serviceStart() {
        if [ "$scenario" = start-failure ] && [ "$(yq '.phase' "$HIHY_CONFIG_FILE")" = new ]; then return 1; fi
        echo running > "$HIHY_ROOT_DIR/service-state"
    }
    waitHihyServiceHealthy() { serviceIsActive; }
    secureHihyPermissions() { return 0; }
    removeOwnedFirewallRules() {
        rm -f "$HIHY_FIREWALL_STATE_FILE"
        : > "$HIHY_ROOT_DIR/actual-rules"
    }
    allowPort() {
        if [ "$scenario" = restore-failure ] && [ "$2" = 47000:48000 ]; then return 1; fi
        printf '%s %s\n' "$1" "$2" >> "$HIHY_ROOT_DIR/actual-rules"
        printf 'backend=%s|protocol=%s|port=%s\n' "${3:-nft}" "$1" "$2" >> "$HIHY_FIREWALL_STATE_FILE"
    }
    setHysteriaConfig() {
        portHoppingStatus=false; portHoppingStart=50000; portHoppingEnd=51000; masquerade_tcp=false
        echo 'phase: new' > "$HIHY_CONFIG_FILE"
        echo new-acl > "$HIHY_ACL_FILE"
        echo new-key > "$HIHY_ROOT_DIR/cert/server.key"
        allowPort udp 30000
        case "$scenario" in success | start-failure | export-failure) return 0;; *) return 1;; esac
    }
    generate_client_config() { [ "$scenario" != export-failure ]; }
    if [ "$scenario" = success ]; then
        changeServerConfig > "$HIHY_ROOT_DIR/output"
        assert_eq "$(cat "$HIHY_ROOT_DIR/service-state")" "$initial"
        assert_eq "$(yq '.phase' "$HIHY_CONFIG_FILE")" new
    else
        if changeServerConfig > "$HIHY_ROOT_DIR/output"; then fail "$scenario incorrectly succeeded"; fi
        if [ "$scenario" = export-failure ]; then
            assert_eq "$(yq '.phase' "$HIHY_CONFIG_FILE")" new
        else
            assert_eq "$(yq '.phase' "$HIHY_CONFIG_FILE")" old
            assert_eq "$(cat "$HIHY_ACL_FILE")" old-acl
            assert_eq "$(cat "$HIHY_ROOT_DIR/cert/server.key")" old-key
            assert_eq "$(cat "$HIHY_ROOT_DIR/service-state")" "$initial"
            grep -qx 'udp 443' "$HIHY_ROOT_DIR/actual-rules" || fail 'UDP missing'
            grep -qx 'tcp 443' "$HIHY_ROOT_DIR/actual-rules" || fail 'TCP missing'
            if [ "$scenario" != restore-failure ]; then
                grep -qx 'udp 47000:48000' "$HIHY_ROOT_DIR/actual-rules" || fail 'old hop range missing'
                grep -qx 'backend=nft|protocol=udp|port=47000:48000' "$HIHY_FIREWALL_STATE_FILE" || fail 'ownership not rebuilt'
            fi
            if grep -q 30000 "$HIHY_ROOT_DIR/actual-rules"; then fail 'new rule leaked'; fi
        fi
    fi
    local backups
    backups=$(find "$HIHY_ROOT_DIR/result" -maxdepth 1 -name 'reconfigure.*' | wc -l)
    case "$scenario" in restore-failure | export-failure) assert_eq "$backups" 1;; *) assert_eq "$backups" 0;; esac
)
for state in running stopped; do
    run_reconfigure_case config-failure "$state"
    run_reconfigure_case success "$state"
    run_reconfigure_case legacy "$state"
done
run_reconfigure_case start-failure running
run_reconfigure_case restore-failure running
run_reconfigure_case export-failure running

# All strings round-trip; exported URIs retain authentication and query boundaries.
mkdir -p "$HIHY_ROOT_DIR"/{conf,bin,result} "$scratch/exports"
cat > "$HIHY_ROOT_DIR/bin/appS" <<'CORE'
#!/bin/sh
printf 'Version: v2.12.3\n'
CORE
chmod +x "$HIHY_ROOT_DIR/bin/appS"
cat > "$HIHY_BACKUP_FILE" <<'YAML'
remarks: regression
serverAddress: '[::1]'
domain: real.example.com
insecure: true
masquerade_tcp: false
realmMode: false
portHoppingStatus: false
congestionMode: bbr
congestionType: bbr
congestionBbrProfile: standard
YAML
printf 'listen: ":443"\n' > "$HIHY_CONFIG_FILE"
generate_qr() { return 0; }
cd "$scratch/exports"
for secret in '00123' true null 'abc #def' 'abc: def' 'a@b:c/?&#+% 中文'; do
    addOrUpdateYaml "$HIHY_CONFIG_FILE" auth.password "$secret" string
    addOrUpdateYaml "$HIHY_CONFIG_FILE" obfs.type salamander string
    addOrUpdateYaml "$HIHY_CONFIG_FILE" obfs.salamander.password "$secret" string
    addOrUpdateYaml "$HIHY_CONFIG_FILE" acme.dns.config.cloudflare_api_token "$secret" string
    addOrUpdateYaml "$HIHY_BACKUP_FILE" remarks '中文, [x] #备注' string
    generate_client_config > "$scratch/export.log"
    assert_eq "$(yq -r '.auth' "$client_configfile")" "$secret"
    assert_eq "$(yq -r '.server' "$client_configfile")" '[::1]:443'
    assert_eq "$(yq -r '.obfs.salamander.password' "$client_configfile")" "$secret"
    meta_file="./Hy2-${safe_remarks}-ClashMeta.yaml"
    assert_eq "$(yq -r '.proxies[0].password' "$meta_file")" "$secret"
    assert_eq "$(yq -r '.proxies[0].server' "$meta_file")" ::1
    assert_eq "$(yq -r '.proxy-groups[0].proxies[0]' "$meta_file")" '中文, [x] #备注'
    python3 - "$url" "$secret" <<'PY'
import sys
from urllib.parse import urlsplit,parse_qs,unquote
u=urlsplit(sys.argv[1]); q=parse_qs(u.query)
assert unquote(u.username)==sys.argv[2]
assert q['obfs-password']==[sys.argv[2]]
assert q['sni']==['real.example.com']
assert u.hostname=='::1'
assert unquote(u.fragment)=='Hy2-中文, [x] #备注'
PY
done

# ACME chooses run vs renew, and supplies the configured renewal threshold.
mkdir -p "$HIHY_CERT_MANAGER_DIR"/{config,state,lego/certificates,bin,nodes} "$HIHY_SHARED_CERT_DIR/current"
cat > "$HIHY_CERT_MANAGER_CONFIG" <<'CONF'
domain=example.com
email=test@example.com
renew_days=40
CONF
export HIHY_TEST_LEGO_ARGS="$scratch/lego-args"
cat > "$HIHY_LEGO_BIN" <<'LEGO'
#!/bin/sh
printf '%s\n' "$@" > "$HIHY_TEST_LEGO_ARGS"
LEGO
chmod +x "$HIHY_LEGO_BIN"
(
    installLego() { return 0; }
    verifyCloudflareToken() { return 0; }
    publishSharedCertificate() { return 0; }
    issueOrRenewWildcardCertificate
    assert_eq "$(tail -1 "$HIHY_TEST_LEGO_ARGS")" run
    touch "$HIHY_CERT_MANAGER_DIR/lego/certificates/_.example.com.crt"
    issueOrRenewWildcardCertificate
    assert_eq "$(tail -3 "$HIHY_TEST_LEGO_ARGS" | tr '\n' ' ')" 'renew --days 40 '
    assert_eq "$(head -1 "$HIHY_TEST_LEGO_ARGS")" --path
)

# Real deployment bookkeeping, with an SSH fixture that never leaves this process.
printf 'certificate-one\n' > "$HIHY_SHARED_CERT_DIR/current/fullchain.pem"
printf 'key-one\n' > "$HIHY_SHARED_CERT_DIR/current/privkey.pem"
for name in a b; do
    printf 'name=%s\nhost=%s.example.com\nport=22\nuser=root\n' "$name" "$name" > "$HIHY_CERT_MANAGER_DIR/nodes/$name.conf"
done
ssh() {
    cat >/dev/null
    printf '%s\n' "${!#}" >> "$scratch/ssh-calls"
    [ "${fail_b:-false}" != true ] || [ "${!#}" != root@b.example.com ]
}
getCertificateDaysRemaining() { echo 90; }
issueOrRenewWildcardCertificate() { echo renewed >> "$scratch/renew-calls"; }
fail_b=true
if renewAndDeployCertificates; then fail 'failed deployment hidden'; fi
fail_b=false
renewAndDeployCertificates
assert_eq "$(grep -c root@a.example.com "$scratch/ssh-calls")" 1
assert_eq "$(grep -c root@b.example.com "$scratch/ssh-calls")" 2
[ ! -f "$scratch/renew-calls" ] || fail 'healthy certificate renewed unnecessarily'
renewAndDeployCertificates
assert_eq "$(wc -l < "$scratch/ssh-calls")" 3
printf 'certificate-two\n' > "$HIHY_SHARED_CERT_DIR/current/fullchain.pem"
renewAndDeployCertificates
assert_eq "$(wc -l < "$scratch/ssh-calls")" 5
(
    tar() { return 1; }
    if deployCertificateToNode "$HIHY_CERT_MANAGER_DIR/nodes/a.conf"; then fail 'tar failure hidden by SSH success'; fi
)
getCertificateDaysRemaining() { echo 10; }
renewAndDeployCertificates
assert_eq "$(wc -l < "$scratch/renew-calls")" 1
printf 'PASS: configuration recovery, firewall ownership, text/URI round-trips, architecture, renewal and node retries\n'
