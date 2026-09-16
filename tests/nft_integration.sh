#!/usr/bin/env bash
# Requires root, nft, iproute2, yq v4 and Python. Never modifies the host network.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$#" -eq 0 ]; then
    exec unshare --net -- bash "$0" "$(readlink /proc/self/ns/net)"
fi
[ "$1" != "$(readlink /proc/self/ns/net)" ] || { echo 'Network namespace isolation failed' >&2; exit 1; }
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export HIHY_ROOT_DIR="$scratch/root" HIHY_BIN_LINK="$scratch/hihy"
export HIHY_SERVICE_FILE="$scratch/hihy.service" HIHY_NFT_SERVICE_FILE="$scratch/firewall.service"
export HIHY_INIT_SERVICE="$scratch/init" HIHY_LEGACY_SERVICE="$scratch/legacy" HIHY_RC_LOCAL="$scratch/rc.local"
source server/hy2.sh
fail() { echo "FAIL: $*" >&2; exit 1; }
# Service manager operations are fixtures; packet filtering uses the real kernel.
detectServiceManager() { echo legacy; }
systemctl() { return 0; }
rc-update() { return 0; }
installHihyLauncher "$PWD/server/hy2.sh"
ensureHihyDirectories
ip link set lo up
nft -f - <<'NFT'
table inet administrator {
    chain input {
        type filter hook input priority 0; policy drop;
        ct state established,related accept
        udp dport 5353 accept comment "admin-udp-5353"
    }
    chain later {
        type filter hook input priority 20; policy accept;
        ct state established,related accept
        udp dport 5353 accept comment "admin-udp-5353"
        drop
    }
    chain forward {
        type filter hook forward priority 0; policy drop;
    }
}
table ip administrator4 {
    chain input {
        type filter hook input priority 10; policy drop;
        ct state established,related accept
        udp dport 5353 accept comment "admin-udp-5353"
    }
}
table ip6 administrator6 {
    chain input {
        type filter hook input priority 10; policy drop;
        ct state established,related accept
        udp dport 5353 accept comment "admin-udp-5353"
    }
}
NFT
nft list ruleset > "$scratch/baseline.nft"
# Older installations use a table comment, which older nft JSON output omits.
nft -f - <<'NFT'
table inet hihy_firewall {
    comment "hihy-owned:v1"
    chain hihy_input {
        type filter hook input priority -10; policy accept;
        udp dport 4433 accept
    }
}
NFT

probe_udp() {
    python3 - "$1" "$2" <<'PY'
import socket, sys
port, allowed = int(sys.argv[1]), sys.argv[2] == 'allowed'
for family, host in [(socket.AF_INET, '127.0.0.1'), (socket.AF_INET6, '::1')]:
    with socket.socket(family, socket.SOCK_DGRAM) as receiver, socket.socket(family, socket.SOCK_DGRAM) as sender:
        receiver.bind((host, port))
        receiver.settimeout(0.3)
        sender.sendto(b'firewall probe', (host, port))
        try:
            received = receiver.recv(100) == b'firewall probe'
        except socket.timeout:
            received = False
        assert received == allowed, (host, port, received, allowed)
PY
}
probe_udp 443 blocked
allowPort udp 4433 nft
probe_udp 443 blocked
allowPort udp 443 nft
allowPort udp 47000:47002 nft
allowPort tcp 443 nft
probe_udp 443 allowed
probe_udp 4433 allowed
probe_udp 47000 allowed
probe_udp 47002 allowed
probe_udp 47003 blocked
probe_udp 5353 allowed
python3 - <<'PY'
import socket
for family, host in [(socket.AF_INET, '127.0.0.1'), (socket.AF_INET6, '::1')]:
    with socket.socket(family, socket.SOCK_STREAM) as server, socket.socket(family, socket.SOCK_STREAM) as client:
        server.bind((host, 443))
        server.listen()
        client.settimeout(2)
        client.connect((host, 443))
        peer, _ = server.accept()
        with peer:
            peer.sendall(b'accepted')
            assert client.recv(8) == b'accepted'
PY

# Repeated application replaces only managed rules and must not create duplicates.
allowPort udp 443 nft
nft -j list ruleset > "$scratch/live.json"
python3 - "$scratch/live.json" <<'PY'
import json, sys
rules = [x['rule'] for x in json.load(open(sys.argv[1]))['nftables'] if 'rule' in x]
owned = [r for r in rules if r.get('comment', '').startswith('hihy-owned:input:v1:')]
assert len(owned) == 16, len(owned)  # four port/protocol pairs in four base chains
assert not any(r['chain'] == 'forward' for r in owned)
PY

# Failed application must preserve the live rules and remove only the failed state entry.
cp "$HIHY_FIREWALL_STATE_FILE" "$scratch/state-before"
nft list ruleset > "$scratch/before-failure.nft"
(
    nft() {
        if [ "${1:-}" = -j ] && [ "${2:-}" = -f ]; then return 1; fi
        command nft "$@"
    }
    if allowPort udp 444 nft; then fail 'failed transaction reported success'; fi
    if removeOwnedFirewallRules; then fail 'failed removal reported success'; fi
)
cmp "$scratch/state-before" "$HIHY_FIREWALL_STATE_FILE" || fail 'failed operation changed ownership'
[ -f "$HIHY_NFT_LOADER" ] || fail 'failed removal discarded loader'
nft list ruleset > "$scratch/after-failure.nft"
cmp "$scratch/before-failure.nft" "$scratch/after-failure.nft" || fail 'failed transaction changed live rules'

# A firewall reload changes handles and removes our rules. The boot loader rebuilds them.
nft flush ruleset
nft -f "$scratch/baseline.nft"
"$HIHY_NFT_LOADER"
probe_udp 443 allowed
probe_udp 47001 allowed
removeOwnedFirewallRules
probe_udp 443 blocked
probe_udp 5353 allowed
nft list ruleset > "$scratch/after.nft"
cmp "$scratch/baseline.nft" "$scratch/after.nft" || fail 'administrator rules changed during cleanup'
[ ! -f "$HIHY_FIREWALL_STATE_FILE" ] || fail 'ownership state remains'
[ ! -f "$HIHY_NFT_LOADER" ] || fail 'loader remains'

# Preserve an administrator table with the same name and leave failed additions unowned.
nft add table inet hihy_firewall
if allowPort udp 444 nft; then fail 'unowned table replaced'; fi
if firewallRuleExists nft udp 444; then fail 'failed addition recorded as owned'; fi
removeOwnedFirewallRules
nft list table inet hihy_firewall >/dev/null || fail 'unowned table removed'
echo 'PASS: nftables IPv4/IPv6 traffic, multiple INPUT chains, port ranges, reload, ownership and cleanup'
