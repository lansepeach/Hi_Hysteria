#!/usr/bin/env bash
# Real packet filtering in an isolated namespace; persistence writes only to scratch.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$#" -eq 0 ]; then
    exec unshare --net --mount -- bash "$0" "$(readlink /proc/self/ns/net)"
fi
[ "$1" != "$(readlink /proc/self/ns/net)" ] || { echo 'Network isolation failed' >&2; exit 1; }
mount --make-rprivate /
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
# Additional file isolation even if a future change bypasses our persistence fixture.
if [ -d /etc/iptables ]; then
    mkdir "$scratch/etc-iptables"
    mount --bind "$scratch/etc-iptables" /etc/iptables
fi
export HIHY_ROOT_DIR="$scratch/root" HIHY_BIN_LINK="$scratch/hihy"
export HIHY_SERVICE_FILE="$scratch/service" HIHY_INIT_SERVICE="$scratch/init" HIHY_LEGACY_SERVICE="$scratch/legacy"
export HIHY_NFT_SERVICE_FILE="$scratch/nft-service" HIHY_RC_LOCAL="$scratch/rc.local"
source server/hy2.sh
fail() { echo "FAIL: $*" >&2; exit 1; }
netfilter-persistent() {
    [ "$1" = save ] || fail 'unexpected persistence operation'
    iptables-save > "$scratch/saved.v4"
    ip6tables-save > "$scratch/saved.v6"
}
systemctl() { fail 'host service mutation'; }
rc-update() { fail 'host service mutation'; }
ensureHihyDirectories
ip link set lo up
iptables -P INPUT DROP
ip6tables -P INPUT DROP
iptables -A INPUT -p udp --dport 5353 -j ACCEPT
ip6tables -A INPUT -p udp --dport 5353 -j ACCEPT
probe() {
    python3 - "$1" "$2" <<'PY'
import socket,sys
for family,host in ((socket.AF_INET,'127.0.0.1'),(socket.AF_INET6,'::1')):
    with socket.socket(family,socket.SOCK_DGRAM) as rx, socket.socket(family,socket.SOCK_DGRAM) as tx:
        rx.bind((host,int(sys.argv[1]))); rx.settimeout(.2)
        tx.sendto(b'probe',(host,int(sys.argv[1])))
        try: received=rx.recv(100)==b'probe'
        except socket.timeout: received=False
        assert received==(sys.argv[2]=='allowed'),(host,sys.argv[1],received)
PY
}
probe 44443 blocked
allowPort udp 44443 iptables
allowPort udp 47000:47002 iptables
allowPort udp 44443 iptables
probe 44443 allowed
probe 47001 allowed
probe 47003 blocked
probe 5353 allowed
[ "$(wc -l < "$HIHY_FIREWALL_STATE_FILE")" = 4 ] || fail 'family ownership or duplicate rules'
grep -qF 'hihy-owned:udp:44443' "$scratch/saved.v4" || fail 'IPv4 not persisted'
grep -qF 'hihy-owned:udp:44443' "$scratch/saved.v6" || fail 'IPv6 not persisted'
# A failure in one family must retain its removal records for retry.
(
    ip6tables() { if [ "${3:-}" = -D ]; then return 1; fi; command ip6tables "$@"; }
    if removeOwnedFirewallRules; then fail 'IPv6 cleanup failure hidden'; fi
    [ -f "$HIHY_FIREWALL_STATE_FILE" ] || fail 'failed cleanup discarded state'
)
removeOwnedFirewallRules
probe 44443 blocked
probe 47001 blocked
probe 5353 allowed
[ ! -f "$HIHY_FIREWALL_STATE_FILE" ] || fail 'ownership records remain'
if grep -q hihy-owned "$scratch/saved.v4" "$scratch/saved.v6"; then fail 'removed rules persisted'; fi
# Upgrades from old IPv4-only records must add the missing IPv6 rule.
iptables -I INPUT -p udp --dport 44443 -m comment --comment hihy-owned:udp:44443 -j ACCEPT
recordOwnedFirewallRule iptables udp 44443
allowPort udp 44443 iptables
probe 44443 allowed
removeOwnedFirewallRules
# A failed save is an error and keeps the records needed to retry cleanup.
(
    netfilter-persistent() { return 1; }
    if allowPort udp 44443 iptables; then fail 'persistence failure hidden'; fi
    if removeOwnedFirewallRules; then fail 'removal persistence failure hidden'; fi
    [ -f "$HIHY_FIREWALL_STATE_FILE" ] || fail 'persistence failure discarded ownership'
)
removeOwnedFirewallRules
probe 44443 blocked
printf 'PASS: iptables IPv4/IPv6 traffic, ranges, legacy upgrade, ownership, persistence and failed cleanup retries\n'
