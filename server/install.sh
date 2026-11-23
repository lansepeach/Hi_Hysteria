#!/bin/bash

set -e
umask 077

case "${1:-}" in
    "" | --upgrade) [ "$#" -le 1 ] || exit 1 ;;
    --help) printf '用法: bash install.sh [--upgrade]\n--upgrade 只更新管理脚本，不打开菜单或更改服务。\n'; exit 0 ;;
    *) printf '未知参数: %s（使用 --help 查看用法）\n' "$1" >&2; exit 1 ;;
esac

HIHY_URL="${HIHY_URL:-https://raw.githubusercontent.com/lansepeach/Hi_Hysteria/refs/heads/main/server/hy2.sh}"
HIHY_BIN="${HIHY_BIN:-${HIHY_BIN_LINK:-/usr/bin/hihy}}"
HIHY_ROOT_DIR="${HIHY_ROOT_DIR:-/etc/hihy}"

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: 请使用 root 权限运行"
    exit 1
fi

installLauncher() (
    local stage="" lock="${HIHY_ROOT_DIR}.operation.lock" version old_version newest
    if ! mkdir -m 700 -- "$lock" 2>/dev/null; then
        echo "ERROR: 无法获取 hihy 操作锁：$lock。请确认没有其他 hihy 任务正在运行。" >&2
        return 1
    fi
    trap 'if [ -n "$stage" ]; then rm -rf -- "$stage"; fi; rm -f -- "$lock/pid"; rmdir -- "$lock"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    printf '%s\n' "$BASHPID" >"$lock/pid" || return 1
    stage=$(mktemp -d "$(dirname "$HIHY_BIN")/.hihy-upgrade.XXXXXX") || return 1

    echo "正在下载 hihy 管理脚本 (Hysteria2)..."
    if command -v curl >/dev/null 2>&1; then
        curl -fL --connect-timeout 5 --max-time 30 -o "$stage/hihy" "$HIHY_URL" || return 1
    elif command -v wget >/dev/null 2>&1; then
        wget -q -T 30 -O "$stage/hihy" "$HIHY_URL" || return 1
    else
        echo "ERROR: 未找到 curl 或 wget" >&2
        return 1
    fi

    version=$(sed -nE 's/^hihyV="(ver[0-9]+\.[0-9]+)"$/\1/p' "$stage/hihy") || return 1
    if [[ ! "$version" =~ ^ver[0-9]+\.[0-9]+$ ]] || ! bash -n "$stage/hihy" ||
        ! grep -qF 'checkRoot()' "$stage/hihy" || ! grep -qF 'menu()' "$stage/hihy"; then
        echo "ERROR: 下载的 hihy 脚本校验失败，保留现有安装" >&2
        return 1
    fi

    chmod 755 "$stage/hihy" || return 1
    if [ -e "$HIHY_BIN" ]; then
        [ -f "$HIHY_BIN" ] || { echo "ERROR: 启动器路径不是普通文件：$HIHY_BIN" >&2; return 1; }
        old_version=$(sed -nE 's/^hihyV="(ver[0-9]+\.[0-9]+)"$/\1/p; s/^hihyV="([0-9]+)\.0\.([0-9]+)"$/ver\1.\2/p' "$HIHY_BIN") || return 1
        if [[ "$old_version" =~ ^ver[0-9]+\.[0-9]+$ ]]; then
            newest=$(printf '%s\n' "$old_version" "$version" | sort -V | tail -n 1) || return 1
            if [ "$newest" != "$version" ]; then
                echo "ERROR: 下载版本 $version 低于已安装的 $old_version，拒绝降级。" >&2
                return 1
            fi
        fi
        if [ -x "$HIHY_BIN" ] && cmp -s "$stage/hihy" "$HIHY_BIN"; then
            echo "hihy $version 启动器已是该版本，无需替换。"
            return 0
        fi
        cp -pL -- "$HIHY_BIN" "$stage/previous" &&
            mv -Tf -- "$stage/previous" "$HIHY_BIN.previous" || return 1
        echo "旧脚本备份：$HIHY_BIN.previous"
    fi
    mv -Tf -- "$stage/hihy" "$HIHY_BIN" || return 1
    echo "hihy $version 已就绪。原有服务、配置和核心未修改。"
)

installLauncher
if [ "${1:-}" != --upgrade ]; then
    HIHY_BIN_LINK="$HIHY_BIN" exec "$HIHY_BIN"
fi
