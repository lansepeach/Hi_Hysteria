#!/bin/bash
hihyV="ver1.19"

umask 077

HIHY_ROOT_DIR="${HIHY_ROOT_DIR:-/etc/hihy}"
HIHY_BIN_LINK="${HIHY_BIN_LINK:-/usr/bin/hihy}"
HIHY_YQ_BIN="${HIHY_YQ_BIN:-/usr/bin/yq}"
HIHY_PID_FILE="${HIHY_PID_FILE:-/var/run/hihy.pid}"
HIHY_RC_LOCAL="${HIHY_RC_LOCAL:-/etc/rc.local}"
HIHY_CONFIG_FILE="${HIHY_CONFIG_FILE:-$HIHY_ROOT_DIR/conf/config.yaml}"
HIHY_BACKUP_FILE="${HIHY_BACKUP_FILE:-$HIHY_ROOT_DIR/conf/backup.yaml}"
HIHY_ACL_FILE="${HIHY_ACL_FILE:-$HIHY_ROOT_DIR/acl/acl.txt}"
HIHY_LOG_FILE="${HIHY_LOG_FILE:-$HIHY_ROOT_DIR/logs/hihy.log}"
HIHY_SERVICE_FILE="${HIHY_SERVICE_FILE:-/etc/systemd/system/hihy.service}"
HIHY_LEGACY_SERVICE="${HIHY_LEGACY_SERVICE:-/etc/rc.d/hihy}"
HIHY_INIT_SERVICE="${HIHY_INIT_SERVICE:-/etc/init.d/hihy}"
HIHY_FIREWALL_STATE_FILE="${HIHY_FIREWALL_STATE_FILE:-$HIHY_ROOT_DIR/result/firewall-owned.state}"
HIHY_NFT_DIR="${HIHY_NFT_DIR:-$HIHY_ROOT_DIR/firewall}"
HIHY_NFT_RULESET_FILE="${HIHY_NFT_RULESET_FILE:-$HIHY_NFT_DIR/hihy-firewall.nft}"
HIHY_NFT_LOADER="${HIHY_NFT_LOADER:-$HIHY_NFT_DIR/apply.sh}"
HIHY_NFT_SERVICE_FILE="${HIHY_NFT_SERVICE_FILE:-/etc/systemd/system/hihy-firewall.service}"
HIHY_MIGRATION_STATE_FILE="${HIHY_MIGRATION_STATE_FILE:-$HIHY_ROOT_DIR/result/service-migration.state}"
HIHY_CERT_MANAGER_DIR="${HIHY_CERT_MANAGER_DIR:-$HIHY_ROOT_DIR/cert-manager}"
HIHY_CERT_MANAGER_CONFIG="${HIHY_CERT_MANAGER_CONFIG:-$HIHY_CERT_MANAGER_DIR/config/manager.conf}"
HIHY_CERT_TOKEN_FILE="${HIHY_CERT_TOKEN_FILE:-$HIHY_CERT_MANAGER_DIR/credentials/cloudflare.token}"
HIHY_CERT_DEPLOY_KEY="${HIHY_CERT_DEPLOY_KEY:-$HIHY_CERT_MANAGER_DIR/credentials/deploy_ed25519}"
HIHY_CERT_KNOWN_HOSTS="${HIHY_CERT_KNOWN_HOSTS:-$HIHY_CERT_MANAGER_DIR/known_hosts}"
HIHY_SHARED_CERT_DIR="${HIHY_SHARED_CERT_DIR:-$HIHY_ROOT_DIR/cert/shared}"
HIHY_LEGO_BIN="${HIHY_LEGO_BIN:-$HIHY_CERT_MANAGER_DIR/bin/lego}"
HIHY_LEGO_VERSION="${HIHY_LEGO_VERSION:-5.4.0}"
# ===== 自维护仓库配置 =====
HIHY_REPO_OWNER="${HIHY_REPO_OWNER:-lansepeach}"
HIHY_REPO_NAME="${HIHY_REPO_NAME:-Hi_Hysteria}"
HIHY_REPO_BRANCH="${HIHY_REPO_BRANCH:-main}"
HIHY_REMOTE_SCRIPT_PATH="${HIHY_REMOTE_SCRIPT_PATH:-server/hy2.sh}"
HIHY_REMOTE_VERSION_PATH="${HIHY_REMOTE_VERSION_PATH:-VERSION}"

HIHY_REPO_URL="${HIHY_REPO_URL:-https://github.com/${HIHY_REPO_OWNER}/${HIHY_REPO_NAME}}"
HIHY_REMOTE_SCRIPT_URL="${HIHY_REMOTE_SCRIPT_URL:-https://raw.githubusercontent.com/${HIHY_REPO_OWNER}/${HIHY_REPO_NAME}/refs/heads/${HIHY_REPO_BRANCH}/${HIHY_REMOTE_SCRIPT_PATH}}"
HIHY_REMOTE_SCRIPT_MIRROR_URL="${HIHY_REMOTE_SCRIPT_MIRROR_URL:-https://cdn.jsdelivr.net/gh/${HIHY_REPO_OWNER}/${HIHY_REPO_NAME}@${HIHY_REPO_BRANCH}/${HIHY_REMOTE_SCRIPT_PATH}}"
HIHY_REMOTE_VERSION_URL="${HIHY_REMOTE_VERSION_URL:-https://raw.githubusercontent.com/${HIHY_REPO_OWNER}/${HIHY_REPO_NAME}/refs/heads/${HIHY_REPO_BRANCH}/${HIHY_REMOTE_VERSION_PATH}}"

HIHY_VERSION_STATUS_FILE="${HIHY_VERSION_STATUS_FILE:-$HIHY_ROOT_DIR/result/version-check.state}"
HIHY_VERSION_CHECK_LOCK_FILE="${HIHY_VERSION_CHECK_LOCK_FILE:-$HIHY_ROOT_DIR/result/version-check.lock}"
HIHY_VERSION_CHECK_TTL="${HIHY_VERSION_CHECK_TTL:-21600}"
HIHY_REMOTE_CONNECT_TIMEOUT="${HIHY_REMOTE_CONNECT_TIMEOUT:-5}"
HIHY_REMOTE_MAX_TIME="${HIHY_REMOTE_MAX_TIME:-30}"

ensureHihyDirectories() {
    mkdir -p "$HIHY_ROOT_DIR/bin" "$HIHY_ROOT_DIR/conf" "$HIHY_ROOT_DIR/cert" \
        "$HIHY_ROOT_DIR/result" "$HIHY_ROOT_DIR/acl" "$HIHY_ROOT_DIR/logs" "$HIHY_NFT_DIR"
    chmod 755 "$HIHY_ROOT_DIR/bin"
    chmod 700 "$HIHY_ROOT_DIR/conf" "$HIHY_ROOT_DIR/cert" "$HIHY_ROOT_DIR/result" \
        "$HIHY_ROOT_DIR/acl" "$HIHY_ROOT_DIR/logs" "$HIHY_NFT_DIR"
}

secureHihyPermissions() {
    ensureHihyDirectories || return 1

    [ -f "$HIHY_CONFIG_FILE" ] && chmod 600 "$HIHY_CONFIG_FILE"
    [ -f "$HIHY_BACKUP_FILE" ] && chmod 600 "$HIHY_BACKUP_FILE"
    [ -f "$HIHY_ACL_FILE" ] && chmod 600 "$HIHY_ACL_FILE"
    [ -f "$HIHY_LOG_FILE" ] && chmod 600 "$HIHY_LOG_FILE"
    [ -f "$HIHY_FIREWALL_STATE_FILE" ] && chmod 600 "$HIHY_FIREWALL_STATE_FILE"
    [ -f "$HIHY_NFT_RULESET_FILE" ] && chmod 600 "$HIHY_NFT_RULESET_FILE"
    [ -f "$HIHY_NFT_LOADER" ] && chmod 700 "$HIHY_NFT_LOADER"
    [ -f "$HIHY_MIGRATION_STATE_FILE" ] && chmod 600 "$HIHY_MIGRATION_STATE_FILE"
    [ -f "$HIHY_ROOT_DIR/bin/appS" ] && chmod 755 "$HIHY_ROOT_DIR/bin/appS"
    [ -f "$HIHY_BIN_LINK" ] && chmod 755 "$HIHY_BIN_LINK"

    if [ -d "$HIHY_ROOT_DIR/cert" ]; then
        find "$HIHY_ROOT_DIR/cert" -type f -name '*.key' -exec chmod 600 {} + 2>/dev/null || true
        find "$HIHY_ROOT_DIR/cert" -type f -name '*.crt' -exec chmod 644 {} + 2>/dev/null || true
    fi
    if [ -d "$HIHY_CERT_MANAGER_DIR" ]; then
        chmod 700 "$HIHY_CERT_MANAGER_DIR" "$HIHY_CERT_MANAGER_DIR/config" \
            "$HIHY_CERT_MANAGER_DIR/credentials" "$HIHY_CERT_MANAGER_DIR/lego" \
            "$HIHY_CERT_MANAGER_DIR/releases" "$HIHY_CERT_MANAGER_DIR/nodes" \
            "$HIHY_CERT_MANAGER_DIR/logs" "$HIHY_CERT_MANAGER_DIR/state" 2>/dev/null || true
        find "$HIHY_CERT_MANAGER_DIR" -type f -name '*.key' -exec chmod 600 {} + 2>/dev/null || true
        [ -f "$HIHY_CERT_TOKEN_FILE" ] && chmod 600 "$HIHY_CERT_TOKEN_FILE"
        [ -f "$HIHY_CERT_MANAGER_CONFIG" ] && chmod 600 "$HIHY_CERT_MANAGER_CONFIG"
    fi
}

validate_protocol() {
    [ "$1" = "tcp" ] || [ "$1" = "udp" ]
}

validate_port_range() {
    validate_port "$1" && validate_port "$2" && [ "$1" -lt "$2" ]
}

sanitizeFileComponent() {
    local value="$1"
    value=$(printf '%s' "$value" | tr -c 'A-Za-z0-9._-' '_')
    value=${value#.}
    value=${value#-}
    [ -n "$value" ] || value="hihy"
    printf '%s\n' "$value"
}

validateDownloadedShell() {
    local file="$1"

    [ -s "$file" ] || return 1
    bash -n "$file" || return 1
    grep -qE '^[[:space:]]*hihyV=' "$file" || return 1
    grep -qF 'checkRoot()' "$file" || return 1
    grep -qF 'menu()' "$file" || return 1
}

ensureCertificateManagerDirectories() {
    mkdir -p "$HIHY_CERT_MANAGER_DIR/bin" "$HIHY_CERT_MANAGER_DIR/config" \
        "$HIHY_CERT_MANAGER_DIR/credentials" "$HIHY_CERT_MANAGER_DIR/lego" \
        "$HIHY_CERT_MANAGER_DIR/releases" "$HIHY_CERT_MANAGER_DIR/nodes" \
        "$HIHY_CERT_MANAGER_DIR/logs" "$HIHY_CERT_MANAGER_DIR/state" \
        "$HIHY_SHARED_CERT_DIR/releases"
    chmod 700 "$HIHY_CERT_MANAGER_DIR" "$HIHY_CERT_MANAGER_DIR/config" \
        "$HIHY_CERT_MANAGER_DIR/credentials" "$HIHY_CERT_MANAGER_DIR/lego" \
        "$HIHY_CERT_MANAGER_DIR/releases" "$HIHY_CERT_MANAGER_DIR/nodes" \
        "$HIHY_CERT_MANAGER_DIR/logs" "$HIHY_CERT_MANAGER_DIR/state" \
        "$HIHY_SHARED_CERT_DIR" "$HIHY_SHARED_CERT_DIR/releases"
    chmod 755 "$HIHY_CERT_MANAGER_DIR/bin"
}

getCertificateManagerValue() {
    local key="$1"
    [ -f "$HIHY_CERT_MANAGER_CONFIG" ] || return 1
    grep -E "^${key}=" "$HIHY_CERT_MANAGER_CONFIG" | head -n 1 | cut -d= -f2-
}

writeCertificateManagerConfig() {
    local domain="$1"
    local email="$2"
    local temp_file

    printf '%s' "$domain" | grep -Eq '^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' || return 1
    printf '%s' "$email" | grep -Eq '^[^[:space:]@]+@[^[:space:]@]+$' || return 1
    ensureCertificateManagerDirectories || return 1
    temp_file=$(mktemp "$HIHY_CERT_MANAGER_DIR/config/.manager.conf.XXXXXX") || return 1
    cat >"$temp_file" <<EOF
mode=manager
domain=${domain}
wildcard=*.${domain}
email=${email}
provider=cloudflare
renew_days=30
EOF
    chmod 600 "$temp_file"
    mv -f "$temp_file" "$HIHY_CERT_MANAGER_CONFIG"
}

certificateMatchesKey() {
    local cert="$1"
    local key="$2"
    local cert_hash key_hash

    openssl x509 -in "$cert" -noout >/dev/null 2>&1 || return 1
    openssl pkey -in "$key" -noout >/dev/null 2>&1 || return 1
    cert_hash=$(openssl x509 -in "$cert" -pubkey -noout | openssl sha256)
    key_hash=$(openssl pkey -in "$key" -pubout | openssl sha256)
    [ "$cert_hash" = "$key_hash" ]
}

validateCertificateBundle() {
    local cert="$1"
    local key="$2"
    local domain="$3"
    local subject_alt_names

    [ -s "$cert" ] && [ -s "$key" ] || return 1
    certificateMatchesKey "$cert" "$key" || return 1
    openssl x509 -in "$cert" -checkend 86400 -noout >/dev/null 2>&1 || return 1
    subject_alt_names=$(openssl x509 -in "$cert" -noout -ext subjectAltName 2>/dev/null) || return 1
    # SAN entries are comma-separated; a substring also accepts *.example.com.evil.test.
    printf '%s\n' "$subject_alt_names" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
        | grep -ixF "DNS:*.${domain}" >/dev/null || return 1
}

installLego() {
    local arch asset base_url temp_dir archive checksums expected actual

    if [ -x "$HIHY_LEGO_BIN" ] && "$HIHY_LEGO_BIN" --version 2>/dev/null | grep -q "version ${HIHY_LEGO_VERSION}"; then
        return 0
    fi
    case "$(uname -m)" in
        x86_64) arch="amd64" ;;
        aarch64 | arm64) arch="arm64" ;;
        i386 | i686) arch="386" ;;
        armv7*) arch="armv7" ;;
        *) echoColor red "当前架构不支持自动安装 Lego。"; return 1 ;;
    esac
    ensureCertificateManagerDirectories || return 1
    asset="lego_v${HIHY_LEGO_VERSION}_linux_${arch}.tar.gz"
    base_url="https://github.com/go-acme/lego/releases/download/v${HIHY_LEGO_VERSION}"
    temp_dir=$(mktemp -d "$HIHY_CERT_MANAGER_DIR/.lego-install.XXXXXX") || return 1
    archive="$temp_dir/$asset"
    checksums="$temp_dir/checksums.txt"
    if ! downloadToFile "$base_url/$asset" "$archive" || \
        ! downloadToFile "$base_url/lego_${HIHY_LEGO_VERSION}_checksums.txt" "$checksums"; then
        rm -rf "$temp_dir"
        return 1
    fi
    expected=$(grep -E "[[:space:]]${asset}$" "$checksums" | awk '{print $1}' | head -n 1)
    actual=$(sha256sum "$archive" | awk '{print $1}')
    if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
        rm -rf "$temp_dir"
        echoColor red "Lego SHA-256 校验失败。"
        return 1
    fi
    tar -xzf "$archive" -C "$temp_dir" lego || { rm -rf "$temp_dir"; return 1; }
    "$temp_dir/lego" --version 2>/dev/null | grep -q "version ${HIHY_LEGO_VERSION}" || { rm -rf "$temp_dir"; return 1; }
    command install -m 755 "$temp_dir/lego" "$HIHY_LEGO_BIN"
    rm -rf "$temp_dir"
}

verifyCloudflareToken() {
    local token response
    [ -s "$HIHY_CERT_TOKEN_FILE" ] || return 1
    token=$(cat "$HIHY_CERT_TOKEN_FILE")
    response=$(curl -fsS --connect-timeout 5 --max-time 15 \
        -H "Authorization: Bearer ${token}" \
        https://api.cloudflare.com/client/v4/user/tokens/verify 2>/dev/null) || return 1
    printf '%s' "$response" | grep -q '"status":"active"'
}

installHihyLauncher() {
    local source_path="${1:-${BASH_SOURCE[0]}}"
    local bin_link="${2:-$HIHY_BIN_LINK}"
    local bin_dir

    bin_dir="$(dirname "$bin_link")"
    mkdir -p "$bin_dir"

    if [ -f "$source_path" ] && [ "$source_path" != "$bin_link" ]; then
        cp "$source_path" "$bin_link"
    elif [ ! -f "$bin_link" ]; then
        if ! downloadToFile "$HIHY_REMOTE_SCRIPT_URL" "$bin_link"; then
            downloadToFile "$HIHY_REMOTE_SCRIPT_MIRROR_URL" "$bin_link" || return 1
        fi
    fi

    if [ -f "$bin_link" ]; then
        chmod 755 "$bin_link"
        return 0
    fi

    return 1
}

downloadToFile() {
    local url="$1"
    local output_path="$2"
    local output_dir
    local output_name
    local tmp_path

    output_dir=$(dirname "$output_path")
    output_name=$(basename "$output_path")
    mkdir -p "$output_dir" || return 1
    tmp_path=$(mktemp "${output_dir}/.${output_name}.tmp.XXXXXX") || return 1

    if [ -L "$output_path" ]; then
        rm -f "$tmp_path"
        return 1
    fi

    if command -v curl >/dev/null 2>&1; then
        if ! curl -fL \
            --connect-timeout "${HIHY_REMOTE_CONNECT_TIMEOUT:-5}" \
            --max-time "${HIHY_REMOTE_MAX_TIME:-30}" \
            -o "$tmp_path" "$url"; then
            rm -f "$tmp_path"
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -q -O "$tmp_path" "$url"; then
            rm -f "$tmp_path"
            return 1
        fi
    else
        return 1
    fi

    if [ ! -s "$tmp_path" ]; then
        rm -f "$tmp_path"
        return 1
    fi

    mv -f "$tmp_path" "$output_path"
}

startInstallValidationProcess() {
    local yaml_file="$1"
    local debug_file="${2:-./hihy_debug.info}"

    /etc/hihy/bin/appS -c "$yaml_file" server >"$debug_file" 2>&1 &
    printf '%s\n' "$!"
}

fetchRemoteBodyFromSources() {
    local url
    local response

    for url in "$@"; do
        if command -v curl >/dev/null 2>&1; then
            if response=$(curl -fsSL \
                --connect-timeout "${HIHY_REMOTE_CONNECT_TIMEOUT:-5}" \
                --max-time "${HIHY_REMOTE_MAX_TIME:-30}" \
                "$url" 2>/dev/null); then
                printf '%s' "$response"
                return 0
            fi
        elif command -v wget >/dev/null 2>&1; then
            if response=$(wget -q -O - "$url" 2>/dev/null); then
                printf '%s' "$response"
                return 0
            fi
        fi
    done

    return 1
}

fetchRemoteHeadersFromSources() {
    local url
    local response

    for url in "$@"; do
        if response=$(curl -fsSIL --connect-timeout "$HIHY_REMOTE_CONNECT_TIMEOUT" --max-time "$HIHY_REMOTE_MAX_TIME" "$url" 2>/dev/null); then
            printf '%s' "$response"
            return 0
        fi
    done

    return 1
}

getLatestHihyVersion() {
    local content
    local version

    version=$(fetchRemoteBodyFromSources "${HIHY_REMOTE_VERSION_URL}?t=$(date +%s)" 2>/dev/null | tr -d '\r\n[:space:]')
    if printf '%s' "$version" | grep -Eq '^ver[0-9]+\.[0-9]+$'; then
        printf '%s\n' "$version"
        return 0
    fi

    content=$(fetchRemoteBodyFromSources "$HIHY_REMOTE_SCRIPT_URL" "$HIHY_REMOTE_SCRIPT_MIRROR_URL") || return 1

    version=$(printf '%s\n' "$content" \
        | grep -E '^[[:space:]]*hihyV=' \
        | head -n 1 \
        | sed -E 's/^[[:space:]]*hihyV=["'\''"]?([^"'\''"]+)["'\''"]?.*/\1/')

    if [ -z "$version" ]; then
        return 1
    fi

    printf '%s\n' "$version"
}

isHysteriaReleaseVersion() {
    [[ "$1" =~ ^app/v[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

getLatestHysteriaVersion() {
    local content version headers
    content=$(fetchRemoteBodyFromSources "https://api.github.com/repos/HyNetworks/hysteria/releases/latest") || true
    if [ -n "$content" ]; then
        version=$(printf '%s' "$content" | yq -p=json -r '.tag_name // ""' 2>/dev/null)
        if isHysteriaReleaseVersion "$version"; then
            printf '%s\n' "$version"
            return 0
        fi
    fi
    headers=$(fetchRemoteHeadersFromSources "https://github.com/HyNetworks/hysteria/releases/latest") || return 1
    version=$(printf '%s\n' "$headers" | tr -d '\r' \
        | sed -nE 's@^[Ll][Oo][Cc][Aa][Tt][Ii][Oo][Nn]:.*releases/tag/(app(/|%2[Ff])v[0-9]+\.[0-9]+\.[0-9]+)[[:space:]]*$@\1@p' \
        | tail -n 1 | sed 's/%2[Ff]/\//g')
    isHysteriaReleaseVersion "$version" || return 1
    printf '%s\n' "$version"
}

getHysteriaReleaseAsset() {
    local version="$1" asset_name="$2" content
    isHysteriaReleaseVersion "$version" || return 1
    content=$(fetchRemoteBodyFromSources "https://api.github.com/repos/HyNetworks/hysteria/releases/tags/${version//\//%2F}") || return 1
    # 一次请求同时获取下载地址和摘要，避免额外消耗 GitHub API 配额。
    printf '%s' "$content" | HIHY_ASSET_NAME="$asset_name" yq -p=json -o=json \
        '.assets[] | select(.name == strenv(HIHY_ASSET_NAME))' 2>/dev/null
}

getLocalHysteriaVersion() {
    local core_bin="${1:-$HIHY_ROOT_DIR/bin/appS}"

    if [ ! -x "$core_bin" ]; then
        return 1
    fi

    local version
    version=$(echo app/$("$core_bin" version 2>/dev/null | grep Version: | awk '{print $2}' | head -n 1))
    if [ -z "$version" ] || [ "$version" = "app/" ]; then
        return 1
    fi

    printf '%s\n' "$version"
}

ensureVersionCheckStateDir() {
    mkdir -p "$(dirname "$HIHY_VERSION_STATUS_FILE")" "$(dirname "$HIHY_VERSION_CHECK_LOCK_FILE")"
}

readVersionCheckValue() {
    local file_path="$1"
    local key="$2"

    if [ ! -f "$file_path" ]; then
        return 1
    fi

    grep -E "^${key}=" "$file_path" 2>/dev/null | head -n 1 | cut -d '=' -f 2-
}

writeVersionCheckState() {
    local checked_at="$1"
    local hihy_status="$2"
    local hihy_remote="$3"
    local core_status="$4"
    local core_remote="$5"
    local state_file="$HIHY_VERSION_STATUS_FILE"
    local temp_file="${state_file}.tmp.$$"

    ensureVersionCheckStateDir
    cat >"$temp_file" <<EOF
checked_at=${checked_at}
hihy_status=${hihy_status}
hihy_remote=${hihy_remote}
core_status=${core_status}
core_remote=${core_remote}
EOF
    mv "$temp_file" "$state_file"
    chmod 600 "$state_file"
}

acquireVersionCheckLock() {
    local lock_file="$HIHY_VERSION_CHECK_LOCK_FILE"
    local lock_pid=""

    ensureVersionCheckStateDir

    if [ -f "$lock_file" ]; then
        lock_pid=$(readVersionCheckValue "$lock_file" "pid")
        if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
            return 1
        fi
        rm -f "$lock_file"
    fi

    cat >"$lock_file" <<EOF
pid=${BASHPID:-$$}
started_at=$(date +%s)
EOF
    chmod 600 "$lock_file"
}

releaseVersionCheckLock() {
    rm -f "$HIHY_VERSION_CHECK_LOCK_FILE"
}

is_uint() {
    echo "$1" | grep -Eq '^[0-9]+$'
}

validate_port() {
    local p="$1"
    is_uint "$p" && [ "$p" -ge 1 ] && [ "$p" -le 65535 ]
}

shouldStartVersionCheck() {
    local now
    local checked_at
    local lock_pid

    now=$(date +%s)

    if [ -f "$HIHY_VERSION_CHECK_LOCK_FILE" ]; then
        lock_pid=$(readVersionCheckValue "$HIHY_VERSION_CHECK_LOCK_FILE" "pid")
        if [ -n "$lock_pid" ] && is_uint "$lock_pid" && kill -0 "$lock_pid" 2>/dev/null; then
            return 1
        fi
        rm -f "$HIHY_VERSION_CHECK_LOCK_FILE"
    fi

    checked_at=$(readVersionCheckValue "$HIHY_VERSION_STATUS_FILE" "checked_at")
    if is_uint "$checked_at" && is_uint "$HIHY_VERSION_CHECK_TTL"; then
        if [ $((now - checked_at)) -lt "$HIHY_VERSION_CHECK_TTL" ]; then
            return 1
        fi
    fi

    return 0
}

refreshVersionCheckState() {
    local checked_at
    local local_hihy_version="$hihyV"
    local remote_hihy_version=""
    local hihy_status="unknown"
    local local_core_version=""
    local remote_core_version=""
    local core_status="missing"

    if ! acquireVersionCheckLock; then
        return 0
    fi

    trap 'releaseVersionCheckLock' EXIT

    checked_at=$(date +%s)

    remote_hihy_version=$(getLatestHihyVersion || true)
    if [ -n "$remote_hihy_version" ]; then
        if [ "$local_hihy_version" != "$remote_hihy_version" ]; then
            hihy_status="update"
        else
            hihy_status="current"
        fi
    else
        hihy_status="error"
    fi

    local_core_version=$(getLocalHysteriaVersion || true)
    if [ -n "$local_core_version" ]; then
        remote_core_version=$(getLatestHysteriaVersion || true)
        if [ -n "$remote_core_version" ]; then
            if [ "$local_core_version" != "$remote_core_version" ]; then
                core_status="update"
            else
                core_status="current"
            fi
        else
            core_status="error"
        fi
    fi

    writeVersionCheckState "$checked_at" "$hihy_status" "$remote_hihy_version" "$core_status" "$remote_core_version"

    releaseVersionCheckLock
    trap - EXIT
}

startBackgroundVersionCheck() {
    if ! shouldStartVersionCheck; then
        return 0
    fi

    (refreshVersionCheckState) >/dev/null 2>&1 &
}

displayCachedVersionNotifications() {
    local hihy_status
    local hihy_remote
    local core_status
    local core_remote

    if [ ! -f "$HIHY_VERSION_STATUS_FILE" ]; then
        return 0
    fi

    hihy_status=$(readVersionCheckValue "$HIHY_VERSION_STATUS_FILE" "hihy_status")
    hihy_remote=$(readVersionCheckValue "$HIHY_VERSION_STATUS_FILE" "hihy_remote")
    core_status=$(readVersionCheckValue "$HIHY_VERSION_STATUS_FILE" "core_status")
    core_remote=$(readVersionCheckValue "$HIHY_VERSION_STATUS_FILE" "core_remote")

    if [ "$hihy_status" = "update" ] && [ -n "$hihy_remote" ]; then
        echoColor purple "[☺] hihy需更新,version:v${hihy_remote},建议更新并查看日志: ${HIHY_REPO_URL}/"
    fi

    if [ "$core_status" = "update" ] && [ -n "$core_remote" ]; then
        echoColor purple "[!] hysteria2 core有更新,version:${core_remote}  日志: https://v2.hysteria.network/docs/Changelog/"
    fi
}

# 检测虚拟化类型的函数
detectVirtualization() {
    local virt_type=""

    # 检查是否为 OpenVZ
    if [ -f "/proc/user_beancounters" ]; then
        virt_type="openvz"
    # 检查是否为 LXC
    elif [ -f "/proc/1/environ" ] && grep -q "container=lxc" /proc/1/environ 2>/dev/null; then
        virt_type="lxc"
    # 检查 systemd-detect-virt（如果可用）
    elif command -v systemd-detect-virt >/dev/null 2>&1; then
        local detected=$(systemd-detect-virt 2>/dev/null)
        case "$detected" in
            "openvz") virt_type="openvz" ;;
            "lxc") virt_type="lxc" ;;
            "lxc-libvirt") virt_type="lxc" ;;
            *) virt_type="other" ;;
        esac
    # 检查 /proc/cpuinfo 中的虚拟化标识
    elif grep -q "flags.*hypervisor" /proc/cpuinfo 2>/dev/null; then
        virt_type="other"
    # 检查 cgroup 中的容器标识
    elif [ -f "/proc/1/cgroup" ]; then
        if grep -q ":/lxc/" /proc/1/cgroup 2>/dev/null; then
            virt_type="lxc"
        elif grep -q ":/docker/" /proc/1/cgroup 2>/dev/null; then
            virt_type="docker"
        else
            virt_type="unknown"
        fi
    else
        virt_type="unknown"
    fi

    echo "$virt_type"
}

# 获取启动命令前缀（是否使用 chrt）
getStartCommand() {
    local virt_type=$(detectVirtualization)
    local command_prefix=""

    [ "${HIHY_DISABLE_CHRT:-false}" = "true" ] && return 0

    case "$virt_type" in
        "openvz" | "lxc" | "docker")
            # OpenVZ、LXC 和 Docker 容器中不使用 chrt
            command_prefix=""
            ;;
        *)
            # 其他环境检查是否支持 chrt
            if command -v chrt >/dev/null 2>&1; then
                # 测试 chrt 是否可用
                if chrt -r 1 echo "test" >/dev/null 2>&1; then
                    command_prefix="chrt -r 99"
                else
                    command_prefix=""
                fi
            else
                command_prefix=""
            fi
            ;;
    esac

    echo "$command_prefix"
}

cronTask() {
    if [ -f "/etc/hihy/logs/hihy.log" ]; then
        echo "" >/etc/hihy/logs/hihy.log
    fi
}
echoColor() {
    local printN="${printN:-}"
    case $1 in
        # 红色
        "red") echo -e "\033[31m${printN}$2 \033[0m" ;;
        # 天蓝色
        "skyBlue") echo -e "\033[1;36m${printN}$2 \033[0m" ;;
        # 绿色
        "green") echo -e "\033[32m${printN}$2 \033[0m" ;;
        # 白色
        "white") echo -e "\033[37m${printN}$2 \033[0m" ;;
        # 洋红色
        "magenta") echo -e "\033[35m${printN}$2 \033[0m" ;;
        # 黄色
        "yellow") echo -e "\033[33m${printN}$2 \033[0m" ;;
        # 紫色
        "purple") echo -e "\033[1;35m${printN}$2 \033[0m" ;;
        # 黑底黄字
        "yellowBlack") echo -e "\033[1;33;40m${printN}$2 \033[0m" ;;
        # 绿底白字
        "greenWhite") echo -e "\033[42;37m${printN}$2 \033[0m" ;;
        # 蓝色
        "blue") echo -e "\033[34m${printN}$2 \033[0m" ;;
        # 青色
        "cyan") echo -e "\033[36m${printN}$2 \033[0m" ;;
        # 黑色
        "black") echo -e "\033[30m${printN}$2 \033[0m" ;;
        # 灰色
        "gray") echo -e "\033[90m${printN}$2 \033[0m" ;;
        # 亮红色
        "lightRed") echo -e "\033[91m${printN}$2 \033[0m" ;;
        # 亮绿色
        "lightGreen") echo -e "\033[92m${printN}$2 \033[0m" ;;
        # 亮黄色
        "lightYellow") echo -e "\033[93m${printN}$2 \033[0m" ;;
        # 亮蓝色
        "lightBlue") echo -e "\033[94m${printN}$2 \033[0m" ;;
        # 亮洋红色
        "lightMagenta") echo -e "\033[95m${printN}$2 \033[0m" ;;
        # 亮青色
        "lightCyan") echo -e "\033[96m${printN}$2 \033[0m" ;;
        # 亮白色
        "lightWhite") echo -e "\033[97m${printN}$2 \033[0m" ;;
    esac
}

# 检测系统架构的函数
getArchitecture() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64)
            echo "amd64"
            ;;
        i386 | i686)
            echo "386"
            ;;
        aarch64 | arm64)
            echo "arm64"
            ;;
        armv6* | armv7* | arm)
            echo "arm"
            ;;
        armv5*)
            echoColor red "官方 yq ARM 包要求 ARMv6；ARMv5 请预先安装兼容的 yq v4。" >&2
            return 1
            ;;
        mipsle | mips64le)
            echo "$arch"
            ;;
        mips | mips64)
            if [ "$(od -An -tu1 -j5 -N1 /proc/self/exe | tr -d '[:space:]')" = 1 ]; then
                echo "${arch}le"
            else
                echo "$arch"
            fi
            ;;
        s390x)
            echo "s390x"
            ;;
        riscv64)
            echo "riscv64"
            ;;
        loongarch64)
            echo "loong64"
            ;;
        *)
            echoColor red "没有匹配的 yq 架构: $arch" >&2
            return 1
            ;;
    esac
}

checkSystemForUpdate() {
    local release=""
    local installType=""
    local updateNeeded=false
    local packageManager=""
    local requiredPackages=("wget" "curl" "lsof" "bash" "iptables" "bc")

    # 检测包管理器
    if command -v apt >/dev/null; then
        packageManager="apt"
        installType="apt -y -q install"
        upgrade="apt update"
    elif command -v yum >/dev/null; then
        packageManager="yum"
        installType="yum -y -q install"
        upgrade="yum update -y --skip-broken"
    elif command -v dnf >/dev/null; then
        packageManager="dnf"
        installType="dnf -y install"
        upgrade="dnf update -y"
    elif command -v pacman >/dev/null; then
        packageManager="pacman"
        installType="pacman -Sy --noconfirm"
        upgrade="pacman -Syy"
    elif command -v apk >/dev/null; then
        packageManager="apk"
        installType="apk add --no-cache"
        upgrade="apk update"
    else
        echoColor red "\n未检测到支持的包管理器，请将以下信息反馈给开发者："
        echoColor yellow "$(cat /etc/issue 2>/dev/null)"
        echoColor yellow "$(cat /proc/version 2>/dev/null)"
        exit 1
    fi

    # 检查必需的包
    for package in "${requiredPackages[@]}"; do
        if ! command -v "$package" >/dev/null; then
            echoColor green "*$package"
            updateNeeded=true
        fi
    done

    # 检查 dig 命令
    if ! command -v dig >/dev/null; then
        echoColor green "*dnsutils"
        updateNeeded=true
    fi

    # 检查 qrencode 包
    if ! command -v qrencode >/dev/null; then
        echoColor green "*qrencode"
        updateNeeded=true
    fi

    # 检查 qrencode 包
    if ! command -v crontab >/dev/null; then
        echoColor green "*crontab"
        updateNeeded=true
    fi

    # 检查 chrt 命令
    if ! command -v chrt >/dev/null; then
        echoColor green "*util-linux"
        updateNeeded=true
    fi

    # 仅在需要安装包时更新软件源
    if [ "$updateNeeded" = true ]; then
        echoColor purple "\n更新软件源..."
        ${upgrade}

        # 安装必需的包
        for package in "${requiredPackages[@]}"; do
            if ! command -v "$package" >/dev/null; then
                ${installType} "$package"
            fi
        done

        # 安装 dig
        if ! command -v dig >/dev/null; then
            case $packageManager in
                "apt") ${installType} "dnsutils" ;;
                "yum" | "dnf") ${installType} "bind-utils" ;;
                "pacman") ${installType} "bind-tools" ;;
                "apk") ${installType} "bind-tools" ;;
            esac
        fi

        # 安装 qrencode
        if ! command -v qrencode >/dev/null; then
            case $packageManager in
                "apt") ${installType} "qrencode" ;;
                "yum" | "dnf") ${installType} "qrencode" ;;
                "pacman") ${installType} "qrencode" ;;
                "apk") ${installType} "libqrencode-tools" ;;
            esac
        fi

        # 安装 util-linux
        if ! command -v chrt >/dev/null; then
            ${installType} "util-linux"
        fi

        # 确保有 pkill 命令
        if ! command -v pkill >/dev/null 2>&1; then
            case $packageManager in
                "apt") ${installType} "procps" ;;
                "yum" | "dnf") ${installType} "procps" ;;
                "pacman") ${installType} "procps" ;;
                "apk") ${installType} "procps" ;;
            esac
        fi

        # 确保有 crontab 命令
        if ! command -v crontab >/dev/null 2>&1; then
            case $packageManager in
                "apt") ${installType} "cron" ;;
                "yum" | "dnf") ${installType} "cron" ;;
                "pacman") ${installType} "cronie" ;;
                "apk") ${installType} "cronie" ;;
            esac
        fi

        echoColor purple "\n软件包安装完成."
    fi

    # 检查 yq 命令
    # 安装 yq
    if ! command -v yq >/dev/null || ! yq --version 2>/dev/null | grep -q 'version v4\.'; then
        arch=$(getArchitecture) || return 1
        echoColor purple "正在下载 yq (${arch})..."
        if ! downloadToFile "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${arch}" "$HIHY_YQ_BIN"; then
            if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
                echoColor red "下载 yq 失败：未找到 wget 或 curl"
            else
                echoColor red "下载 yq 失败：wget/curl 下载异常"
            fi
            exit 1
        fi
        chmod +x "$HIHY_YQ_BIN"
        "$HIHY_YQ_BIN" --version 2>/dev/null | grep -q 'version v4\.' || {
            echoColor red "yq 无法运行或版本不兼容。"; return 1;
        }
    fi
}

getPortBindMsg() {
    # $1 type UDP or TCP
    # $2 port
    local msg
    if [ "$1" == "UDP" ]; then
        msg=$(lsof -i "${1}:${2}")
    else
        msg=$(lsof -i "${1}:${2}" | grep LISTEN)
    fi

    if [ -z "$msg" ]; then
        return
    fi

    local command pid name
    command=$(echo "$msg" | awk '{print $1}')
    pid=$(echo "$msg" | awk '{print $2}')
    name=$(echo "$msg" | awk '{print $9}')
    echoColor purple "Port: ${1}/${2} 已经被 ${command}(${name}) 占用,进程pid为: ${pid}."
    if printf '%s' "$command" | grep -q '^appS$' && serviceIsActive; then
        echoColor green "检测到端口由当前 Hysteria 服务占用，是否停止该服务?(y/N)"
        read -r bindP
        if [[ "$bindP" =~ ^[yY]$ ]] && serviceStop; then
            sleep 2
            return 0
        fi
    fi
    echoColor red "为避免误杀其他服务，脚本不会自动终止未知进程。请手动处理端口占用或更换端口。"
    [ "$1" = "TCP" ] && [ "$2" = "80" ] && echoColor yellow "也可以改用 DNS 验证申请证书。"
    return 1
}

generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuid=$(uuidgen)
    elif [ -f /proc/sys/kernel/random/uuid ]; then
        uuid=$(cat /proc/sys/kernel/random/uuid)
    else
        uuid=$(cat /dev/urandom | tr -dc 'a-f0-9' | head -c 32 | sed 's/\(.\{8\}\)/\1-/g;s/-$//')
    fi
    echo "$uuid"
}

getListenPrimaryPort() {
    local listen_value="$1"

    if [ -z "$listen_value" ] || [ "$listen_value" = "null" ]; then
        echo ""
        return
    fi

    listen_value=${listen_value#*:}
    listen_value=$(echo "$listen_value" | awk -F',' '{print $1}')
    echo "$listen_value" | awk -F'-' '{print $1}'
}

getListenRangePart() {
    local listen_value="$1"

    if [ -z "$listen_value" ] || [ "$listen_value" = "null" ]; then
        echo ""
        return
    fi

    listen_value=${listen_value#*:}
    if echo "$listen_value" | grep -q ','; then
        echo "$listen_value" | awk -F',' '{print $2}'
    else
        echo ""
    fi
}

getBackupValueOrDefault() {
    local file=$1
    local key=$2
    local default_value=$3
    local value

    value=$(getYamlValue "$file" "$key" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$value" ] || [ "$value" = "null" ]; then
        echo "$default_value"
    else
        echo "$value"
    fi
}

cleanupLegacyPortHoppingNatIfPresent() {
    if command -v iptables-save >/dev/null 2>&1 && iptables-save 2>/dev/null | grep -q "PortHopping-hihysteria"; then
        delPortHoppingNat >/dev/null 2>&1 || true
        return
    fi

    if command -v ip6tables-save >/dev/null 2>&1 && ip6tables-save 2>/dev/null | grep -q "PortHopping-hihysteria"; then
        delPortHoppingNat >/dev/null 2>&1 || true
    fi
}

getInstallFailureMarker() {
    local root_dir="${1:-$HIHY_ROOT_DIR}"
    echo "${root_dir}/result/install.failed"
}

getHihyServiceScriptPrimary() {
    echo "${1:-/etc/init.d/hihy}"
}

getHihyServiceScriptFallback() {
    echo "${1:-/etc/rc.d/hihy}"
}

classifyInstallState() {
    local root_dir="${1:-$HIHY_ROOT_DIR}"
    local bin_link="${2:-$HIHY_BIN_LINK}"
    local service_primary="${3:-$(getHihyServiceScriptPrimary)}"
    local service_fallback="${4:-$(getHihyServiceScriptFallback)}"
    local failure_marker="${5:-$(getInstallFailureMarker "$root_dir")}"
    local owned_paths=(
        "$root_dir/bin/appS"
        "$root_dir/conf/config.yaml"
        "$root_dir/conf/backup.yaml"
        "$HIHY_SERVICE_FILE"
        "$service_primary"
        "$service_fallback"
        "$bin_link"
    )
    local has_any_artifact="false"
    local has_core_assets="false"
    local has_service_assets="false"
    local path

    for path in "${owned_paths[@]}"; do
        if [ -e "$path" ]; then
            has_any_artifact="true"
            case "$path" in
                "$root_dir/bin/appS" | "$root_dir/conf/config.yaml" | "$root_dir/conf/backup.yaml")
                    has_core_assets="true"
                    ;;
                "$HIHY_SERVICE_FILE" | "$service_primary" | "$service_fallback")
                    has_service_assets="true"
                    ;;
            esac
        fi
    done

    if [ -f "$failure_marker" ]; then
        echo "partially-installed"
        return
    fi

    if [ "$has_core_assets" = "true" ] && [ "$has_service_assets" = "true" ] && [ -f "$bin_link" ]; then
        echo "installed"
        return
    fi

    if [ "$has_any_artifact" = "true" ]; then
        echo "partially-installed"
        return
    fi

    echo "not-installed"
}

markInstallFailed() {
    local phase="$1"
    local details="$2"
    local failure_marker

    failure_marker="$(getInstallFailureMarker)"
    mkdir -p "$(dirname "$failure_marker")"
    printf 'phase=%s\ndetails=%s\n' "$phase" "$details" >"$failure_marker"
    chmod 600 "$failure_marker"
}

clearInstallFailureMarker() {
    local failure_marker
    failure_marker="$(getInstallFailureMarker)"
    rm -f "$failure_marker"
}

recoverPartialInstallState() {
    local root_dir="${1:-$HIHY_ROOT_DIR}"
    local bin_link="${2:-$HIHY_BIN_LINK}"
    local service_primary="${3:-$(getHihyServiceScriptPrimary)}"
    local service_fallback="${4:-$(getHihyServiceScriptFallback)}"
    local failure_marker="${5:-$(getInstallFailureMarker "$root_dir")}"
    local rc_local="${6:-$HIHY_RC_LOCAL}"
    local pid_file="${7:-$HIHY_PID_FILE}"

    if [ -f "$HIHY_SERVICE_FILE" ] && command -v systemctl >/dev/null 2>&1; then
        systemctl disable --now hihy.service >/dev/null 2>&1 || true
        rm -f "$HIHY_SERVICE_FILE"
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
    rm -f "$service_primary" "$service_fallback" "$pid_file"
    rm -f "$root_dir/conf/config.yaml" "$root_dir/conf/backup.yaml"
    rm -f "$failure_marker"

    if [ -f "$rc_local" ]; then
        sed -i '/\/etc\/rc\.d\/hihy start/d' "$rc_local"
        sed -i '/\/etc\/rc\.d\/allow-port start/d' "$rc_local"
        sed -i '/\/etc\/rc\.d\/port-hopping start/d' "$rc_local"
    fi

    rm -f "$bin_link"
}

addOrUpdateYaml() {
    local file=$1
    local keyPath=$2
    local value=$3
    local valueType=${4:-"auto"} # auto, string, number, bool

    # 检查文件是否存在，如果不存在则创建一个空文件
    if [[ ! -f "$file" ]]; then
        touch "$file"
    fi

    # 将值转换为 JSON 格式以避免解析错误
    local jsonValue
    if [[ $valueType == "auto" ]]; then
        jsonValue=$(printf '%s\n' "$value" | yq eval -o=json) || return 1
    elif [[ $valueType == "string" ]]; then
        HIHY_YAML_VALUE="$value" yq eval ".${keyPath} = strenv(HIHY_YAML_VALUE)" -i "$file"
        return $?
    elif [[ $valueType == "number" ]]; then
        jsonValue=$(printf '%s\n' "$value" | yq eval -o=json) || return 1
    elif [[ $valueType == "bool" ]]; then
        jsonValue=$(printf '%s\n' "$value" | yq eval -o=json) || return 1
    else
        echo "Unsupported value type: $valueType"
        return 1
    fi

    # 使用 yq 修改 YAML 文件
    yq eval ".${keyPath} = ${jsonValue}" -i "$file"
}

getYamlValue() {
    local file=$1    # YAML文件路径
    local keyPath=$2 # 键路径，用点号分隔

    # 检查文件是否存在
    if [[ ! -f "$file" ]]; then
        echo "错误: 文件不存在"
        return 1
    fi

    # 使用 yq 读取 YAML 文件中的值
    value=$(yq eval ".${keyPath}" "$file")

    # 检查 yq 命令是否成功执行
    if [[ $? -ne 0 ]]; then
        echo "错误: 读取 YAML 文件失败"
        return 1
    fi

    echo "$value"
}

countdown() {
    local seconds=$1
    echo -ne "\033[32m⏰ 倒计时:\033[0m "

    while [ $seconds -gt 0 ]; do
        # 打印当前数字
        echo -ne "\033[31m$seconds\033[0m"
        sleep 1

        # 计算退格数量
        local digits=${#seconds}
        for ((i = 0; i < digits; i++)); do
            echo -ne "\b \b"
        done

        ((seconds--))
    done

    # 清除最后一个数字并显示完成消息
    echo -ne " " # 清除最后显示的数字
    echo -e "\n\033[32m✨ 完成!\033[0m"
}

getECHConfigList() {
    local key_path="$1" config
    [ -r "$key_path" ] || return 1
    # 只导出公开的 ECH CONFIGS 块，绝不输出 ECH KEYS。
    config=$(awk '/^-----BEGIN ECH CONFIGS-----$/ {inside=1; next}
        /^-----END ECH CONFIGS-----$/ {inside=0; done=1; exit}
        inside {gsub(/[[:space:]]/, ""); printf "%s", $0}
        END {if (!done) exit 1}' "$key_path") || return 1
    [[ "$config" =~ ^[A-Za-z0-9+/]+={0,2}$ ]] || return 1
    printf '%s' "$config" | base64 -d >/dev/null 2>&1 || return 1
    printf '%s\n' "$config"
}

encodeURIComponent() {
    local LC_ALL=C value="$1" char encoded i
    for ((i=0; i<${#value}; i++)); do
        char="${value:i:1}"
        case "$char" in
            [a-zA-Z0-9.~_-]) printf '%s' "$char" ;;
            *) printf -v encoded '%%%02X' "'$char"; printf '%s' "$encoded" ;;
        esac
    done
}

encodeECHQuery() { encodeURIComponent "$1"; }

formatURIHost() {
    local host="$1"
    host="${host#[}"
    host="${host%]}"
    if [[ "$host" == *:* ]]; then
        [ "${2:-uri}" = native ] || host="${host//%/%25}"
        printf '[%s]' "$host"
    else
        printf '%s' "$host"
    fi
}

prepareECH() {
    local old_path="${1:-}" choice public_name key_dir
    ech_key_path=""
    if [ -n "$old_path" ] && [ "$old_path" != null ]; then
        echoColor green "ECH: 1、保留启用(默认)  2、关闭"
        read -r choice || return 1
        [ "$choice" != 2 ] || return 0
        ech_key_path="$old_path"
    else
        echoColor green "ECH: 1、关闭(默认)  2、启用"
        echoColor yellow "ECH 加密真实 SNI，适合未开启混淆的连接；客户端需支持 ECH。"
        read -r choice || return 1
        [ "$choice" = 2 ] || return 0
        ech_key_path="$HIHY_ROOT_DIR/cert/ech.pem"
    fi
    if [[ "$ech_key_path" != /* ]]; then
        echoColor red "ECH 密钥路径必须为绝对路径，请先修正 ech.keyPath。"
        return 1
    fi
    if [ ! -e "$ech_key_path" ]; then
        if [ -n "$old_path" ] && [ "$old_path" != null ]; then
            echoColor red "原 ECH 密钥不存在: $old_path。请恢复密钥或选择关闭；不会自动轮换密钥。"
            return 1
        fi
        "$HIHY_ROOT_DIR/bin/appS" ech --help >/dev/null 2>&1 || {
            echoColor red "生成 ECH 密钥需要 Hysteria v2.12.3 或更高版本，请先更新核心。"
            return 1
        }
        echoColor green "请输入 ECH 外层公开域名(明文可见，例如 decoy.example.com):"
        read -r public_name || return 1
        [ -n "$public_name" ] || { echoColor red "公开域名不能为空。"; return 1; }
        key_dir=$(dirname "$ech_key_path")
        mkdir -p "$key_dir" || return 1
        # 不传 --overwrite；已有密钥必须复用，不能静默轮换。
        "$HIHY_ROOT_DIR/bin/appS" ech --public-name "$public_name" --output "$ech_key_path" >/dev/null || return 1
    fi
    getECHConfigList "$ech_key_path" >/dev/null || {
        echoColor red "ECH 密钥文件缺少有效的 ECH CONFIGS 块，无法导出客户端配置。"
        return 1
    }
    chmod 600 "$ech_key_path" || return 1
    echoColor green "ECH 已启用，复用密钥: $ech_key_path"
    echoColor yellow "ECH 不替代 TLS 证书；开启混淆时通常没有额外收益。"
}

exportClientECH() {
    local server_config="$1" client_config="$2" key_path
    ech_config=""
    key_path=$(getYamlValue "$server_config" "ech.keyPath") || return 1
    if [ -n "$key_path" ] && [ "$key_path" != null ]; then
        if [[ "$key_path" != /* ]]; then
            echoColor red "请先将服务端 ech.keyPath 改为绝对路径后再导出。" >&2
            return 1
        fi
        ech_config=$(getECHConfigList "$key_path") || {
            echoColor red "无法读取 ECH 公开配置，已中止导出以避免丢失 ECH。" >&2
            return 1
        }
        addOrUpdateYaml "$client_config" "tls.ech" "$ech_config" "string" || return 1
    else
        yq eval 'del(.tls.ech)' -i "$client_config" || return 1
    fi
}

setHysteriaConfig() {
    local ech_key_path="" old_ech_path=""
    if [ "$#" -gt 0 ]; then
        ech_key_path="$1"
    else
        if [ -f "$HIHY_CONFIG_FILE" ]; then
            old_ech_path=$(getYamlValue "$HIHY_CONFIG_FILE" "ech.keyPath") || return 1
        fi
        prepareECH "$old_ech_path" || return 1
    fi
    mkdir -p /etc/hihy/bin /etc/hihy/conf /etc/hihy/cert /etc/hihy/result /etc/hihy/acl/
    acl_file="/etc/hihy/acl/acl.txt"
    if [ -f "${acl_file}" ]; then
        rm -f "${acl_file}"
    fi
    touch $acl_file
    echoColor yellowBlack "开始配置:"
    echo -e "\033[32m(0/13)是否使用Realm模式(P2P穿透,无需公网IP):\n\n\033[0m"
    echo -e "Realm是Hysteria2的P2P穿透模式,通过牵手(rendezvous)服务器介绍双方进行UDP打洞,"
    echo -e "打洞成功后流量直连,不经过牵手服务器。服务器无需公网IP、无需端口转发即可运行。"
    echo -e "适用: NAT/家庭宽带/CGNAT/无公网IP环境。详情: https://hysteria.network/zh/docs/advanced/Realms/"
    echo -e "\033[33m\033[01m⚠ 目前仅支持使用hysteria core直接运行\033[0m\033[32m\n"
    echo -e "\033[33m\033[01m1、不使用(默认)\n2、使用Realm模式\033[0m\033[32m\n\n输入序号:\033[0m"
    read -r realmChoice || return 1
    if [ -z "${realmChoice}" ] || [ "${realmChoice}" == "1" ]; then
        realmMode="false"
    elif [ "${realmChoice}" == "2" ]; then
        realmMode="true"
        realmName=$(generate_uuid)
        echo -e "\n->您的Realm名(请勿泄露,知道此名称的人可以获得你的服务器ip地址): "$(echoColor red ${realmName})"\n"
        echoColor green "\n请选择牵手(rendezvous)服务器:"
        echo -e "官方服务器地址为 realm.hy2.io, 使用默认密码 public 即可,无需修改"
        echo -e "\033[33m\033[01m1、官方牵手服务器(默认): realm.hy2.io\n2、自建牵手服务器\033[0m\033[32m\n\n输入序号:\033[0m"
        read -r realmServerChoice || return 1
        if [ -z "${realmServerChoice}" ] || [ "${realmServerChoice}" == "1" ]; then
            realmAddress="realm.hy2.io"
            realmPassword="public"
        elif [ "${realmServerChoice}" == "2" ]; then
            echoColor green "请输入牵手服务器地址(格式: host:port 或 host):"
            read -r realmAddressInput || return 1
            while [ -z "${realmAddressInput}" ]; do
                echoColor red "地址不能为空,请重新输入:"
                read -r realmAddressInput || return 1
            done
            realmAddress="${realmAddressInput}"
            echoColor green "请输入牵手服务器密码(默认: public):"
            read -r realmPasswordInput || return 1
            if [ -z "${realmPasswordInput}" ]; then
                realmPassword="public"
            else
                realmPassword="${realmPasswordInput}"
            fi
        else
            echoColor red "牵手服务器选项输入错误。"
            return 1
        fi
        realmURI="realm://$(encodeURIComponent "$realmPassword")@${realmAddress}/$(encodeURIComponent "$realmName")"
        echo -e "\n->牵手地址: "$(echoColor red ${realmURI})"\n"
        if command -v warp >/dev/null 2>&1 && [ -f "/etc/wireguard/warp.conf" ]; then
            echoColor purple "\n->检测到已安装WARP,可通过 warp d 命令获得双栈WARP IP"
        fi
        echoColor green "\n(可选)是否安装服务器全局WARP[fscarmen]通过Cloudflare WARP IP打洞连接Hysteria2?"
        echo -e "原理: WARP通过WireGuard协议接入Cloudflare全球边缘网络,为服务器分配WARP IP。"
        echo -e "Hysteria2利用该WARP IP进行Realm打洞,客户端实际连接到Cloudflare边缘节点,"
        echo -e "从而隐藏服务器真实IP,相当于变相在Cloudflare CDN上使用Hysteria2。"
        echo -e "注意: 由于cloudflare warp是nat4, 所以客户端必须得是有公网ip或者nat1/2才能使用(一般可以直接用无需担心)"
        echo -e ""
        echo -e "\033[33m\033[01m1、跳过(默认)\n2、安装WARP\033[0m\033[32m\n\n输入序号:\033[0m"
        read -r warpChoice || return 1
        if [ "${warpChoice}" == "2" ]; then
            echoColor purple "\n->开始安装WARP,请稍候..."
            echoColor purple "请在WARP安装菜单中选择 [全局] 工作模式(出现菜单时手动选择全局)"
            wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh 2>/dev/null
            bash menu.sh d
            if [ -f "/etc/wireguard/warp.conf" ]; then
                current_mtu=$(grep -oP '^MTU = \K\d+' /etc/wireguard/warp.conf)
                if [ -n "${current_mtu}" ] && [ "${current_mtu}" -lt 1320 ]; then
                    sed -i "s/^MTU = ${current_mtu}/MTU = 1320/g" /etc/wireguard/warp.conf
                    echoColor purple "\n->MTU已从 ${current_mtu} 调整为 1320"
                elif [ -n "${current_mtu}" ]; then
                    echoColor purple "\n->当前MTU=${current_mtu},无需调整(≥1320)"
                fi
                echoColor purple "\n->正在开启WARP..."
                warp o
                sleep 3
                echoColor purple "\n->正在重新开启WARP以确保连接稳定..."
                warp o
                warpEnabled="true"
                echoColor purple "\n->WARP安装完成,Hysteria2将通过Cloudflare WARP IP打洞连接"
            else
                echoColor red "\n->WARP安装失败: 未找到/etc/wireguard/warp.conf"
                echoColor red "请手动执行: wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh d"
                echoColor red "WARP未成功安装,终止脚本执行"
                exit 1
            fi
        else
            warpEnabled="false"
            echoColor purple "\n->跳过WARP安装,直接使用服务器真实IP"
        fi
    else
        echoColor red "Realm 模式选项输入错误。"
        return 1
    fi
    echo -e "\033[32m(1/11)请选择证书方式:\n\n\033[0m\033[33m\033[01m1、ACME HTTP 自动申请(需开放 TCP/80)\n2、使用已有证书文件\n3、自签证书\n4、ACME DNS 自动申请\n5、使用多服务器证书管理已发布的证书(主菜单 16)\033[0m\033[32m\n\n输入序号:\033[0m"
    read -r certNum || return 1
    useAcme=false
    useLocalCert=false
    yaml_file="$HIHY_CONFIG_FILE"

    if [ -z "${certNum}" ] || [ "${certNum}" == "3" ]; then
        echoColor green "请输入自签证书的域名(默认:helloworld.com):"
        read -r domain
        if [ -z "${domain}" ]; then
            domain="helloworld.com"
        fi
        echo -e "->自签证书域名为:"$(echoColor red ${domain})"\n"
        if [ "${realmMode}" == "true" ]; then
            ip=""
            echo -e "\n->牵手地址: "$(echoColor red ${realmURI})"\n"
        else
            ip=$(curl -4 -s -m 8 ip.sb)
            if [ -z "${ip}" ]; then
                ip=$(curl -s -m 8 ip.sb)
            fi
            echoColor green "判断客户端连接所使用的地址是否正确?公网ip:"$(echoColor red ${ip})"\n"
            while true; do
                echo -e "\033[32m请选择:\n\n\033[0m\033[33m\033[01m1、正确(默认)\n2、不正确,手动输入ip\033[0m\033[32m\n\n输入序号:\033[0m"
                read -r ipNum
                if [ -z "${ipNum}" ] || [ "${ipNum}" == "1" ]; then
                    break
                elif [ "${ipNum}" == "2" ]; then
                    echoColor green "请输入正确的公网ip(ipv6地址不需要加[]):"
                    read -r ip
                    if [ -z "${ip}" ]; then
                        echoColor red "输入错误,请重新输入..."
                        continue
                    fi
                    break
                else
                    echoColor red "\n->输入错误,请重新输入:"
                fi
            done
        fi
        cert="/etc/hihy/cert/${domain}.crt"
        key="/etc/hihy/cert/${domain}.key"
        useAcme=false
        if [ "${realmMode}" == "true" ]; then
            echoColor purple "\n\n->您已选择自签${domain}证书加密.牵手地址:"$(echoColor red ${realmURI})"\n"
        else
            echoColor purple "\n\n->您已选择自签${domain}证书加密.公网ip:"$(echoColor red ${ip})"\n"
        fi
        echo -e "\n"

    elif [ "${certNum}" == "2" ]; then
        echoColor green "请输入证书cert文件路径(需fullchain cert,提供完整证书链):"
        read -r local_cert
        while :; do
            if [ ! -f "${local_cert}" ]; then
                echoColor red "\n\n->路径不存在,请重新输入!"
                echoColor green "请输入证书cert文件路径:"
                read -r local_cert
            else
                break
            fi
        done
        echo -e "\n\n->cert文件路径: "$(echoColor red ${local_cert})"\n"
        echoColor green "请输入证书key文件路径:"
        read -r local_key
        while :; do
            if [ ! -f "${local_key}" ]; then
                echoColor red "\n\n->路径不存在,请重新输入!"
                echoColor green "请输入证书key文件路径:"
                read -r local_key
            else
                break
            fi
        done
        echo -e "\n\n->key文件路径: "$(echoColor red ${local_key})"\n"
        echoColor green "请输入所选证书域名:"
        read -r domain
        while :; do
            if [ -z "${domain}" ]; then
                echoColor red "\n\n->此选项不能为空,请重新输入!"
                echoColor green "请输入所选证书域名:"
                read -r domain
            else
                break
            fi
        done
        useAcme=false
        useLocalCert=true
        echoColor purple "\n\n->您已选择本地证书加密.域名:"$(echoColor red ${domain})"\n"
    elif [ "${certNum}" == "5" ]; then
        local shared_domain
        shared_domain=$(getCertificateReceiverDomain 2>/dev/null || true)
        local_cert="$HIHY_SHARED_CERT_DIR/current/fullchain.pem"
        local_key="$HIHY_SHARED_CERT_DIR/current/privkey.pem"
        if [ -z "$shared_domain" ] || ! validateCertificateBundle "$local_cert" "$local_key" "$shared_domain"; then
            echoColor red "尚未找到证书管理功能发布的有效共享证书。"
            echoColor yellow "请先完成基础安装，再从主菜单 16『多服务器证书管理』初始化中心端或接收端。"
            return 1
        fi
        echoColor green "请输入本机客户端连接域名(必须属于 *.${shared_domain}):"
        read -r domain
        case "$domain" in
            *."$shared_domain") ;;
            *)
                echoColor red "域名不在 *.${shared_domain} 证书覆盖范围内。"
                return 1
                ;;
        esac
        useAcme=false
        useLocalCert=true
        echoColor purple "\n\n->使用多服务器证书管理已发布的证书，连接域名:"$(echoColor red "${domain}")"\n"
    elif [ "${certNum}" == "4" ]; then
        echoColor green "请输入域名:"
        read -r domain
        while :; do
            if [ -z "${domain}" ]; then
                echoColor red "\n\n->此选项不能为空,请重新输入!"
                echoColor green "请输入域名(需正确解析到本机,关闭CDN):"
                read -r domain
            else
                break
            fi
        done
        echo -e "\n\n->域名: "$(echoColor red ${domain})"\n"
        echo -e "\033[32m请选择DNS服务商:\n\n\033[0m\033[33m\033[01m1、Cloudflare(默认)\n2、Duck DNS\n3、Gandi.net\n4、Godaddy\n5、Namecheap\n6、Njalla\n7、Porkbun\n8、Vultr\033[0m\033[32m\n\n输入序号:\033[0m"
        read -r dnsNum
        if [ -z "${dnsNum}" ] || [ "${dnsNum}" == "1" ]; then
            dns="cloudflare"
            echo -e "\n\n->您选择Cloudflare DNS验证\n"
            echoColor green "请输入cloudflare_api_token:"
            while :; do
                read -r cloudflare_api_token
                if [ -z "${cloudflare_api_token}" ]; then
                    echoColor red "\n\n->此选项不能为空,请重新输入!"
                    echoColor green "请输入cloudflare_api_token:"
                else
                    break
                fi
            done
        elif [ "${dnsNum}" == "2" ]; then
            dns="duckdns"
            echo -e "\n\n->您选择Duck DNS DNS验证\n"
            echoColor green "请输入Duck DNS duckdns_api_token:"
            while :; do
                read -r duckdns_api_token
                if [ -z "${duckdns_api_token}" ]; then
                    echoColor red "\n\n->此选项不能为空,请重新输入!"
                    echoColor green "请输入Duck DNS duckdns_api_token:"
                else
                    break
                fi
            done
            echoColor green "请输入Duck DNS duckdns_override_domain:"
            while :; do
                read -r duckdns_override_domain
                if [ -z "${duckdns_override_domain}" ]; then
                    echoColor red "\n\n->此选项不能为空,请重新输入!"
                    echoColor green "请输入Duck DNS duckdns_override_domain:"
                else
                    break
                fi
            done
        elif [ "${dnsNum}" == "3" ]; then
            dns="gandi"
            echo -e "\n\n->您选择Gandi.net DNS验证\n"
            echoColor green "请输入Gandi gandi_api_token:"
            while :; do
                read -r gandi_api_token
                if [ -z "${gandi_api_token}" ]; then
                    echoColor red "\n\n->此选项不能为空,请重新输入!"
                    echoColor green "请输入Gandi gandi_api_token:"
                else
                    break
                fi
            done
        elif [ "${dnsNum}" == "4" ]; then
            dns="godaddy"
            echo -e "\n\n->您选择Godaddy DNS验证\n"
            echoColor green "请输入Godaddy godaddy_api_token:"
            while :; do
                read -r godaddy_api_token
                if [ -z "${godaddy_api_token}" ]; then
                    echoColor red "\n\n->此选项不能为空,请重新输入!"
                    echoColor green "请输入 Godaddy godaddy_api_token:"
                else
                    break
                fi
            done
        elif [ "${dnsNum}" == "5" ]; then
            dns="namecheap"
            echo -e "\n\n->您选择Namecheap DNS验证\n"
            echoColor green "请输入Namecheap namecheap_api_key:"
            while :; do
                read -r namecheap_api_key
                if [ -z "${namecheap_api_key}" ]; then
                    echoColor red "\n\n->此选项不能为空,请重新输入!"
                    echoColor green "请输入Namecheap namecheap_api_key:"
                else
                    break
                fi
            done
            echoColor green "请输入Namecheap namecheap_api_user:"
            while :; do
                read -r namecheap_api_user
                if [ -z "${namecheap_api_user}" ]; then
                    echoColor red "\n\n->此选项不能为空,请重新输入!"
                    echoColor green "请输入Namecheap namecheap_api_user:"
                else
                    break
                fi
            done
            echoColor green "请输入Namecheap白名单客户端公网IP(留空由Core自动检测):"
            read -r namecheap_client_ip
        elif [ "${dnsNum}" == "6" ]; then
            dns="njalla"
            echo -e "\n\n->您选择Njalla DNS验证\n"
            echoColor green "请输入Njalla njalla_api_token:"
            while :; do
                read -r njalla_api_token
                if [ -z "${njalla_api_token}" ]; then
                    echoColor red "\n\n->此选项不能为空,请重新输入!"
                    echoColor green "请输入Njalla njalla_api_token:"
                else
                    break
                fi
            done
        elif [ "${dnsNum}" == "7" ]; then
            dns="porkbun"
            echo -e "\n\n->您选择Porkbun DNS验证\n"
            echoColor green "请输入Porkbun porkbun_api_key:"
            while :; do
                read -r porkbun_api_key
                if [ -z "${porkbun_api_key}" ]; then
                    echoColor red "\n\n->此选项不能为空,请重新输入!"
                    echoColor green "请输入Porkbun porkbun_api_key:"
                else
                    break
                fi
            done
            echoColor green "请输入Porkbun porkbun_api_secret_key:"
            while :; do
                read -r porkbun_api_secret_key
                if [ -z "${porkbun_api_secret_key}" ]; then
                    echoColor red "\n\n->此选项不能为空,请重新输入!"
                    echoColor green "请输入Porkbun porkbun_api_secret_key:"
                else
                    break
                fi
            done
        elif [ "${dnsNum}" == "8" ]; then
            dns="vultr"
            echo -e "\n\n->您选择Vultr DNS验证\n"
            echoColor green "请输入Vultr vultr_api_token:"
            while :; do
                read -r vultr_api_token
                if [ -z "${vultr_api_token}" ]; then
                    echoColor red "\n\n->此选项不能为空,请重新输入!"
                    echoColor green "请输入Vultr vultr_api_token:"
                else
                    break
                fi
            done
        else
            echoColor red "\n->输入错误,请重新输入:"
        fi
        ip=$(curl -4 -s -m 8 ip.sb)
        if [ -z "${ip}" ]; then
            ip=$(curl -s -m 8 ip.sb)
        fi
        echoColor green "判断客户端连接所使用的地址是否正确?公网ip:"$(echoColor red ${ip})"\n"
        while true; do
            echo -e "\033[32m请选择:\n\n\033[0m\033[33m\033[01m1、正确(默认)\n2、不正确,手动输入ip\033[0m\033[32m\n\n输入序号:\033[0m"
            read -r ipNum
            if [ -z "${ipNum}" ] || [ "${ipNum}" == "1" ]; then
                break
            elif [ "${ipNum}" == "2" ]; then
                echoColor green "请输入正确的公网ip(ipv6地址不需要加[]):"
                read -r ip
                if [ -z "${ip}" ]; then
                    echoColor red "输入错误,请重新输入..."
                    continue
                fi
                break
            else
                echoColor red "\n->输入错误,请重新输入:"
            fi
        done
        echo -e "\n\n->您选择使用acme dns验证申请证书: "$(echoColor red ${domain})"\n"
        echo -e "\n ->dns验证方式: "$(echoColor red ${dns})"\n"
        echo -e "\n ->公网ip: "$(echoColor red ${ip})"\n"
        useAcme=true
        useDns=true
    elif [ "${certNum}" == "1" ]; then
        echoColor green "请输入域名(需正确解析到本机,关闭CDN):"
        read -r domain
        while :; do
            if [ -z "${domain}" ]; then
                echoColor red "\n\n->此选项不能为空,请重新输入!"
                echoColor green "请输入域名(需正确解析到本机,关闭CDN):"
                read -r domain
            else
                break
            fi
        done
        while :; do
            echoColor purple "\n->检测${domain},DNS解析..."
            ip_resolv=$(dig +short ${domain} A)
            if [ -z "${ip_resolv}" ]; then
                ip_resolv=$(dig +short ${domain} AAAA)
            fi
            if [ -z "${ip_resolv}" ]; then
                echoColor red "\n\n->域名解析失败,没有获得任何dns记录(A/AAAA),请检查域名是否正确解析到本机!"
                echoColor green "请输入域名(需正确解析到本机,关闭CDN):"
                read -r domain
                continue
            fi
            remoteip=$(echo ${ip_resolv} | awk -F " " '{print $1}')
            v6str=":"
            result=$(echo ${remoteip} | grep ${v6str})
            if [ "${result}" != "" ]; then
                localip=$(curl -6 -s -m 8 ip.sb)
            else
                localip=$(curl -4 -s -m 8 ip.sb)
            fi
            if [ -z "${localip}" ]; then
                localip=$(curl -s -m 8 ip.sb)
                if [ -z "${localip}" ]; then
                    echoColor red "\n\n->获取本机ip失败,请检查网络连接!curl -s -m 8 ip.sb"
                    exit 1
                fi
            fi
            if [ "${localip}" != "${remoteip}" ]; then
                echo -e " \n\n->本机ip: "$(echoColor red ${localip})" \n\n->域名ip: "$(echoColor red ${remoteip})"\n"
                echoColor green "多ip或者dns未生效时可能检测失败,如果你确定正确解析到了本机,是否自己指定本机ip? [y/N]:"
                read -r isLocalip
                if [ "${isLocalip}" == "y" ]; then
                    echoColor green "请自行输入本机ip:"
                    read -r localip
                    while :; do
                        if [ -z "${localip}" ]; then
                            echoColor red "\n\n->此选项不能为空,请重新输入!"
                            echoColor green "请输入本机ip:"
                            read -r localip
                        else
                            break
                        fi
                    done
                fi
                if [ "${localip}" != "${remoteip}" ]; then
                    echoColor red "\n\n->域名解析到的ip与本机ip不一致,请重新输入!"
                    echoColor green "请输入域名(需正确解析到本机,关闭CDN):"
                    read -r domain
                    continue
                else
                    break
                fi
            else
                break
            fi
        done
        useAcme=true
        useDns=false
        echoColor purple "\n\n->解析正确,使用hysteria内置ACME申请证书.域名:"$(echoColor red ${domain})"\n"
    else
        echoColor red "证书方式输入错误。"
        return 1
    fi

    rm -f "$yaml_file"
    touch "$yaml_file"
    if [ -n "$ech_key_path" ]; then
        addOrUpdateYaml "$yaml_file" "ech.keyPath" "$ech_key_path" "string" || return 1
    fi

    if [ "${realmMode}" == "true" ]; then
        port=""
        echoColor purple "\n->Realm模式无需配置端口,跳过端口设置\n"
    else
        while :; do
            echoColor green "\n(2/11)请输入你想要开启的端口,此端口是server端口,推荐443.(默认随机10000-65535)"
            echo "并没有证据表明非udp/443的端口会被阻断,它仅仅是可能有更好的伪装一种措施,$(echoColor red "如果你使用端口跳跃的话，这里建议使用随机端口")"
            read -r port
            if [ -z "${port}" ]; then
                port=$(($(od -An -N2 -i /dev/urandom) % (65534 - 10001) + 10001))
                echo -e "\n->使用随机端口:"$(echoColor red udp/${port})"\n"
            else
                echo -e "\n->您输入的端口:"$(echoColor red udp/${port})"\n"
            fi
            if ! validate_port "${port}"; then
                echoColor red "端口范围错误,请重新输入!"
                continue
            fi
            pIDa=$(lsof -i udp:${port} | grep -v "PID" | awk '{print $2}')
            if [ "$pIDa" != "" ]; then
                echoColor red "\n->端口${port}被占用,PID:${pIDa}!请重新输入或者运行kill -9 ${pIDa}后重新安装!"
            else
                break
            fi
        done
    fi

    if [ "${realmMode}" != "true" ]; then
        echoColor green "\n->(3/13)是否使用端口跳跃(Port Hopping),推荐使用"
        echo -e "Tip: 长时间单端口 UDP 连接容易被运营商封锁/QoS/断流,启动此功能可以有效避免此问题."
        echo -e "更加详细介绍请参考: https://v2.hysteria.network/zh/docs/advanced/Port-Hopping/\n"
        explainOfficialPortHopping
        echo -e "\033[32m选择是否启用:\n\n\033[0m\033[33m\033[01m1、启用(默认)\n2、跳过\033[0m\033[32m\n\n输入序号:\033[0m"
        read -r portHoppingStatus
        if [ -z "${portHoppingStatus}" ] || [ "${portHoppingStatus}" == "1" ]; then
            portHoppingStatus="true"
            echoColor purple "\n->您选择启用端口跳跃/多端口(Port Hopping)功能"
            echo -e "端口跳跃/多端口(Port Hopping)功能需要占用多个端口,请保证这些端口没有监听其他服务\nTip: 将使用 Hysteria2 原生范围监听,服务端会自动处理范围内端口的转发规则.\n"
            while :; do
                echoColor green "请输入起始端口(默认47000):"
                read -r portHoppingStart
                if [ -z "${portHoppingStart}" ]; then
                    portHoppingStart=47000
                fi
                if ! validate_port "${portHoppingStart}"; then
                    echoColor red "\n->端口范围错误,请重新输入!"
                    continue
                fi
                echo -e "\n->起始端口:"$(echoColor red ${portHoppingStart})"\n"
                echoColor green "请输入结束端口(默认48000):"
                read -r portHoppingEnd
                if [ -z "${portHoppingEnd}" ]; then
                    portHoppingEnd=48000
                fi
                if ! validate_port "${portHoppingEnd}"; then
                    echoColor red "\n->端口范围错误,请重新输入!"
                    continue
                fi
                echo -e "\n->结束端口:"$(echoColor red ${portHoppingEnd})"\n"
                if [ ${portHoppingStart} -ge ${portHoppingEnd} ]; then
                    echoColor red "\n->起始端口必须小于结束端口,请重新输入!"
                else
                    break
                fi
            done
            echo -e "\033[32m请选择端口跳跃时间模式:\n\n\033[0m\033[33m\033[01m1、固定跳跃时间(默认)\n2、随机跳跃时间\033[0m\033[32m\n\n输入序号:\033[0m"
            read -r portHoppingIntervalModeNum
            if [ -z "${portHoppingIntervalModeNum}" ] || [ "${portHoppingIntervalModeNum}" == "1" ]; then
                portHoppingIntervalMode="fixed"
                while :; do
                    echoColor green "请输入固定跳跃间隔(默认30s, 不能低于5s):"
                    read -r portHoppingHopInterval
                    if [ -z "${portHoppingHopInterval}" ]; then
                        portHoppingHopInterval="30s"
                    fi
                    echo -e "\n->固定跳跃间隔:"$(echoColor red ${portHoppingHopInterval})"\n"
                    hopSeconds=$(echo "${portHoppingHopInterval}" | sed 's/s$//')
                    if ! echo "${hopSeconds}" | grep -Eq '^[0-9]+$' || [ "${hopSeconds}" -lt 5 ]; then
                        echoColor red "\n->固定跳跃间隔格式错误,请输入不小于5s的秒数,例如30s"
                        continue
                    fi
                    break
                done
                portHoppingMinHopInterval=""
                portHoppingMaxHopInterval=""
            else
                portHoppingIntervalMode="random"
                portHoppingHopInterval=""
                while :; do
                    echoColor green "请输入最小跳跃间隔(默认10s, 不能低于5s):"
                    read -r portHoppingMinHopInterval
                    if [ -z "${portHoppingMinHopInterval}" ]; then
                        portHoppingMinHopInterval="10s"
                    fi
                    echo -e "\n->最小跳跃间隔:"$(echoColor red ${portHoppingMinHopInterval})"\n"
                    minHopSeconds=$(echo "${portHoppingMinHopInterval}" | sed 's/s$//')
                    if ! echo "${minHopSeconds}" | grep -Eq '^[0-9]+$' || [ "${minHopSeconds}" -lt 5 ]; then
                        echoColor red "\n->最小跳跃间隔格式错误,请输入不小于5s的秒数,例如10s"
                        continue
                    fi
                    echoColor green "请输入最大跳跃间隔(默认30s, 需大于等于最小间隔):"
                    read -r portHoppingMaxHopInterval
                    if [ -z "${portHoppingMaxHopInterval}" ]; then
                        portHoppingMaxHopInterval="30s"
                    fi
                    echo -e "\n->最大跳跃间隔:"$(echoColor red ${portHoppingMaxHopInterval})"\n"
                    maxHopSeconds=$(echo "${portHoppingMaxHopInterval}" | sed 's/s$//')
                    if ! echo "${maxHopSeconds}" | grep -Eq '^[0-9]+$' || [ "${maxHopSeconds}" -lt "${minHopSeconds}" ]; then
                        echoColor red "\n->最大跳跃间隔格式错误,请输入大于等于最小间隔的秒数,例如30s"
                        continue
                    fi
                    break
                done
            fi
            clientPort="${portHoppingStart}-${portHoppingEnd}"
            echo -e "\n->您选择的端口跳跃/多端口(Port Hopping)参数为: "$(echoColor red ${portHoppingStart}-${portHoppingEnd})"\n"
            if [ "${portHoppingIntervalMode}" == "fixed" ]; then
                echo -e "\n->固定跳跃间隔: "$(echoColor red ${portHoppingHopInterval})"\n"
            else
                echo -e "\n->随机跳跃间隔范围: "$(echoColor red ${portHoppingMinHopInterval}~${portHoppingMaxHopInterval})"\n"
            fi
        else
            portHoppingStatus="false"
            portHoppingIntervalMode=""
            portHoppingHopInterval=""
            portHoppingMinHopInterval=""
            portHoppingMaxHopInterval=""
            echoColor red "\n->您选择不使用端口跳跃功能"
        fi
    else
        portHoppingStatus="false"
        echoColor purple "\n->Realm模式无需端口跳跃,跳过此设置\n"
    fi

    echoColor green "(4/13)请选择拥塞控制模式:"
    echo -e "Reno: 更保守、更稳，适合优先考虑兼容性和稳定性的场景"
    echo -e "BBR: 更积极，通常吞吐更高，适合追求速度的场景"
    echo -e "Brutal: Hysteria 2 独享特色，固定速率模型，在恶劣网络环境下通常更值得优先尝试，尤其适合已知链路真实带宽、希望获得更强抗抖动和抢带宽能力的场景"
    echo -e "\033[32m请选择:\n\n\033[0m\033[33m\033[01m1、Reno(保守)\n2、BBR(均衡)\n3、Brutal(激进,默认)\033[0m\033[32m\n\n输入序号:\033[0m"
    read -r congestion_num
    if [ "${congestion_num}" == "1" ]; then
        congestion_mode="reno"
        congestion_type="reno"
        congestion_bbr_profile=""
        ignore_client_bandwidth="true"
        echo -e "\n->您选择的拥塞控制模式: "$(echoColor red Reno)"\n"
    elif [ "${congestion_num}" == "2" ]; then
        congestion_mode="bbr"
        congestion_type="bbr"
        ignore_client_bandwidth="true"
        echoColor green "BBR 提供三档调节方式，适合不同网络环境："
        echo -e "1、保守 / conservative：更保守，收敛更稳，适合链路波动较大、网络质量一般、优先稳定性的场景"
        echo -e "2、均衡 / standard(默认)：官方默认预设，速度与稳定性更均衡，适合大多数 VPS 和家庭宽带环境"
        echo -e "3、激进 / aggressive：更激进，更积极抢占带宽，适合链路质量较好、追求更高吞吐的场景，但波动时可能更敏感"
        echo -e "\033[32m请选择 BBR 预设等级:\n\n\033[0m\033[33m\033[01m1、初级(conservative)\n2、中级(standard，默认)\n3、高级(aggressive)\033[0m\033[32m\n\n输入序号:\033[0m"
        read -r bbr_profile_num
        case "${bbr_profile_num}" in
            1) congestion_bbr_profile="conservative" ;;
            3) congestion_bbr_profile="aggressive" ;;
            *) congestion_bbr_profile="standard" ;;
        esac
        echo -e "\n->您选择的拥塞控制模式: "$(echoColor red BBR)" / BBR预设: "$(echoColor red ${congestion_bbr_profile})"\n"
    else
        congestion_mode="brutal"
        congestion_type=""
        congestion_bbr_profile=""
        ignore_client_bandwidth="false"
        echo -e "\n->您选择的拥塞控制模式: "$(echoColor red Brutal)"\n"
    fi

    if [ "${congestion_mode}" == "brutal" ]; then
        echoColor green "(5/13)请输入您到此服务器的平均延迟,用于 Brutal 模式下估算 QUIC 窗口(默认200,单位:ms):"
        read -r delay
        if [ -z "${delay}" ]; then
            delay=200
        fi
        echo -e "\n->延迟:$(echoColor red ${delay})ms\n"
        echo -e "\n期望速度,这是客户端在 Brutal 模式下使用的目标带宽。"$(echoColor red Tips:脚本会自动*1.10做冗余，带宽不要高于真实链路极限，否则反而可能更不稳定!)
        echoColor green "(6/13)请输入客户端期望的下行速度:(默认50,单位:mbps):"
        read -r download
        if [ -z "${download}" ]; then
            download=50
        fi
        echo -e "\n->客户端下行速度："$(echoColor red ${download})"mbps\n"
        echo -e "\033[32m(7/13)请输入客户端期望的上行速度(默认10,单位:mbps):\033[0m"
        read -r upload
        if [ -z "${upload}" ]; then
            upload=10
        fi
        echo -e "\n->客户端上行速度："$(echoColor red ${upload})"mbps\n"
    else
        delay=""
        download=""
        upload=""
        echoColor lightYellow "(5-7/13)当前选择的是非 Brutal 模式，已跳过延时与上下行带宽输入，改用拥塞控制器本地配置。"
    fi
    echoColor green "(8/13)请输入认证口令(默认随机生成UUID作为密码,建议使用强密码):"
    read -r auth_secret
    if [ -z "${auth_secret}" ]; then
        auth_secret=$(generate_uuid)
    fi
    echo -e "\n->认证口令:"$(echoColor red ${auth_secret})"\n"
    echo -e "Tips: 如果使用obfs混淆,抗封锁能力更强,能被识别为未知udp流量。\n但是会增加cpu负载导致峰值速度下降,如果您追求性能且未被针对封锁建议不使用"
    echo -e "\033[32m(9/13)是否使用流量混淆:\n\n\033[0m\033[33m\033[01m1、不使用(推荐)\n2、salamander - 将数据包混淆为无特征随机字节\n3、gecko(实验性) - 在salamander基础上额外拆分QUIC握手包，抗检测更强\033[0m\033[32m\n\n输入序号:\033[0m"
    read -r obfs_num
    if [ -z "${obfs_num}" ] || [ ${obfs_num} == "1" ]; then
        obfs_status="false"
        obfs_type=""
    elif [ ${obfs_num} == "2" ]; then
        obfs_status="true"
        obfs_type="salamander"
        obfs_pass=${auth_secret}
    else
        obfs_status="true"
        obfs_type="gecko"
        obfs_pass=${auth_secret}
    fi
    if [ "${obfs_status}" == "true" ]; then
        echo -e "\n->您将使用${obfs_type}混淆加密流量\n"
    else
        echo -e "\n->您将不使用混淆\n"
    fi
    if [ "${realmMode}" != "true" ]; then
        echo -e "\033[32m(10/13)请选择伪装类型:\n\n\033[0m\033[33m\033[01m1、string(默认、返回一个固定的字符串)\n2、proxy(作为一个反向代理，从另一个网站提供内容。)\n3、file(作为一个静态文件服务器，从一个目录提供内容。目录内必须含有index.html)\033[0m\033[32m\n\n输入序号:\033[0m"
        read -r masquerade_type
        if [ -z "${masquerade_type}" ] || [ ${masquerade_type} == "1" ]; then
            masquerade_type="string"
            echo -e "请输入伪装字符串(默认:HelloWorld):"
            read -r masquerade_string
            if [ -z "${masquerade_string}" ]; then
                masquerade_string="HelloWorld"
            fi
            echo -e "\n->伪装字符串:$(echoColor red ${masquerade_string})\n"
            echo -e "请输入http伪装标头content-stuff(默认:HelloWorld):"
            read -r masquerade_stuff
            if [ -z "${masquerade_stuff}" ]; then
                masquerade_stuff="HelloWorld"
            fi
            echo -e "\n->http伪装标头content-stuff:$(echoColor red ${masquerade_stuff})\n"
        elif [ ${masquerade_type} == "2" ]; then
            masquerade_type="proxy"
            echoColor green "请输入伪装代理地址(默认:https://www.helloworld.org):"
            echo -e "反代该网址但不会替换网页内域名"
            read -r masquerade_proxy
            if [ -z "${masquerade_proxy}" ]; then
                masquerade_proxy="https://www.helloworld.org"
            fi
            echo -e "\n->伪装代理地址:"$(echoColor red ${masquerade_proxy})"\n"
            echo -e "\033[32m是否附加 X-Forwarded-For / Host / Proto 请求头:\n\n\033[0m\033[33m\033[01m1、启用(默认)\n2、关闭\033[0m\033[32m\n\n输入序号:\033[0m"
            read -r masquerade_xforwarded
            if [ -z "${masquerade_xforwarded}" ] || [ "${masquerade_xforwarded}" == "1" ]; then
                masquerade_xforwarded="true"
            else
                masquerade_xforwarded="false"
            fi
            echo -e "\n->X-Forwarded请求头: "$(echoColor red ${masquerade_xforwarded})"\n"
        else
            masquerade_type="file"
            masquerade_xforwarded="false"
            echoColor green "请输入伪装网站文件目录(默认:/etc/hihy/file,将自动下载mikutap部署):"
            echo -e "默认预览: https://hfiprogramming.github.io/mikutap/"
            read -r masquerade_file
            if [ -z "${masquerade_file}" ]; then
                masquerade_file="/etc/hihy/file"
            fi
            echo -e "\n->伪装网站文件目录:"$(echoColor red ${masquerade_file})"\n"
        fi
        if [ "${masquerade_type}" != "proxy" ]; then
            masquerade_xforwarded="false"
        fi
        if [ "${realmMode}" == "true" ]; then
            masquerade_tcp="false"
            echoColor purple "\n->Realm模式无需TCP监听,跳过伪装端口设置\n"
        else
            echoColor green "(11/13)是否同时监听tcp/${port}端口来增强伪装行为(做戏做全套):"
            echoColor lightYellow "通常网站支持 HTTP/3 的只是将其作为一个升级选项"
            echo -e "监听一个tcp端口来提供伪装内容,使伪装更加自然,如果不启用此选项,浏览器将在不启用H3功能下访问不了伪装内容"
            echo -e "\033[32m请选择:\n\n\033[0m\033[33m\033[01m1、启用(默认)\n2、跳过\033[0m\033[32m\n\n输入序号:\033[0m"
            read -r masquerade_tcp
            if [ -z "${masquerade_tcp}" ] || [ ${masquerade_tcp} == "1" ]; then
                masquerade_tcp="true"
                echo -e "\n->您选择同时监听$(echoColor red tcp/${port})端口\n"
            else
                masquerade_tcp="false"
                echo -e "\n->您选择不监听tcp/${port}端口\n"
            fi
        fi
    fi
    echoColor green "\n(12/13)是否在服务器屏蔽http3流量(hysteria对udp流量拥塞控制无增强效果，导致访问youtube等使用QUIC连接的网站效果不佳):"
    echoColor lightYellow "如果开启此选项，hysteria2将不会代理udp/443，无法使用QUIC连接访问网站，并且需要在客户端配置中禁用QUIC连接，否则会导致连接失败。\n"
    echo -e "也可以仅在客户端屏蔽QUIC/HTTP3/UDP 443连接，服务器不做屏蔽，效果一样\n"
    echo -e "\033[32m请选择:\n\n\033[0m\033[33m\033[01m1、启用(推荐)\n2、跳过(默认)\033[0m\033[32m\n\n输入序号:\033[0m"
    read -r block_http3
    if [ -z "${block_http3}" ] || [ ${block_http3} == "2" ]; then
        block_http3="false"
        echo -e "\n->您选择不屏蔽http3流量，这会导致访问使用QUIC连接的网站无hy2增强效果\n"
        echoColor lightYellow "Tip: 建议在客户端开启屏蔽QUIC/HTTP3/UDP 443此选项以获得更好的访问体验。\n"
    else
        block_http3="true"
        echoColor red "\n->您选择屏蔽http3流量，请根据自己使用的客户端，屏蔽QUIC/HTTP3流量，否则会导致对使用QUIC的网站连接失败\n"
    fi
    echoColor green "(13/13)请输入客户端名称备注(默认使用域名或IP区分,例如输入test,则名称为Hy2-test):"
    read -r remarks
    echoColor green "\n配置录入完成!\n"
    echoColor yellowBlack "执行配置..."
    max_CRW=0
    if [ "${congestion_mode}" == "brutal" ]; then
        download=$(($download + $download / 10))
        upload=$(($upload + $upload / 10))
        CRW=$(($delay * $download * 1000000 / 1000 * 2))
        SRW=$(($CRW / 5 * 2))
        max_CRW=$(($CRW * 3 / 2))
        max_SRW=$(($SRW * 3 / 2))
        server_upload=${download}
        server_download=${upload}
    fi

    if [ "${realmMode}" == "true" ]; then
        addOrUpdateYaml "$yaml_file" "listen" "${realmURI}" "string"
    elif [ "${portHoppingStatus}" == "true" ]; then
        addOrUpdateYaml "$yaml_file" "listen" ":${port},${portHoppingStart}-${portHoppingEnd}" "string"
    else
        addOrUpdateYaml "$yaml_file" "listen" ":${port}" "string"
    fi
    if [ "${realmMode}" == "true" ]; then
        addOrUpdateYaml "$yaml_file" "realm.stunServers[0]" "stun.nextcloud.com:3478"
        addOrUpdateYaml "$yaml_file" "realm.stunServers[1]" "global.stun.twilio.com:3478"
        addOrUpdateYaml "$yaml_file" "realm.stunTimeout" "5s"
        addOrUpdateYaml "$yaml_file" "realm.punchTimeout" "5s"
        addOrUpdateYaml "$yaml_file" "realm.heartbeatInterval" "30s"
        addOrUpdateYaml "$yaml_file" "realm.insecure" "false"
    else
        yq eval 'del(.realm)' -i "$yaml_file"
    fi
    addOrUpdateYaml "$yaml_file" "auth.type" "password"
    addOrUpdateYaml "$yaml_file" "auth.password" "${auth_secret}" "string"
    addOrUpdateYaml "$yaml_file" "ignoreClientBandwidth" "${ignore_client_bandwidth}"
    if [ "${congestion_mode}" != "brutal" ]; then
        addOrUpdateYaml "$yaml_file" "congestion.type" "${congestion_type}"
    else
        yq eval 'del(.congestion)' -i "$yaml_file"
    fi
    if [ "${congestion_type}" == "bbr" ]; then
        addOrUpdateYaml "$yaml_file" "congestion.bbrProfile" "${congestion_bbr_profile}"
    fi
    if [ "${obfs_status}" == "true" ]; then
        addOrUpdateYaml "$yaml_file" "obfs.type" "${obfs_type}"
        addOrUpdateYaml "$yaml_file" "obfs.${obfs_type}.password" "${obfs_pass}" "string"
    else
        yq eval 'del(.obfs)' -i "$yaml_file"
    fi
    if [ "${congestion_mode}" == "brutal" ]; then
        addOrUpdateYaml "$yaml_file" "quic.initStreamReceiveWindow" "${SRW}"
        addOrUpdateYaml "$yaml_file" "quic.maxStreamReceiveWindow" "${max_SRW}"
        addOrUpdateYaml "$yaml_file" "quic.initConnReceiveWindow" "${CRW}"
        addOrUpdateYaml "$yaml_file" "quic.maxConnReceiveWindow" "${max_CRW}"
    else
        yq eval 'del(.quic.initStreamReceiveWindow, .quic.maxStreamReceiveWindow, .quic.initConnReceiveWindow, .quic.maxConnReceiveWindow)' -i "$yaml_file"
    fi
    addOrUpdateYaml "$yaml_file" "quic.maxIdleTimeout" "30s"
    addOrUpdateYaml "$yaml_file" "quic.maxIncomingStreams" "1024"
    addOrUpdateYaml "$yaml_file" "quic.disablePathMTUDiscovery" "false"
    addOrUpdateYaml "$yaml_file" "quic.disableStatelessReset" "false"
    if [ "${congestion_mode}" == "brutal" ]; then
        addOrUpdateYaml "$yaml_file" "bandwidth.up" "${server_upload}mbps"
        addOrUpdateYaml "$yaml_file" "bandwidth.down" "${server_download}mbps"
    else
        yq eval 'del(.bandwidth)' -i "$yaml_file"
    fi
    addOrUpdateYaml "$yaml_file" "acl.file" "${acl_file}" "string"
    case ${masquerade_type} in
        "string")
            addOrUpdateYaml "$yaml_file" "masquerade.type" "string"
            addOrUpdateYaml "$yaml_file" "masquerade.string.content" "${masquerade_string}" "string"
            addOrUpdateYaml "$yaml_file" "masquerade.string.headers.content-type" "text/plain"
            addOrUpdateYaml "$yaml_file" "masquerade.string.headers.custom-stuff" "${masquerade_stuff}" "string"
            addOrUpdateYaml "$yaml_file" "masquerade.string.statusCode" "200"
            ;;
        "proxy")
            addOrUpdateYaml "$yaml_file" "masquerade.type" "proxy"
            addOrUpdateYaml "$yaml_file" "masquerade.proxy.url" "${masquerade_proxy}" "string"
            addOrUpdateYaml "$yaml_file" "masquerade.proxy.rewriteHost" "true"
            echoColor green "是否跳过伪装上游 TLS 证书验证?"
            echoColor yellow "1、不跳过，验证证书(推荐/默认)  2、跳过验证(仅自签或特殊上游)"
            read -r masquerade_insecure_choice
            if [ "$masquerade_insecure_choice" = "2" ]; then
                addOrUpdateYaml "$yaml_file" "masquerade.proxy.insecure" "true" "bool"
            else
                addOrUpdateYaml "$yaml_file" "masquerade.proxy.insecure" "false" "bool"
            fi
            addOrUpdateYaml "$yaml_file" "masquerade.proxy.xForwarded" "${masquerade_xforwarded}"
            ;;
        "file")
            addOrUpdateYaml "$yaml_file" "masquerade.type" "file"
            addOrUpdateYaml "$yaml_file" "masquerade.file.dir" "${masquerade_file}" "string"
            if [ ! -d "${masquerade_file}" ]; then
                mkdir -p ${masquerade_file}
                wget -q -O ./mikutap.tar.gz https://github.com/HFIProgramming/mikutap/archive/refs/tags/2.0.0.tar.gz
                tar -xzf ./mikutap.tar.gz -C ${masquerade_file} --strip-components=1
                rm -r ./mikutap.tar.gz
            fi
            ;;
    esac
    if [ "${realmMode}" != "true" ] && [ "${masquerade_tcp}" == "true" ]; then
        addOrUpdateYaml "$yaml_file" "masquerade.listenHTTPS" ":${port}"
    fi
    addOrUpdateYaml "$yaml_file" "speedTest" "true"
    if echo "${useAcme}" | grep -q "false"; then
        if echo "${useLocalCert}" | grep -q "false"; then
            v6str=":"
            result=$(echo ${ip} | grep ${v6str})
            if [ "${result}" != "" ]; then
                ip="[${ip}]"
            fi
            u_host=${ip}
            u_domain=${domain}
            if [ -z "${remarks}" ]; then
                remarks="${ip}"
            fi
            insecure="1"
            days=3650
            mail="no-reply@qq.com"
            echoColor purple "开始生成自签名证书...\n"
            echoColor green "生成 CA 私钥..."
            openssl genrsa -out /etc/hihy/cert/${domain}.ca.key 2048
            echoColor green "生成 CA 证书..."
            openssl req -new -x509 -days ${days} -key /etc/hihy/cert/${domain}.ca.key -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=PonyMa/OU=Tecent/emailAddress=${mail}/CN=Tencent Root CA" -out /etc/hihy/cert/${domain}.ca.crt
            echoColor green "生成服务器私钥和 CSR..."
            openssl req -newkey rsa:2048 -nodes -keyout /etc/hihy/cert/${domain}.key -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=PonyMa/OU=Tecent/emailAddress=${mail}/CN=${domain}" -out /etc/hihy/cert/${domain}.csr
            echoColor green "使用 CA 签署服务器证书..."
            openssl x509 -req -extfile <(printf "subjectAltName=DNS:${domain},DNS:${domain}") -days ${days} -in /etc/hihy/cert/${domain}.csr -CA /etc/hihy/cert/${domain}.ca.crt -CAkey /etc/hihy/cert/${domain}.ca.key -CAcreateserial -out /etc/hihy/cert/${domain}.crt
            echoColor green "清理临时文件..."
            rm /etc/hihy/cert/${domain}.ca.key /etc/hihy/cert/${domain}.ca.srl /etc/hihy/cert/${domain}.csr
            echoColor green "移动 CA 证书到结果目录..."
            mv /etc/hihy/cert/${domain}.ca.crt /etc/hihy/result
            echoColor purple "证书生成成功！\n"
            addOrUpdateYaml "$yaml_file" "tls.cert" "/etc/hihy/cert/${domain}.crt" "string"
            addOrUpdateYaml "$yaml_file" "tls.key" "/etc/hihy/cert/${domain}.key" "string"
            addOrUpdateYaml "$yaml_file" "tls.sniGuard" "strict"
        else
            u_host=${domain}
            u_domain=${domain}
            if [ -z "${remarks}" ]; then
                remarks="${domain}"
            fi
            insecure="0"
            addOrUpdateYaml "$yaml_file" "tls.cert" "${local_cert}" "string"
            addOrUpdateYaml "$yaml_file" "tls.key" "${local_key}" "string"
            addOrUpdateYaml "$yaml_file" "tls.sniGuard" "strict"
        fi
    else
        u_host=${domain}
        u_domain=${domain}
        insecure="0"
        if [ -z "${remarks}" ]; then
            remarks="${domain}"
        fi
        addOrUpdateYaml "$yaml_file" "acme.domains" "${domain}" "string"
        addOrUpdateYaml "$yaml_file" "acme.email" "pekora@${domain}" "string"
        addOrUpdateYaml "$yaml_file" "acme.ca" "letsencrypt"
        addOrUpdateYaml "$yaml_file" "acme.dir" "/etc/hihy/cert"
        if [ "${useDns}" == "true" ]; then
            u_host=${ip}
            addOrUpdateYaml "$yaml_file" "acme.type" "dns"
            case ${dns} in
                "cloudflare")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "cloudflare"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.cloudflare_api_token" "${cloudflare_api_token}" "string"
                    ;;
                "duckdns")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "duckdns"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.duckdns_api_token" "${duckdns_api_token}" "string"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.duckdns_override_domain" "${duckdns_override_domain}" "string"
                    ;;
                "gandi")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "gandi"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.gandi_api_token" "${gandi_api_token}" "string"
                    ;;
                "godaddy")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "godaddy"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.godaddy_api_token" "${godaddy_api_token}" "string"
                    ;;
                "namecheap")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "namecheap"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.namecheap_api_key" "${namecheap_api_key}" "string"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.namecheap_api_user" "${namecheap_api_user}" "string"
                    if [ -n "${namecheap_client_ip}" ]; then
                        addOrUpdateYaml "$yaml_file" "acme.dns.config.namecheap_client_ip" "${namecheap_client_ip}" "string"
                    fi
                    ;;
                "njalla")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "njalla"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.njalla_api_token" "${njalla_api_token}" "string"
                    ;;
                "porkbun")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "porkbun"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.porkbun_api_key" "${porkbun_api_key}" "string"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.porkbun_api_secret_key" "${porkbun_api_secret_key}" "string"
                    ;;
                "vultr")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "vultr"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.vultr_api_token" "${vultr_api_token}" "string"
                    ;;
            esac
        else
            getPortBindMsg TCP 80
            allowPort tcp 80 || return 1
            addOrUpdateYaml "$yaml_file" "acme.type" "http"
            addOrUpdateYaml "$yaml_file" "acme.listenHost" "0.0.0.0"
        fi
    fi
    if [ "${realmMode}" == "true" ]; then
        u_host="${realmURI}"
    fi

    addOrUpdateYaml "$yaml_file" "sniff.enabled" "true"
    addOrUpdateYaml "$yaml_file" "sniff.timeout" "2s"
    addOrUpdateYaml "$yaml_file" "sniff.rewriteDomain" "false"
    addOrUpdateYaml "$yaml_file" "sniff.tcpPorts" "80,443"
    addOrUpdateYaml "$yaml_file" "sniff.udpPorts" "80,443"
    addOrUpdateYaml "$yaml_file" "outbounds[0].name" "hihy" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[0].type" "direct" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[0].direct.mode" "auto" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[0].direct.fastOpen" "false" "bool"
    addOrUpdateYaml "$yaml_file" "outbounds[1].name" "v4_only" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[1].type" "direct" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[1].direct.mode" "4" "number"
    addOrUpdateYaml "$yaml_file" "outbounds[1].direct.fastOpen" "false" "bool"
    addOrUpdateYaml "$yaml_file" "outbounds[2].name" "v6_only" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[2].type" "direct" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[2].direct.mode" "6" "number"
    addOrUpdateYaml "$yaml_file" "outbounds[2].direct.fastOpen" "false" "bool"
    trafficPort=$(($(od -An -N2 -i /dev/urandom) % (65534 - 10001) + 10001))
    if [ "$trafficPort" == "${port}" ]; then
        trafficPort=$((${port} + 1))
    fi
    addOrUpdateYaml "$yaml_file" "trafficStats.listen" "127.0.0.1:${trafficPort}"
    addOrUpdateYaml "$yaml_file" "trafficStats.secret" "${auth_secret}" "string"
    if [ ${block_http3} == "true" ]; then
        echo -e "reject(all, udp/443)" >${acl_file}
    fi
    if [ ${max_CRW} -gt 0 ]; then
        sysctl -w net.core.rmem_max=${max_CRW}
        sysctl -w net.core.wmem_max=${max_CRW}
    fi
    if echo "${portHoppingStatus}" | grep -q "true"; then
        sysctl -w net.ipv4.ip_forward=1
        sysctl -w net.ipv6.conf.all.forwarding=1
    fi
    if [ ! -f "/etc/sysctl.conf" ]; then
        touch /etc/sysctl.conf
    fi
    sysctl -p
    echo -e "\033[1;;35m\nTest config...\n\033[0m"
    validation_pid=$(startInstallValidationProcess "${yaml_file}" "./hihy_debug.info")
    if [ "${useAcme}" == "true" ]; then
        countdown 20
    else
        countdown 5
    fi
    msg=$(cat ./hihy_debug.info)
    case ${msg} in
        *"failed to get a certificate with ACME"*)
            markInstallFailed "certificate" "failed to get a certificate with ACME"
            echoColor red "域名:${u_host},申请证书失败!请重新安装使用自签证书."
            rm /etc/hihy/conf/config.yaml
            rm -f "$HIHY_BACKUP_FILE"
            delHihyFirewallPort
            rm ./hihy_debug.info
            echoColor yellow "当前安装处于未完成状态，可修正问题后重新执行安装，或执行卸载进行清理。"
            wait "$validation_pid" 2>/dev/null || true
            return 1
            ;;
        *"bind: address already in use"*)
            markInstallFailed "port-bind" "bind: address already in use"
            rm /etc/hihy/conf/config.yaml
            rm -f "$HIHY_BACKUP_FILE"
            delHihyFirewallPort
            echoColor red "端口被占用,请更换端口!"
            rm ./hihy_debug.info
            echoColor yellow "当前安装处于未完成状态，可更换端口后重新执行安装，或执行卸载进行清理。"
            wait "$validation_pid" 2>/dev/null || true
            return 1
            ;;
        *"server up and running"*)
            echoColor green "Test success!"
            echoColor purple "Stop test program..."
            kill "$validation_pid" 2>/dev/null || true
            wait "$validation_pid" 2>/dev/null || true
            rm ./hihy_debug.info
            if [ "${realmMode}" != "true" ]; then
                allowPort udp "${port}" || return 1
                if [ "${portHoppingStatus}" == "true" ]; then
                    allowPort udp "${portHoppingStart}:${portHoppingEnd}" || return 1
                fi
                if [ "${masquerade_tcp}" == "true" ]; then
                    getPortBindMsg TCP ${port}
                    allowPort tcp "${port}" || return 1
                fi
            fi
            echoColor purple "Generating config..."
            ;;
        *)
            markInstallFailed "config-test" "unknown error while validating generated config"
            if ! command -v pkill >/dev/null 2>&1; then
                apk add --no-cache procps
            fi
            kill "$validation_pid" 2>/dev/null || true
            wait "$validation_pid" 2>/dev/null || true
            echoColor red "未知错误: 请查看下方错误信息,并提交issue到github"
            echoColor yellow "已保留未完成安装状态，修正问题后可重新执行安装，或执行卸载进行清理。"
            cat ./hihy_debug.info
            rm ./hihy_debug.info
            return 1
            ;;
    esac
    if [ -f "/etc/hihy/conf/backup.yaml" ]; then
        rm /etc/hihy/conf/backup.yaml
    fi
    backup_file="$HIHY_BACKUP_FILE"
    touch ${backup_file}
    addOrUpdateYaml ${backup_file} "remarks" "${remarks}" "string"
    addOrUpdateYaml ${backup_file} "serverAddress" "${u_host}" "string"
    addOrUpdateYaml ${backup_file} "serverPort" "${port}"
    addOrUpdateYaml ${backup_file} "congestionMode" "${congestion_mode}"
    addOrUpdateYaml ${backup_file} "congestionType" "${congestion_type}"
    addOrUpdateYaml ${backup_file} "ignoreClientBandwidth" "${ignore_client_bandwidth}"
    if [ "${congestion_type}" == "bbr" ]; then
        addOrUpdateYaml ${backup_file} "congestionBbrProfile" "${congestion_bbr_profile}"
    fi
    addOrUpdateYaml ${backup_file} "portHoppingStatus" "${portHoppingStatus}"
    addOrUpdateYaml ${backup_file} "portHoppingStart" "${portHoppingStart}"
    addOrUpdateYaml ${backup_file} "portHoppingEnd" "${portHoppingEnd}"
    addOrUpdateYaml ${backup_file} "portHoppingIntervalMode" "${portHoppingIntervalMode}"
    addOrUpdateYaml ${backup_file} "portHoppingHopInterval" "${portHoppingHopInterval}"
    addOrUpdateYaml ${backup_file} "portHoppingMinHopInterval" "${portHoppingMinHopInterval}"
    addOrUpdateYaml ${backup_file} "portHoppingMaxHopInterval" "${portHoppingMaxHopInterval}"
    addOrUpdateYaml ${backup_file} "domain" "${domain}" "string"
    addOrUpdateYaml ${backup_file} "trafficPort" "${trafficPort}"
    addOrUpdateYaml ${backup_file} "socks5_status" "false"
    addOrUpdateYaml ${backup_file} "realmMode" "${realmMode}"
    if [ "${realmMode}" == "true" ]; then
        addOrUpdateYaml ${backup_file} "realmURI" "${realmURI}" "string"
        addOrUpdateYaml ${backup_file} "realmName" "${realmName}" "string"
    fi
    addOrUpdateYaml ${backup_file} "masquerade_xforwarded" "${masquerade_xforwarded}"
    if [ "$masquerade_tcp" == "true" ]; then
        addOrUpdateYaml ${backup_file} "masquerade_tcp" "true"
    else
        addOrUpdateYaml ${backup_file} "masquerade_tcp" "false"
    fi
    if [ ${insecure} == "1" ]; then
        addOrUpdateYaml ${backup_file} "insecure" "true"
    else
        addOrUpdateYaml ${backup_file} "insecure" "false"
    fi
    secureHihyPermissions
    if ! installHihyLauncher; then
        markInstallFailed "launcher" "failed to install hihy launcher"
        echoColor red "hihy 命令安装失败,请检查网络或写入权限后重试."
        exit 1
    fi
    echoColor greenWhite "安装成功,请查看下方配置详细信息"
}

getHysteriaAssetName() {
    local arch="${1:-$(uname -m)}"
    case "$arch" in
        x86_64) echo hysteria-linux-amd64 ;;
        aarch64 | arm64) echo hysteria-linux-arm64 ;;
        armv5*) echo hysteria-linux-armv5 ;;
        armv6* | armv7* | arm) echo hysteria-linux-arm ;;
        mipsle) echo hysteria-linux-mipsle ;;
        mips | mips64)
            # uname 在部分 MIPSLE 系统也报告 mips；读取本机 ELF 的 EI_DATA。
            if [ "$(od -An -tu1 -j5 -N1 /proc/self/exe | tr -d '[:space:]')" = 1 ]; then
                echo hysteria-linux-mipsle
            else
                echoColor red "上游没有大端 MIPS 核心。" >&2
                return 1
            fi
            ;;
        riscv64) echo hysteria-linux-riscv64 ;;
        s390x) echo hysteria-linux-s390x ;;
        i686 | i386) echo hysteria-linux-386 ;;
        loongarch64) echo hysteria-linux-loong64 ;;
        *) echoColor red "不支持的核心架构: $arch" >&2; return 1 ;;
    esac
}

downloadHysteriaCore() (
    local version="${1:-}" destination="${2:-$HIHY_ROOT_DIR/bin/appS}"
    local asset metadata download_url expected_digest actual_digest stage
    [ -n "$version" ] || version=$(getLatestHysteriaVersion) || return 1
    isHysteriaReleaseVersion "$version" || { echoColor red "无法获取有效的正式版本。"; return 1; }
    asset=$(getHysteriaAssetName) || return 1
    command -v sha256sum >/dev/null 2>&1 || { echoColor red "缺少 sha256sum，无法校验核心。"; return 1; }
    mkdir -p "$HIHY_ROOT_DIR/bin" || return 1
    stage=$(mktemp -d "$HIHY_ROOT_DIR/bin/.download.XXXXXX") || return 1
    trap 'rm -rf "$stage"' EXIT
    metadata=$(getHysteriaReleaseAsset "$version" "$asset" || true)
    download_url=$(printf '%s' "$metadata" | yq -p=json -r '.browser_download_url // ""' 2>/dev/null) || true
    expected_digest=$(printf '%s' "$metadata" | yq -p=json -r '.digest // ""' 2>/dev/null) || true
    if [ -z "$download_url" ] || [ "$download_url" = null ]; then
        download_url="https://github.com/HyNetworks/hysteria/releases/download/${version}/${asset}"
    fi
    echoColor purple "下载 Hysteria ${version}..."
    HIHY_REMOTE_MAX_TIME="${HIHY_CORE_DOWNLOAD_TIMEOUT:-180}" downloadToFile "$download_url" "$stage/appS" || return 1
    if [ -z "$expected_digest" ] || [ "$expected_digest" = null ]; then
        # API 限流或没有 digest 时仍必须校验，不能直接运行未校验的文件。
        downloadToFile "https://github.com/HyNetworks/hysteria/releases/download/${version}/hashes.txt" "$stage/hashes.txt" || return 1
        expected_digest=$(awk -v name="$asset" '$2 == "build/" name || $2 == name {print $1}' "$stage/hashes.txt")
        expected_digest="sha256:$expected_digest"
    fi
    actual_digest=$(sha256sum "$stage/appS") || return 1
    actual_digest="sha256:${actual_digest%% *}"
    if [[ ! "$expected_digest" =~ ^sha256:[0-9a-f]{64}$ ]] || [ "$actual_digest" != "$expected_digest" ]; then
        echoColor red "Hysteria Core SHA-256 校验失败，保留原核心。"
        return 1
    fi
    chmod 755 "$stage/appS" || return 1
    if [ "$(getLocalHysteriaVersion "$stage/appS")" != "$version" ]; then
        echoColor red "下载的核心无法运行或版本不匹配。"
        return 1
    fi
    mv -f "$stage/appS" "$destination" || return 1
    echoColor green "核心下载及校验完成。"
)

hihyProcessAlive() {
    local pid="$1" state
    [[ "$pid" =~ ^[0-9]+$ ]] && [ "$pid" -gt 1 ] || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    state=$(awk '/^State:/ {print $2}' "/proc/$pid/status" 2>/dev/null)
    [ -n "$state" ] && [ "$state" != Z ]
}

getHihyServicePID() {
    if [ -f "$HIHY_SERVICE_FILE" ] && [ "$(detectServiceManager)" = systemd ]; then
        systemctl show -p MainPID --value hihy.service
    else
        [ -r "$HIHY_PID_FILE" ] || return 1
        cat "$HIHY_PID_FILE"
    fi
}

waitHihyServiceHealthy() {
    local initial_pid current_pid i
    initial_pid=$(getHihyServicePID) || return 1
    hihyProcessAlive "$initial_pid" || return 1
    # 不仅检查启动命令返回值，也检查延迟退出和 systemd 重启循环。
    for ((i=0; i<5; i++)); do
        sleep 1
        serviceIsActive || return 1
        current_pid=$(getHihyServicePID) || return 1
        [ "$current_pid" = "$initial_pid" ] && hihyProcessAlive "$current_pid" || return 1
    done
}

updateHysteriaCore() (
    local core="$HIHY_ROOT_DIR/bin/appS" rollback_core="$HIHY_ROOT_DIR/bin/appS.rollback"
    local local_version version stage="" was_running=false lock="$HIHY_ROOT_DIR/bin/.core-update.lock"
    [ -x "$core" ] || { echoColor red "Hysteria core not found."; return 1; }
    mkdir "$lock" 2>/dev/null || { echoColor red "已有核心更新任务，或异常退出留下锁: $lock"; return 1; }
    trap 'rm -rf "${stage:-$lock/stage}"; rmdir "$lock"' EXIT
    version=$(getLatestHysteriaVersion) || { echoColor red "无法获取最新版本，保留当前服务。"; return 1; }
    isHysteriaReleaseVersion "$version" || return 1
    local_version=$(getLocalHysteriaVersion "$core")
    echoColor purple "当前核心: $local_version; 最新核心: $version"
    [ "$local_version" != "$version" ] || { echoColor green "已是最新版本。"; return 0; }
    stage=$(mktemp -d "$HIHY_ROOT_DIR/bin/.update.XXXXXX") || return 1
    downloadHysteriaCore "$version" "$stage/appS" || return 1
    cp -p "$core" "$stage/rollback" && mv -f "$stage/rollback" "$rollback_core" || return 1
    serviceIsActive && was_running=true
    mv -f "$stage/appS" "$core" || return 1
    if [ "$was_running" = true ]; then
        if ! serviceRestart || ! waitHihyServiceHealthy; then
            echoColor yellow "新核心启动失败，正在恢复旧核心..."
            cp -p "$rollback_core" "$stage/restore" && mv -f "$stage/restore" "$core" || return 1
            if serviceRestart && waitHihyServiceHealthy; then
                echoColor yellow "已恢复旧核心并启动服务，更新未完成。"
            else
                echoColor red "已恢复旧核心，但服务启动失败，请查看日志。备份: $rollback_core"
            fi
            return 1
        fi
    fi
    rm -f "$HIHY_VERSION_STATUS_FILE"
    if [ "$was_running" = true ]; then
        echoColor green "核心更新成功，服务已启动。旧核心: $rollback_core"
    else
        echoColor green "核心更新成功，服务保持停止状态。旧核心: $rollback_core"
    fi
)

hihy_update_notifycation() {
    displayCachedVersionNotifications
}

hihyUpdate() {
    local localV="${hihyV}"
    local remoteV=""
    local tmp_file=""

    remoteV=$(getLatestHihyVersion || true)

    if [ -z "$remoteV" ]; then
        echoColor red "Network Error: Can't connect to ${HIHY_REPO_URL}!"
        exit 1
    fi

    echo -e "Local hihy version: $(echoColor red "${localV}")"
    echo -e "Remote hihy version: $(echoColor red "${remoteV}")"

    if [ "$localV" = "$remoteV" ]; then
        echoColor green "Already the latest version. Ignore."
        return 0
    fi

    tmp_file="${HIHY_BIN_LINK}.tmp.$$"

    if ! downloadToFile "${HIHY_REMOTE_SCRIPT_URL}?t=$(date +%s)" "$tmp_file"; then
        if ! downloadToFile "$HIHY_REMOTE_SCRIPT_MIRROR_URL" "$tmp_file"; then
            rm -f "$tmp_file"
            echoColor red "hihy 更新失败，请检查网络或写入权限。"
            exit 1
        fi
    fi

    chmod 755 "$tmp_file"
    if ! validateDownloadedShell "$tmp_file"; then
        rm -f "$tmp_file"
        echoColor red "下载的 hihy 脚本校验失败，保留当前版本。"
        exit 1
    fi
    mv "$tmp_file" "$HIHY_BIN_LINK"

    rm -f "$HIHY_VERSION_STATUS_FILE"

    echoColor green "hihy 更新完成。"
    echoColor purple "更新来源: ${HIHY_REPO_URL}"
    echoColor purple "正在重新载入新版脚本..."
    exec "$HIHY_BIN_LINK"
}

hyCore_update_notifycation() {
    displayCachedVersionNotifications
}

setup_rc_local_for_arch() {
    # 检测是否为 Arch Linux
    if grep -q "Arch Linux" /etc/os-release; then
        echo "Detected Arch Linux. Setting up rc.local with systemd..."

        # 创建 /etc/systemd/system/rc-local.service 文件
        cat <<EOF | tee /etc/systemd/system/rc-local.service
[Unit]
Description=/etc/rc.local Compatibility
ConditionPathExists=/etc/rc.local

[Service]
Type=forking
ExecStart=/etc/rc.local
TimeoutSec=0
RemainAfterExit=yes
GuessMainPID=no

[Install]
WantedBy=multi-user.target
EOF
        # 启用 rc-local 服务
        systemctl enable rc-local

        echo "rc.local has been set up and started with systemd."
    fi
}

detectServiceManager() {
    if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
        echo "systemd"
    elif command -v rc-service >/dev/null 2>&1 && command -v rc-update >/dev/null 2>&1; then
        echo "openrc"
    else
        echo "legacy"
    fi
}

isNativeHihySystemdService() {
    local load_state fragment_path source_path

    [ "$(detectServiceManager)" = "systemd" ] || return 1
    load_state=$(systemctl show -p LoadState --value hihy.service 2>/dev/null)
    fragment_path=$(systemctl show -p FragmentPath --value hihy.service 2>/dev/null)
    source_path=$(systemctl show -p SourcePath --value hihy.service 2>/dev/null)

    [ "$load_state" = "loaded" ] || return 1
    [ -n "$fragment_path" ] || return 1
    case "$fragment_path" in
        /run/systemd/generator/* | /run/systemd/generator.late/*) return 1 ;;
    esac
    [ -z "$source_path" ] || return 1
}

writeSystemdService() {
    local start_cmd_prefix
    local exec_start
    local temp_file
    local backup_file=""
    local verify_log="$HIHY_ROOT_DIR/result/service-migration.verify.log"

    start_cmd_prefix=$(getStartCommand)
    if [ -n "$start_cmd_prefix" ]; then
        if [ "${start_cmd_prefix%% *}" = "chrt" ]; then
            start_cmd_prefix="$(command -v chrt)${start_cmd_prefix#chrt}"
        fi
        exec_start="$start_cmd_prefix $HIHY_ROOT_DIR/bin/appS --log-level info -c $HIHY_CONFIG_FILE server"
    else
        exec_start="$HIHY_ROOT_DIR/bin/appS --log-level info -c $HIHY_CONFIG_FILE server"
    fi

    temp_file=$(mktemp "${HIHY_SERVICE_FILE}.tmp.XXXXXX") || return 1
    cat >"$temp_file" <<EOF
[Unit]
Description=Hysteria 2 Server managed by Hi_Hysteria
Documentation=${HIHY_REPO_URL}
Wants=network-online.target
After=network-online.target
$(if grep -q '^backend=nft|' "$HIHY_FIREWALL_STATE_FILE" 2>/dev/null; then printf '%s\n' 'Requires=hihy-firewall.service' 'After=hihy-firewall.service'; fi)

[Service]
Type=simple
User=root
Group=root
UMask=0077
ExecStart=${exec_start}
Restart=on-failure
RestartSec=3s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    chmod 644 "$temp_file"
    if [ -f "$HIHY_SERVICE_FILE" ]; then
        backup_file=$(mktemp "${HIHY_SERVICE_FILE}.backup.XXXXXX") || return 1
        cp -a "$HIHY_SERVICE_FILE" "$backup_file" || return 1
    fi
    mv -f "$temp_file" "$HIHY_SERVICE_FILE"
    if command -v systemd-analyze >/dev/null 2>&1; then
        if ! systemd-analyze verify "$HIHY_SERVICE_FILE" >"$verify_log" 2>&1; then
            chmod 600 "$verify_log"
            echoColor yellow "systemd-analyze 预检查返回警告，将继续用实际加载和启动结果验证。"
            echoColor yellow "诊断日志: $verify_log"
        else
            rm -f "$verify_log"
        fi
    fi
    [ -n "$backup_file" ] && rm -f "$backup_file"
    return 0
}

writeOpenRcService() {
    cat >"$HIHY_INIT_SERVICE" <<EOF
#!/sbin/openrc-run

name="hihy"
description="Hysteria 2 Server managed by Hi_Hysteria"
command="${HIHY_ROOT_DIR}/bin/appS"
command_args="--log-level info -c ${HIHY_CONFIG_FILE} server"
command_background="yes"
pidfile="${HIHY_PID_FILE}"
output_log="${HIHY_LOG_FILE}"
error_log="${HIHY_LOG_FILE}"

depend() {
    need net
    after firewall
}

start_pre() {
    checkpath --directory --owner root:root --mode 0700 "${HIHY_ROOT_DIR}/logs"
    checkpath --file --owner root:root --mode 0600 "${HIHY_LOG_FILE}"
}
EOF
    chmod 755 "$HIHY_INIT_SERVICE"
}

writeLegacyService() {
    local start_cmd_prefix
    start_cmd_prefix=$(getStartCommand)
    mkdir -p "$(dirname "$HIHY_LEGACY_SERVICE")"

    cat >"$HIHY_LEGACY_SERVICE" <<EOF
#!/bin/sh
HIHY_PATH="${HIHY_ROOT_DIR}"
PID_FILE="${HIHY_PID_FILE}"
LOG_FILE="${HIHY_LOG_FILE}"
START_CMD_PREFIX="${start_cmd_prefix}"

start() {
    if [ -f "\$PID_FILE" ] && kill -0 "\$(cat "\$PID_FILE")" 2>/dev/null; then
        echo "hihy is already running"
        return 0
    fi
    rm -f "\$PID_FILE"
    if [ -n "\$START_CMD_PREFIX" ]; then
        nohup \$START_CMD_PREFIX "\$HIHY_PATH/bin/appS" --log-level info -c "\$HIHY_PATH/conf/config.yaml" server >"\$LOG_FILE" 2>&1 &
    else
        nohup "\$HIHY_PATH/bin/appS" --log-level info -c "\$HIHY_PATH/conf/config.yaml" server >"\$LOG_FILE" 2>&1 &
    fi
    echo \$! >"\$PID_FILE"
}

stop() {
    [ -f "\$PID_FILE" ] || return 0
    pid=\$(cat "\$PID_FILE")
    if kill -0 "\$pid" 2>/dev/null; then
        kill "\$pid"
    fi
    rm -f "\$PID_FILE"
}

status() {
    if [ -f "\$PID_FILE" ] && kill -0 "\$(cat "\$PID_FILE")" 2>/dev/null; then
        echo "hihy is running"
        return 0
    fi
    echo "hihy is not running"
    return 3
}

case "\$1" in
    start) start ;;
    stop) stop ;;
    restart) stop; sleep 2; start ;;
    status) status ;;
    log) tail -f "\$LOG_FILE" ;;
    *) echo "Usage: \$0 {start|stop|restart|status|log}"; exit 1 ;;
esac
EOF
    chmod 755 "$HIHY_LEGACY_SERVICE"
    if [ -d "$(dirname "$HIHY_INIT_SERVICE")" ]; then
        ln -sf "$HIHY_LEGACY_SERVICE" "$HIHY_INIT_SERVICE"
    fi
    if [ ! -f "$HIHY_RC_LOCAL" ]; then
        printf '#!/bin/bash\n' >"$HIHY_RC_LOCAL"
        chmod 755 "$HIHY_RC_LOCAL"
    fi
    if ! grep -qF "$HIHY_LEGACY_SERVICE start" "$HIHY_RC_LOCAL"; then
        printf '%s start\n' "$HIHY_LEGACY_SERVICE" >>"$HIHY_RC_LOCAL"
    fi
}

installHihyService() {
    local manager
    local service_log="$HIHY_ROOT_DIR/result/service-install.log"
    manager=$(detectServiceManager)
    ensureHihyDirectories || return 1
    : >"$service_log"
    chmod 600 "$service_log"

    case "$manager" in
        systemd)
            if ! writeSystemdService; then
                echoColor red "systemd unit 文件生成失败。"
                return 1
            fi
            if ! systemctl daemon-reload >>"$service_log" 2>&1; then
                echoColor red "systemd daemon-reload 失败。"
                tail -n 30 "$service_log"
                return 1
            fi
            if ! systemctl enable hihy.service >>"$service_log" 2>&1; then
                echoColor red "hihy.service 启用失败。"
                tail -n 30 "$service_log"
                return 1
            fi
            if systemctl restart hihy.service >>"$service_log" 2>&1 && systemctl is-active --quiet hihy.service; then
                rm -f "$service_log"
                return 0
            fi

            if grep -q '^ExecStart=.*/chrt ' "$HIHY_SERVICE_FILE"; then
                echoColor yellow "实时调度启动失败，正在移除 chrt 优先级并重试。"
                systemctl stop hihy.service >>"$service_log" 2>&1 || true
                if HIHY_DISABLE_CHRT=true writeSystemdService && \
                    systemctl daemon-reload >>"$service_log" 2>&1 && \
                    systemctl restart hihy.service >>"$service_log" 2>&1 && \
                    systemctl is-active --quiet hihy.service; then
                    echoColor green "已使用普通调度模式启动 hihy.service。"
                    rm -f "$service_log"
                    return 0
                fi
            fi

            systemctl status hihy.service --no-pager -l >>"$service_log" 2>&1 || true
            journalctl -u hihy.service -n 30 --no-pager >>"$service_log" 2>&1 || true
            echoColor red "hihy.service 启动失败，详细日志如下："
            tail -n 40 "$service_log"
            echoColor yellow "完整日志: $service_log"
            return 1
            ;;
        openrc)
            writeOpenRcService || return 1
            rc-update add hihy default >>"$service_log" 2>&1 || return 1
            rc-service hihy restart >>"$service_log" 2>&1 || rc-service hihy start >>"$service_log" 2>&1 || return 1
            ;;
        *)
            writeLegacyService || return 1
            "$HIHY_LEGACY_SERVICE" restart >>"$service_log" 2>&1 || return 1
            ;;
    esac
    rm -f "$service_log"
}

serviceStart() {
    if [ -f "$HIHY_SERVICE_FILE" ] && [ "$(detectServiceManager)" = "systemd" ]; then
        if systemctl start hihy.service && systemctl is-active --quiet hihy.service; then
            return 0
        fi
        if grep -q '^ExecStart=.*/chrt ' "$HIHY_SERVICE_FILE"; then
            echoColor yellow "实时调度启动失败，正在改用普通调度模式。"
            systemctl stop hihy.service >/dev/null 2>&1 || true
            HIHY_DISABLE_CHRT=true writeSystemdService && systemctl daemon-reload && \
                systemctl start hihy.service && systemctl is-active --quiet hihy.service
        else
            return 1
        fi
    elif [ -f "$HIHY_INIT_SERVICE" ] && [ "$(detectServiceManager)" = "openrc" ]; then
        rc-service hihy start
    else
        "$HIHY_LEGACY_SERVICE" start
    fi
}

serviceStop() {
    if [ -f "$HIHY_SERVICE_FILE" ] && [ "$(detectServiceManager)" = "systemd" ]; then
        systemctl stop hihy.service
    elif [ -f "$HIHY_INIT_SERVICE" ] && [ "$(detectServiceManager)" = "openrc" ]; then
        rc-service hihy stop
    else
        "$HIHY_LEGACY_SERVICE" stop
    fi
}

serviceRestart() {
    if [ -f "$HIHY_SERVICE_FILE" ] && [ "$(detectServiceManager)" = "systemd" ]; then
        if systemctl restart hihy.service && systemctl is-active --quiet hihy.service; then
            return 0
        fi
        if grep -q '^ExecStart=.*/chrt ' "$HIHY_SERVICE_FILE"; then
            echoColor yellow "实时调度启动失败，正在改用普通调度模式。"
            systemctl stop hihy.service >/dev/null 2>&1 || true
            HIHY_DISABLE_CHRT=true writeSystemdService && systemctl daemon-reload && \
                systemctl restart hihy.service && systemctl is-active --quiet hihy.service
        else
            return 1
        fi
    elif [ -f "$HIHY_INIT_SERVICE" ] && [ "$(detectServiceManager)" = "openrc" ]; then
        rc-service hihy restart
    else
        "$HIHY_LEGACY_SERVICE" restart
    fi
}

serviceIsActive() {
    if [ -f "$HIHY_SERVICE_FILE" ] && [ "$(detectServiceManager)" = "systemd" ]; then
        systemctl is-active --quiet hihy.service
    elif [ -f "$HIHY_INIT_SERVICE" ] && [ "$(detectServiceManager)" = "openrc" ]; then
        rc-service hihy status >/dev/null 2>&1
    else
        local pid
        pid=$(getHihyServicePID) || return 1
        hihyProcessAlive "$pid"
    fi
}

migrateLegacyService() {
    local was_running="false"
    local backup_dir
    local had_init_service="false"
    local migration_log="$HIHY_ROOT_DIR/result/service-migration.log"

    [ "$(detectServiceManager)" = "systemd" ] || return 1
    ensureHihyDirectories || return 1
    : >"$migration_log"
    chmod 600 "$migration_log"
    if isNativeHihySystemdService; then
        systemctl enable hihy.service >/dev/null 2>&1 || true
        if [ -f "$HIHY_RC_LOCAL" ]; then
            sed -i "\|${HIHY_LEGACY_SERVICE} start|d" "$HIHY_RC_LOCAL"
        fi
        return 0
    fi
    [ -f "$HIHY_LEGACY_SERVICE" ] || return 0

    "$HIHY_LEGACY_SERVICE" status >/dev/null 2>&1 && was_running="true"
    backup_dir=$(mktemp -d "$HIHY_ROOT_DIR/result/service-migration.XXXXXX") || return 1
    cp -a "$HIHY_LEGACY_SERVICE" "$backup_dir/hihy.legacy" || return 1
    [ -f "$HIHY_RC_LOCAL" ] && cp -a "$HIHY_RC_LOCAL" "$backup_dir/rc.local"
    if [ -e "$HIHY_INIT_SERVICE" ] || [ -L "$HIHY_INIT_SERVICE" ]; then
        cp -a "$HIHY_INIT_SERVICE" "$backup_dir/hihy.init" || return 1
        rm -f "$HIHY_INIT_SERVICE"
        had_init_service="true"
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi

    if ! writeSystemdService; then
        echoColor red "systemd unit 文件生成失败。"
        rm -f "$HIHY_SERVICE_FILE"
        [ "$had_init_service" = "true" ] && cp -a "$backup_dir/hihy.init" "$HIHY_INIT_SERVICE"
        systemctl daemon-reload >/dev/null 2>&1 || true
        return 1
    fi
    if ! systemctl daemon-reload >>"$migration_log" 2>&1; then
        echoColor red "systemd daemon-reload 失败。"
        tail -n 20 "$migration_log"
        rm -f "$HIHY_SERVICE_FILE"
        [ "$had_init_service" = "true" ] && cp -a "$backup_dir/hihy.init" "$HIHY_INIT_SERVICE"
        systemctl daemon-reload >/dev/null 2>&1 || true
        return 1
    fi
    if ! systemctl enable hihy.service >>"$migration_log" 2>&1; then
        echoColor red "systemd unit 启用失败。"
        tail -n 20 "$migration_log"
        rm -f "$HIHY_SERVICE_FILE"
        [ "$had_init_service" = "true" ] && cp -a "$backup_dir/hihy.init" "$HIHY_INIT_SERVICE"
        systemctl daemon-reload >/dev/null 2>&1 || true
        return 1
    fi

    "$HIHY_LEGACY_SERVICE" stop >/dev/null 2>&1 || true
    if ! systemctl start hihy.service >>"$migration_log" 2>&1 || ! systemctl is-active --quiet hihy.service; then
        echoColor red "原生 hihy.service 启动失败，正在恢复旧启动方式。"
        systemctl status hihy.service --no-pager >>"$migration_log" 2>&1 || true
        tail -n 30 "$migration_log"
        systemctl disable --now hihy.service >/dev/null 2>&1 || true
        rm -f "$HIHY_SERVICE_FILE"
        systemctl daemon-reload >/dev/null 2>&1 || true
        cp -a "$backup_dir/hihy.legacy" "$HIHY_LEGACY_SERVICE"
        [ "$had_init_service" = "true" ] && cp -a "$backup_dir/hihy.init" "$HIHY_INIT_SERVICE"
        [ -f "$backup_dir/rc.local" ] && cp -a "$backup_dir/rc.local" "$HIHY_RC_LOCAL"
        systemctl daemon-reload >/dev/null 2>&1 || true
        [ "$was_running" = "true" ] && "$HIHY_LEGACY_SERVICE" start >/dev/null 2>&1
        return 1
    fi

    if [ -f "$HIHY_RC_LOCAL" ]; then
        sed -i "\|${HIHY_LEGACY_SERVICE} start|d" "$HIHY_RC_LOCAL"
    fi
    rm -f "$HIHY_INIT_SERVICE"
    cat >"$HIHY_LEGACY_SERVICE" <<EOF
#!/bin/sh
case "\$1" in
    start|stop|restart|status) systemctl "\$1" hihy.service ;;
    log) journalctl -u hihy.service -f ;;
    *) echo "Usage: \$0 {start|stop|restart|status|log}"; exit 1 ;;
esac
EOF
    chmod 755 "$HIHY_LEGACY_SERVICE"
    printf 'manager=systemd\nmigrated_at=%s\nbackup_dir=%s\n' "$(date +%s)" "$backup_dir" >"$HIHY_MIGRATION_STATE_FILE"
    chmod 600 "$HIHY_MIGRATION_STATE_FILE"
    rm -f "$migration_log"
}

promptLegacyServiceMigration() {
    [ "$(detectServiceManager)" = "systemd" ] || return 0
    isNativeHihySystemdService && return 0
    [ -f "$HIHY_LEGACY_SERVICE" ] || return 0
    [ -f "$HIHY_ROOT_DIR/result/service-migration.dismissed" ] && return 0

    echoColor yellow "检测到旧版 rc.local/SysV 启动方式，建议迁移到原生 systemd。"
    echoColor yellow "迁移会先验证新服务，失败时自动恢复旧启动方式。"
    echoColor yellow "1) 现在迁移  2) 暂不迁移  3) 不再提示"
    read -r migration_choice
    case "$migration_choice" in
        1)
            if migrateLegacyService; then
                echoColor green "已迁移到原生 systemd。"
            else
                echoColor red "迁移失败，已保留或恢复旧启动方式。"
            fi
            ;;
        3)
            ensureHihyDirectories
            touch "$HIHY_ROOT_DIR/result/service-migration.dismissed"
            chmod 600 "$HIHY_ROOT_DIR/result/service-migration.dismissed"
            ;;
    esac
}

installCronTask() {
    local temp_file
    command -v crontab >/dev/null 2>&1 || return 1
    temp_file=$(mktemp) || return 1
    crontab -l 2>/dev/null >"$temp_file" || true
    sed -i '/# hihy-managed: weekly-log-truncate/d;/[[:space:]]hihy cronTask[[:space:]]*$/d;/\/usr\/bin\/hihy cronTask[[:space:]]*$/d' "$temp_file"
    if [ "$(detectServiceManager)" != "systemd" ]; then
        printf '%s\n' '# hihy-managed: weekly-log-truncate' >>"$temp_file"
        printf '%s\n' '15 4 * * 1 /usr/bin/hihy cronTask' >>"$temp_file"
    fi
    crontab "$temp_file"
    local result=$?
    rm -f "$temp_file"
    return "$result"
}

removeCronTask() {
    local temp_file
    command -v crontab >/dev/null 2>&1 || return 0
    temp_file=$(mktemp) || return 1
    crontab -l 2>/dev/null >"$temp_file" || true
    sed -i '/# hihy-managed: weekly-log-truncate/d;/[[:space:]]hihy cronTask[[:space:]]*$/d;/\/usr\/bin\/hihy cronTask[[:space:]]*$/d' "$temp_file"
    crontab "$temp_file"
    local result=$?
    rm -f "$temp_file"
    return "$result"
}

detectFirewallBackend() {
    if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
        echo "firewalld"
    elif command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q '^Status: active'; then
        echo "ufw"
    elif command -v nft >/dev/null 2>&1 && nft list ruleset >/dev/null 2>&1; then
        echo "nft"
    elif command -v iptables >/dev/null 2>&1; then
        echo "iptables"
    else
        echo "none"
    fi
}

recordOwnedFirewallRule() {
    local backend="$1"
    local protocol="$2"
    local port="$3"
    ensureHihyDirectories || return 1
    touch "$HIHY_FIREWALL_STATE_FILE"
    chmod 600 "$HIHY_FIREWALL_STATE_FILE"
    if ! grep -qxF "backend=${backend}|protocol=${protocol}|port=${port}" "$HIHY_FIREWALL_STATE_FILE"; then
        printf 'backend=%s|protocol=%s|port=%s\n' "$backend" "$protocol" "$port" >>"$HIHY_FIREWALL_STATE_FILE"
    fi
}

nftOwnedTableExists() {
    nft list table inet hihy_firewall >/dev/null 2>&1
}

nftOwnedTableIsManaged() {
    nft list table inet hihy_firewall 2>/dev/null | grep -q 'comment "hihy-owned:v1"'
}

writeNftOwnedRuleset() {
    local line backend protocol port nft_port temp_file check_file
    ensureHihyDirectories || return 1
    temp_file=$(mktemp "$HIHY_NFT_RULESET_FILE.tmp.XXXXXX") || return 1
    cat >"$temp_file" <<'EOF'
table inet hihy_firewall {
    comment "hihy-owned:v1"
    chain hihy_input {
        type filter hook input priority -10; policy accept;
EOF
    if [ -f "$HIHY_FIREWALL_STATE_FILE" ]; then
        while IFS= read -r line; do
            backend=$(printf '%s' "$line" | cut -d'|' -f1 | cut -d= -f2)
            protocol=$(printf '%s' "$line" | cut -d'|' -f2 | cut -d= -f2)
            port=$(printf '%s' "$line" | cut -d'|' -f3 | cut -d= -f2)
            [ "$backend" = "nft" ] || continue
            validate_protocol "$protocol" || continue
            if [[ "$port" == *:* ]]; then
                validate_port_range "${port%%:*}" "${port##*:}" || continue
                nft_port="${port/:/-}"
            else
                validate_port "$port" || continue
                nft_port="$port"
            fi
            printf '        %s dport %s accept comment "hihy-owned:%s:%s"\n' \
                "$protocol" "$nft_port" "$protocol" "$port" >>"$temp_file"
        done <"$HIHY_FIREWALL_STATE_FILE"
    fi
    cat >>"$temp_file" <<'EOF'
    }
}
EOF
    chmod 600 "$temp_file"
    if nftOwnedTableExists; then
        check_file=$(mktemp "$HIHY_NFT_RULESET_FILE.check.XXXXXX") || { rm -f "$temp_file"; return 1; }
        printf 'delete table inet hihy_firewall\n' >"$check_file"
        cat "$temp_file" >>"$check_file"
        nft -c -f "$check_file" >/dev/null 2>&1 || { rm -f "$temp_file" "$check_file"; return 1; }
        rm -f "$check_file"
    else
        nft -c -f "$temp_file" >/dev/null 2>&1 || { rm -f "$temp_file"; return 1; }
    fi
    mv -f "$temp_file" "$HIHY_NFT_RULESET_FILE"
}

writeNftFirewallBatch() {
    local batch="$1" mode="${2:-apply}" snapshot table_name commands
    local backend protocol port match_port
    snapshot=$(nft -j list ruleset) || return 1
    table_name=$(printf '%s' "$snapshot" | yq -p=json -r '
        .nftables[] | select(has("table")) | .table |
        select(.family == "inet" and .name == "hihy_firewall") | .name') || return 1
    # JSON preserves table/chain names without interpolating them into nft syntax.
    printf '%s\n' '{"nftables":[]}' >"$batch" || return 1
    if [ -n "$table_name" ]; then
        # Older nft JSON versions omit table comments; accept the legacy text marker too.
        if nftOwnedTableIsManaged; then
            yq -p=json -o=json -i '.nftables += [{"delete": {"table": {"family": "inet", "name": "hihy_firewall"}}}]' "$batch" || return 1
        elif [ "$mode" = apply ]; then
            echoColor red "检测到同名但不属于 Hi_Hysteria 的 nftables 表，拒绝修改。"
            return 1
        else
            echoColor yellow "保留同名但不属于 Hi_Hysteria 的 nftables 表。"
        fi
    fi
    # Handles change after reload. Discover only our tagged rules from the live ruleset.
    commands=$(printf '%s' "$snapshot" | yq -p=json -o=json -I=0 '[
        .nftables[] | select(has("rule")) | .rule |
        select(.family == "inet" or .family == "ip" or .family == "ip6") |
        select(.family != "inet" or .table != "hihy_firewall") |
        select((.comment // "") | test("^hihy-owned:input:v1:(tcp|udp):[0-9]+(:[0-9]+)?$")) |
        {"delete": {"rule": {"family": .family, "table": .table, "chain": .chain, "handle": .handle}}}
        ]') || return 1
    HIHY_NFT_COMMANDS="$commands" yq -p=json -o=json -i '.nftables += env(HIHY_NFT_COMMANDS)' "$batch" || return 1
    [ "$mode" = apply ] || return 0
    yq -p=json -o=json -i '.nftables += [
        {"add": {"table": {"family": "inet", "name": "hihy_firewall"}}},
        {"add": {"chain": {"family": "inet", "table": "hihy_firewall", "name": "hihy_input",
            "type": "filter", "hook": "input", "prio": -10, "policy": "accept"}}},
        {"add": {"rule": {"family": "inet", "table": "hihy_firewall", "chain": "hihy_input",
            "expr": [{"counter": null}], "comment": "hihy-owned:v1"}}}
        ]' "$batch" || return 1
    # An accept in our own base chain cannot override drops in later base chains.
    # Insert the requested ports at the start of every existing INPUT filter chain.
    [ -f "$HIHY_FIREWALL_STATE_FILE" ] || return 0
    while IFS='|' read -r backend protocol port; do
        [ "$backend" = backend=nft ] || continue
        protocol=${protocol#protocol=}
        port=${port#port=}
        validate_protocol "$protocol" || return 1
        if [[ "$port" == *:* ]]; then
            validate_port_range "${port%%:*}" "${port##*:}" || return 1
            match_port="{\"range\": [${port%%:*}, ${port##*:}]}"
        else
            validate_port "$port" || return 1
            match_port="$port"
        fi
        commands=$(printf '%s' "$snapshot" |
            HIHY_NFT_PROTOCOL="$protocol" HIHY_NFT_PORT="$match_port" HIHY_NFT_PORT_LABEL="$port" \
            yq -p=json -o=json -I=0 '
            [{"match": {"op": "==", "left": {"payload": {"protocol": strenv(HIHY_NFT_PROTOCOL), "field": "dport"}},
                "right": env(HIHY_NFT_PORT)}}, {"accept": null}] as $expr |
            [.nftables[] | select(has("chain")) | .chain |
                select(.family == "inet" or .family == "ip" or .family == "ip6") |
                select(.hook == "input" and .type == "filter") |
                select(.family != "inet" or .table != "hihy_firewall") |
                {"insert": {"rule": {"family": .family, "table": .table, "chain": .name, "expr": $expr,
                    "comment": "hihy-owned:input:v1:" + strenv(HIHY_NFT_PROTOCOL) + ":" + strenv(HIHY_NFT_PORT_LABEL)}}}
            ] + [{"add": {"rule": {"family": "inet", "table": "hihy_firewall", "chain": "hihy_input", "expr": $expr,
                "comment": "hihy-owned:" + strenv(HIHY_NFT_PROTOCOL) + ":" + strenv(HIHY_NFT_PORT_LABEL)}}}]') || return 1
        HIHY_NFT_COMMANDS="$commands" yq -p=json -o=json -i '.nftables += env(HIHY_NFT_COMMANDS)' "$batch" || return 1
    done <"$HIHY_FIREWALL_STATE_FILE"
}

restoreNftOwnedFirewall() (
    local mode="${1:-apply}" batch
    ensureHihyDirectories || return 1
    batch=$(mktemp "$HIHY_NFT_DIR/apply.XXXXXX") || return 1
    trap 'rm -f "$batch"' EXIT
    if [ "$mode" = apply ]; then
        writeNftOwnedRuleset || return 1
    fi
    writeNftFirewallBatch "$batch" "$mode" || return 1
    # Deletion of old rules and insertion of new rules form one atomic transaction.
    nft -j -c -f "$batch" && nft -j -f "$batch"
)

writeNftLoader() {
    # Re-discover chains and rule handles on boot instead of persisting stale handles.
    {
        printf '#!/bin/bash\n'
        printf 'export HIHY_ROOT_DIR=%q HIHY_FIREWALL_STATE_FILE=%q HIHY_NFT_DIR=%q HIHY_NFT_RULESET_FILE=%q\n' \
            "$HIHY_ROOT_DIR" "$HIHY_FIREWALL_STATE_FILE" "$HIHY_NFT_DIR" "$HIHY_NFT_RULESET_FILE"
        printf 'exec %q firewall-restore\n' "$HIHY_BIN_LINK"
    } >"$HIHY_NFT_LOADER" || return 1
    chmod 700 "$HIHY_NFT_LOADER"
}

installNftPersistence() {
    writeNftLoader || return 1
    case "$(detectServiceManager)" in
        systemd)
            cat >"$HIHY_NFT_SERVICE_FILE" <<EOF
[Unit]
Description=Hi_Hysteria-owned nftables rules
Documentation=${HIHY_REPO_URL}
After=nftables.service
Before=hihy.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=${HIHY_NFT_LOADER}

[Install]
WantedBy=multi-user.target
EOF
            chmod 644 "$HIHY_NFT_SERVICE_FILE"
            systemctl daemon-reload >/dev/null 2>&1 || return 1
            systemctl enable hihy-firewall.service >/dev/null 2>&1 || return 1
            ;;
        openrc)
            cat >"${HIHY_INIT_SERVICE}-firewall" <<EOF
#!/sbin/openrc-run
name="hihy-firewall"
description="Hi_Hysteria-owned nftables rules"
command="${HIHY_NFT_LOADER}"
command_background="no"
depend() {
    need localmount
    after nftables
    before hihy
}
EOF
            chmod 755 "${HIHY_INIT_SERVICE}-firewall"
            rc-update add hihy-firewall default >/dev/null 2>&1 || return 1
            ;;
        *)
            if [ ! -f "$HIHY_RC_LOCAL" ]; then
                printf '#!/bin/bash\n' >"$HIHY_RC_LOCAL"
                chmod 755 "$HIHY_RC_LOCAL"
            fi
            sed -i "\|${HIHY_NFT_LOADER}|d" "$HIHY_RC_LOCAL"
            if grep -qF "$HIHY_LEGACY_SERVICE start" "$HIHY_RC_LOCAL"; then
                sed -i "\|${HIHY_LEGACY_SERVICE} start|i ${HIHY_NFT_LOADER}" "$HIHY_RC_LOCAL"
            else
                printf '%s\n' "$HIHY_NFT_LOADER" >>"$HIHY_RC_LOCAL"
            fi
            ;;
    esac
}

applyNftOwnedRuleset() {
    if nftOwnedTableExists && ! nftOwnedTableIsManaged; then
        echoColor red "检测到同名但不属于 Hi_Hysteria 的 nftables 表，拒绝修改。"
        return 1
    fi
    installNftPersistence || return 1
    restoreNftOwnedFirewall
}

removeNftOwnedFirewall() {
    if command -v nft >/dev/null 2>&1; then
        # Keep persistence and ownership metadata available if cleanup fails.
        restoreNftOwnedFirewall remove || return 1
    fi
    if command -v systemctl >/dev/null 2>&1; then
        systemctl disable hihy-firewall.service >/dev/null 2>&1 || true
        rm -f "$HIHY_NFT_SERVICE_FILE"
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
    if command -v rc-update >/dev/null 2>&1; then
        rc-update del hihy-firewall default >/dev/null 2>&1 || true
    fi
    rm -f "${HIHY_INIT_SERVICE}-firewall"
    if [ -f "$HIHY_RC_LOCAL" ]; then
        sed -i "\|${HIHY_NFT_LOADER}|d" "$HIHY_RC_LOCAL"
    fi
    rm -f "$HIHY_NFT_RULESET_FILE" "$HIHY_NFT_LOADER"
    return 0
}

firewallRuleExists() {
    local backend="$1"
    local protocol="$2"
    local port="$3"
    local zone

    case "$backend" in
        ufw) ufw status | grep -Eq "(^|[[:space:]])${port}/${protocol}([[:space:]]|$)" ;;
        firewalld)
            zone=$(firewall-cmd --get-default-zone)
            firewall-cmd --zone="$zone" --query-port="${port/:/-}/${protocol}" --permanent >/dev/null 2>&1
            ;;
        nft) grep -qxF "backend=nft|protocol=${protocol}|port=${port}" "$HIHY_FIREWALL_STATE_FILE" 2>/dev/null ;;
        iptables) iptables -w 5 -C INPUT -p "$protocol" --dport "$port" -m comment --comment "hihy-owned:${protocol}:${port}" -j ACCEPT >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

allowPort() {
    local protocol="$1"
    local port="$2"
    local backend
    local zone

    validate_protocol "$protocol" || return 1
    if [[ "$port" == *:* ]]; then
        validate_port_range "${port%%:*}" "${port##*:}" || return 1
    else
        validate_port "$port" || return 1
    fi

    backend="${3:-$(detectFirewallBackend)}"
    case "$backend" in ufw | firewalld | iptables | nft | none) ;; *) return 1 ;; esac
    if [ "$backend" = "none" ]; then
        echoColor yellow "未检测到活动防火墙，请在云安全组中开放 ${port}/${protocol}。"
        return 0
    fi

    if firewallRuleExists "$backend" "$protocol" "$port"; then
        if [ "$backend" = nft ]; then
            applyNftOwnedRuleset || return 1
            echoColor purple "已重新应用脚本管理的防火墙规则: ${port}/${protocol}"
            return 0
        fi
        echoColor purple "防火墙规则已存在，不会在卸载时删除: ${port}/${protocol}"
        return 0
    fi

    case "$backend" in
        ufw) ufw allow "${port}/${protocol}" >/dev/null || return 1 ;;
        firewalld)
            zone=$(firewall-cmd --get-default-zone)
            firewall-cmd --zone="$zone" --add-port="${port/:/-}/${protocol}" --permanent >/dev/null || return 1
            firewall-cmd --reload >/dev/null || return 1
            ;;
        iptables)
            iptables -w 5 -I INPUT -p "$protocol" --dport "$port" -m comment --comment "hihy-owned:${protocol}:${port}" -j ACCEPT || return 1
            command -v netfilter-persistent >/dev/null 2>&1 && netfilter-persistent save >/dev/null 2>&1 || true
            ;;
        nft)
            recordOwnedFirewallRule "$backend" "$protocol" "$port" || return 1
            if ! applyNftOwnedRuleset; then
                sed -i "/^backend=nft|protocol=${protocol}|port=${port}$/d" "$HIHY_FIREWALL_STATE_FILE"
                writeNftOwnedRuleset >/dev/null 2>&1 || true
                echoColor red "nftables 自动放行失败。"
                return 1
            fi
            echoColor purple "已自动开放: ${port}/${protocol} (${backend})"
            return 0
            ;;
    esac
    recordOwnedFirewallRule "$backend" "$protocol" "$port"
    echoColor purple "已自动开放: ${port}/${protocol} (${backend})"
}

removeOwnedFirewallRules() {
    local line backend protocol port zone has_nft="false" has_firewalld=false result=0
    if [ ! -f "$HIHY_FIREWALL_STATE_FILE" ]; then
        removeNftOwnedFirewall
        return $?
    fi

    while IFS= read -r line; do
        backend=$(printf '%s' "$line" | cut -d'|' -f1 | cut -d= -f2)
        protocol=$(printf '%s' "$line" | cut -d'|' -f2 | cut -d= -f2)
        port=$(printf '%s' "$line" | cut -d'|' -f3 | cut -d= -f2)
        validate_protocol "$protocol" || continue
        case "$backend" in
            ufw) ufw delete allow "${port}/${protocol}" >/dev/null 2>&1 || result=1 ;;
            firewalld)
                has_firewalld=true
                zone=$(firewall-cmd --get-default-zone 2>/dev/null || echo public)
                firewall-cmd --zone="$zone" --remove-port="${port/:/-}/${protocol}" --permanent >/dev/null 2>&1 || result=1
                ;;
            iptables)
                while iptables -w 5 -C INPUT -p "$protocol" --dport "$port" -m comment --comment "hihy-owned:${protocol}:${port}" -j ACCEPT >/dev/null 2>&1; do
                    iptables -w 5 -D INPUT -p "$protocol" --dport "$port" -m comment --comment "hihy-owned:${protocol}:${port}" -j ACCEPT || { result=1; break; }
                done
                ;;
            nft) has_nft="true" ;;
        esac
    done <"$HIHY_FIREWALL_STATE_FILE"
    if [ "$has_firewalld" = true ]; then
        firewall-cmd --reload >/dev/null 2>&1 || result=1
    fi
    command -v netfilter-persistent >/dev/null 2>&1 && netfilter-persistent save >/dev/null 2>&1 || true
    if [ "$has_nft" = "true" ] || nftOwnedTableExists || [ -f "$HIHY_NFT_RULESET_FILE" ] || [ -f "$HIHY_NFT_SERVICE_FILE" ]; then
        removeNftOwnedFirewall || result=1
    fi
    if [ "$result" = 0 ]; then
        rm -f "$HIHY_FIREWALL_STATE_FILE" || result=1
    fi
    return "$result"
}

explainOfficialPortHopping() {
    echoColor purple "Hysteria 2 官方端口跳跃原理:"
    echoColor yellow "- 客户端定期在端口范围内随机切换 UDP 端口。"
    echoColor yellow "- 服务端使用 listen 范围，由 Hysteria 自动创建 nftables/iptables 重定向规则。"
    echoColor yellow "- Hysteria 停止时会自动清理其重定向规则。"
    echoColor yellow "- 本脚本只负责开放本机防火墙端口范围，不清空或覆盖系统规则。"
    echoColor yellow "- 云厂商安全组仍需单独开放相同 UDP 范围。"
}

verifyOfficialPortHopping() {
    local start_port="$1"
    local end_port="$2"
    if command -v nft >/dev/null 2>&1 && nft list ruleset 2>/dev/null | grep -Eq "udp dport ${start_port}-${end_port}"; then
        return 0
    fi
    if command -v iptables-save >/dev/null 2>&1 && iptables-save -t nat 2>/dev/null | grep -Eq -- "--dports? ${start_port}:${end_port}|--dport ${start_port}:${end_port}"; then
        return 0
    fi
    return 1
}

uninstall_rc_local_for_arch() {
    # 检测是否为 Arch Linux
    if grep -q "Arch Linux" /etc/os-release; then
        echo "Detected Arch Linux. Uninstalling rc.local systemd service..."

        # 停止并禁用 rc-local 服务
        systemctl stop rc-local
        systemctl disable rc-local

        # 删除 /etc/systemd/system/rc-local.service 文件
        rm /etc/systemd/system/rc-local.service

        # 重新加载 systemd 配置
        systemctl daemon-reload

        echo "rc.local systemd service has been uninstalled."
    fi
}

install() {
    local install_state
    install_state=$(classifyInstallState)

    if [ "$install_state" = "installed" ]; then
        echoColor green "你已经成功安装hysteria,如需修改配置请使用选项9/12"
        exit 0
    fi

    if [ "$install_state" = "partially-installed" ]; then
        echoColor yellow "检测到未完成的安装残留，正在清理脚本管理的文件后继续安装..."
        cleanupLegacyPortHoppingNatIfPresent >/dev/null 2>&1 || true
        delHihyFirewallPort udp >/dev/null 2>&1 || true
        delHihyFirewallPort tcp >/dev/null 2>&1 || true
        recoverPartialInstallState
        echoColor purple "已完成部分安装状态恢复，继续执行安装。"
    fi

    # 创建必要目录
    ensureHihyDirectories
    markInstallFailed "install-start" "installation started but not completed"
    echoColor purple "Ready to install.\n"

    # 获取版本并下载核心
    checkSystemForUpdate || return 1
    downloadHysteriaCore || return 1
    setHysteriaConfig || return 1

    if ! installHihyService; then
        markInstallFailed "service" "failed to install or start service"
        echoColor red "服务安装或启动失败。"
        return 1
    fi

    if [ "${portHoppingStatus}" = "true" ]; then
        if verifyOfficialPortHopping "$portHoppingStart" "$portHoppingEnd"; then
            echoColor green "已检测到 Hysteria 官方端口范围重定向规则。"
        else
            echoColor yellow "服务已启动，但暂未检测到官方端口范围重定向规则。请检查 nft/iptables、服务日志和云安全组。"
        fi
    fi

    installCronTask || echoColor yellow "定时日志清理任务安装失败，可稍后重试。"

    generate_client_config
    secureHihyPermissions
    clearInstallFailureMarker
    echoColor yellowBlack "安装完毕"
}

# 将 listen 中的范围端口格式 47000-48000 转换为防火墙规则使用的 47000:48000
formatFirewallPortSpec() {
    local port_spec="$1"
    echo "${port_spec//-/:}"
}

# 将防火墙命令输出按空白拆分成独立 token，再进行精确匹配
hasFirewallToken() {
    local token="$1"
    tr -s '[:space:]' '\n' | grep -Fxq "$token"
}

# 输出ufw端口开放状态
checkUFWAllowPort() {
    local port=$1
    if ufw status | hasFirewallToken "$port"; then
        echoColor purple "UFW OPEN: ${port}"
    else
        echoColor red "UFW OPEN FAIL: ${port}"
        exit 1
    fi
}

# 输出firewall-cmd端口开放状态
checkFirewalldAllowPort() {
    local port=$1
    local protocol=$2
    if firewall-cmd --list-ports --permanent | hasFirewallToken "${port}/${protocol}"; then
        echoColor purple "FIREWALLD OPEN: ${port}/${protocol}"
    else
        echoColor red "FIREWALLD OPEN FAIL: ${port}/${protocol}"
        exit 1
    fi
}

legacyAllowPortUnsafe() {
    echoColor red "旧版防火墙实现已禁用，拒绝执行可能覆盖全局规则的操作。"
    return 1
    # 如果防火墙启动状态则添加相应的开放端口
    # $1 tcp/udp
    # $2 port

    # 检查是否为 Alpine Linux
    if [ -f /etc/alpine-release ]; then
        # Alpine 默认使用 iptables
        if command -v iptables >/dev/null 2>&1; then
            if ! iptables -L | grep -q "allow ${1}/${2}(hihysteria)"; then
                iptables -I INPUT -p ${1} --dport ${2} -m comment --comment "allow ${1}/${2}(hihysteria)" -j ACCEPT
                echoColor purple "IPTABLES OPEN: ${1}/${2}"

                # 保存 iptables 规则
                if [ -d /etc/iptables ]; then
                    iptables-save >/etc/iptables/rules.v4
                else
                    mkdir -p /etc/iptables
                    iptables-save >/etc/iptables/rules.v4
                fi
            fi
            return 0
        fi

        # 如果没有 iptables，检查 nftables
        if command -v nft >/dev/null 2>&1; then
            if ! nft list ruleset | grep -q "allow ${1}/${2}(hihysteria)"; then
                nft add rule inet filter input ip protocol ${1} dport ${2} comment "allow ${1}/${2}(hihysteria)" accept
                echoColor purple "NFTABLES OPEN: ${1}/${2}"
                nft list ruleset >/etc/nftables.conf
            fi
            return 0
        fi
    else
        # 其他 Linux 发行版的处理逻辑
        # 检查 systemd
        if command -v systemctl >/dev/null 2>&1; then
            # 检查 netfilter-persistent
            if systemctl is-active --quiet netfilter-persistent; then
                if ! iptables -L | grep -q "allow ${1}/${2}(hihysteria)"; then
                    iptables -I INPUT -p ${1} --dport ${2} -m comment --comment "allow ${1}/${2}(hihysteria)" -j ACCEPT
                    echoColor purple "IPTABLES OPEN: ${1}/${2}"
                    netfilter-persistent save
                fi
                return 0
            fi

            # 检查 firewalld
            if systemctl is-active --quiet firewalld; then
                if ! firewall-cmd --list-ports --permanent | hasFirewallToken "${2}/${1}"; then
                    firewall-cmd --zone=public --add-port=${2}/${1} --permanent
                    echoColor purple "FIREWALLD OPEN: ${1}/${2}"
                    firewall-cmd --reload
                fi
                return 0
            fi
        fi

        # 检查 UFW
        if command -v ufw >/dev/null 2>&1; then
            if ufw status | hasFirewallToken "active"; then
                if ! ufw status | hasFirewallToken "${2}/${1}"; then
                    ufw allow ${2}/${1}
                    checkUFWAllowPort ${2}/${1}
                fi
                return 0
            fi
        fi

        # 检查 iptables
        if command -v iptables >/dev/null 2>&1; then
            if ! iptables -L | grep -q "allow ${1}/${2}(hihysteria)"; then
                iptables -I INPUT -p ${1} --dport ${2} -m comment --comment "allow ${1}/${2}(hihysteria)" -j ACCEPT
                mkdir -p /etc/rc.d
                # 在没有netfilter的情况下持久化规则
                if [ ! -f "/etc/rc.d/allow-port" ]; then
                    cat >/etc/rc.d/allow-port <<EOF
#!/bin/sh
iptables -I INPUT -p ${1} --dport ${2} -m comment --comment "allow ${1}/${2}(hihysteria)" -j ACCEPT
EOF
                    chmod +x /etc/rc.d/allow-port
                else
                    if ! grep -q "allow ${1}/${2}(hihysteria)" /etc/rc.d/allow-port; then
                        echo "iptables -I INPUT -p ${1} --dport ${2} -m comment --comment \"allow ${1}/${2}(hihysteria)\" -j ACCEPT" >>/etc/rc.d/allow-port
                    fi
                fi

                if [ ! -f "/etc/rc.local" ]; then
                    touch /etc/rc.local
                    echo "#!/bin/bash" >/etc/rc.local
                    chmod +x /etc/rc.local
                fi
                if ! grep -q "/etc/rc.d/allow-port" /etc/rc.local; then
                    echo "/etc/rc.d/allow-port start" >>/etc/rc.local
                fi
            fi

            echoColor purple "IPTABLES OPEN: ${1}/${2}"
            return 0
        fi

        # 检查 nftables
        if command -v nft >/dev/null 2>&1; then
            if ! nft list ruleset | grep -q "allow ${1}/${2}(hihysteria)"; then
                nft add rule inet filter input ip protocol ${1} dport ${2} comment "allow ${1}/${2}(hihysteria)" accept
                echoColor purple "NFTABLES OPEN: ${1}/${2}"
                nft list ruleset >/etc/nftables.conf
            fi
            return 0
        fi
    fi

    echoColor red "未检测到支持的防火墙工具，请手动开放端口 ${1}/${2}"
    return 1
}

addPortHoppingNat() {
    echoColor yellow "当前版本使用 Hysteria 官方内置端口范围，不再由脚本手工创建 NAT 规则。"
    explainOfficialPortHopping
    return 1
}

delPortHoppingNat() {
    [ -f /etc/init.d/port-hopping ] && rc-service port-hopping stop >/dev/null 2>&1 || true
    [ -f /etc/init.d/port-hopping ] && rc-update del port-hopping default >/dev/null 2>&1 || true
    rm -f /etc/init.d/port-hopping /etc/rc.d/port-hopping
    if [ -f "$HIHY_RC_LOCAL" ]; then
        sed -i '/\/etc\/rc.d\/port-hopping/d' "$HIHY_RC_LOCAL"
    fi
    echoColor purple "已移除旧版端口跳跃启动脚本；官方运行时规则由 Hysteria 停止时自行清理。"
}

checkRoot() {
    if [ "$(id -u)" -ne 0 ]; then
        echoColor red "Please run this script with root privileges!"
        exit 1
    fi
}

uninstall() {
    local install_state
    install_state=$(classifyInstallState)
    portHoppingStatus=$(getBackupValueOrDefault "/etc/hihy/conf/backup.yaml" "portHoppingStatus" "false")
    if [ "$install_state" = "not-installed" ]; then
        echoColor red "Hysteria 未安装!"
        exit 1
    fi

    if [ "$install_state" = "partially-installed" ]; then
        echoColor yellow "检测到未完成的安装残留，正在按部分安装状态执行卸载清理..."
    fi

    serviceStop >/dev/null 2>&1 || true
    if command -v systemctl >/dev/null 2>&1; then
        systemctl disable --now hihy-cert-renew.timer >/dev/null 2>&1 || true
        rm -f /etc/systemd/system/hihy-cert-renew.timer /etc/systemd/system/hihy-cert-renew.service
    fi
    case "$(detectServiceManager)" in
        systemd)
            systemctl disable hihy.service >/dev/null 2>&1 || true
            rm -f "$HIHY_SERVICE_FILE"
            systemctl daemon-reload >/dev/null 2>&1 || true
            ;;
        openrc) rc-update del hihy default >/dev/null 2>&1 || true ;;
    esac
    rm -f "$HIHY_INIT_SERVICE" "$HIHY_LEGACY_SERVICE"

    removeCronTask || true
    removeOwnedFirewallRules
    delPortHoppingNat

    # 删除相关目录和文件
    rm -rf "$HIHY_ROOT_DIR"
    rm -f "$HIHY_PID_FILE"

    if [ -f "$HIHY_RC_LOCAL" ]; then
        sed -i "\|${HIHY_LEGACY_SERVICE} start|d" "$HIHY_RC_LOCAL"
        if grep -q "/etc/rc.d/allow-port" "$HIHY_RC_LOCAL"; then
            sed -i '/\/etc\/rc.d\/allow-port start/d' "$HIHY_RC_LOCAL"
        fi
    fi

    if [ -f "$HIHY_BIN_LINK" ]; then
        rm "$HIHY_BIN_LINK"
    fi

    # 检测并提示卸载WARP/WireProxy
    if command -v warp >/dev/null 2>&1 && [ -f "/etc/wireguard/warp.conf" ]; then
        echoColor purple "\n->检测到WARP/WireProxy安装"
        echoColor green "是否卸载WARP/WireProxy?"
        echo -e "\033[33m\033[01m1、卸载\n2、保留\033[0m\033[32m\n\n输入序号:\033[0m"
        read -r warpUninstallChoice
        if [ -z "${warpUninstallChoice}" ] || [ "${warpUninstallChoice}" == "1" ]; then
            echoColor purple "\n->正在卸载WARP/WireProxy..."
            warp u || true
            echoColor purple "\n->WARP/WireProxy卸载完成"
        else
            echoColor purple "\n->保留WARP/WireProxy安装"
        fi
    fi
    # 检查是否完全删除
    if [ ! -d "$HIHY_ROOT_DIR" ]; then
        echoColor green "Hysteria 已完全卸载!"
    else
        echoColor red "卸载过程中发生错误，请检查是否有残留文件或进程。"
        exit 1
    fi
}

generate_qr() {
    local url=$1

    # 使用最小合法尺寸 1
    local qr_size=1
    local margin=1
    local level="L" # 使用最低纠错级别以减小大小
    # 生成并显示 QR 码
    # -l L: 使用最低级别的纠错
    # -m margin: 设置边距
    # -s 1: 使用最小合法尺寸
    qrencode -t ANSIUTF8 -o - -l "$level" -m "$margin" -s 1 "${url}"

    if [ $? -eq 0 ]; then
        echoColor green "\nQR code generated successfully."
    else
        echoColor red "\nFailed to generate QR code."
        return 1
    fi
}

generate_client_config() {
    if [ ! -f "$HIHY_CONFIG_FILE" ] || [ ! -x "$HIHY_ROOT_DIR/bin/appS" ]; then
        echoColor red "hysteria2 未安装!"
        exit 1
    fi
    remarks=$(getYamlValue "$HIHY_BACKUP_FILE" "remarks")
    serverAddress=$(getYamlValue "$HIHY_BACKUP_FILE" "serverAddress")
    realmMode=$(getBackupValueOrDefault "$HIHY_BACKUP_FILE" "realmMode" "false")
    if [ "${realmMode}" == "true" ]; then
        realmURI=$(getYamlValue "$HIHY_BACKUP_FILE" "realmURI")
    fi
    listen_value=$(getYamlValue "$HIHY_CONFIG_FILE" "listen")
    port=$(getListenPrimaryPort "${listen_value}")
    auth_secret=$(getYamlValue "$HIHY_CONFIG_FILE" "auth.password")
    tls_sni=$(getYamlValue "$HIHY_BACKUP_FILE" "domain")
    insecure=$(getYamlValue "$HIHY_BACKUP_FILE" "insecure")
    masquerade_tcp=$(getYamlValue "$HIHY_BACKUP_FILE" "masquerade_tcp")
    obfs_type=$(getYamlValue "$HIHY_CONFIG_FILE" "obfs.type")
    if [ "${obfs_type}" == "salamander" ] || [ "${obfs_type}" == "gecko" ]; then
        obfs_status="true"
        obfs_pass=$(getYamlValue "$HIHY_CONFIG_FILE" "obfs.${obfs_type}.password")
    else
        obfs_status="false"
        obfs_type=""
        obfs_pass=""
    fi
    SRW=$(getYamlValue "$HIHY_CONFIG_FILE" "quic.initStreamReceiveWindow")
    CRW=$(getYamlValue "$HIHY_CONFIG_FILE" "quic.initConnReceiveWindow")
    max_CRW=$(getYamlValue "$HIHY_CONFIG_FILE" "quic.maxConnReceiveWindow")
    max_SRW=$(getYamlValue "$HIHY_CONFIG_FILE" "quic.maxStreamReceiveWindow")
    if [ "${SRW}" = "null" ]; then
        SRW=""
    fi
    if [ "${CRW}" = "null" ]; then
        CRW=""
    fi
    if [ "${max_CRW}" = "null" ]; then
        max_CRW=""
    fi
    if [ "${max_SRW}" = "null" ]; then
        max_SRW=""
    fi
    congestion_mode=$(getBackupValueOrDefault "$HIHY_BACKUP_FILE" "congestionMode" "brutal")
    congestion_type=$(getBackupValueOrDefault "$HIHY_BACKUP_FILE" "congestionType" "")
    congestion_bbr_profile=$(getBackupValueOrDefault "$HIHY_BACKUP_FILE" "congestionBbrProfile" "standard")
    download=$(getYamlValue "$HIHY_CONFIG_FILE" "bandwidth.up")
    upload=$(getYamlValue "$HIHY_CONFIG_FILE" "bandwidth.down")
    if [ "${download}" = "null" ]; then
        download=""
    fi
    if [ "${upload}" = "null" ]; then
        upload=""
    fi
    portHoppingStatus=$(getYamlValue "$HIHY_BACKUP_FILE" "portHoppingStatus")
    if [ "${portHoppingStatus}" == "true" ]; then
        portHoppingStart=$(getBackupValueOrDefault "$HIHY_BACKUP_FILE" "portHoppingStart" "${port}")
        portHoppingEnd=$(getBackupValueOrDefault "$HIHY_BACKUP_FILE" "portHoppingEnd" "${port}")
        portHoppingIntervalMode=$(getBackupValueOrDefault "$HIHY_BACKUP_FILE" "portHoppingIntervalMode" "fixed")
        portHoppingHopInterval=$(getBackupValueOrDefault "$HIHY_BACKUP_FILE" "portHoppingHopInterval" "30s")
        portHoppingMinHopInterval=$(getBackupValueOrDefault "$HIHY_BACKUP_FILE" "portHoppingMinHopInterval" "10s")
        portHoppingMaxHopInterval=$(getBackupValueOrDefault "$HIHY_BACKUP_FILE" "portHoppingMaxHopInterval" "30s")
        serverPortRange="${portHoppingStart}-${portHoppingEnd}"
    fi
    safe_remarks=$(sanitizeFileComponent "$remarks")
    client_configfile="./Hy2-${safe_remarks}-v2rayN.yaml"
    if [ -f "${client_configfile}" ]; then
        rm -f "${client_configfile}"
    fi
    touch ${client_configfile}
    chmod 600 "$client_configfile"
    local uri_host native_host
    uri_host=$(formatURIHost "$serverAddress")
    native_host=$(formatURIHost "$serverAddress" native)
    if [ "${realmMode}" == "true" ]; then
        addOrUpdateYaml "$client_configfile" "server" "${realmURI}" "string"
    elif [ "${portHoppingStatus}" == "true" ]; then
        addOrUpdateYaml "$client_configfile" "server" "${native_host}:${port},${serverPortRange}" "string"
    else
        addOrUpdateYaml "$client_configfile" "server" "${native_host}:${port}" "string"
    fi
    addOrUpdateYaml "$client_configfile" "auth" "$auth_secret" "string"
    if [ "${realmMode}" == "true" ]; then
        addOrUpdateYaml "$client_configfile" "realm.stunServers[0]" "stun.chat.bilibili.com:3478"
        addOrUpdateYaml "$client_configfile" "realm.stunServers[1]" "stun.miwifi.com:3478"
        addOrUpdateYaml "$client_configfile" "realm.stunServers[2]" "stun.nextcloud.com:3478"
        addOrUpdateYaml "$client_configfile" "realm.stunServers[3]" "global.stun.twilio.com:3478"
        addOrUpdateYaml "$client_configfile" "realm.stunTimeout" "5s"
        addOrUpdateYaml "$client_configfile" "realm.punchTimeout" "5s"
        addOrUpdateYaml "$client_configfile" "realm.heartbeatInterval" "30s"
        addOrUpdateYaml "$client_configfile" "realm.insecure" "false"
    else
        yq eval 'del(.realm)' -i "$client_configfile"
    fi

    local ech_config=""
    exportClientECH "$HIHY_CONFIG_FILE" "$client_configfile" || return 1
    addOrUpdateYaml "$client_configfile" "tls.sni" "${tls_sni}" "string"
    if [ "${insecure}" == "true" ]; then
        addOrUpdateYaml "$client_configfile" "tls.insecure" "true"
    elif [ "${insecure}" == "false" ]; then
        addOrUpdateYaml "$client_configfile" "tls.insecure" "false"
    fi
    addOrUpdateYaml "$client_configfile" "transport.type" "udp"
    if [ "${portHoppingStatus}" == "true" ]; then
        if [ "${portHoppingIntervalMode}" == "random" ]; then
            addOrUpdateYaml "$client_configfile" "transport.udp.minHopInterval" "${portHoppingMinHopInterval}"
            addOrUpdateYaml "$client_configfile" "transport.udp.maxHopInterval" "${portHoppingMaxHopInterval}"
            yq eval 'del(.transport.udp.hopInterval)' -i "$client_configfile"
        else
            addOrUpdateYaml "$client_configfile" "transport.udp.hopInterval" "${portHoppingHopInterval}"
            yq eval 'del(.transport.udp.minHopInterval, .transport.udp.maxHopInterval)' -i "$client_configfile"
        fi
    fi
    if [ "${obfs_status}" == "true" ]; then
        addOrUpdateYaml "$client_configfile" "obfs.type" "${obfs_type}"
        addOrUpdateYaml "$client_configfile" "obfs.${obfs_type}.password" "${obfs_pass}" "string"
    else
        yq eval 'del(.obfs)' -i "$client_configfile"
    fi
    if [ "${congestion_mode}" != "brutal" ]; then
        addOrUpdateYaml "$client_configfile" "congestion.type" "${congestion_type}"
        if [ "${congestion_type}" == "bbr" ]; then
            addOrUpdateYaml "$client_configfile" "congestion.bbrProfile" "${congestion_bbr_profile}"
        fi
    fi
    if [ "${congestion_mode}" == "brutal" ]; then
        addOrUpdateYaml "$client_configfile" "quic.initStreamReceiveWindow" "${SRW}"
        addOrUpdateYaml "$client_configfile" "quic.initConnReceiveWindow" "${CRW}"
        addOrUpdateYaml "$client_configfile" "quic.maxConnReceiveWindow" "${max_CRW}"
        addOrUpdateYaml "$client_configfile" "quic.maxStreamReceiveWindow" "${max_SRW}"
    else
        yq eval 'del(.quic.initStreamReceiveWindow, .quic.initConnReceiveWindow, .quic.maxConnReceiveWindow, .quic.maxStreamReceiveWindow)' -i "$client_configfile"
    fi
    addOrUpdateYaml "$client_configfile" "quic.keepAlivePeriod" "60s"
    if [ "${congestion_mode}" == "brutal" ]; then
        addOrUpdateYaml "$client_configfile" "bandwidth.down" "${download}"
        addOrUpdateYaml "$client_configfile" "bandwidth.up" "${upload}"
    else
        yq eval 'del(.bandwidth)' -i "$client_configfile"
    fi
    addOrUpdateYaml "$client_configfile" "fastOpen" "true"
    addOrUpdateYaml "$client_configfile" "lazy" "true"
    addOrUpdateYaml "$client_configfile" "socks5.listen" "127.0.0.1:20808"
    if [ "${realmMode}" == "true" ]; then
        url=""
    else
        url_base="hy2://$(encodeURIComponent "$auth_secret")@${uri_host}"

        if [ "${portHoppingStatus}" == "true" ]; then
            url_base="${url_base}:${port}/?mport=${serverPortRange}&"
        else
            url_base="${url_base}:${port}/?"
        fi

        if [ "${insecure}" == "true" ]; then
            url_base="${url_base}insecure=1"
        else
            url_base="${url_base}insecure=0"
        fi

        if [ "${obfs_status}" == "true" ]; then
            url_base="${url_base}&obfs=$(encodeURIComponent "$obfs_type")&obfs-password=$(encodeURIComponent "$obfs_pass")"
        fi
        if [ -n "$ech_config" ]; then
            url_base="${url_base}&ech=$(encodeECHQuery "$ech_config")"
        fi
        url="${url_base}&sni=$(encodeURIComponent "$tls_sni")#$(encodeURIComponent "Hy2-${remarks}")"
    fi
    # 在生成配置前添加分隔线
    echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "📝 生成客户端配置文件..."

    # 美化输出信息
    echo -e "\n✨ 配置信息如下:"
    local localV=$(echo app/$("$HIHY_ROOT_DIR/bin/appS" version | grep Version: | awk '{print $2}' | head -n 1))
    echo -e "\n📌 当前hysteria2 server版本: $(echoColor red ${localV})"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ "${realmMode}" != "true" ]; then
        if [ "${portHoppingStatus}" == "false" ]; then
            echo -e "⚠️  注意: 伪装并未监听tcp端口"
            echo -e "💡 您可能需要$(echoColor red 手动在浏览器添加h3)支持才能访问"
        fi

        if [ "${insecure}" == "true" ]; then
            echo -e "\n⚠️  安全提示:"
            echo -e "🔒 您使用自签证书,如需要验证伪装网站:"
            echo -e "   1. 自行修改浏览器信任证书"
            echo -e "   2. 设置hosts使IP指向该域名"
        fi
        echoColor purple "\n🌐 1、伪装地址: $(echoColor red https://${tls_sni}:${port})"
    fi

    if [ "${realmMode}" == "true" ]; then
        echoColor purple "\n🌐 Realm模式 - 服务器通过P2P打洞连接,无需公网IP和端口"
        echoColor purple "\n🔗 1、牵手地址:"
        echoColor green "  ${realmURI}"
        echo -e "\n"
        echoColor yellow "⚠ 请确保您的客户端支持Hysteria2 Realm模式"
        echoColor yellow "客户端配置中server字段使用上述牵手地址,认证密码为: "$(echoColor red ${auth_secret})
        echo -e "\n"
        echoColor yellow "Realm模式不支持分享链接和ClashMeta配置,请使用原生配置文件"
    else
        if [ -n "$ech_config" ]; then
            echoColor purple "\n🔗 2、支持 ECH 的客户端分享链接（请确认导入后保留 ECH 参数）:\n"
        else
            echoColor purple "\n🔗 2、[v2rayN-Windows/v2rayN-Andriod/nekobox/passwall/Shadowrocket]分享链接:\n"
        fi
        echoColor green "${url}"
        echo -e "\n"
        generate_qr "${url}"
    fi

    if [ "${realmMode}" == "true" ]; then
        echoColor purple "\n📄 2、[推荐] [Nekoray/V2rayN/NekoBoxforAndroid]原生配置文件,更新最快、参数最全、效果最好。文件地址: $(echoColor green ${client_configfile})"
    else
        echoColor purple "\n📄 3、[推荐] [Nekoray/V2rayN/NekoBoxforAndroid]原生配置文件,更新最快、参数最全、效果最好。文件地址: $(echoColor green ${client_configfile})"
    fi
    echoColor purple "客户端使用教程: ${HIHY_REPO_URL}/blob/${HIHY_REPO_BRANCH}/md/client.md"
    echoColor green "↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓COPY↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓"
    cat ${client_configfile}
    echoColor green "↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑COPY↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑"
    if [ -n "$ech_config" ]; then
        echoColor yellow "ECH 已写入原生 YAML 和可用的分享链接；暂不生成 Clash Meta 配置。"
    elif [ "${realmMode}" != "true" ]; then
        generateMetaYaml
    fi

    echo -e "\n✅ 配置生成完成!"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
}

generateMetaYaml() {
    local ech_path
    ech_path=$(getYamlValue "$HIHY_CONFIG_FILE" "ech.keyPath") || return 1
    if [ -n "$ech_path" ] && [ "$ech_path" != null ]; then
        echoColor yellow "ECH 模式请使用原生 Hysteria YAML；暂不导出 Clash Meta 配置。"
        return 1
    fi
    remarks=$(getYamlValue "$HIHY_BACKUP_FILE" "remarks")
    local safe_remarks
    safe_remarks=$(sanitizeFileComponent "$remarks")
    local metaFile="./Hy2-${safe_remarks}-ClashMeta.yaml"
    if [ -f "${metaFile}" ]; then
        rm -f ${metaFile}
    fi
    touch ${metaFile}
    chmod 600 "$metaFile"

    cat <<EOF >${metaFile}
mixed-port: 7890
allow-lan: true
mode: rule
log-level: info
ipv6: true
dns:
  enable: true
  listen: 0.0.0.0:53
  ipv6: true
  default-nameserver:
    - 114.114.114.114
    - 223.5.5.5
  enhanced-mode: redir-host
  nameserver:
    - https://dns.alidns.com/dns-query
    - https://223.5.5.5/dns-query
  fallback:
    - 114.114.114.114
    - 223.5.5.5
rule-providers:
  reject:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/reject.txt"
    path: ./ruleset/reject.yaml
    interval: 86400

  icloud:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/icloud.txt"
    path: ./ruleset/icloud.yaml
    interval: 86400

  apple:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/apple.txt"
    path: ./ruleset/apple.yaml
    interval: 86400

  google:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/google.txt"
    path: ./ruleset/google.yaml
    interval: 86400

  proxy:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/proxy.txt"
    path: ./ruleset/proxy.yaml
    interval: 86400

  direct:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/direct.txt"
    path: ./ruleset/direct.yaml
    interval: 86400

  private:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/private.txt"
    path: ./ruleset/private.yaml
    interval: 86400

  gfw:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/gfw.txt"
    path: ./ruleset/gfw.yaml
    interval: 86400

  greatfire:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/greatfire.txt"
    path: ./ruleset/greatfire.yaml
    interval: 86400

  tld-not-cn:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/tld-not-cn.txt"
    path: ./ruleset/tld-not-cn.yaml
    interval: 86400

  telegramcidr:
    type: http
    behavior: ipcidr
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/telegramcidr.txt"
    path: ./ruleset/telegramcidr.yaml
    interval: 86400

  cncidr:
    type: http
    behavior: ipcidr
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/cncidr.txt"
    path: ./ruleset/cncidr.yaml
    interval: 86400

  lancidr:
    type: http
    behavior: ipcidr
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/lancidr.txt"
    path: ./ruleset/lancidr.yaml
    interval: 86400

  applications:
    type: http
    behavior: classical
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/applications.txt"
    path: ./ruleset/applications.yaml
    interval: 86400

rules:
  - RULE-SET,applications,DIRECT
  - DOMAIN,clash.razord.top,DIRECT
  - DOMAIN,yacd.haishan.me,DIRECT
  - DOMAIN,services.googleapis.cn,PROXY
  - RULE-SET,private,DIRECT
  - RULE-SET,reject,REJECT
  - RULE-SET,icloud,DIRECT
  - RULE-SET,apple,DIRECT
  - RULE-SET,google,DIRECT
  - RULE-SET,proxy,PROXY
  - RULE-SET,direct,DIRECT
  - RULE-SET,lancidr,DIRECT
  - RULE-SET,cncidr,DIRECT
  - RULE-SET,telegramcidr,PROXY
  - GEOIP,LAN,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,PROXY
EOF
    realmMode=$(getBackupValueOrDefault "$HIHY_BACKUP_FILE" "realmMode" "false")
    serverAddress=$(getYamlValue "$HIHY_BACKUP_FILE" "serverAddress")
    listen_value=$(getYamlValue "$HIHY_CONFIG_FILE" "listen")
    port=$(getListenPrimaryPort "${listen_value}")
    auth_secret=$(getYamlValue "$HIHY_CONFIG_FILE" "auth.password")
    tls_sni=$(getYamlValue "$HIHY_BACKUP_FILE" "domain")
    insecure=$(getYamlValue "$HIHY_BACKUP_FILE" "insecure")
    masquerade_tcp=$(getYamlValue "$HIHY_BACKUP_FILE" "masquerade_tcp")
    obfs_type=$(getYamlValue "$HIHY_CONFIG_FILE" "obfs.type")
    if [ "${obfs_type}" == "salamander" ] || [ "${obfs_type}" == "gecko" ]; then
        obfs_status="true"
        obfs_pass=$(getYamlValue "$HIHY_CONFIG_FILE" "obfs.${obfs_type}.password")
    else
        obfs_status="false"
        obfs_type=""
        obfs_pass=""
    fi
    SRW=$(getYamlValue "$HIHY_CONFIG_FILE" "quic.initStreamReceiveWindow")
    CRW=$(getYamlValue "$HIHY_CONFIG_FILE" "quic.initConnReceiveWindow")
    max_CRW=$(getYamlValue "$HIHY_CONFIG_FILE" "quic.maxConnReceiveWindow")
    max_SRW=$(getYamlValue "$HIHY_CONFIG_FILE" "quic.maxStreamReceiveWindow")
    download=$(getYamlValue "$HIHY_CONFIG_FILE" "bandwidth.up")
    download=$(echo ${download} | sed 's/[^0-9]//g')
    upload=$(getYamlValue "$HIHY_CONFIG_FILE" "bandwidth.down")
    upload=$(echo ${upload} | sed 's/[^0-9]//g')
    portHoppingStatus=$(getYamlValue "$HIHY_BACKUP_FILE" "portHoppingStatus")
    if [ "${portHoppingStatus}" == "true" ]; then
        portHoppingStart=$(getBackupValueOrDefault "$HIHY_BACKUP_FILE" "portHoppingStart" "${port}")
        portHoppingEnd=$(getBackupValueOrDefault "$HIHY_BACKUP_FILE" "portHoppingEnd" "${port}")
    fi
    serverAddress="${serverAddress#[}"
    serverAddress="${serverAddress%]}"
    addOrUpdateYaml "${metaFile}" "proxies[0].name" "${remarks}" "string"
    addOrUpdateYaml "${metaFile}" "proxies[0].type" "hysteria2"
    if [ "${realmMode}" == "true" ]; then
        addOrUpdateYaml "${metaFile}" "proxies[0].server" "${serverAddress}" "string"
        yq eval 'del(.proxies[0].port)' -i "${metaFile}"
    else
        addOrUpdateYaml "${metaFile}" "proxies[0].server" "${serverAddress}" "string"
        addOrUpdateYaml "${metaFile}" "proxies[0].port" "${port}"
        if [ "${portHoppingStatus}" == "true" ]; then
            addOrUpdateYaml "${metaFile}" "proxies[0].ports" "${portHoppingStart}-${portHoppingEnd}"
        fi
    fi
    addOrUpdateYaml "${metaFile}" "proxies[0].password" "${auth_secret}" "string"
    # BBR/Reno 不设置固定带宽，不能导出空的 " Mbps"。
    if [[ "$upload" =~ ^[0-9]+$ ]] && [ "$upload" -gt 0 ]; then
        addOrUpdateYaml "${metaFile}" "proxies[0].up" "${upload} Mbps"
    else
        yq eval 'del(.proxies[0].up)' -i "$metaFile"
    fi
    if [[ "$download" =~ ^[0-9]+$ ]] && [ "$download" -gt 0 ]; then
        addOrUpdateYaml "${metaFile}" "proxies[0].down" "${download} Mbps"
    else
        yq eval 'del(.proxies[0].down)' -i "$metaFile"
    fi
    addOrUpdateYaml "${metaFile}" "proxies[0].skip-cert-verify" "${insecure}"
    if [ "${obfs_status}" == "true" ]; then
        addOrUpdateYaml "${metaFile}" "proxies[0].obfs" "${obfs_type}"
        addOrUpdateYaml "${metaFile}" "proxies[0].obfs-password" "${obfs_pass}" "string"
    else
        yq eval 'del(.proxies[0].obfs, .proxies[0].obfs-password)' -i "${metaFile}"
    fi
    addOrUpdateYaml "${metaFile}" "proxies[0].sni" "${tls_sni}" "string"
    addOrUpdateYaml "${metaFile}" "proxy-groups[0].name" "PROXY"
    addOrUpdateYaml "${metaFile}" "proxy-groups[0].type" "select"
    addOrUpdateYaml "${metaFile}" "proxy-groups[0].proxies[0]" "${remarks}" "string"
    echoColor purple "\n📱 4、[Clash.Mini/ClashX.Meta/Clash.Meta for Android/Clash.verge/openclash] ClashMeta配置。文件地址: $(echoColor green ${metaFile})"
    if [ "${realmMode}" == "true" ]; then
        echoColor yellow "⚠ Clash Meta可能不完全支持Realm模式,建议优先使用原生配置文件"
    fi

}

checkLogs() {
    if [ "$(detectServiceManager)" = "systemd" ] && [ -f "$HIHY_SERVICE_FILE" ]; then
        journalctl -u hihy.service -f
    elif [ -f "$HIHY_LOG_FILE" ]; then
        tail -f "$HIHY_LOG_FILE"
    else
        echoColor red "日志文件不存在!"
    fi
}
start() {
    if serviceStart; then
        echoColor green "启动成功!"
    else
        echoColor red "启动失败!"
        return 1
    fi
}
stop() {
    if serviceStop; then
        echoColor green "停止成功!"
    else
        echoColor red "停止失败!"
        return 1
    fi
}
restart() {
    if serviceRestart; then
        echoColor green "重启成功!"
    else
        echoColor red "重启失败!"
        return 1
    fi
}
checkStatus() {
    if serviceIsActive; then
        echoColor green "hysteria正在运行"
        version=$(/etc/hihy/bin/appS version | grep "^Version" | awk '{print $2}')
        echoColor purple "当前版本: $(echoColor red ${version})"
    else
        echoColor red "hysteria未运行"
        return 1
    fi
}

# 定义格式化字节大小的函数
format_bytes() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt $((1024 * 1024)) ]; then
        echo "$(echo "scale=2; $bytes/1024" | bc)KB"
    elif [ $bytes -lt $((1024 * 1024 * 1024)) ]; then
        echo "$(echo "scale=2; $bytes/(1024*1024)" | bc)MB"
    else
        echo "$(echo "scale=2; $bytes/(1024*1024*1024)" | bc)GB"
    fi
}

getHysteriaTrafic() {
    local api_port=$(getYamlValue "/etc/hihy/conf/backup.yaml" "trafficPort")
    local secret=$(getYamlValue "/etc/hihy/conf/config.yaml" "auth.password")

    if [ -n "$secret" ]; then
        CURL_OPTS=(-H "Authorization: $secret")
    else
        CURL_OPTS=()
    fi

    echo "=========== Hysteria 服务器状态 ==========="

    # 流量统计部分保持不变
    echoColor green "【流量统计】"
    curl -s "${CURL_OPTS[@]}" "http://127.0.0.1:${api_port}/traffic" \
        | grep -oE '"[^"]+":{"tx":[0-9]+,"rx":[0-9]+}' \
        | while IFS=: read -r user stats; do
            tx=$(echo $stats | grep -oE '"tx":[0-9]+' | cut -d: -f2)
            rx=$(echo $stats | grep -oE '"rx":[0-9]+' | cut -d: -f2)
            user=$(echo $user | tr -d '"')
            tx_formatted=$(format_bytes $tx)
            rx_formatted=$(format_bytes $rx)
            printf "用户: %-20s 上传: %8s  下载: %8s\n" "$user" "$tx_formatted" "$rx_formatted"
        done

    # 在线用户部分保持不变
    echoColor green "\n【在线用户】"
    curl -s "${CURL_OPTS[@]}" "http://127.0.0.1:${api_port}/online" \
        | grep -oE '"[^"]+":[0-9]+' \
        | while IFS=: read -r user count; do
            user=$(echo $user | tr -d '"')
            count=$(echo $count | tr -d ' ')
            printf "用户: %-20s 设备数: %d\n" "$user" "$count"
        done

    echoColor green "\n【活动连接】"
    STREAMS_OUTPUT=$(curl -s "${CURL_OPTS[@]}" -H "Accept: text/plain" "http://127.0.0.1:${api_port}/dump/streams")

    if [ "$(echo "$STREAMS_OUTPUT" | wc -l)" -le 1 ]; then
        echo "当前没有活动连接"
    else
        # 打印表头
        printf "%-8s | %-15s | %-10s | %-3s | %-10s | %-10s | %-12s | %-12s | %-20s | %-20s\n" \
            "状态" "用户" "连接ID" "流数" "上传" "下载" "存活时间" "最后活动" "请求地址" "目标地址"
        echo "----------|-----------------|------------|------|------------|------------|--------------|--------------|----------------------|----------------------"

        # 使用临时文件存储排序数据
        temp_file=$(mktemp)

        echo "$STREAMS_OUTPUT" | awk 'BEGIN {
            status["ESTAB"]="已建立"
            status["CLOSED"]="已关闭"
        }

        function format_bytes(bytes) {
            if (bytes < 1024) return bytes "B"
            if (bytes < 1024*1024) return sprintf("%.2fKB", bytes/1024)
            if (bytes < 1024*1024*1024) return sprintf("%.2fMB", bytes/(1024*1024))
            return sprintf("%.2fGB", bytes/(1024*1024*1024))
        }

        function format_time(time) {
            if (time == "-") return 0
            if (index(time, "ms") > 0) {
                gsub("ms", "", time)
                return time/1000
            }
            if (index(time, "s") > 0) {
                gsub("s", "", time)
                return time
            }
            if (index(time, "m") > 0) {
                gsub("m", "", time)
                return time * 60
            }
            if (index(time, "h") > 0) {
                gsub("h", "", time)
                return time * 3600
            }
            return time
        }

        function format_time_display(seconds) {
            if (seconds < 1) return sprintf("%.0fms", seconds * 1000)
            if (seconds < 60) return sprintf("%.1f秒", seconds)
            if (seconds < 3600) return sprintf("%.1f分钟", seconds/60)
            return sprintf("%.1f小时", seconds/3600)
        }

        NR > 1 {
            last_active = format_time($8)
            printf "%s|%s|%s|%s|%s|%s|%s|%.2f|%s|%s\n", \
                status[$1], $2, $3, $4, \
                format_bytes($5), format_bytes($6), \
                format_time_display(format_time($7)), \
                last_active, \
                $9, $10
        }' | sort -t'|' -k8,8nr >"$temp_file"

        # 读取排序后的数据并格式化输出
        while IFS='|' read -r state user conn_id flows up down alive last_active req_addr target_addr; do
            printf "%-8s | %-15s | %-10s | %-3s | %-10s | %-10s | %-12s | %-12s | %-20s | %-20s\n" \
                "$state" "$user" "$conn_id" "$flows" "$up" "$down" \
                "$alive" "$(format_time_display $last_active)" "$req_addr" "$target_addr"
        done <"$temp_file"

        rm -f "$temp_file"
    fi

    echo "========================================"
}

# 辅助函数：格式化时间显示
format_time_display() {
    local seconds=$1

    # 处理毫秒级别
    if (($(echo "$seconds < 1" | bc -l))); then
        printf "%.0f毫秒" $(echo "$seconds * 1000" | bc -l)
        return
    fi

    # 处理秒级别
    if (($(echo "$seconds < 60" | bc -l))); then
        printf "%.1f秒" "$seconds"
        return
    fi

    # 处理分钟级别
    if (($(echo "$seconds < 3600" | bc -l))); then
        local minutes=$(echo "$seconds / 60" | bc -l)
        printf "%.1f分钟" "$minutes"
        return
    fi

    # 处理小时级别
    local hours=$(echo "$seconds / 3600" | bc -l)
    # 如果小时数小于0.1，显示为分钟
    if (($(echo "$hours < 0.1" | bc -l))); then
        local minutes=$(echo "$seconds / 60" | bc -l)
        printf "%.1f分钟" "$minutes"
    else
        printf "%.1f小时" "$hours"
    fi
}

legacyDelHihyFirewallPortUnsafe() {
    echoColor red "旧版防火墙删除实现已禁用，拒绝执行全量规则恢复。"
    return 1
    # 如果防火墙启动状态则删除之前的规则
    local listen_value=$(getYamlValue "/etc/hihy/conf/config.yaml" "listen")
    local port=$(getListenPrimaryPort "${listen_value}")
    local port_range=$(getListenRangePart "${listen_value}")
    local firewall_port_range=$(formatFirewallPortSpec "${port_range}")
    local protocol=$1

    # realm模式下listen值非端口号(为realm URI),跳过防火墙规则删除
    if [ -z "${port}" ] || ! echo "${port}" | grep -qE '^[0-9]+$'; then
        return 0
    fi
    # 检查并处理不同的防火墙管理工具
    if command -v ufw >/dev/null && ufw status | hasFirewallToken "active"; then
        if ufw status | hasFirewallToken "${port}/${protocol}"; then
            ufw delete allow "${port}/${protocol}" 2>/dev/null
            echoColor purple "UFW DELETE: ${port}/${protocol}"
        # 兼容旧版本未带协议的 ufw 规则
        elif ufw status | hasFirewallToken "${port}"; then
            ufw delete allow "${port}" 2>/dev/null
            echoColor purple "UFW DELETE: ${port}"
        fi
        if [ -n "${firewall_port_range}" ] && ufw status | hasFirewallToken "${firewall_port_range}/${protocol}"; then
            ufw delete allow "${firewall_port_range}/${protocol}" 2>/dev/null
            echoColor purple "UFW DELETE: ${firewall_port_range}/${protocol}"
        fi
    elif command -v firewall-cmd >/dev/null && systemctl is-active --quiet firewalld; then
        if firewall-cmd --list-ports --permanent | hasFirewallToken "${port}/${protocol}"; then
            firewall-cmd --zone=public --remove-port="${port}/${protocol}" --permanent 2>/dev/null
            firewall-cmd --reload 2>/dev/null
            echoColor purple "FIREWALLD DELETE: ${port}/${protocol}"
        fi
        if [ -n "${firewall_port_range}" ] && firewall-cmd --list-ports --permanent | hasFirewallToken "${firewall_port_range}/${protocol}"; then
            firewall-cmd --zone=public --remove-port="${firewall_port_range}/${protocol}" --permanent 2>/dev/null
            firewall-cmd --reload 2>/dev/null
            echoColor purple "FIREWALLD DELETE: ${firewall_port_range}/${protocol}"
        fi
    elif command -v iptables >/dev/null; then
        iptables-save | sed -e "/hihysteria/d" | iptables-restore
        ip6tables-save | sed -e "/hihysteria/d" | ip6tables-restore
        if command -v systemctl >/dev/null 2>&1; then
            # 检查 netfilter-persistent
            if systemctl is-active --quiet netfilter-persistent; then
                netfilter-persistent save
            fi
        fi
        if [ -f "/etc/rc.d/allow-port" ]; then
            sed -i "/${protocol}\/${port}(hihysteria)/d" /etc/rc.d/allow-port
            if [ -n "${firewall_port_range}" ]; then
                local port_range_comment=$(echo "${firewall_port_range}" | sed 's/:/\\:/g')
                sed -i "/${protocol}\/${port_range_comment}(hihysteria)/d" /etc/rc.d/allow-port
            fi
        fi

        echoColor purple "IPTABLES DELETE: ${port}/${protocol}"
        if [ -n "${firewall_port_range}" ]; then
            echoColor purple "IPTABLES DELETE: ${firewall_port_range}/${protocol}"
        fi
    fi
}

delHihyFirewallPort() {
    removeOwnedFirewallRules
}

changeIp64() {
    local socks5_status=$(getYamlValue "/etc/hihy/conf/backup.yaml" "socks5_status")
    local config_file="/etc/hihy/conf/config.yaml"
    if [ "${socks5_status}" == "true" ]; then
        echoColor red "当前已经开启socks5转发,不支持修改优先级,如需分流请使用ACL管理"
        exit 1
    fi
    mode_now=$(getYamlValue "$config_file" "outbounds[0].direct.mode")

    case "${mode_now}" in
        46) mode_name="IPv4 优先，失败后回退 IPv6" ;;
        64) mode_name="IPv6 优先，失败后回退 IPv4" ;;
        4) mode_name="仅 IPv4" ;;
        6) mode_name="仅 IPv6" ;;
        *) mode_name="自动选择，IPv4/IPv6 竞速" ;;
    esac

    public_ipv4=$(curl -4 -fsS --connect-timeout 3 --max-time 8 https://api.ipify.org 2>/dev/null || true)
    public_ipv6=$(curl -6 -fsS --connect-timeout 3 --max-time 8 https://api64.ipify.org 2>/dev/null || true)

    echoColor purple "当前出口模式: $(echoColor red "${mode_name} (${mode_now})")"
    if [ -n "${public_ipv4}" ]; then
        echoColor purple "服务器公网 IPv4: $(echoColor red "${public_ipv4}")"
    else
        echoColor yellow "服务器公网 IPv4: 不可用或检测失败"
    fi
    if [ -n "${public_ipv6}" ]; then
        echoColor purple "服务器公网 IPv6: $(echoColor red "${public_ipv6}")"
    else
        echoColor yellow "服务器公网 IPv6: 不可用或检测失败"
    fi
    echoColor yellow "提示: 优先模式会在首选协议不可用时回退；仅 IPv4/IPv6 不会回退。"
    echoColor yellow "1) IPv4 优先"
    echoColor yellow "2) IPv6 优先"
    echoColor yellow "3) 仅 IPv4"
    echoColor yellow "4) 仅 IPv6"
    echoColor yellow "5) 自动选择"
    echoColor yellow "0) 退出"
    read -r -p "请选择: " input
    case $input in
        1)
            if [ "${mode_now}" == "46" ]; then
                echoColor yellow "当前已经是ipv4优先模式"
            else
                addOrUpdateYaml "$config_file" "outbounds[0].direct.mode" "46"
                restart
                echoColor green "切换成功"
            fi

            ;;
        2)
            if [ "${mode_now}" == "64" ]; then
                echoColor yellow "当前已经是ipv6优先模式"
            else
                addOrUpdateYaml "$config_file" "outbounds[0].direct.mode" "64"
                restart
                echoColor green "切换成功"
            fi

            ;;

        3)
            if [ "${mode_now}" == "4" ]; then
                echoColor yellow "当前已经是仅 IPv4 模式"
            else
                addOrUpdateYaml "$config_file" "outbounds[0].direct.mode" "4"
                restart
                echoColor green "已切换为仅 IPv4，所有代理出口只使用 ${public_ipv4:-IPv4}"
            fi
            ;;
        4)
            if [ "${mode_now}" == "6" ]; then
                echoColor yellow "当前已经是仅 IPv6 模式"
            else
                addOrUpdateYaml "$config_file" "outbounds[0].direct.mode" "6"
                restart
                echoColor green "已切换为仅 IPv6，所有代理出口只使用 ${public_ipv6:-IPv6}"
            fi
            ;;
        5)
            if [ "${mode_now}" == "auto" ]; then
                echoColor yellow "当前已经是自动选择模式"
            else
                addOrUpdateYaml "$config_file" "outbounds[0].direct.mode" "auto"
                restart
                echoColor green "切换成功"
            fi
            ;;
        0) exit 0 ;;
        *)
            echoColor red "输入错误!"
            exit 1
            ;;
    esac
}

restoreReconfiguration() {
    local backup_dir="$1" was_running="$2" backend protocol rule_port result=0
    local old_port old_realm old_hopping old_start old_end old_tcp
    if ! serviceStop && serviceIsActive; then
        echoColor red "新服务未能停止，尚未恢复文件。"
        return 1
    fi
    removeOwnedFirewallRules || return 1
    cp -a "$backup_dir/config.yaml" "$HIHY_CONFIG_FILE" || return 1
    cp -a "$backup_dir/backup.yaml" "$HIHY_BACKUP_FILE" || return 1
    if [ -f "$backup_dir/acl.txt" ]; then
        cp -a "$backup_dir/acl.txt" "$HIHY_ACL_FILE" || return 1
    else
        rm -f "$HIHY_ACL_FILE" || return 1
    fi
    if [ -d "$backup_dir/cert" ]; then
        mkdir -p "$HIHY_ROOT_DIR/cert" || return 1
        cp -a "$backup_dir/cert/." "$HIHY_ROOT_DIR/cert/" || return 1
    fi
    if [ -f "$backup_dir/firewall-owned.state" ]; then
        # 逐条重建实际规则并重新记录所有权，不能只恢复状态文件。
        while IFS='|' read -r backend protocol rule_port; do
            [ -n "$backend" ] || continue
            allowPort "${protocol#protocol=}" "${rule_port#port=}" "${backend#backend=}" || result=1
        done < "$backup_dir/firewall-owned.state"
    else
        # 兼容尚无所有权记录的旧安装；已有的外部规则不会被接管。
        old_realm=$(getBackupValueOrDefault "$backup_dir/backup.yaml" realmMode false)
        old_port=$(getYamlValue "$backup_dir/backup.yaml" serverPort)
        if [ "$old_realm" != true ] && validate_port "$old_port"; then
            allowPort udp "$old_port" || result=1
            old_hopping=$(getBackupValueOrDefault "$backup_dir/backup.yaml" portHoppingStatus false)
            old_tcp=$(getBackupValueOrDefault "$backup_dir/backup.yaml" masquerade_tcp false)
            if [ "$old_hopping" = true ]; then
                old_start=$(getYamlValue "$backup_dir/backup.yaml" portHoppingStart)
                old_end=$(getYamlValue "$backup_dir/backup.yaml" portHoppingEnd)
                allowPort udp "$old_start:$old_end" || result=1
            fi
            if [ "$old_tcp" = true ]; then
                allowPort tcp "$old_port" || result=1
            fi
        fi
    fi
    secureHihyPermissions || result=1
    if [ "$was_running" = true ]; then
        if ! serviceStart || ! waitHihyServiceHealthy; then
            echoColor red "旧配置已恢复，但服务未恢复正常。"
            result=1
        fi
    fi
    if [ "$result" = 0 ]; then
        clearInstallFailureMarker
        echoColor yellow "已恢复旧配置、防火墙和原服务启停状态。"
    fi
    return "$result"
}

changeServerConfig() {
    local backup_dir was_running=false failed=false
    if [ "$(classifyInstallState)" != installed ]; then
        echoColor red "请先安装hysteria2,再去修改配置..."
        return 1
    fi
    local old_ech_path ech_key_path=""
    old_ech_path=$(getYamlValue "$HIHY_CONFIG_FILE" ech.keyPath) || return 1
    prepareECH "$old_ech_path" || return 1
    backup_dir=$(mktemp -d "$HIHY_ROOT_DIR/result/reconfigure.XXXXXX") || return 1
    cp -a "$HIHY_CONFIG_FILE" "$backup_dir/config.yaml" &&
        cp -a "$HIHY_BACKUP_FILE" "$backup_dir/backup.yaml" || { rm -rf "$backup_dir"; return 1; }
    if [ -f "$HIHY_ACL_FILE" ]; then
        cp -a "$HIHY_ACL_FILE" "$backup_dir/acl.txt" || { rm -rf "$backup_dir"; return 1; }
    fi
    if [ -f "$HIHY_FIREWALL_STATE_FILE" ]; then
        cp -a "$HIHY_FIREWALL_STATE_FILE" "$backup_dir/firewall-owned.state" || { rm -rf "$backup_dir"; return 1; }
    fi
    if [ -d "$HIHY_ROOT_DIR/cert" ]; then
        cp -a "$HIHY_ROOT_DIR/cert" "$backup_dir/cert" || { rm -rf "$backup_dir"; return 1; }
    fi
    serviceIsActive && was_running=true
    if [ "$was_running" = true ]; then
        serviceStop || { echoColor red "停止服务失败，备份保留在 $backup_dir"; return 1; }
    fi
    if ! removeOwnedFirewallRules || ! setHysteriaConfig "$ech_key_path"; then
        failed=true
    elif [ "$was_running" = true ]; then
        if ! serviceStart || ! waitHihyServiceHealthy; then
            failed=true
        fi
    fi
    if [ "$failed" = true ]; then
        echoColor yellow "重新配置未完成，正在恢复旧状态。"
        if restoreReconfiguration "$backup_dir" "$was_running"; then
            rm -rf "$backup_dir"
        else
            echoColor red "恢复未完全成功，备份保留在 $backup_dir，请检查日志和防火墙。"
        fi
        return 1
    fi
    if ! generate_client_config; then
        echoColor yellow "服务端配置已保存，但客户端导出失败。旧配置备份: $backup_dir"
        return 1
    fi
    rm -rf "$backup_dir"
    echoColor green "配置修改成功，已保留原服务启停状态。"
}

aclControl() {
    local acl_file="/etc/hihy/acl/acl.txt"
    if [ ! -f "${acl_file}" ]; then
        echoColor red "未找到acl文件"
        exit 1
    fi
    echoColor purple "请选择管理操作:"
    echoColor yellow "1) 添加"
    echoColor yellow "2) 删除"
    echoColor yellow "3) 查看"
    echoColor yellow "0) 退出"
    read -r -p "请选择: " input
    case $input in
        1)
            echoColor green "请选择ACL控制方式"
            echoColor yellow "1) 添加域名ipv4分流"
            echoColor yellow "2) 添加域名ipv6分流"
            echoColor yellow "3) 添加屏蔽域名"
            read -r -p "请选择: " input
            case $input in
                1)
                    read -r -p "请输入要分流ipv4的域名: " domain
                    if [ -z "${domain}" ]; then
                        echoColor red "域名不能为空"
                        exit 1
                    fi
                    if grep -q "v4_only(suffix:${domain})" "${acl_file}"; then
                        echoColor red "规则已存在"
                    else
                        echo "v4_only(suffix:${domain})" >>"${acl_file}"
                        echoColor green "添加成功"
                        restart
                    fi
                    ;;
                2)
                    read -r -p "请输入要分流ipv6的域名: " domain
                    if [ -z "${domain}" ]; then
                        echoColor red "域名不能为空"
                        exit 1
                    fi
                    if grep -q "v6_only(suffix:${domain})" "${acl_file}"; then
                        echoColor red "规则已存在"
                    else
                        echo "v6_only(suffix:${domain})" >>"${acl_file}"
                        echoColor green "添加成功"
                        restart
                    fi
                    ;;
                3)
                    read -r -p "请输入要屏蔽的域名: " rejectInput
                    if [ -z "${rejectInput}" ]; then
                        echoColor red "域名不能为空"
                        exit 1
                    fi
                    if grep -q "reject(suffix:${rejectInput})" "${acl_file}"; then
                        echoColor red "规则已存在"
                    else
                        echo "reject(suffix:${rejectInput})" >>"${acl_file}"
                        echoColor green "添加成功"
                        restart
                    fi
                    ;;
                *)
                    echoColor red "输入错误!"
                    exit 1
                    ;;
            esac
            ;;
        2)
            read -r -p "请输入要删除的域名规则: " domain
            if [ -z "${domain}" ]; then
                echoColor red "域名不能为空"
                exit 1
            fi
            if grep -q "${domain}" "${acl_file}"; then
                sed -i "/${domain}/d" "${acl_file}"
                echoColor green "删除成功"
                restart
            else
                echoColor red "规则不存在"
            fi

            ;;
        3)
            echoColor purple "当前ACL列表:"
            cat "${acl_file}"
            ;;
        0) exit 0 ;;
        *)
            echoColor red "输入错误!"
            exit 1
            ;;
    esac

}

addSocks5Outbound() {
    if [ ! -f "/etc/hihy/conf/config.yaml" ]; then
        echoColor red "未找到配置文件"
        exit 1
    fi
    local server_config="/etc/hihy/conf/config.yaml"
    local backup_config="/etc/hihy/conf/backup.yaml"
    echo -e "Tip: WireProxy借助cloudflare warp提供免费好用的socks5代理,比起warp全局开销更小,建议性能不好的机器使用."
    echo -e "\033[32m请选择:\n\n\033[0m\033[33m\033[01m1、自动添加一个warp socks5接口作为hysteria2出站(默认,使用fscarmen WireProxy方案)\n2、自定义socks5地址\n3、卸载已经配置的outbound\033[0m\033[32m\n\n输入序号:\033[0m"
    read -r num
    if [ -z "${num}" ] || [ ${num} == "1" ]; then
        socks5_status=$(getYamlValue "/etc/hihy/conf/backup.yaml" "socks5_status")
        if [ "${socks5_status}" == "true" ]; then
            echoColor red "当前已经开启socks5 outbound,请删除后再添加"
            exit 1
        fi
        local conf_file="/etc/wireguard/proxy.conf"
        if [ -f "$conf_file" ]; then
            echoColor green "找到WireProxy配置文件,使用当前配置"
        else
            wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh w
        fi

        if [ ! -f "$conf_file" ]; then
            echoColor red "未找到WireProxy配置文件,请保证正确安装WireProxy"
            exit 1
        fi
        local port=$(grep "BindAddress" "$conf_file" | grep -v "^#" | awk -F':' '{print $2}')
        echoColor purple "->本机WireProxy socks5端口: $(echoColor red ${port})"

        # 在数组开头插入新的outbound配置
        yq eval '.outbounds = [{"name": "warp", "type": "socks5", "socks5": {"addr": "127.0.0.1:'$port'"}}] + .outbounds' -i "${server_config}"

        restart
        addOrUpdateYaml ${backup_config} "socks5_status" "true"
        echoColor green "添加warp outbound成功"

    elif [ ${num} == "2" ]; then
        socks5_status=$(getYamlValue "/etc/hihy/conf/backup.yaml" "socks5_status")
        if [ "${socks5_status}" == "true" ]; then
            echoColor red "当前已经开启socks5 outbound,请删除后再添加"
            exit 1
        fi
        read -r -p "请输入socks5地址(ip:端口): " socks5_addr
        if [ -z "${socks5_addr}" ]; then
            echoColor red "地址不能为空"
            exit 1
        fi
        read -r -p "请输入socks5用户名,如果没有鉴权直接留空: " socks5_user
        if [ -n "${socks5_user}" ]; then
            read -r -p "请输入socks5密码: " socks5_pass
            if [ -z "${socks5_pass}" ]; then
                echoColor red "密码不能为空"
                exit 1
            fi
        fi
        local server_config="/etc/hihy/conf/config.yaml"
        if [ -n "${socks5_user}" ]; then
            yq eval '.outbounds = [{"name": "custom", "type": "socks5", "socks5": {"addr": "'$socks5_addr'", "username": "'$socks5_user'", "password": "'$socks5_pass'"}}] + .outbounds' -i "${server_config}"
        else
            yq eval '.outbounds = [{"name": "custom", "type": "socks5", "socks5": {"addr": "'$socks5_addr'"}}] + .outbounds' -i "${server_config}"

        fi
        restart
        addOrUpdateYaml ${backup_config} "socks5_status" "true"
        echoColor green "添加socks5 outbound成功"
    elif [ ${num} == "3" ]; then
        # 删除outbounds相关配置
        outbound_name=$(getYamlValue ${server_config} "outbounds[0].name")
        if [ "${outbound_name}" == "warp" ] || [ "${outbound_name}" == "custom" ]; then
            yq eval 'del(.outbounds[0])' -i "${server_config}"
            if [ "${outbound_name}" == "warp" ]; then
                warp u
            fi
            restart
            addOrUpdateYaml ${backup_config} "socks5_status" "false"
            echoColor green "卸载成功"
        else
            echoColor red "未找到socks5 outbound"
        fi

    else
        echoColor red "输入错误"
        exit 1
    fi

}

publishSharedCertificate() {
    local source_cert="$1"
    local source_key="$2"
    local domain="$3"
    local release_id release_dir current_link

    validateCertificateBundle "$source_cert" "$source_key" "$domain" || return 1
    ensureCertificateManagerDirectories || return 1
    release_id=$(date -u +%Y%m%dT%H%M%SZ)
    release_dir="$HIHY_SHARED_CERT_DIR/releases/$release_id"
    mkdir -p "$release_dir"
    chmod 700 "$release_dir"
    command install -m 644 "$source_cert" "$release_dir/fullchain.pem"
    command install -m 600 "$source_key" "$release_dir/privkey.pem"
    openssl x509 -in "$source_cert" -noout -fingerprint -sha256 >"$release_dir/fingerprint"
    chmod 600 "$release_dir/fingerprint"
    current_link="$HIHY_SHARED_CERT_DIR/current"
    ln -sfn "releases/$release_id" "$HIHY_SHARED_CERT_DIR/.current.new"
    mv -Tf "$HIHY_SHARED_CERT_DIR/.current.new" "$current_link"
    find "$HIHY_SHARED_CERT_DIR/releases" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' 2>/dev/null \
        | sort -nr | cut -d' ' -f2- | sed -n '4,$p' | while IFS= read -r old_release; do
            rm -rf "$old_release"
        done
}

migrateLocalHysteriaToSharedCertificate() {
    local domain="$1"
    local backup_config="$HIHY_ROOT_DIR/conf/config.before-shared-cert.yaml"
    local cert_path="$HIHY_SHARED_CERT_DIR/current/fullchain.pem"
    local key_path="$HIHY_SHARED_CERT_DIR/current/privkey.pem"

    validateCertificateBundle "$cert_path" "$key_path" "$domain" || return 1
    cp -a "$HIHY_CONFIG_FILE" "$backup_config" || return 1
    chmod 600 "$backup_config"
    yq eval 'del(.acme)' -i "$HIHY_CONFIG_FILE" || return 1
    addOrUpdateYaml "$HIHY_CONFIG_FILE" "tls.cert" "$cert_path" "string"
    addOrUpdateYaml "$HIHY_CONFIG_FILE" "tls.key" "$key_path" "string"
    addOrUpdateYaml "$HIHY_CONFIG_FILE" "tls.sniGuard" "strict" "string"
    chmod 600 "$HIHY_CONFIG_FILE"
    if ! serviceRestart || ! serviceIsActive; then
        cp -a "$backup_config" "$HIHY_CONFIG_FILE"
        serviceRestart >/dev/null 2>&1 || true
        return 1
    fi
}

issueOrRenewWildcardCertificate() {
    local domain email wildcard lego_cert lego_key renew_days action="run"

    domain=$(getCertificateManagerValue domain) || return 1
    email=$(getCertificateManagerValue email) || return 1
    wildcard="*.${domain}"
    installLego || return 1
    verifyCloudflareToken || { echoColor red "Cloudflare Token 无效或无法验证。"; return 1; }

    lego_cert="$HIHY_CERT_MANAGER_DIR/lego/certificates/_.${domain}.crt"
    lego_key="$HIHY_CERT_MANAGER_DIR/lego/certificates/_.${domain}.key"
    [ -f "$lego_cert" ] && action="renew"

    renew_days=$(getCertificateManagerValue renew_days 2>/dev/null) || renew_days=30
    [[ "$renew_days" =~ ^[0-9]+$ ]] && [ "$renew_days" -gt 0 ] || return 1
    local lego_args=(--path "$HIHY_CERT_MANAGER_DIR/lego" --email "$email"
        --accept-tos --dns cloudflare --dns.propagation.disable-rns --domains "$wildcard" "$action")
    [ "$action" != renew ] || lego_args+=(--days "$renew_days")
    if ! CF_DNS_API_TOKEN_FILE="$HIHY_CERT_TOKEN_FILE" "$HIHY_LEGO_BIN" "${lego_args[@]}"; then
        echoColor red "通配符证书申请或续期失败。"
        return 1
    fi
    publishSharedCertificate "$lego_cert" "$lego_key" "$domain" || return 1
    printf 'last_issue=%s\n' "$(date +%s)" >"$HIHY_CERT_MANAGER_DIR/state/last-issue.state"
    chmod 600 "$HIHY_CERT_MANAGER_DIR/state/last-issue.state"
}

getCertificateDaysRemaining() {
    local cert="$1" end_date end_epoch now
    end_date=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | cut -d= -f2-) || return 1
    end_epoch=$(date -d "$end_date" +%s 2>/dev/null) || return 1
    now=$(date +%s)
    echo $(((end_epoch - now) / 86400))
}

renewAndDeployCertificates() {
    local cert="$HIHY_SHARED_CERT_DIR/current/fullchain.pem" renew_days days=0
    renew_days=$(getCertificateManagerValue renew_days 2>/dev/null) || renew_days=30
    [[ "$renew_days" =~ ^[0-9]+$ ]] && [ "$renew_days" -gt 0 ] || return 1
    if [ -f "$cert" ]; then
        days=$(getCertificateDaysRemaining "$cert" 2>/dev/null) || days=0
    fi
    if [ "$days" -le "$renew_days" ]; then
        issueOrRenewWildcardCertificate || return 1
    fi
    # 续期成功后某个节点失败，下次定时任务也必须重试该节点。
    deployCertificateToAllNodes pending
}

installCertificateRenewTimer() {
    if [ "$(detectServiceManager)" != "systemd" ]; then
        local temp_file
        command -v crontab >/dev/null 2>&1 || return 1
        temp_file=$(mktemp) || return 1
        crontab -l 2>/dev/null >"$temp_file" || true
        sed -i '/# hihy-managed: certificate-renewal/d;/\/usr\/bin\/hihy cert renew-auto/d' "$temp_file"
        printf '%s\n' '# hihy-managed: certificate-renewal' >>"$temp_file"
        printf '%s\n' '17 3 * * * /usr/bin/hihy cert renew-auto' >>"$temp_file"
        crontab "$temp_file"
        local result=$?
        rm -f "$temp_file"
        return "$result"
    fi
    cat >/etc/systemd/system/hihy-cert-renew.service <<EOF
[Unit]
Description=Renew and deploy Hi_Hysteria shared wildcard certificate
After=network-online.target

[Service]
Type=oneshot
UMask=0077
ExecStart=${HIHY_BIN_LINK} cert renew-auto
EOF
    cat >/etc/systemd/system/hihy-cert-renew.timer <<'EOF'
[Unit]
Description=Daily Hi_Hysteria certificate renewal check

[Timer]
OnCalendar=daily
RandomizedDelaySec=2h
Persistent=true

[Install]
WantedBy=timers.target
EOF
    chmod 644 /etc/systemd/system/hihy-cert-renew.service /etc/systemd/system/hihy-cert-renew.timer
    systemctl daemon-reload && systemctl enable --now hihy-cert-renew.timer
}

initCertificateManager() {
    local current_domain domain email token
    current_domain=$(getYamlValue "$HIHY_CONFIG_FILE" "acme.domains" 2>/dev/null)
    current_domain=${current_domain#*.}
    current_domain=${current_domain#[}
    current_domain=${current_domain%]}
    current_domain=${current_domain//\"/}
    if printf '%s' "$current_domain" | grep -q '\.'; then
        domain=$(printf '%s' "$current_domain" | awk -F. '{print $(NF-1)"."$NF}')
    fi
    email=$(getYamlValue "$HIHY_CONFIG_FILE" "acme.email" 2>/dev/null)

    if [ -n "$domain" ]; then
        echoColor green "主域名(默认:${domain}):"
    else
        echoColor green "请输入用于通配符证书的主域名(例如 example.com):"
    fi
    read -r input_domain
    [ -n "$input_domain" ] && domain="$input_domain"
    printf '%s' "$domain" | grep -Eq '^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' || {
        echoColor red "请输入有效的主域名。"
        return 1
    }
    [ -n "$email" ] && [ "$email" != "null" ] || email="admin@${domain}"
    echoColor green "ACME 邮箱(默认:${email}):"
    read -r input_email
    [ -n "$input_email" ] && email="$input_email"
    writeCertificateManagerConfig "$domain" "$email" || return 1

    token=$(getYamlValue "$HIHY_CONFIG_FILE" "acme.dns.config.cloudflare_api_token" 2>/dev/null)
    if [ -z "$token" ] || [ "$token" = "null" ]; then
        echoColor green "请输入 Cloudflare API Token(输入不回显):"
        read -r -s token
        echo
    else
        echoColor purple "已从当前 Hysteria 配置导入 Cloudflare Token。"
    fi
    [ -n "$token" ] || return 1
    printf '%s' "$token" >"$HIHY_CERT_TOKEN_FILE"
    chmod 600 "$HIHY_CERT_TOKEN_FILE"
    verifyCloudflareToken || { echoColor red "Cloudflare Token 验证失败。"; return 1; }
    installLego || return 1
    issueOrRenewWildcardCertificate || return 1
    migrateLocalHysteriaToSharedCertificate "$domain" || return 1
    installCertificateRenewTimer || echoColor yellow "自动续期 timer 安装失败，可稍后手动执行。"
    echoColor green "本机已配置为证书中心并切换到共享通配符证书。"
}

ensureCertificateDeployKey() {
    ensureCertificateManagerDirectories || return 1
    if [ ! -f "$HIHY_CERT_DEPLOY_KEY" ]; then
        ssh-keygen -q -t ed25519 -N '' -C 'hihy-cert-deploy' -f "$HIHY_CERT_DEPLOY_KEY" || return 1
    fi
    chmod 600 "$HIHY_CERT_DEPLOY_KEY"
    chmod 644 "${HIHY_CERT_DEPLOY_KEY}.pub"
    touch "$HIHY_CERT_KNOWN_HOSTS"
    chmod 600 "$HIHY_CERT_KNOWN_HOSTS"
}

initCertificateReceiver() {
    local domain="$1"
    if [ -z "$domain" ]; then
        echoColor green "请输入共享通配符证书的主域名(例如 example.com):"
        read -r domain
    fi
    printf '%s' "$domain" | grep -Eq '^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' || return 1
    ensureCertificateManagerDirectories || return 1
    cat >"$HIHY_CERT_MANAGER_DIR/config/receiver.conf" <<EOF
mode=receiver
domain=${domain}
EOF
    chmod 600 "$HIHY_CERT_MANAGER_DIR/config/receiver.conf"
    echoColor green "证书接收节点已初始化。"
}

getCertificateReceiverDomain() {
    local file="$HIHY_CERT_MANAGER_DIR/config/receiver.conf"
    if [ -f "$file" ]; then
        grep '^domain=' "$file" | head -n 1 | cut -d= -f2-
    else
        getCertificateManagerValue domain
    fi
}

receiveCertificatePackage() {
    local domain temp_dir cert key backup_config=""
    domain=$(getCertificateReceiverDomain) || return 1
    temp_dir=$(mktemp -d "$HIHY_ROOT_DIR/.cert-receive.XXXXXX") || return 1
    chmod 700 "$temp_dir"
    if ! tar -xzf - -C "$temp_dir"; then
        rm -rf "$temp_dir"
        return 1
    fi
    cert="$temp_dir/fullchain.pem"
    key="$temp_dir/privkey.pem"
    validateCertificateBundle "$cert" "$key" "$domain" || { rm -rf "$temp_dir"; return 1; }
    publishSharedCertificate "$cert" "$key" "$domain" || { rm -rf "$temp_dir"; return 1; }

    if [ -f "$HIHY_CONFIG_FILE" ]; then
        if [ "$(getYamlValue "$HIHY_CONFIG_FILE" "tls.cert" 2>/dev/null)" != "$HIHY_SHARED_CERT_DIR/current/fullchain.pem" ]; then
            backup_config="$HIHY_ROOT_DIR/conf/config.before-shared-cert.yaml"
            migrateLocalHysteriaToSharedCertificate "$domain" || { rm -rf "$temp_dir"; return 1; }
        fi
    fi
    rm -rf "$temp_dir"
    echo "certificate received"
}

validateCertificateNodeField() {
    local type="$1" value="$2"
    case "$type" in
        name) printf '%s' "$value" | grep -Eq '^[A-Za-z0-9._-]+$' ;;
        host) printf '%s' "$value" | grep -Eq '^[A-Za-z0-9.:-]+$' ;;
        user) printf '%s' "$value" | grep -Eq '^[A-Za-z_][A-Za-z0-9_-]*$' ;;
        port) validate_port "$value" ;;
        domain) printf '%s' "$value" | grep -Eq '^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' ;;
        *) return 1 ;;
    esac
}

addCertificateNode() {
    local manager_domain name host port user node_domain node_file public_key auth_line
    manager_domain=$(getCertificateManagerValue domain) || return 1
    ensureCertificateDeployKey || return 1
    echoColor green "节点名称:"
    read -r name
    echoColor green "SSH 地址:"
    read -r host
    echoColor green "SSH 端口(默认22):"
    read -r port
    [ -n "$port" ] || port=22
    echoColor green "SSH 用户(默认root):"
    read -r user
    [ -n "$user" ] || user=root
    echoColor green "节点证书域名:"
    read -r node_domain
    validateCertificateNodeField name "$name" && validateCertificateNodeField host "$host" && \
        validateCertificateNodeField port "$port" && validateCertificateNodeField user "$user" && \
        validateCertificateNodeField domain "$node_domain" || return 1
    case "$node_domain" in
        *."$manager_domain") ;;
        *) echoColor red "节点域名不在 *.${manager_domain} 覆盖范围内。"; return 1 ;;
    esac

    ssh-keyscan -p "$port" -H "$host" 2>/dev/null >>"$HIHY_CERT_KNOWN_HOSTS" || return 1
    sort -u "$HIHY_CERT_KNOWN_HOSTS" -o "$HIHY_CERT_KNOWN_HOSTS"
    public_key=$(cat "${HIHY_CERT_DEPLOY_KEY}.pub")
    auth_line="restrict,command=\"${HIHY_BIN_LINK} cert receive\" ${public_key}"
    echoColor yellow "将通过当前 SSH 登录权限初始化接收节点并安装受限部署公钥。"
    if ! ssh -p "$port" -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$HIHY_CERT_KNOWN_HOSTS" \
        "${user}@${host}" "set -e; ${HIHY_BIN_LINK} cert receiver-init '${manager_domain}'; mkdir -p ~/.ssh; chmod 700 ~/.ssh; touch ~/.ssh/authorized_keys; if ! grep -qF '${public_key}' ~/.ssh/authorized_keys; then printf '%s\\n' '${auth_line}' >> ~/.ssh/authorized_keys; fi; chmod 600 ~/.ssh/authorized_keys"; then
        return 1
    fi
    node_file="$HIHY_CERT_MANAGER_DIR/nodes/${name}.conf"
    cat >"$node_file" <<EOF
name=${name}
host=${host}
port=${port}
user=${user}
domain=${node_domain}
EOF
    chmod 600 "$node_file"
    deployCertificateToNode "$node_file"
}

deployCertificateToNode() {
    local node_file="$1" host port user name cert key cert_digest
    [ -f "$node_file" ] || return 1
    host=$(grep '^host=' "$node_file" | cut -d= -f2-)
    port=$(grep '^port=' "$node_file" | cut -d= -f2-)
    user=$(grep '^user=' "$node_file" | cut -d= -f2-)
    name=$(grep '^name=' "$node_file" | cut -d= -f2-)
    cert="$HIHY_SHARED_CERT_DIR/current/fullchain.pem"
    key="$HIHY_SHARED_CERT_DIR/current/privkey.pem"
    [ -f "$cert" ] && [ -f "$key" ] || return 1
    cert_digest=$(sha256sum "$cert") || return 1
    cert_digest=${cert_digest%% *}
    if (set -o pipefail; tar -czf - -C "$HIHY_SHARED_CERT_DIR/current" fullchain.pem privkey.pem \
        | ssh -i "$HIHY_CERT_DEPLOY_KEY" -p "$port" -o BatchMode=yes \
            -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$HIHY_CERT_KNOWN_HOSTS" \
            "${user}@${host}"); then
        printf 'node=%s\nstatus=success\ndeployed_at=%s\ncert_sha256=%s\n' "$name" "$(date +%s)" "$cert_digest" >"$HIHY_CERT_MANAGER_DIR/state/node-${name}.state"
        chmod 600 "$HIHY_CERT_MANAGER_DIR/state/node-${name}.state"
        echoColor green "节点 ${name} 证书分发成功。"
        return 0
    fi
    printf 'node=%s\nstatus=failed\ndeployed_at=%s\n' "$name" "$(date +%s)" >"$HIHY_CERT_MANAGER_DIR/state/node-${name}.state"
    chmod 600 "$HIHY_CERT_MANAGER_DIR/state/node-${name}.state"
    echoColor red "节点 ${name} 证书分发失败。"
    return 1
}

deployCertificateToAllNodes() {
    local mode="${1:-all}" node_file name state_file digest result=0
    [ -d "$HIHY_CERT_MANAGER_DIR/nodes" ] || return 0
    digest=$(sha256sum "$HIHY_SHARED_CERT_DIR/current/fullchain.pem") || return 1
    digest=${digest%% *}
    for node_file in "$HIHY_CERT_MANAGER_DIR"/nodes/*.conf; do
        [ -f "$node_file" ] || continue
        name=$(grep '^name=' "$node_file" | cut -d= -f2-)
        validateCertificateNodeField name "$name" || { result=1; continue; }
        state_file="$HIHY_CERT_MANAGER_DIR/state/node-${name}.state"
        if [ "$mode" = pending ] && [ -f "$state_file" ] &&
            grep -qx 'status=success' "$state_file" && grep -qx "cert_sha256=$digest" "$state_file"; then
            continue
        fi
        deployCertificateToNode "$node_file" || result=1
    done
    return "$result"
}

removeCertificateNode() {
    local name
    echoColor green "请输入要删除的节点名称:"
    read -r name
    validateCertificateNodeField name "$name" || return 1
    rm -f "$HIHY_CERT_MANAGER_DIR/nodes/${name}.conf" "$HIHY_CERT_MANAGER_DIR/state/node-${name}.state"
}

showCertificateNodes() {
    local node_file state_file name host port user domain status deployed_at deployed_time count=0
    echoColor purple "已配置的 SSH 证书节点"
    printf '%-16s %-30s %-8s %-12s %-30s %-12s %s\n' \
        "节点名称" "SSH 地址" "端口" "用户" "证书域名" "分发状态" "最近分发时间"
    printf '%s\n' "------------------------------------------------------------------------------------------------------------------------"
    for node_file in "$HIHY_CERT_MANAGER_DIR"/nodes/*.conf; do
        [ -f "$node_file" ] || continue
        name=$(grep '^name=' "$node_file" | head -n 1 | cut -d= -f2-)
        host=$(grep '^host=' "$node_file" | head -n 1 | cut -d= -f2-)
        port=$(grep '^port=' "$node_file" | head -n 1 | cut -d= -f2-)
        user=$(grep '^user=' "$node_file" | head -n 1 | cut -d= -f2-)
        domain=$(grep '^domain=' "$node_file" | head -n 1 | cut -d= -f2-)
        status="尚未分发"
        deployed_time="-"
        state_file="$HIHY_CERT_MANAGER_DIR/state/node-${name}.state"
        if [ -f "$state_file" ]; then
            status=$(grep '^status=' "$state_file" | head -n 1 | cut -d= -f2-)
            deployed_at=$(grep '^deployed_at=' "$state_file" | head -n 1 | cut -d= -f2-)
            case "$status" in
                success) status="成功" ;;
                failed) status="失败" ;;
                "") status="未知" ;;
            esac
            if is_uint "$deployed_at"; then
                deployed_time=$(date -d "@${deployed_at}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$deployed_at")
            fi
        fi
        printf '%-16s %-30s %-8s %-12s %-30s %-12s %s\n' \
            "${name:-未知}" "${host:-未知}" "${port:-22}" "${user:-root}" "${domain:-未知}" "$status" "$deployed_time"
        count=$((count + 1))
    done
    if [ "$count" -eq 0 ]; then
        echoColor yellow "尚未添加 SSH 证书节点。"
        return 0
    fi
    echoColor purple "节点总数: ${count}"
    echoColor yellow "以上仅显示连接元数据，不显示部署私钥、Cloudflare Token 或其他凭据。"
}

exportCertificateManagerProfile() {
    local output temp_dir archive
    command -v gpg >/dev/null 2>&1 || return 1
    [ -f "$HIHY_CERT_MANAGER_CONFIG" ] && [ -f "$HIHY_CERT_TOKEN_FILE" ] || return 1
    temp_dir=$(mktemp -d "$HIHY_CERT_MANAGER_DIR/.profile-export.XXXXXX") || return 1
    chmod 700 "$temp_dir"
    mkdir -p "$temp_dir/profile/nodes"
    cp -a "$HIHY_CERT_MANAGER_CONFIG" "$temp_dir/profile/manager.conf"
    cp -a "$HIHY_CERT_TOKEN_FILE" "$temp_dir/profile/cloudflare.token"
    [ -f "$HIHY_CERT_DEPLOY_KEY" ] && cp -a "$HIHY_CERT_DEPLOY_KEY" "$temp_dir/profile/deploy_ed25519"
    [ -f "${HIHY_CERT_DEPLOY_KEY}.pub" ] && cp -a "${HIHY_CERT_DEPLOY_KEY}.pub" "$temp_dir/profile/deploy_ed25519.pub"
    [ -f "$HIHY_CERT_KNOWN_HOSTS" ] && cp -a "$HIHY_CERT_KNOWN_HOSTS" "$temp_dir/profile/known_hosts"
    cp -a "$HIHY_CERT_MANAGER_DIR"/nodes/. "$temp_dir/profile/nodes/" 2>/dev/null || true
    archive="$temp_dir/profile.tar.gz"
    tar -czf "$archive" -C "$temp_dir" profile || { rm -rf "$temp_dir"; return 1; }
    output="./hihy-cert-profile-$(getCertificateManagerValue domain)-$(date +%Y%m%d).gpg"
    echoColor yellow "请输入配置包加密口令，GPG 将要求确认。"
    if ! gpg --symmetric --cipher-algo AES256 --output "$output" "$archive"; then
        rm -rf "$temp_dir"
        return 1
    fi
    chmod 600 "$output"
    rm -rf "$temp_dir"
    echoColor green "加密配置包已导出: $output"
}

importCertificateManagerProfile() {
    local input="$1" temp_dir archive profile_dir
    command -v gpg >/dev/null 2>&1 || return 1
    if [ -z "$input" ]; then
        echoColor green "请输入 .gpg 配置包路径:"
        read -r input
    fi
    [ -f "$input" ] || return 1
    ensureCertificateManagerDirectories || return 1
    temp_dir=$(mktemp -d "$HIHY_CERT_MANAGER_DIR/.profile-import.XXXXXX") || return 1
    chmod 700 "$temp_dir"
    archive="$temp_dir/profile.tar.gz"
    gpg --output "$archive" --decrypt "$input" || { rm -rf "$temp_dir"; return 1; }
    tar -xzf "$archive" -C "$temp_dir" || { rm -rf "$temp_dir"; return 1; }
    profile_dir="$temp_dir/profile"
    [ -f "$profile_dir/manager.conf" ] && [ -f "$profile_dir/cloudflare.token" ] || { rm -rf "$temp_dir"; return 1; }
    command install -m 600 "$profile_dir/manager.conf" "$HIHY_CERT_MANAGER_CONFIG"
    command install -m 600 "$profile_dir/cloudflare.token" "$HIHY_CERT_TOKEN_FILE"
    [ -f "$profile_dir/deploy_ed25519" ] && command install -m 600 "$profile_dir/deploy_ed25519" "$HIHY_CERT_DEPLOY_KEY"
    [ -f "$profile_dir/deploy_ed25519.pub" ] && command install -m 644 "$profile_dir/deploy_ed25519.pub" "${HIHY_CERT_DEPLOY_KEY}.pub"
    [ -f "$profile_dir/known_hosts" ] && command install -m 600 "$profile_dir/known_hosts" "$HIHY_CERT_KNOWN_HOSTS"
    cp -a "$profile_dir"/nodes/. "$HIHY_CERT_MANAGER_DIR/nodes/" 2>/dev/null || true
    rm -rf "$temp_dir"
    verifyCloudflareToken || return 1
    echoColor green "证书中心配置导入完成。"
}

showCertificateManagerStatus() {
    local domain cert days issuer serial node_file name state
    domain=$(getCertificateManagerValue domain 2>/dev/null || getCertificateReceiverDomain 2>/dev/null || true)
    cert="$HIHY_SHARED_CERT_DIR/current/fullchain.pem"
    echoColor purple "证书角色: $(getCertificateManagerValue mode 2>/dev/null || echo receiver)"
    echoColor purple "主域名: ${domain:-未配置}"
    if [ -f "$cert" ]; then
        days=$(getCertificateDaysRemaining "$cert" 2>/dev/null || echo unknown)
        issuer=$(openssl x509 -in "$cert" -noout -issuer 2>/dev/null | sed 's/^issuer=//')
        serial=$(openssl x509 -in "$cert" -noout -serial 2>/dev/null | cut -d= -f2-)
        echoColor purple "剩余有效期: ${days} 天"
        echoColor purple "签发者: ${issuer}"
        echoColor purple "序列号: ${serial}"
        openssl x509 -in "$cert" -noout -fingerprint -sha256
    else
        echoColor yellow "尚未发布共享证书。"
    fi
    for node_file in "$HIHY_CERT_MANAGER_DIR"/nodes/*.conf; do
        [ -f "$node_file" ] || continue
        name=$(grep '^name=' "$node_file" | cut -d= -f2-)
        state="$HIHY_CERT_MANAGER_DIR/state/node-${name}.state"
        if [ -f "$state" ]; then
            echoColor yellow "节点 ${name}: $(grep '^status=' "$state" | cut -d= -f2-)"
        else
            echoColor yellow "节点 ${name}: 尚未分发"
        fi
    done
}

certificateManagerMenu() {
    echoColor purple "多服务器证书管理"
    echoColor purple "中心端负责申请通配符证书并分发；接收端负责接收并供本机 Hysteria 使用。"
    echoColor yellow "1) 设置本机为中心端(申请和分发证书)"
    echoColor yellow "2) 设置本机为接收端(接收中心端证书)"
    echoColor yellow "3) 申请/续期并发布通配符证书"
    echoColor yellow "4) 添加并初始化 SSH 节点"
    echoColor yellow "5) 删除节点"
    echoColor yellow "6) 向全部节点分发证书"
    echoColor yellow "7) 查看证书和节点状态"
    echoColor yellow "8) 导出 GPG 加密配置包"
    echoColor yellow "9) 导入 GPG 加密配置包"
    echoColor yellow "10) 查看所有 SSH 节点"
    echoColor yellow "0) 返回"
    read -r cert_choice
    case "$cert_choice" in
        1) initCertificateManager ;;
        2) initCertificateReceiver ;;
        3) issueOrRenewWildcardCertificate && deployCertificateToAllNodes ;;
        4) addCertificateNode ;;
        5) removeCertificateNode ;;
        6) deployCertificateToAllNodes ;;
        7) showCertificateManagerStatus ;;
        8) exportCertificateManagerProfile ;;
        9) importCertificateManagerProfile ;;
        10) showCertificateNodes ;;
        0) return 0 ;;
        *) return 1 ;;
    esac
}

show_menu() {
    secureHihyPermissions >/dev/null 2>&1 || true
    promptLegacyServiceMigration
    clear
    echo -e " -------------------------------------------"
    echo -e "|**********      Hi Hysteria       **********|"
    echo -e "|**********      Author: AI驱动      **********|"
    echo -e "|**********     Version: $(echoColor red "${hihyV}")    **********|"
    echo -e " -------------------------------------------"
    echo -e "Tips: $(echoColor green "hihy") 命令再次运行本脚本."
    echo -e "$(echoColor skyBlue ".............................................")"
    echo -e "$(echoColor purple "###############################")"

    echo -e "$(echoColor skyBlue ".....................")"
    echo -e "$(echoColor yellow "1)  安装 hysteria2")"
    echo -e "$(echoColor magenta "2)  卸载")"
    echo -e "$(echoColor skyBlue ".....................")"
    echo -e "$(echoColor yellow "3)  启动")"
    echo -e "$(echoColor magenta "4)  暂停")"
    echo -e "$(echoColor yellow "5)  重新启动")"
    echo -e "$(echoColor yellow "6)  运行状态")"
    echo -e "$(echoColor skyBlue ".....................")"
    echo -e "$(echoColor yellow "7)  更新Core")"
    echo -e "$(echoColor yellow "8)  查看当前配置")"
    echo -e "$(echoColor red "9)  重新配置")"
    echo -e "$(echoColor yellow "10) 切换ipv4/ipv6优先级")"
    echo -e "$(echoColor yellow "11) 更新hihy")"
    echo -e "$(echoColor lightMagenta "12) ACL域名分流")"
    echo -e "$(echoColor skyBlue "13) 查看hysteria2统计信息")"
    echo -e "$(echoColor yellow "14) 查看实时日志")"
    echo -e "$(echoColor yellow "15) 添加socks5出站[支持自动配置warp]")"
    echo -e "$(echoColor lightCyan "16) 多服务器证书管理")"

    echo -e "$(echoColor purple "###############################")"

    echo -e "$(echoColor magenta "0) 退出")"
    echo -e "$(echoColor skyBlue ".............................................")"
    echo -e ""
    hihy_update_notifycation
    echo -e "\n"
    startBackgroundVersionCheck
}

wait_for_continue() {
    echo -e "\n$(echoColor green "按任意键返回主菜单...")"
    read -r -n 1 -s
}

menu() {
    while true; do
        show_menu
        read -r -p "请选择: " input
        case $input in
            1)
                install
                exit $?
                ;;
            2)
                uninstall
                exit 0
                ;;
            3)
                start
                wait_for_continue
                ;;
            4)
                stop
                wait_for_continue
                ;;
            5)
                restart
                wait_for_continue
                ;;
            6)
                checkStatus
                wait_for_continue
                ;;
            7)
                updateHysteriaCore
                exit $?
                ;;
            8)
                generate_client_config
                wait_for_continue
                ;;
            9)
                changeServerConfig
                exit $?
                ;;
            10)
                changeIp64
                exit 0
                ;;
            11)
                hihyUpdate
                exit 0
                ;;
            12)
                aclControl
                exit 0
                ;;
            13)
                getHysteriaTrafic
                wait_for_continue
                ;;
            14)
                checkLogs
                exit 0
                ;;
            15)
                addSocks5Outbound
                exit 0
                ;;
            16)
                certificateManagerMenu
                wait_for_continue
                ;;
            0) exit 0 ;;
            *)
                echoColor red "Input Error !!!"
                wait_for_continue
                ;;
        esac
    done
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    checkRoot
    case "$1" in
        install | 1)
            echoColor purple "-> 1) 安装 hysteria"
            install
            ;;
        uninstall | 2)
            echoColor purple "-> 2) 卸载 hysteria"
            uninstall
            ;;
        start | 3)
            echoColor purple "-> 3) 启动 hysteria"
            start
            ;;
        stop | 4)
            echoColor purple "-> 4) 暂停 hysteria"
            stop
            ;;
        restart | 5)
            echoColor purple "-> 5) 重新启动 hysteria"
            restart
            ;;
        checkStatus | 6)
            echoColor purple "-> 6) 运行状态"
            checkStatus
            ;;
        updateHysteriaCore | 7)
            echoColor purple "-> 7) 更新Core"
            updateHysteriaCore
            ;;
        generate_client_config | 8)
            echoColor purple "-> 8) 查看当前配置"
            generate_client_config
            ;;
        changeServerConfig | 9)
            echoColor purple "-> 9) 重新配置"
            changeServerConfig
            ;;
        changeIp64 | 10)
            echoColor purple "-> 10) 切换ipv4/ipv6优先级"
            changeIp64
            ;;
        hihyUpdate | 11)
            echoColor purple "-> 11) 更新hihy"
            hihyUpdate
            ;;
        aclControl | 12)
            echoColor purple "-> 12) ACL管理"
            aclControl
            ;;
        getHysteriaTrafic | 13)
            echoColor purple "-> 13) 查看hysteria统计信息"
            getHysteriaTrafic
            ;;
        checkLogs | 14)
            echoColor purple "-> 14) 查看实时日志"
            checkLogs
            ;;
        addSocks5Outbound | 15)
            echoColor purple "-> 15) 添加socks5出站"
            addSocks5Outbound
            ;;
        cert | 16)
            case "$2" in
                manager-init) initCertificateManager ;;
                receiver-init) initCertificateReceiver "$3" ;;
                issue) issueOrRenewWildcardCertificate ;;
                renew-auto) renewAndDeployCertificates ;;
                deploy) deployCertificateToAllNodes ;;
                node-add) addCertificateNode ;;
                node-remove) removeCertificateNode ;;
                status) showCertificateManagerStatus ;;
                nodes) showCertificateNodes ;;
                export) exportCertificateManagerProfile ;;
                import) importCertificateManagerProfile "$3" ;;
                receive) receiveCertificatePackage ;;
                *) certificateManagerMenu ;;
            esac
            ;;
        migrate-service)
            if migrateLegacyService; then
                echoColor green "服务迁移完成。"
            else
                echoColor red "服务迁移失败或当前无需迁移。"
                exit 1
            fi
            ;;
        firewall-apply) applyNftOwnedRuleset ;;
        firewall-restore) restoreNftOwnedFirewall ;;
        cronTask) cronTask ;;
        *) menu ;;
    esac
fi
