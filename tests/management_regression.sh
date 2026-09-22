#!/usr/bin/env bash
# No root/network access: service managers, package managers and persistence are fixtures.
set -euo pipefail
cd "$(dirname "$0")/.."
repo=$PWD
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export HIHY_ROOT_DIR="$scratch/root" HIHY_BIN_LINK="$scratch/hihy"
export HIHY_SERVICE_FILE="$scratch/service" HIHY_INIT_SERVICE="$scratch/init" HIHY_LEGACY_SERVICE="$scratch/legacy"
export HIHY_PID_FILE="$scratch/pid" HIHY_RC_LOCAL="$scratch/rc.local"
source server/hy2.sh
fail() { echo "FAIL: $*" >&2; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "expected '$2', got '$1'"; }
# Fail before invoking any host mutation, even if a regression reaches a new branch.
for unsafe in systemctl rc-service rc-update nft iptables ip6tables netfilter-persistent sysctl curl wget apt dnf yum apk pacman crontab; do
    eval "$unsafe() { fail 'unexpected host command: $unsafe'; }"
done
ensureHihyDirectories
(
    # nft may emit multiple writes after the ownership marker; consume the complete stream.
    nft() { printf 'comment "hihy-owned:v1"\n'; printf '%200000s\n' padding; }
    nftOwnedTableIsManaged || fail 'pipefail misclassified a managed nft table'
)
printf '#!/bin/sh\necho "Version: v2.12.3"\n' > "$HIHY_ROOT_DIR/bin/appS"
chmod +x "$HIHY_ROOT_DIR/bin/appS"
reset_config() {
    cat > "$HIHY_CONFIG_FILE" <<'YAML'
listen: :44443
auth: {type: password, password: test-secret}
tls: {cert: old.crt, key: old.key}
outbounds: [{name: hihy, type: direct}]
YAML
    cat > "$HIHY_BACKUP_FILE" <<'YAML'
remarks: audit
serverAddress: 127.0.0.1
domain: helloworld.com
insecure: true
socks5_status: false
realmMode: false
portHoppingStatus: false
masquerade_tcp: false
congestionMode: bbr
congestionType: bbr
congestionBbrProfile: standard
YAML
}
serviceIsActive() { [ "$(cat "$scratch/service-state")" = running ]; }
serviceRestart() { echo running > "$scratch/service-state"; }
waitHihyServiceHealthy() { serviceIsActive; }
echo stopped > "$scratch/service-state"

# Invalid input is rejected before arithmetic; leading zeros are decimal.
readPositiveInteger answer 50 1000000 <<< $'10.5\n-1\n1+2\n99999999999999\n00008' > "$scratch/numeric.log"
assert_eq "$answer" 8
if readPositiveInteger answer 50 1000000 </dev/null; then fail 'EOF accepted'; fi

# Use the real interactive generator with invalid bandwidth and EOF, not a mock of it.
(
    set +u
    reset_config
    echo old-acl > "$HIHY_ACL_FILE"
    touch "$scratch/local.crt" "$scratch/local.key"
    cp "$HIHY_CONFIG_FILE" "$scratch/before-config"
    cp "$HIHY_BACKUP_FILE" "$scratch/before-backup"
    classifyInstallState() { echo installed; }
    serviceStop() { echo stopped > "$scratch/service-state"; }
    serviceStart() { echo running > "$scratch/service-state"; }
    removeOwnedFirewallRules() { return 0; }
    allowPort() { return 0; }
    lsof() { return 0; }
    echo running > "$scratch/service-state"
    if changeServerConfig > "$scratch/reconfigure.log" 2>&1 <<INPUT

1
2
$scratch/local.crt
$scratch/local.key
real.example.com
44443
2
3
200
10.5
INPUT
    then fail 'incomplete configuration succeeded'; fi
    cmp "$scratch/before-config" "$HIHY_CONFIG_FILE" || fail 'old config lost'
    cmp "$scratch/before-backup" "$HIHY_BACKUP_FILE" || fail 'old metadata lost'
    assert_eq "$(cat "$HIHY_ACL_FILE")" old-acl
    assert_eq "$(cat "$scratch/service-state")" running
    [ -z "$(find "$HIHY_ROOT_DIR/conf" -name '.configure.*' -print)" ] || fail 'staging file leaked'
)

# Fatal exits from a configuration child must still enter the parent's rollback.
(
    reset_config
    echo old-acl > "$HIHY_ACL_FILE"
    classifyInstallState() { echo installed; }
    prepareECH() { ech_key_path=''; }
    removeOwnedFirewallRules() { return 0; }
    allowPort() { return 0; }
    serviceStop() { echo stopped > "$scratch/service-state"; }
    serviceStart() { echo running > "$scratch/service-state"; }
    setHysteriaConfig() { beginReconfiguration "$2" || return 1; echo broken > "$HIHY_CONFIG_FILE"; exit 7; }
    echo running > "$scratch/service-state"
    if changeServerConfig > "$scratch/exit.log"; then fail 'child exit accepted'; fi
    assert_eq "$(yq '.auth.password' "$HIHY_CONFIG_FILE")" test-secret
    assert_eq "$(cat "$scratch/service-state")" running
)

# Failed file writes must preserve the previous configuration and metadata.
(
    reset_config
    cp "$HIHY_CONFIG_FILE" "$scratch/write-before"
    cp "$HIHY_BACKUP_FILE" "$scratch/write-backup-before"
    echo running > "$scratch/service-state"
    cp() {
        if [[ "$*" == *new-backup.yaml* ]]; then return 1; fi
        command cp "$@"
    }
    if applyHihyConfigFiles "$scratch/write-before" "$scratch/write-backup-before" > /dev/null; then
        fail 'configuration file write failure hidden'
    fi
    cmp "$scratch/write-before" "$HIHY_CONFIG_FILE" || fail 'failed config write changed config'
    cmp "$scratch/write-backup-before" "$HIHY_BACKUP_FILE" || fail 'failed config write changed metadata'
)

# Credentials round-trip and write/restart failures preserve both files and state.
reset_config
for state in stopped running; do
    echo "$state" > "$scratch/service-state"
    configureSocks5Outbound custom '[::1]:1080' 'user " 中文' 'p"ass\with # spaces' > /dev/null
    assert_eq "$(yq '.outbounds[0].socks5.username' "$HIHY_CONFIG_FILE")" 'user " 中文'
    assert_eq "$(yq '.outbounds[0].socks5.password' "$HIHY_CONFIG_FILE")" 'p"ass\with # spaces'
    assert_eq "$(yq '.socks5_status' "$HIHY_BACKUP_FILE")" true
    assert_eq "$(cat "$scratch/service-state")" "$state"
    configureSocks5Outbound remove > /dev/null
    assert_eq "$(yq '.outbounds[0].name' "$HIHY_CONFIG_FILE")" hihy
    assert_eq "$(yq '.socks5_status' "$HIHY_BACKUP_FILE")" false
    assert_eq "$(cat "$scratch/service-state")" "$state"
done
addSocks5Outbound <<< $'2\n127.0.0.1:1080\nalice\np"ass' > /dev/null
assert_eq "$(yq '.outbounds[0].socks5.password' "$HIHY_CONFIG_FILE")" 'p"ass'
addSocks5Outbound <<< 3 > /dev/null
cp "$HIHY_CONFIG_FILE" "$scratch/socks-before"
cp "$HIHY_BACKUP_FILE" "$scratch/socks-backup-before"
(
    yq() { [ -z "${HIHY_SOCKS_NAME:-}" ] || return 1; command yq "$@"; }
    if configureSocks5Outbound custom 127.0.0.1:1080 a b; then fail 'YAML write failure hidden'; fi
)
(
    serviceRestart() { [ "$(yq '.outbounds[0].name' "$HIHY_CONFIG_FILE")" = hihy ]; }
    if configureSocks5Outbound custom 127.0.0.1:1080 a b; then fail 'restart failure hidden'; fi
)
cmp "$scratch/socks-before" "$HIHY_CONFIG_FILE" || fail 'SOCKS rollback lost config'
cmp "$scratch/socks-backup-before" "$HIHY_BACKUP_FILE" || fail 'SOCKS rollback lost metadata'

# Exact ACL deletion retains unrelated domains and supports case-insensitive DNS.
printf '%s\n' 'reject(suffix:example.com)' 'v4_only(suffix:example.com)' 'reject(suffix:notexample.com)' 'reject(suffix:exampleXcom)' 'reject(all, udp/443)' > "$HIHY_ACL_FILE"
aclControl <<< $'2\nEXAMPLE.COM' > /dev/null
assert_eq "$(wc -l < "$HIHY_ACL_FILE")" 3
grep -qxF 'reject(suffix:notexample.com)' "$HIHY_ACL_FILE" || fail 'unrelated suffix deleted'
grep -qxF 'reject(suffix:exampleXcom)' "$HIHY_ACL_FILE" || fail 'regex matched literal dot'

# A real wildcard certificate must not silently replace an incompatible client SNI.
reset_config
ensureCertificateManagerDirectories
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$scratch/shared.key" -out "$scratch/shared.crt" \
    -subj '/CN=*.example.com' -addext 'subjectAltName=DNS:*.example.com' -days 3 >/dev/null 2>&1
publishSharedCertificate "$scratch/shared.crt" "$scratch/shared.key" example.com
first_release=$(readlink "$HIHY_SHARED_CERT_DIR/current")
publishSharedCertificate "$scratch/shared.crt" "$scratch/shared.key" example.com
[ "$(readlink "$HIHY_SHARED_CERT_DIR/current")" != "$first_release" ] || fail 'same-second publication overwrote release'
for host in example.com a.b.example.com node.example.com.evil.test -bad.example.com; do
    if validateWildcardHostname example.com "$host"; then fail "invalid wildcard hostname accepted: $host"; fi
done
validateWildcardHostname EXAMPLE.COM Node.example.com || fail 'valid hostname rejected'
cp "$HIHY_CONFIG_FILE" "$scratch/cert-before"
if migrateLocalHysteriaToSharedCertificate example.com 2>/dev/null; then fail 'incompatible SNI accepted'; fi
cmp "$scratch/cert-before" "$HIHY_CONFIG_FILE" || fail 'refused migration changed configuration'
(
    serviceRestart() { [ "$(yq '.tls.cert' "$HIHY_CONFIG_FILE")" = old.crt ]; }
    if migrateLocalHysteriaToSharedCertificate example.com node.example.com; then fail 'failed certificate restart accepted'; fi
)
cmp "$scratch/cert-before" "$HIHY_CONFIG_FILE" || fail 'certificate rollback lost config'
assert_eq "$(yq '.domain' "$HIHY_BACKUP_FILE")" helloworld.com
for state in stopped running; do
    echo "$state" > "$scratch/service-state"
    migrateLocalHysteriaToSharedCertificate example.com node.example.com > /dev/null
    assert_eq "$(cat "$scratch/service-state")" "$state"
done
assert_eq "$(yq '.domain' "$HIHY_BACKUP_FILE")" node.example.com
assert_eq "$(yq '.insecure' "$HIHY_BACKUP_FILE")" false
assert_eq "$(yq '.serverAddress' "$HIHY_BACKUP_FILE")" 127.0.0.1
mkdir "$scratch/exports"
(
    cd "$scratch/exports"
    generate_qr() { return 0; }
    generate_client_config > /dev/null
    assert_eq "$(yq '.tls.sni' Hy2-audit-v2rayN.yaml)" node.example.com
    assert_eq "$(yq '.tls.insecure' Hy2-audit-v2rayN.yaml)" false
)
initCertificateReceiver example.com receiver.example.com > /dev/null
echo stopped > "$scratch/service-state"
mkdir "$scratch/package"
cp "$scratch/shared.crt" "$scratch/package/fullchain.pem"
cp "$scratch/shared.key" "$scratch/package/privkey.pem"
tar -czf "$scratch/package.tgz" -C "$scratch/package" fullchain.pem privkey.pem
receiveCertificatePackage < "$scratch/package.tgz" > /dev/null
assert_eq "$(yq '.domain' "$HIHY_BACKUP_FILE")" receiver.example.com
assert_eq "$(cat "$scratch/service-state")" stopped

# Failed uninstall must retain the launcher, state and configuration before touching host services.
(
    classifyInstallState() { echo installed; }
    serviceStop() { return 0; }
    removeOwnedFirewallRules() { return 1; }
    touch "$HIHY_BIN_LINK"
    echo 'backend=iptables|protocol=udp|port=44443' > "$HIHY_FIREWALL_STATE_FILE"
    if uninstall <<< UNINSTALL; then fail 'failed cleanup reported successful uninstall'; fi
    [ -f "$HIHY_CONFIG_FILE" ] && [ -f "$HIHY_FIREWALL_STATE_FILE" ] && [ -f "$HIHY_BIN_LINK" ] || fail 'uninstall deleted recovery files'
)

# Cron removal preserves user jobs and removes both managed jobs.
(
    cron_file="$scratch/crontab"
    crontab() { if [ "$1" = -l ]; then cat "$cron_file"; else cp "$1" "$cron_file"; fi; }
    detectServiceManager() { echo openrc; }
    printf '0 0 * * * /bin/true\n' > "$cron_file"
    installCronTask
    installCertificateRenewTimer
    removeCronTask
    assert_eq "$(cat "$cron_file")" '0 0 * * * /bin/true'
)

# Source refresh failure, install failure and missing tools after success all stop installation.
for scenario in refresh install missing success; do
(
    available=false
    command() {
        if [ "${1:-}" = -v ]; then
            if [ "$2" = bc ]; then [ "$available" = true ]; else return 0; fi
        else builtin command "$@"; fi
    }
    apt() {
        if [ "$1" = update ]; then [ "$scenario" != refresh ]; return; fi
        [ "$scenario" != install ] || return 100
        if [ "$scenario" = success ]; then available=true; fi
        return 0
    }
    if [ "$scenario" = success ]; then
        checkSystemForUpdate > /dev/null
    elif checkSystemForUpdate > /dev/null; then
        fail "dependency $scenario failure ignored"
    fi
)
done

# Bootstrap keeps the child's exit code, and rejects invalid downloads without replacing the launcher.
(
    id() { echo 0; }
    curl() { while [ "$1" != -o ]; do shift; done; cp "$HIHY_TEST_DOWNLOAD" "$2"; }
    export -f id curl
    export HIHY_BIN="$scratch/bootstrap" HIHY_TEST_DOWNLOAD="$scratch/download.sh"
    for status in 0 7; do
        printf '#!/bin/bash\nhihyV="test"\ncheckRoot() { :; }\nexit %s\n' "$status" > "$HIHY_TEST_DOWNLOAD"
        result=0
        bash "$repo/server/install.sh" > /dev/null || result=$?
        assert_eq "$result" "$status"
    done
    cp "$HIHY_BIN" "$scratch/bootstrap-before"
    echo 'broken ) shell' > "$HIHY_TEST_DOWNLOAD"
    if bash "$repo/server/install.sh" > /dev/null 2>&1; then fail 'invalid bootstrap accepted'; fi
    cmp "$HIHY_BIN" "$scratch/bootstrap-before" || fail 'invalid download replaced launcher'
)
(
    cd "$scratch"
    if python3 "$repo/optimize_hihy.py" > /dev/null 2>&1; then fail 'retired optimizer succeeded'; fi
    [ ! -e server/hy2.optimized.sh ] || fail 'retired optimizer generated unsafe script'
)
printf 'PASS: numeric/exit recovery, SOCKS credentials and rollback, ACL deletion, certificate SNI and rollback, uninstall, cron, dependencies, installer and retired optimizer\n'
