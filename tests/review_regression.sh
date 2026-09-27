#!/usr/bin/env bash
# Review fixes: isolated files, real certificate/archive handling, mocked host services.
set -euo pipefail
cd "$(dirname "$0")/.."
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export HIHY_ROOT_DIR="$scratch/root" HIHY_BIN_LINK="$scratch/hihy"
export HIHY_SERVICE_FILE="$scratch/hihy.service" HIHY_INIT_SERVICE="$scratch/init"
export HIHY_LEGACY_SERVICE="$scratch/legacy" HIHY_RC_LOCAL="$scratch/rc.local"
export HIHY_NFT_SERVICE_FILE="$scratch/hihy-firewall.service"
export HIHY_CERT_RENEW_SERVICE_FILE="$scratch/hihy-cert-renew.service"
export HIHY_CERT_RENEW_TIMER_FILE="$scratch/hihy-cert-renew.timer"
source server/hy2.sh
fail() { echo "FAIL: $*" >&2; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "expected '$2', got '$1'"; }
for unsafe in systemctl systemd-analyze rc-service rc-update nft iptables ip6tables curl wget crontab ssh; do
    eval "$unsafe() { fail 'unexpected host command: $unsafe'; }"
done
ensureHihyDirectories
printf '#!/bin/sh\necho "Version: v2.12.3"\n' > "$HIHY_ROOT_DIR/bin/appS"
chmod +x "$HIHY_ROOT_DIR/bin/appS"

# Repeated failed reception must retain the old active release, without leaking candidates.
(
    initCertificateReceiver example.com node.example.com > /dev/null
    printf 'domain: node.example.com\n' > "$HIHY_BACKUP_FILE"
    printf 'listen: :44443\nauth: {type: password, password: test}\n' > "$HIHY_CONFIG_FILE"
    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
        -keyout "$scratch/privkey.pem" -out "$scratch/fullchain.pem" \
        -subj '/CN=*.example.com' -addext 'subjectAltName=DNS:*.example.com' -days 3 >/dev/null 2>&1
    publishSharedCertificate "$scratch/fullchain.pem" "$scratch/privkey.pem" example.com
    original=$(readlink "$HIHY_SHARED_CERT_DIR/current")
    touch -d '2020-01-01' "$HIHY_SHARED_CERT_DIR/$original"
    tar -czf "$scratch/certificate.tgz" -C "$scratch" fullchain.pem privkey.pem
    (
        migrateLocalHysteriaToSharedCertificate() { return 1; }
        for attempt in 1 2 3 4; do
            if receiveCertificatePackage < "$scratch/certificate.tgz" > /dev/null; then fail 'failed receive reported success'; fi
            assert_eq "$(readlink "$HIHY_SHARED_CERT_DIR/current")" "$original"
            cmp "$scratch/fullchain.pem" "$HIHY_SHARED_CERT_DIR/current/fullchain.pem" || fail 'rollback certificate deleted'
            assert_eq "$(find "$HIHY_SHARED_CERT_DIR/releases" -mindepth 1 -maxdepth 1 -type d | wc -l)" 1
        done
    )
    serviceIsActive() { return 1; }
    for attempt in 1 2 3 4; do
        receiveCertificatePackage < "$scratch/certificate.tgz" > /dev/null
    done
    [ -f "$HIHY_SHARED_CERT_DIR/current/fullchain.pem" ] || fail 'successful receive lost active certificate'
    assert_eq "$(find "$HIHY_SHARED_CERT_DIR/releases" -mindepth 1 -maxdepth 1 -type d | wc -l)" 3
    assert_eq "$(yq '.tls.cert' "$HIHY_CONFIG_FILE")" "$HIHY_SHARED_CERT_DIR/current/fullchain.pem"
)

# Exercise actual reconfiguration, dependency editing, and rollback with service fixtures.
for initial in running stopped; do
    for scenario in success start-failure reload-failure; do
        [ "$scenario:$initial" != start-failure:stopped ] || continue
        (
            printf 'auth: {type: password, password: test}\nphase: old\n' > "$HIHY_CONFIG_FILE"
            printf 'realmMode: false\nserverPort: 44443\n' > "$HIHY_BACKUP_FILE"
            printf 'backend=nft|protocol=udp|port=44443\n' > "$HIHY_FIREWALL_STATE_FILE"
            touch "$HIHY_NFT_SERVICE_FILE"
            printf '%s\n' "$initial" > "$scratch/service-state"
            detectServiceManager() { echo systemd; }
            getStartCommand() { :; }
            systemd-analyze() { return 0; }
            systemctl() {
                [ "$*" = daemon-reload ] || fail "unexpected systemctl: $*"
                if [ "$scenario" = reload-failure ] && [ "$(yq '.phase' "$HIHY_CONFIG_FILE")" = new ]; then return 1; fi
                cp "$HIHY_SERVICE_FILE" "$scratch/loaded.service"
            }
            writeSystemdService
            printf '\n# custom setting\n' >> "$HIHY_SERVICE_FILE"
            cp "$HIHY_SERVICE_FILE" "$scratch/unit-before"
            classifyInstallState() { echo installed; }
            prepareECH() { ech_key_path=''; }
            serviceIsActive() { [ "$(cat "$scratch/service-state")" = running ]; }
            serviceStop() { echo stopped > "$scratch/service-state"; }
            serviceStart() {
                if grep -q '^Requires=hihy-firewall.service$' "$HIHY_SERVICE_FILE" && [ ! -f "$HIHY_NFT_SERVICE_FILE" ]; then return 1; fi
                if [ "$scenario" = start-failure ] && [ "$(yq '.phase' "$HIHY_CONFIG_FILE")" = new ]; then return 1; fi
                echo running > "$scratch/service-state"
            }
            waitHihyServiceHealthy() { serviceIsActive; }
            removeOwnedFirewallRules() { rm -f "$HIHY_FIREWALL_STATE_FILE" "$HIHY_NFT_SERVICE_FILE"; }
            allowPort() {
                recordOwnedFirewallRule nft "$1" "$2"
                touch "$HIHY_NFT_SERVICE_FILE"
            }
            setHysteriaConfig() {
                beginReconfiguration "$2" || return 1
                printf 'phase: new\nlisten: realm://public@realm.invalid/test\n' > "$HIHY_CONFIG_FILE"
                printf 'realmMode: true\n' > "$HIHY_BACKUP_FILE"
            }
            generate_client_config() { return 0; }
            if [ "$scenario" = success ]; then
                changeServerConfig > /dev/null
                if grep -q '^Requires=hihy-firewall.service$' "$scratch/loaded.service"; then fail 'stale firewall dependency'; fi
                grep -qx '# custom setting' "$HIHY_SERVICE_FILE" || fail 'custom unit settings lost'
                # Switching back to nft reinstates its boot dependency without starting service.
                recordOwnedFirewallRule nft udp 44443
                syncHihyFirewallServiceDependency
                grep -qx 'Requires=hihy-firewall.service' "$scratch/loaded.service" || fail 'nft dependency not restored'
            else
                if changeServerConfig > /dev/null; then fail 'failed reconfiguration reported success'; fi
                cmp "$scratch/unit-before" "$HIHY_SERVICE_FILE" || fail 'unit rollback lost original settings'
                cmp "$scratch/unit-before" "$scratch/loaded.service" || fail 'restored unit not reloaded'
                [ -f "$HIHY_NFT_SERVICE_FILE" ] || fail 'firewall persistence not restored'
                assert_eq "$(yq '.phase' "$HIHY_CONFIG_FILE")" old
            fi
            assert_eq "$(cat "$scratch/service-state")" "$initial"
        )
    done
done

# The interactive wizard and exporters accept seconds with or without a suffix.
for mode in fixed random; do
    (
        set +u # The interactive script does not require nounset.
        rm -f "$HIHY_CONFIG_FILE" "$HIHY_BACKUP_FILE" "$HIHY_ACL_FILE"
        lsof() { :; }
        allowPort() { :; }
        countdown() { :; }
        generate_qr() { :; }
        startInstallValidationProcess() { printf 'server up and running\n' > "$2"; validation_pid=''; }
        answers=(1 2 "$scratch/fullchain.pem" "$scratch/privkey.pem" node.example.com 44443 1 47000 48000)
        if [ "$mode" = fixed ]; then
            answers+=(1 4 invalid 00030)
        else
            answers+=(2 4 00010 5 00010 00045)
        fi
        answers+=(2 2 test-password 1 1 Hello Hello 2 2 review)
        printf '%s\n' "${answers[@]}" | setHysteriaConfig '' > "$scratch/wizard.log" 2>&1 || {
            cat "$scratch/wizard.log"; fail 'valid wizard input rejected';
        }
        cd "$scratch"
        generate_client_config > /dev/null
        if [ "$mode" = fixed ]; then
            assert_eq "$(yq '.transport.udp.hopInterval' "$client_configfile")" 30s
            addOrUpdateYaml "$HIHY_BACKUP_FILE" portHoppingHopInterval 30 number
        else
            assert_eq "$(yq '.transport.udp.minHopInterval' "$client_configfile")" 10s
            assert_eq "$(yq '.transport.udp.maxHopInterval' "$client_configfile")" 45s
            addOrUpdateYaml "$HIHY_BACKUP_FILE" portHoppingMinHopInterval 10 number
            addOrUpdateYaml "$HIHY_BACKUP_FILE" portHoppingMaxHopInterval 45 number
        fi
        # Old backups with numeric intervals are repaired during export too.
        generate_client_config > /dev/null
        if [ "$mode" = fixed ]; then
            assert_eq "$(yq '.transport.udp.hopInterval' "$client_configfile")" 30s
        else
            assert_eq "$(yq '.transport.udp.maxHopInterval' "$client_configfile")" 45s
        fi
    )
done
for invalid in 0 4 5ss 5ms -5 1.5s 2147483648 999999999999999999999999; do
    if normalizeHopInterval "$invalid" > /dev/null; then fail "invalid interval accepted: $invalid"; fi
done

# Import onto a fresh manager installs an active timer, or reports partial failure.
(
    rm -f "$HIHY_CERT_MANAGER_DIR/config/receiver.conf"
    mkdir -p "$scratch/profile/nodes"
    printf 'mode=manager\ndomain=example.com\nemail=admin@example.com\nrenew_days=30\n' > "$scratch/profile/manager.conf"
    printf test-token > "$scratch/profile/cloudflare.token"
    tar -czf "$scratch/profile.gpg" -C "$scratch" profile
    gpg() { cp "$scratch/profile.gpg" "$2"; }
    verifyCloudflareToken() { return 0; }
    detectServiceManager() { echo systemd; }
    systemctl() {
        printf '%s\n' "$*" >> "$scratch/timer-calls"
        if [ "${timer_failure:-false}" = true ] && [ "$1" = is-active ]; then return 1; fi
    }
    importCertificateManagerProfile "$scratch/profile.gpg" <<< IMPORT > /dev/null
    [ -s "$HIHY_CERT_RENEW_SERVICE_FILE" ] && [ -s "$HIHY_CERT_RENEW_TIMER_FILE" ] || fail 'renewal units missing after import'
    grep -qx 'enable --now hihy-cert-renew.timer' "$scratch/timer-calls" || fail 'timer not enabled'
    grep -qx 'is-active --quiet hihy-cert-renew.timer' "$scratch/timer-calls" || fail 'timer not checked'
    timer_failure=true
    if importCertificateManagerProfile "$scratch/profile.gpg" <<< IMPORT > "$scratch/import.log"; then fail 'inactive timer reported success'; fi
    grep -q '当前尚不能自动续期' "$scratch/import.log" || fail 'missing partial import explanation'
    [ -f "$HIHY_CERT_MANAGER_CONFIG" ] || fail 'timer failure lost imported profile'
    detectServiceManager() { echo openrc; }
    crontab() { if [ "$1" = -l ]; then cat "$scratch/crontab"; else cp "$1" "$scratch/crontab"; fi; }
    printf '0 0 * * * /bin/true\n' > "$scratch/crontab"
    importCertificateManagerProfile "$scratch/profile.gpg" <<< IMPORT > /dev/null
    importCertificateManagerProfile "$scratch/profile.gpg" <<< IMPORT > /dev/null
    assert_eq "$(grep -c 'cert renew-auto' "$scratch/crontab")" 1
    grep -qx '0 0 \* \* \* /bin/true' "$scratch/crontab" || fail 'import lost unrelated cron job'
)

printf 'PASS: certificate retry/pruning, systemd dependency rollback, interval input/exports and renewal after import\n'
