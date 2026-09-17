#!/bin/bash

set -e

echo -e "Downloading hihy (Hysteria2)..."

HIHY_URL="${HIHY_URL:-https://raw.githubusercontent.com/lansepeach/Hi_Hysteria/refs/heads/main/server/hy2.sh}"
HIHY_BIN="${HIHY_BIN:-/usr/bin/hihy}"
HIHY_TMP=""

cleanup() {
    if [ -n "$HIHY_TMP" ]; then
        rm -f "$HIHY_TMP" || true
    fi
    return 0
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: 请使用 root 权限运行"
    exit 1
fi

HIHY_TMP=$(mktemp "$(dirname "$HIHY_BIN")/.hihy.tmp.XXXXXX")

if command -v curl >/dev/null 2>&1; then
    curl -fL --connect-timeout 5 --max-time 30 -o "$HIHY_TMP" "$HIHY_URL"
elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$HIHY_TMP" "$HIHY_URL"
else
    echo "ERROR: 未找到 curl 或 wget"
    exit 1
fi

if [ ! -s "$HIHY_TMP" ] || ! bash -n "$HIHY_TMP" || \
    ! grep -qE '^[[:space:]]*hihyV=' "$HIHY_TMP" || \
    ! grep -qF 'checkRoot()' "$HIHY_TMP"; then
    echo "ERROR: 下载的 hihy 脚本校验失败，保留现有安装"
    exit 1
fi

chmod 755 "$HIHY_TMP"
mv -f "$HIHY_TMP" "$HIHY_BIN"
HIHY_TMP=""

"$HIHY_BIN"
