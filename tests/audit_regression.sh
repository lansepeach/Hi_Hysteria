#!/usr/bin/env bash
# Audit regressions: all filesystem changes are under scratch, no external services.
set -euo pipefail
cd "$(dirname "$0")/.."
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export HIHY_ROOT_DIR="$scratch/root" HIHY_BIN_LINK="$scratch/hihy"
export HIHY_SERVICE_FILE="$scratch/service" HIHY_INIT_SERVICE="$scratch/init" HIHY_LEGACY_SERVICE="$scratch/legacy"
export HIHY_RC_LOCAL="$scratch/rc.local" HIHY_PID_FILE="$scratch/pid"
export HIHY_NFT_SERVICE_FILE="$scratch/nft-service"
source server/hy2.sh
fail() { echo "FAIL: $*" >&2; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "expected '$2', got '$1'"; }
for unsafe in systemctl rc-service rc-update nft iptables ip6tables curl wget apt crontab ssh; do
    eval "$unsafe() { fail 'unexpected host command: $unsafe'; }"
done
ensureHihyDirectories
ensureCertificateManagerDirectories
cat > "$HIHY_CONFIG_FILE" <<'YAML'
listen: :44443
auth: {type: password, password: test-password}
outbounds: [{name: hihy, type: direct, direct: {mode: auto}}]
YAML
printf 'domain: node.example.com\n' > "$HIHY_BACKUP_FILE"
printf 'reject(suffix:old.example.com)\n' > "$HIHY_ACL_FILE"
echo stopped > "$scratch/service-state"
serviceIsActive() { [ "$(cat "$scratch/service-state")" = running ]; }
serviceRestart() { echo restarted >> "$scratch/restarts"; echo running > "$scratch/service-state"; }
waitHihyServiceHealthy() { serviceIsActive; }

# Stopped services stay stopped; failed live changes restore exactly the old files.
configureOutboundIPMode 46 > /dev/null
assert_eq "$(yq '.outbounds[0].direct.mode' "$HIHY_CONFIG_FILE")" 46
[ ! -f "$scratch/restarts" ] || fail 'IP selection started a stopped service'
cp "$HIHY_CONFIG_FILE" "$scratch/config-before"
echo running > "$scratch/service-state"
(
    serviceRestart() { [ "$(yq '.outbounds[0].direct.mode' "$HIHY_CONFIG_FILE")" = 46 ]; }
    if configureOutboundIPMode 6 > /dev/null; then fail 'failed IP restart reported success'; fi
)
cmp "$HIHY_CONFIG_FILE" "$scratch/config-before" || fail 'IP rollback lost config'
if configureOutboundIPMode invalid > /dev/null; then fail 'invalid IP mode accepted'; fi
for value in 'example.com)' 'example.com:443' $'example.com\nreject(all)'; do
    if updateACLRule add "$value" reject > /dev/null; then fail 'invalid ACL domain accepted'; fi
done
cp "$HIHY_ACL_FILE" "$scratch/acl-before"
(
    serviceRestart() { ! grep -q 'new.example.com' "$HIHY_ACL_FILE"; }
    if updateACLRule add new.example.com reject > /dev/null; then fail 'failed ACL restart reported success'; fi
)
cmp "$HIHY_ACL_FILE" "$scratch/acl-before" || fail 'ACL addition rollback failed'
(
    serviceRestart() { grep -q 'old.example.com' "$HIHY_ACL_FILE"; }
    if updateACLRule remove old.example.com > /dev/null; then fail 'failed ACL removal reported success'; fi
)
cmp "$HIHY_ACL_FILE" "$scratch/acl-before" || fail 'ACL deletion rollback failed'
echo stopped > "$scratch/service-state"
updateACLRule add NEW.example.com reject > /dev/null
[ ! -f "$scratch/restarts" ] || fail 'ACL started a stopped service'

# Link members and arbitrary archive files never reach certificate/profile consumers.
python3 - "$scratch" <<'PY'
import io, sys, tarfile
from pathlib import Path
root = Path(sys.argv[1])
for kind in ('symlink', 'hardlink', 'traversal', 'extra', 'duplicate', 'oversized'):
    with tarfile.open(root / (kind + '.tgz'), 'w:gz') as archive:
        for name in ('fullchain.pem', 'privkey.pem'):
            member = tarfile.TarInfo(name)
            member.size = 2 * 1024 * 1024 + 1 if kind == 'oversized' and name == 'fullchain.pem' else 1
            archive.addfile(member, io.BytesIO(b'x' * member.size))
        if kind == 'oversized':
            continue
        member = tarfile.TarInfo('fullchain.pem' if kind == 'duplicate' else 'extra')
        if kind == 'symlink':
            member.type = tarfile.SYMTYPE
            member.linkname = str(root / 'outside')
        elif kind == 'hardlink':
            member.type = tarfile.LNKTYPE
            member.linkname = 'fullchain.pem'
        elif kind == 'traversal':
            member.name = '../outside'
        elif kind == 'oversized':
            member.name = 'profile/manager.conf'
            member.size = 2 * 1024 * 1024 + 1
        archive.addfile(member, io.BytesIO(b'0' * member.size))
PY
for kind in symlink hardlink traversal extra duplicate oversized; do
    mkdir "$scratch/extract-$kind"
    if extractCertificateArchive certificate "$scratch/extract-$kind" < "$scratch/$kind.tgz" > /dev/null 2>&1; then
        fail "unsafe $kind archive accepted"
    fi
done
[ ! -e "$scratch/outside" ] || fail 'archive wrote outside staging'

# Build a valid import bundle; GPG and token verification are isolated fixtures.
mkdir -p "$scratch/package/profile/nodes"
cat > "$scratch/package/profile/manager.conf" <<'CONF'
mode=manager
domain=example.com
email=admin@example.com
renew_days=30
CONF
printf 'imported-token' > "$scratch/package/profile/cloudflare.token"
printf 'name=new\nhost=new.example.com\nport=22\nuser=root\ndomain=new.example.com\n' > "$scratch/package/profile/nodes/new.conf"
tar -czf "$scratch/profile.tgz" -C "$scratch/package" profile
touch "$scratch/profile.gpg"
gpg() { [ "$1" = --output ] || fail 'unexpected gpg command'; cp "$scratch/profile.tgz" "$2"; }
writeCertificateManagerConfig example.com original@example.com
printf original-token > "$HIHY_CERT_TOKEN_FILE"
printf 'name=old\n' > "$HIHY_CERT_MANAGER_DIR/nodes/old.conf"
printf 'status=success\ncert_sha256=old\n' > "$HIHY_CERT_MANAGER_DIR/state/node-old.state"
cp "$HIHY_CERT_MANAGER_CONFIG" "$scratch/manager-before"
verifyCloudflareToken() { return 1; }
if importCertificateManagerProfile "$scratch/profile.gpg" <<< IMPORT > /dev/null; then fail 'bad imported token accepted'; fi
cmp "$HIHY_CERT_MANAGER_CONFIG" "$scratch/manager-before" || fail 'invalid token overwrote manager'
assert_eq "$(cat "$HIHY_CERT_TOKEN_FILE")" original-token
verifyCloudflareToken() { [ "$(cat "$HIHY_CERT_TOKEN_FILE")" = imported-token ]; }
importCertificateManagerProfile "$scratch/profile.gpg" <<< '' > /dev/null
cmp "$HIHY_CERT_MANAGER_CONFIG" "$scratch/manager-before" || fail 'cancelled import modified manager'
(
    mv() {
        if [ "${!#}" = "$HIHY_CERT_TOKEN_FILE" ]; then return 1; fi
        command mv "$@"
    }
    if importCertificateManagerProfile "$scratch/profile.gpg" <<< IMPORT > /dev/null; then fail 'failed profile write hidden'; fi
)
cmp "$HIHY_CERT_MANAGER_CONFIG" "$scratch/manager-before" || fail 'write failure lost manager'
assert_eq "$(cat "$HIHY_CERT_TOKEN_FILE")" original-token
[ -f "$HIHY_CERT_MANAGER_DIR/nodes/old.conf" ] && [ -f "$HIHY_CERT_MANAGER_DIR/state/node-old.state" ] || fail 'profile rollback lost nodes/state'
importCertificateManagerProfile "$scratch/profile.gpg" <<< IMPORT > /dev/null
assert_eq "$(cat "$HIHY_CERT_TOKEN_FILE")" imported-token
[ -f "$HIHY_CERT_MANAGER_DIR/nodes/new.conf" ] && [ ! -e "$HIHY_CERT_MANAGER_DIR/nodes/old.conf" ] || fail 'node list not replaced'
[ ! -e "$HIHY_CERT_MANAGER_DIR/state/node-old.state" ] || fail 'stale deployment success survived import'
[ -z "$(find "$HIHY_CERT_MANAGER_DIR" -maxdepth 1 -name '.profile-*' -print)" ] || fail 'profile transaction leaked'
if validateCertificateNodeField host $'valid.example\ninvalid host'; then fail 'multiline node field accepted'; fi

# Certificate commands share a lock, including nested publication during renewal.
mkdir "${HIHY_CERT_MANAGER_DIR}.operation.lock"
if importCertificateManagerProfile "$scratch/profile.gpg" <<< IMPORT > /dev/null; then fail 'parallel import accepted'; fi
if renewAndDeployCertificates > /dev/null; then fail 'parallel renewal accepted'; fi
rmdir "${HIHY_CERT_MANAGER_DIR}.operation.lock"
innerLockCheck() { [ -d "${HIHY_CERT_MANAGER_DIR}.operation.lock" ]; }
nestedLockCheck() { withCertificateOperationLock innerLockCheck; innerLockCheck; }
withCertificateOperationLock nestedLockCheck
[ ! -e "${HIHY_CERT_MANAGER_DIR}.operation.lock" ] || fail 'certificate lock leaked'

# UFW DENY/outbound entries cannot satisfy an inbound allow request.
(
    ufw() {
        case "$1" in
            status) printf '44443/udp  DENY IN  Anywhere\n44443/udp  ALLOW OUT  Anywhere\n' ;;
            insert) assert_eq "$*" 'insert 1 allow 44443/udp'; echo inserted > "$scratch/ufw-inserted" ;;
            *) fail 'unexpected UFW command' ;;
        esac
    }
    if firewallRuleExists ufw udp 44443; then fail 'DENY or outbound rule treated as inbound allow'; fi
    allowPort udp 44443 ufw > /dev/null
    [ -f "$scratch/ufw-inserted" ] || fail 'UFW allow was not inserted before existing denies'
)
rm -f "$HIHY_FIREWALL_STATE_FILE"

# A changed firewalld default zone must not redirect removal into an unrelated zone.
(
    echo public > "$scratch/default-zone"
    firewall-cmd() {
        case "$1" in
            --get-default-zone) cat "$scratch/default-zone" ;;
            --reload) return 0 ;;
            --zone=*)
                case "$2" in
                    --query-port=*) return 1 ;;
                    --add-port=*) echo "$1" > "$scratch/firewalld-added" ;;
                    --remove-port=*) echo "$1" > "$scratch/firewalld-removed" ;;
                    *) fail 'unexpected firewalld command' ;;
                esac ;;
            *) fail 'unexpected firewalld command' ;;
        esac
    }
    nftOwnedTableExists() { return 1; }
    allowPort udp 44443 firewalld > /dev/null
    grep -qx 'backend=firewalld|protocol=udp|port=44443|zone=public' "$HIHY_FIREWALL_STATE_FILE" || fail 'zone was not recorded'
    echo internal > "$scratch/default-zone"
    removeOwnedFirewallRules
    assert_eq "$(cat "$scratch/firewalld-removed")" --zone=public
)

# Installer/launcher failures must not be masked by chmod/cleanup returning success.
printf original > "$HIHY_BIN_LINK"
printf replacement > "$scratch/launcher-source"
(
    cp() { return 1; }
    if installHihyLauncher "$scratch/launcher-source"; then fail 'launcher copy failure hidden'; fi
)
assert_eq "$(cat "$HIHY_BIN_LINK")" original
(
    command() {
        if [ "${1:-}" = -v ] && { [ "$2" = curl ] || [ "$2" = wget ]; }; then return 1; fi
        builtin command "$@"
    }
    if downloadToFile https://unused.invalid/file "$scratch/no-downloader"; then fail 'download without client accepted'; fi
    [ -z "$(find "$scratch" -maxdepth 1 -name '.no-downloader.tmp.*' -print)" ] || fail 'failed download leaked temp file'
)
printf 'PASS: archive restrictions, profile validation/rollback, certificate locking, IP/ACL recovery and launcher failure reporting\n'
