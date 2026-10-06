#!/usr/bin/env bash
# Export failure paths use temporary files and a fake core; no host services run.
set -euo pipefail
cd "$(dirname "$0")/.."
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export HIHY_ROOT_DIR="$scratch/root"
source server/hy2.sh
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$HIHY_ROOT_DIR/conf" "$HIHY_ROOT_DIR/bin" "$scratch/exports"
printf '#!/bin/sh\necho "Version: v2.13.0"\n' > "$HIHY_ROOT_DIR/bin/appS"
chmod +x "$HIHY_ROOT_DIR/bin/appS"
generate_qr() { return 0; }
cat > "$HIHY_BACKUP_FILE" <<'YAML'
remarks: export-test
serverAddress: 127.0.0.1
domain: example.com
insecure: true
realmMode: false
portHoppingStatus: false
congestionMode: bbr
congestionType: bbr
YAML
cat > "$HIHY_CONFIG_FILE" <<'YAML'
listen: :44443
auth: {type: password, password: export-password}
masquerade: {listenHTTPS: ':44443'}
YAML
cd "$scratch/exports"
native=Hy2-export-test-v2rayN.yaml
meta=Hy2-export-test-ClashMeta.yaml
generate_client_config > "$scratch/success.log"
cp "$native" "$scratch/native-before"
cp "$meta" "$scratch/meta-before"

# An unreadable ECH key must leave previously exported configurations intact.
addOrUpdateYaml "$HIHY_CONFIG_FILE" ech.keyPath "$scratch/missing-ech.pem" string
if generate_client_config > "$scratch/ech-failure.log" 2>&1; then fail 'missing ECH key accepted'; fi
cmp "$native" "$scratch/native-before" || fail 'ECH failure destroyed native export'
cmp "$meta" "$scratch/meta-before" || fail 'ECH failure destroyed Mihomo export'
yq -i 'del(.ech)' "$HIHY_CONFIG_FILE"

# Inject a failure late in each YAML writer, including calls from an if condition
# (where Bash disables errexit). The exporter must explicitly propagate failure.
eval "$(declare -f addOrUpdateYaml | sed '1s/addOrUpdateYaml/realAddOrUpdateYaml/')"
addOrUpdateYaml() {
    [ "$2" != "${fail_key:-}" ] || return 1
    realAddOrUpdateYaml "$@"
}
fail_key=tls.sni
if generate_client_config > "$scratch/native-failure.log" 2>&1; then fail 'native write failure accepted'; fi
cmp "$native" "$scratch/native-before" || fail 'write failure destroyed native export'
fail_key='proxies[0].sni'
if generateMetaYaml > "$scratch/meta-failure.log" 2>&1; then fail 'Mihomo write failure accepted'; fi
cmp "$meta" "$scratch/meta-before" || fail 'write failure destroyed Mihomo export'
fail_key=''

# Permission and rename failures must not be masked by successful cleanup.
writeFixture() { printf 'valid: true\n' > "$1"; }
printf 'previous export\n' > probe.yaml
cp probe.yaml "$scratch/probe-before"
(
    chmod() { return 1; }
    if writeClientExport probe.yaml writeFixture > /dev/null 2>&1; then fail 'chmod failure accepted'; fi
)
cmp probe.yaml "$scratch/probe-before" || fail 'chmod failure replaced old export'
(
    mv() { return 1; }
    if writeClientExport probe.yaml writeFixture > /dev/null 2>&1; then fail 'rename failure accepted'; fi
)
cmp probe.yaml "$scratch/probe-before" || fail 'rename failure replaced old export'
mkdir destination-directory
touch destination-directory/retained
if writeClientExport destination-directory writeFixture > /dev/null 2>&1; then fail 'directory destination accepted'; fi
[ -f destination-directory/retained ] || fail 'directory destination changed'

# Invalid source YAML must fail before publishing an export.
cp "$HIHY_CONFIG_FILE" "$scratch/config-before"
printf 'broken: [\n' > "$HIHY_CONFIG_FILE"
if generate_client_config > "$scratch/parse-failure.log" 2>&1; then fail 'invalid source YAML accepted'; fi
cmp "$native" "$scratch/native-before" || fail 'parse failure replaced native export'
cp "$scratch/config-before" "$HIHY_CONFIG_FILE"

# A destination symlink must never cause a write to the file it points at.
printf 'external file\n' > "$scratch/external"
cp "$scratch/external" "$scratch/external-before"
rm "$native"
ln -s "$scratch/external" "$native"
generate_client_config > /dev/null
cmp "$scratch/external" "$scratch/external-before" || fail 'export followed destination symlink'
[ ! -L "$native" ] || fail 'export did not publish a regular file'
for file in "$native" "$meta"; do
    [ "$(stat -c %a "$file")" = 600 ] || fail 'export permissions are not private'
done
[ -z "$(find . -maxdepth 1 -name '.hihy-export.*' -print)" ] || fail 'export temporary files leaked'

# The TCP notice must follow the actual listener, independently of port hopping.
for hopping in false true; do
    addOrUpdateYaml "$HIHY_BACKUP_FILE" portHoppingStatus "$hopping" bool
    addOrUpdateYaml "$HIHY_BACKUP_FILE" portHoppingStart 47000 number
    addOrUpdateYaml "$HIHY_BACKUP_FILE" portHoppingEnd 48000 number
    addOrUpdateYaml "$HIHY_CONFIG_FILE" masquerade.listenHTTPS ':44443' string
    generate_client_config > "$scratch/tcp-on.log"
    if grep -q '伪装并未监听tcp端口' "$scratch/tcp-on.log"; then fail 'TCP listener reported absent'; fi
    yq -i 'del(.masquerade.listenHTTPS)' "$HIHY_CONFIG_FILE"
    generate_client_config > "$scratch/tcp-off.log"
    grep -q '伪装并未监听tcp端口' "$scratch/tcp-off.log" || fail 'missing TCP listener not reported'
done

printf 'PASS: export rollback, YAML failures, symlink handling, private files and TCP notice\n'
