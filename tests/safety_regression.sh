#!/usr/bin/env bash
# Isolated operation guards and certificate management: no host services or network.
set -euo pipefail
cd "$(dirname "$0")/.."
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export HIHY_ROOT_DIR="$scratch/root" HIHY_BIN_LINK="$scratch/hihy"
export HIHY_INIT_SERVICE="$scratch/init" HIHY_LEGACY_SERVICE="$scratch/legacy"
export HIHY_SERVICE_FILE="$scratch/service" HIHY_PID_FILE="$scratch/pid" HIHY_RC_LOCAL="$scratch/rc.local"
source server/hy2.sh
fail() { echo "FAIL: $*" >&2; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "expected '$2', got '$1'"; }
for unsafe in systemctl rc-service rc-update nft iptables ip6tables sysctl curl wget apt dnf yum apk pacman crontab ssh ssh-keygen ssh-keyscan warp; do
    eval "$unsafe() { fail 'unexpected host command: $unsafe'; }"
done
serviceStop() { fail 'unexpected service stop'; }
removeOwnedFirewallRules() { fail 'unexpected firewall change'; }
recoverPartialInstallState() { fail 'unexpected partial install cleanup'; }
checkSystemForUpdate() { fail 'unexpected dependency installation'; }

# A launcher downloaded by install.sh is not a partially installed service.
touch "$HIHY_BIN_LINK"
assert_eq "$(classifyInstallState)" not-installed
for answer in '' y 1 install; do
    install <<< "$answer" > /dev/null
    [ ! -e "$HIHY_ROOT_DIR" ] || fail 'cancelled install wrote installation directory'
    [ ! -e "${HIHY_ROOT_DIR}.operation.lock" ] || fail 'cancelled install leaked lock'
done
install </dev/null > /dev/null
uninstall </dev/null > /dev/null
[ -f "$HIHY_BIN_LINK" ] || fail 'repeated uninstall removed launcher'

# Existing config wins even when the launcher/service is missing or a failure marker remains.
ensureHihyDirectories
printf '#!/bin/sh\nexit 0\n' > "$HIHY_ROOT_DIR/bin/appS"
chmod +x "$HIHY_ROOT_DIR/bin/appS"
touch "$HIHY_SERVICE_FILE"
assert_eq "$(classifyInstallState)" partially-installed
printf 'listen: :44443\n' > "$HIHY_CONFIG_FILE"
assert_eq "$(classifyInstallState)" installed
cp "$HIHY_CONFIG_FILE" "$scratch/original-config"
markInstallFailed old old
if install <<< INSTALL > /dev/null; then fail 'incomplete configured installation reported success'; fi
cmp "$HIHY_CONFIG_FILE" "$scratch/original-config" || fail 'existing configuration overwritten'
for answer in '' y 2 uninstall; do
    uninstall <<< "$answer" > /dev/null
    cmp "$HIHY_CONFIG_FILE" "$scratch/original-config" || fail 'cancelled uninstall removed config'
done
uninstall </dev/null > /dev/null

# Both entry points share the same lock and never enter a second operation.
mkdir -m 700 "${HIHY_ROOT_DIR}.operation.lock"
if install <<< INSTALL > /dev/null; then fail 'concurrent installation accepted'; fi
if uninstall <<< UNINSTALL > /dev/null; then fail 'concurrent uninstall accepted'; fi
rmdir "${HIHY_ROOT_DIR}.operation.lock"
(
    printf 'remarks: retained\n' > "$HIHY_BACKUP_FILE"
    cp "$HIHY_BACKUP_FILE" "$scratch/original-backup"
    markInstallFailed service test
    setHysteriaConfig() { fail 'repair re-entered configuration wizard'; }
    installHihyService() { printf 'service\n' >> "$scratch/repair-steps"; }
    waitHihyServiceHealthy() { return 0; }
    serviceIsActive() { return 0; }
    installCronTask() { return 0; }
    generate_client_config() { printf 'export\n' >> "$scratch/repair-steps"; return 1; }
    repairHihyInstallation <<< '' > /dev/null
    [ ! -e "$scratch/repair-steps" ] || fail 'unconfirmed repair changed service'
    if repairHihyInstallation <<< REPAIR > /dev/null; then fail 'failed finalization reported success'; fi
    grep -qx 'phase=finalize' "$(getInstallFailureMarker)" || fail 'missing finalization marker'
    generate_client_config() { printf 'export\n' >> "$scratch/repair-steps"; }
    repairHihyInstallation <<< REPAIR > /dev/null
    assert_eq "$(cat "$scratch/repair-steps")" $'service\nexport\nexport'
    cmp "$HIHY_CONFIG_FILE" "$scratch/original-config" || fail 'repair modified service configuration'
    cmp "$HIHY_BACKUP_FILE" "$scratch/original-backup" || fail 'repair modified backup configuration'
    [ ! -e "$(getInstallFailureMarker)" ] || fail 'successful repair left failure marker'
)
(
    rm "$HIHY_CONFIG_FILE"
    rm -f "$HIHY_BACKUP_FILE"
    classifyInstallState() { echo not-installed; }
    checkSystemForUpdate() { echo called > "$scratch/install-entered"; return 1; }
    if install <<< INSTALL > /dev/null; then fail 'installation failure hidden'; fi
    [ -f "$scratch/install-entered" ] || fail 'explicit install did not enter installer'
    [ ! -e "${HIHY_ROOT_DIR}.operation.lock" ] || fail 'failed installation leaked lock'
)
(
    # A confirmed recovery still stops safely if service/firewall cleanup fails.
    HIHY_CONFIG_FILE="$scratch/partial-config.yaml"
    HIHY_BACKUP_FILE="$scratch/partial-backup.yaml"
    classifyInstallState() { echo partially-installed; }
    serviceStop() { return 1; }
    serviceIsActive() { return 0; }
    if install <<< INSTALL > /dev/null; then fail 'recovery continued while service still running'; fi
    serviceStop() { return 0; }
    removeOwnedFirewallRules() { return 1; }
    if install <<< INSTALL > /dev/null; then fail 'recovery ignored firewall failure'; fi
    [ ! -e "${HIHY_ROOT_DIR}.operation.lock" ] || fail 'failed recovery leaked lock'
)
(
    printf 'listen: :44443\n' > "$HIHY_CONFIG_FILE"
    serviceStop() { echo stopped > "$scratch/stopped"; }
    removeOwnedFirewallRules() { return 1; }
    if uninstall <<< UNINSTALL > /dev/null; then fail 'uninstall cleanup failure hidden'; fi
    [ -f "$scratch/stopped" ] && [ -f "$HIHY_CONFIG_FILE" ] || fail 'uninstall recovery state missing'
    [ ! -e "${HIHY_ROOT_DIR}.operation.lock" ] || fail 'failed uninstall leaked lock'
)
(
    rm -f "$HIHY_SERVICE_FILE" "$HIHY_PID_FILE"
    printf '#!/bin/sh\nexit 0\n' > "$HIHY_LEGACY_SERVICE"
    chmod 755 "$HIHY_LEGACY_SERVICE"
    detectServiceManager() { echo systemd; }
    isNativeHihySystemdService() { return 1; }
    writeSystemdService() { touch "$HIHY_SERVICE_FILE"; }
    systemctl() {
        [ -d "${HIHY_ROOT_DIR}.operation.lock" ] || fail 'migration ran without lock'
        case "$1" in daemon-reload | enable) ;; *) fail "unexpected stopped-service migration operation: $*";; esac
    }
    migrateLegacyService > /dev/null
    [ -f "$HIHY_SERVICE_FILE" ] || fail 'stopped service did not migrate'
    [ ! -e "${HIHY_ROOT_DIR}.operation.lock" ] || fail 'migration leaked lock'
)
for migration in running rollback; do
(
    HIHY_SERVICE_FILE="$scratch/native-$migration"
    HIHY_LEGACY_SERVICE="$scratch/legacy-$migration"
    HIHY_INIT_SERVICE="$scratch/init-$migration"
    HIHY_RC_LOCAL="$scratch/rc-$migration"
    HIHY_PID_FILE="$scratch/pid-$migration"
    printf '#!/bin/sh\nexit 0\n' > "$HIHY_LEGACY_SERVICE"
    cp "$HIHY_LEGACY_SERVICE" "$scratch/legacy-before-$migration"
    ln -s "$HIHY_LEGACY_SERVICE" "$HIHY_INIT_SERVICE"
    printf '%s start\n' "$HIHY_LEGACY_SERVICE" > "$HIHY_RC_LOCAL"
    printf '1234\n' > "$HIHY_PID_FILE"
    detectServiceManager() { echo systemd; }
    isNativeHihySystemdService() { return 1; }
    writeSystemdService() { touch "$HIHY_SERVICE_FILE"; }
    legacyHihyProcessMatches() { [ "$1" = 1234 ]; }
    legacyHihyStop() { printf 'legacy-stop\n' >> "$scratch/steps-$migration"; rm -f "$HIHY_PID_FILE"; }
    legacyHihyStart() { printf 'legacy-start\n' >> "$scratch/steps-$migration"; }
    systemctl() {
        case "$1" in
            start) printf 'native-start\n' >> "$scratch/steps-$migration" ;;
            daemon-reload | enable | status | disable) ;;
            *) fail "unexpected migration operation: $*" ;;
        esac
    }
    waitHihyServiceHealthy() { [ "$migration" = running ]; }
    if [ "$migration" = running ]; then
        migrateLegacyService > /dev/null
        assert_eq "$(cat "$scratch/steps-$migration")" $'legacy-stop\nnative-start'
        [ ! -e "$HIHY_INIT_SERVICE" ] || fail 'old init entry remained after migration'
    else
        if migrateLegacyService > /dev/null; then fail 'unhealthy migration reported success'; fi
        assert_eq "$(cat "$scratch/steps-$migration")" $'legacy-stop\nnative-start\nlegacy-start'
        cmp "$HIHY_LEGACY_SERVICE" "$scratch/legacy-before-$migration" || fail 'legacy script not restored'
        [ ! -e "$HIHY_SERVICE_FILE" ] && [ -L "$HIHY_INIT_SERVICE" ] || fail 'failed migration did not restore service entry'
    fi
)
done

# Role detection, defaults and guards do not invoke ACME/SSH on a receiver.
assert_eq "$(getCertificateRole)" unconfigured
showCertificateManagerStatus > "$scratch/status"
grep -q '未配置' "$scratch/status" || fail 'unconfigured machine labelled as receiver'
initCertificateReceiver example.com node.example.com > /dev/null
assert_eq "$(getCertificateRole)" receiver
if initCertificateManager </dev/null > /dev/null; then fail 'receiver overwritten by manager'; fi
if addCertificateNode </dev/null > /dev/null; then fail 'receiver accepted node addition'; fi
if deployCertificateToAllNodes > /dev/null; then fail 'receiver accepted deployment'; fi
rm "$HIHY_CERT_MANAGER_DIR/config/receiver.conf"
writeCertificateManagerConfig example.com admin@example.com
if initCertificateReceiver example.com node.example.com > /dev/null; then fail 'manager overwritten by receiver'; fi

# Duplicates and deletion typos never reach SSH or lose the existing record.
node="$HIHY_CERT_MANAGER_DIR/nodes/a.conf"
printf 'name=a\nhost=a.example.com\nport=22\nuser=root\ndomain=a.example.com\n' > "$node"
cp "$node" "$scratch/original-node"
if addCertificateNode <<< a > /dev/null; then fail 'duplicate node accepted'; fi
cmp "$node" "$scratch/original-node" || fail 'duplicate node overwritten'
removeCertificateNode <<< $'a\ny' > /dev/null
cmp "$node" "$scratch/original-node" || fail 'node deletion typo accepted'
removeCertificateNode <<< $'a\na' > /dev/null
[ ! -e "$node" ] || fail 'confirmed node not removed'
if removeCertificateNode <<< a > /dev/null; then fail 'missing node deletion reported success'; fi

# Failed token validation and EOF preserve the original manager profile and credential.
printf 'old-token' > "$HIHY_CERT_TOKEN_FILE"
cp "$HIHY_CERT_MANAGER_CONFIG" "$scratch/manager-before"
(
    verifyCloudflareToken() { [ "$(cat "$HIHY_CERT_TOKEN_FILE")" = old-token ] || fail 'wrong staged token'; return 1; }
    if initCertificateManager <<< $'RECONFIGURE\n\n\nnode.example.com' > /dev/null; then
        fail 'invalid token accepted'
    fi
)
cmp "$HIHY_CERT_MANAGER_CONFIG" "$scratch/manager-before" || fail 'token failure changed manager'
assert_eq "$(cat "$HIHY_CERT_TOKEN_FILE")" old-token
[ -z "$(find "$HIHY_CERT_MANAGER_DIR/credentials" -name '.token.*' -print)" ] || fail 'token stage leaked'
initCertificateManager </dev/null > /dev/null
cmp "$HIHY_CERT_MANAGER_CONFIG" "$scratch/manager-before" || fail 'EOF changed manager'

# Initializing from scalar or list ACME domains keeps the full multi-label suffix.
(
    HIHY_CONFIG_FILE="$scratch/acme-default.yaml"
    HIHY_BACKUP_FILE="$scratch/acme-default-backup.yaml"
    HIHY_CERT_MANAGER_DIR="$scratch/default-manager"
    HIHY_CERT_MANAGER_CONFIG="$HIHY_CERT_MANAGER_DIR/config/manager.conf"
    HIHY_CERT_TOKEN_FILE="$HIHY_CERT_MANAGER_DIR/credentials/cloudflare.token"
    verifyCloudflareToken() { assert_eq "$(cat "$HIHY_CERT_TOKEN_FILE")" fixture-token; }
    installLego() { return 0; }
    issueOrRenewWildcardCertificate() { assert_eq "$(getCertificateManagerValue domain)" example.co.uk; }
    migrateLocalHysteriaToSharedCertificate() { assert_eq "$1" example.co.uk; assert_eq "$2" node.example.co.uk; }
    installCertificateRenewTimer() { return 0; }
    for domains in '"*.example.co.uk"' '["*.example.co.uk"]'; do
        rm -f "$HIHY_CERT_MANAGER_CONFIG" "$HIHY_CERT_TOKEN_FILE"
        printf 'acme: {domains: %s, email: admin@example.co.uk, dns: {config: {cloudflare_api_token: fixture-token}}}\n' "$domains" > "$HIHY_CONFIG_FILE"
        initCertificateManager <<< $'\n\nnode.example.co.uk' > /dev/null
        assert_eq "$(getCertificateManagerValue domain)" example.co.uk
    done
)

# Version-aware status and pending-only deployment share the same certificate digest.
mkdir -p "$HIHY_SHARED_CERT_DIR/releases/one"
printf certificate-one > "$HIHY_SHARED_CERT_DIR/releases/one/fullchain.pem"
printf key-one > "$HIHY_SHARED_CERT_DIR/releases/one/privkey.pem"
ln -s releases/one "$HIHY_SHARED_CERT_DIR/current"
cp "$scratch/original-node" "$node"
digest=$(sha256sum "$HIHY_SHARED_CERT_DIR/current/fullchain.pem"); digest=${digest%% *}
printf 'status=success\ncert_sha256=outdated\ndeployed_at=100\n' > "$HIHY_CERT_MANAGER_DIR/state/node-a.state"
showCertificateNodes > "$scratch/nodes"
grep -q '待同步' "$scratch/nodes" || fail 'stale success shown as synchronized'
(
    ssh() {
        [[ "$*" == *ConnectTimeout=10* && "$*" == *ServerAliveCountMax=2* && "$*" == *BatchMode=yes* ]] || fail 'SSH timeout missing'
        cat > "$scratch/package.tgz"
    }
    deployCertificateToAllNodes pending > "$scratch/deploy"
    tar -xzf "$scratch/package.tgz" -C "$scratch"
    assert_eq "$(cat "$scratch/fullchain.pem")" certificate-one
    assert_eq "$(cat "$scratch/privkey.pem")" key-one
)
grep -qx "cert_sha256=$digest" "$HIHY_CERT_MANAGER_DIR/state/node-a.state" || fail 'wrong deployment digest'
showCertificateNodes > "$scratch/nodes"
grep -q '已同步' "$scratch/nodes" || fail 'current success not shown'
deployCertificateToAllNodes pending > "$scratch/deploy"
grep -q '已同步跳过 1' "$scratch/deploy" || fail 'current certificate was not skipped'
[ -z "$(find "$HIHY_CERT_MANAGER_DIR" -name '.deploy.*' -print)" ] || fail 'deployment stage leaked'
if deployCertificateToAllNodes invalid > /dev/null; then fail 'invalid deploy mode accepted'; fi

# Failed nodes do not prevent later nodes from being tried; retry includes only failures.
sed 's/a\./b./g;s/name=a/name=b/' "$node" > "$HIHY_CERT_MANAGER_DIR/nodes/b.conf"
(
    ssh() { cat >/dev/null; [[ "${!#}" != root@a.example.com ]]; }
    if deployCertificateToAllNodes all > "$scratch/deploy"; then fail 'partial failure hidden'; fi
    grep -q '成功 1，失败 1' "$scratch/deploy" || fail 'wrong deployment summary'
    ssh() { cat >/dev/null; echo "${!#}" >> "$scratch/retried"; }
    deployCertificateToAllNodes pending > /dev/null
    assert_eq "$(cat "$scratch/retried")" root@a.example.com
)

(
    HIHY_CERT_MANAGER_CONFIG="$scratch/nonexistent-manager.conf"
    unset -f ssh-keygen
    initCertificateReceiver example.com node.example.com >/dev/null
    receiver_home="$scratch/receiver-home"
    mkdir -m 700 -p "$receiver_home/.ssh"
    chmod 700 "$receiver_home" "$HIHY_BIN_LINK"
    getent() { printf 'deploy:x:%s:0::%s:/bin/bash\n' "$(id -u)" "$receiver_home"; }
    ssh-keygen -q -t ed25519 -N '' -f "$scratch/receiver-test-key"
    expected=$(ssh-keygen -E sha256 -lf "$scratch/receiver-test-key.pub" | awk '{print $2}')
    keys="$receiver_home/.ssh/authorized_keys"
    cp "$scratch/receiver-test-key.pub" "$keys"
    if checkCertificateReceiver deploy "$expected" > "$scratch/receiver-check"; then fail 'unrestricted key accepted'; fi
    grep -q '未找到 hihy 标准格式' "$scratch/receiver-check" || fail 'missing restricted key not reported'
    printf 'restrict,command="%s cert receive" %s\n' "$HIHY_BIN_LINK" "$(cat "$scratch/receiver-test-key.pub")" > "$keys"
    chmod 600 "$keys"
    checkCertificateReceiver deploy "$expected" > "$scratch/receiver-check"
    grep -qF "$expected" "$scratch/receiver-check" || fail 'matched fingerprint not reported'
    if checkCertificateReceiver deploy "SHA256:$(printf '%043d' 0)" > "$scratch/receiver-check"; then fail 'fingerprint mismatch accepted'; fi
    grep -q '指纹不匹配' "$scratch/receiver-check" || fail 'fingerprint mismatch not reported'
    chmod 666 "$keys"
    if checkCertificateReceiver deploy "$expected" > "$scratch/receiver-check"; then fail 'writable keys accepted'; fi
    grep -q '权限异常' "$scratch/receiver-check" || fail 'unsafe permissions not reported'
    assert_eq "$(stat -c %a "$keys")" 666
)

# Multiple actions remain in the submenu, and EOF returns rather than looping forever.
certificateManagerMenu <<< $'10\n11\n0' > "$scratch/menu"
[ "$(grep -c '多服务器证书管理 ·' "$scratch/menu")" -eq 3 ] || fail 'certificate submenu exited after one action'
certificateManagerMenu </dev/null > /dev/null
printf 'PASS: install/uninstall confirmation and locks, certificate roles, duplicate/delete guards, token preservation, deployment snapshots/timeouts/retry and submenu\n'
