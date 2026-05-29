#!/bin/bash

set -e

echo -e "Downloading hihy (Hysteria2)..."

HIHY_URL="https://raw.githubusercontent.com/lansepeach/Hi_Hysteria/refs/heads/main/server/hy2.sh"
HIHY_BIN="/usr/bin/hihy"

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: 请使用 root 权限运行"
    exit 1
fi

if command -v curl >/dev/null 2>&1; then
    curl -fL -o "$HIHY_BIN" "$HIHY_URL"
elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$HIHY_BIN" "$HIHY_URL"
else
    echo "ERROR: 未找到 curl 或 wget"
    exit 1
fi

chmod +x "$HIHY_BIN"

"$HIHY_BIN"
