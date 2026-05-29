#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
optimize_hihy.py

用途：
1. 读取 server/hy2.sh
2. 将后续升级检测、自更新源切换到 https://github.com/lansepeach/Hi_Hysteria
3. 优化部分下载逻辑
4. 修复 getLatestHihyVersion 对“第二行版本号”的脆弱依赖
5. 修复 hihyUpdate 先删旧文件再下载新文件的问题
6. 修复 BBR 预设选择 bug
7. 去掉 --no-check-certificate
8. 输出 server/hy2.optimized.sh

运行：
    python3 optimize_hihy.py

之后检查：
    bash -n server/hy2.optimized.sh

确认无误后覆盖：
    cp server/hy2.sh server/hy2.sh.bak
    mv server/hy2.optimized.sh server/hy2.sh
    chmod +x server/hy2.sh
"""

from pathlib import Path
import re
import sys

# ===== 你自己的仓库配置 =====
REPO_OWNER = "lansepeach"
REPO_NAME = "Hi_Hysteria"
REPO_BRANCH = "main"

# 如果你的主脚本路径是 server/hy2.sh，就保持这个。
# 如果你想让 hihy 自更新拉 server/install.sh，就改成 "server/install.sh"。
REMOTE_SCRIPT_PATH = "server/hy2.sh"

ROOT = Path(".")
SRC = ROOT / "server" / "hy2.sh"
OUT = ROOT / "server" / "hy2.optimized.sh"

def die(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)

def replace_bash_function(text: str, func_name: str, new_func: str) -> str:
    """
    替换 Bash 函数：
        name() {
            ...
        }

    用括号计数而不是简单正则，避免函数体里有嵌套 case/if/heredoc 时误判。
    但它不是完整 Bash parser，足够处理普通函数替换。
    """
    pattern = re.compile(rf'(^|\n){re.escape(func_name)}\s*\(\)\s*\{{', re.M)
    match = pattern.search(text)

    if not match:
        print(f"WARN: 未找到函数 {func_name}，跳过替换")
        return text

    start = match.start()
    brace_start = text.find("{", match.start())

    if brace_start == -1:
        print(f"WARN: 函数 {func_name} 格式异常，跳过替换")
        return text

    i = brace_start
    depth = 0
    in_single = False
    in_double = False
    escaped = False

    while i < len(text):
        ch = text[i]

        if escaped:
            escaped = False
            i += 1
            continue

        if ch == "\\":
            escaped = True
            i += 1
            continue

        if ch == "'" and not in_double:
            in_single = not in_single
            i += 1
            continue

        if ch == '"' and not in_single:
            in_double = not in_double
            i += 1
            continue

        if not in_single and not in_double:
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    end = i + 1

                    # 把函数后的换行也吃掉，避免多空行
                    if end < len(text) and text[end] == "\n":
                        end += 1

                    return text[:start] + "\n" + new_func.strip() + "\n" + text[end:]

        i += 1

    print(f"WARN: 无法定位函数 {func_name} 的结束位置，跳过替换")
    return text

def patch_top_repo_config(text: str) -> str:
    """
    替换顶部远程脚本 URL 配置。
    """
    repo_block = f'''# ===== 自维护仓库配置 =====
HIHY_REPO_OWNER="${{HIHY_REPO_OWNER:-{REPO_OWNER}}}"
HIHY_REPO_NAME="${{HIHY_REPO_NAME:-{REPO_NAME}}}"
HIHY_REPO_BRANCH="${{HIHY_REPO_BRANCH:-{REPO_BRANCH}}}"
HIHY_REMOTE_SCRIPT_PATH="${{HIHY_REMOTE_SCRIPT_PATH:-{REMOTE_SCRIPT_PATH}}}"

HIHY_REPO_URL="${{HIHY_REPO_URL:-https://github.com/${{HIHY_REPO_OWNER}}/${{HIHY_REPO_NAME}}}}"
HIHY_REMOTE_SCRIPT_URL="${{HIHY_REMOTE_SCRIPT_URL:-https://raw.githubusercontent.com/${{HIHY_REPO_OWNER}}/${{HIHY_REPO_NAME}}/refs/heads/${{HIHY_REPO_BRANCH}}/${{HIHY_REMOTE_SCRIPT_PATH}}}}"
HIHY_REMOTE_SCRIPT_MIRROR_URL="${{HIHY_REMOTE_SCRIPT_MIRROR_URL:-https://cdn.jsdelivr.net/gh/${{HIHY_REPO_OWNER}}/${{HIHY_REPO_NAME}}@${{HIHY_REPO_BRANCH}}/${{HIHY_REMOTE_SCRIPT_PATH}}}}"
'''

    # 优先替换原来的两行 URL
    new_text, count = re.subn(
        r'^HIHY_REMOTE_SCRIPT_URL=.*\nHIHY_REMOTE_SCRIPT_MIRROR_URL=.*\n',
        repo_block + "\n",
        text,
        flags=re.M,
    )

    if count > 0:
        return new_text

    # 如果没找到旧 URL，就插入到 HIHY_RC_LOCAL 后面
    new_text, count = re.subn(
        r'^(HIHY_RC_LOCAL=.*\n)',
        r'\1' + repo_block + "\n",
        text,
        flags=re.M,
    )

    if count == 0:
        print("WARN: 没找到 HIHY_RC_LOCAL，也没找到旧远程 URL。将尝试插入到 hihyV 后面。")
        new_text, count = re.subn(
            r'^(hihyV=.*\n)',
            r'\1\n' + repo_block + "\n",
            text,
            flags=re.M,
        )

    if count == 0:
        print("WARN: 顶部仓库配置插入失败，请手动检查。")

    return new_text

def global_simple_patches(text: str) -> str:
    """
    做简单全局替换。
    """
    # 去掉危险的 TLS 跳过校验参数
    text = text.replace("--no-check-certificate ", "")
    text = text.replace(" --no-check-certificate", "")
    text = text.replace("--no-check-certificate", "")

    # 替换原作者仓库链接为变量
    text = text.replace(
        "https://github.com/emptysuns/Hi_Hysteria/blob/main/md/client.md",
        "${HIHY_REPO_URL}/blob/${HIHY_REPO_BRANCH}/md/client.md",
    )
    text = text.replace(
        "https://github.com/emptysuns/Hi_Hysteria/issues",
        "${HIHY_REPO_URL}/issues",
    )
    text = text.replace(
        "https://github.com/emptysuns/Hi_Hysteria/",
        "${HIHY_REPO_URL}/",
    )
    text = text.replace(
        "https://github.com/emptysuns/Hi_Hysteria",
        "${HIHY_REPO_URL}",
    )

    # 替换硬编码 raw/cdn 源
    text = text.replace(
        "https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/refs/heads/main/server/hy2.sh",
        "${HIHY_REMOTE_SCRIPT_URL}",
    )
    text = text.replace(
        "https://cdn.jsdelivr.net/gh/emptysuns/Hi_Hysteria@main/server/hy2.sh",
        "${HIHY_REMOTE_SCRIPT_MIRROR_URL}",
    )

    # 修复错误 echoColor 调用
    text = text.replace(
        'echoColor "如果需求上无法关闭 ${1}/${2}端口，请使用其他证书获取方式"',
        'echoColor yellow "如果需求上无法关闭 ${1}/${2}端口，请使用其他证书获取方式"',
    )

    # 修复 BBR 预设选择 bug，兼容不同缩进
    text = re.sub(
        r'''case\s+\$\{bbr_profile_num\}\s+in
(\s*)2\)\s*congestion_bbr_profile="conservative"\s*;;
(\s*)3\)\s*congestion_bbr_profile="aggressive"\s*;;
(\s*)\*\)\s*congestion_bbr_profile="standard"\s*;;
\s*esac''',
        r'''case "${bbr_profile_num}" in
\g<1>1) congestion_bbr_profile="conservative" ;;
\g<2>3) congestion_bbr_profile="aggressive" ;;
\g<3>*) congestion_bbr_profile="standard" ;;
        esac''',
        text,
    )

    # crontab 去重，能匹配就改，匹配不到也不强制
    text = text.replace(
        '''crontab -l >./crontab.tmp 2>/dev/null || touch ./crontab.tmp
echo "15 4 * * 1 hihy cronTask" >>./crontab.tmp
crontab ./crontab.tmp
rm ./crontab.tmp''',
        '''crontab -l >./crontab.tmp 2>/dev/null || touch ./crontab.tmp
if ! grep -qF "hihy cronTask" ./crontab.tmp; then
    echo "15 4 * * 1 hihy cronTask" >>./crontab.tmp
fi
crontab ./crontab.tmp
rm -f ./crontab.tmp''',
    )

    # 如果是从聊天复制导致 URL 带尖括号，只移除 URL 外层尖括号，例如 <https://example.com>
    # 不要全局删除 >，否则会破坏 Bash 重定向符号 >/dev/null 2>&1
    text = re.sub(r'<(https?://[^>\\s]+)>', r'\\1', text)

    return text

NEW_DOWNLOAD_TO_FILE = r'''
downloadToFile() {
    local url="$1"
    local output_path="$2"
    local tmp_path="${output_path}.tmp.$$"

    rm -f "$tmp_path"

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

    mv "$tmp_path" "$output_path"
}
'''

NEW_INSTALL_HIHY_LAUNCHER = r'''
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
'''

NEW_FETCH_REMOTE_BODY = r'''
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
'''

NEW_GET_LATEST_HIHY_VERSION = r'''
getLatestHihyVersion() {
    local content
    local version

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
'''

NEW_DISPLAY_CACHED_VERSION_NOTIFICATIONS = r'''
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
'''

NEW_HELPERS = r'''
is_uint() {
    echo "$1" | grep -Eq '^[0-9]+$'
}

validate_port() {
    local p="$1"
    is_uint "$p" && [ "$p" -ge 1 ] && [ "$p" -le 65535 ]
}
'''

NEW_SHOULD_START_VERSION_CHECK = r'''
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
'''

NEW_REFRESH_VERSION_CHECK_STATE = r'''
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
'''

NEW_HIHY_UPDATE = r'''
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

    if ! downloadToFile "$HIHY_REMOTE_SCRIPT_URL" "$tmp_file"; then
        if ! downloadToFile "$HIHY_REMOTE_SCRIPT_MIRROR_URL" "$tmp_file"; then
            rm -f "$tmp_file"
            echoColor red "hihy 更新失败，请检查网络或写入权限。"
            exit 1
        fi
    fi

    chmod 755 "$tmp_file"
    mv "$tmp_file" "$HIHY_BIN_LINK"

    rm -f "$HIHY_VERSION_STATUS_FILE"

    echoColor green "hihy 更新完成。"
    echoColor purple "更新来源: ${HIHY_REPO_URL}"
}
'''

NEW_DOWNLOAD_HYSTERIA_CORE = r'''
downloadHysteriaCore() {
    local version
    version=$(getLatestHysteriaVersion)

    echo -e "The Latest hysteria version: $(echoColor red "${version}")\nDownload..."

    if [ -z "$version" ]; then
        echoColor red "[Network error]: Failed to get the latest version of hysteria in Github!"
        exit 1
    fi

    local arch
    arch=$(uname -m)

    local url_base="https://github.com/apernet/hysteria/releases/download/${version}/hysteria-linux-"
    local download_url=""

    case "$arch" in
        "x86_64")
            download_url="${url_base}amd64"
            ;;
        "aarch64")
            download_url="${url_base}arm64"
            ;;
        "mips64")
            download_url="${url_base}mipsle"
            ;;
        "s390x")
            download_url="${url_base}s390x"
            ;;
        "i686" | "i386")
            download_url="${url_base}386"
            ;;
        "loongarch64")
            download_url="${url_base}loong64"
            ;;
        *)
            echoColor yellowBlack "Error[OS Message]:${arch}\nPlease open an issue at ${HIHY_REPO_URL}/issues !"
            exit 1
            ;;
    esac

    mkdir -p /etc/hihy/bin

    if ! downloadToFile "$download_url" "/etc/hihy/bin/appS"; then
        echoColor red "Network Error: Can't download Hysteria core!"
        exit 1
    fi

    chmod 755 /etc/hihy/bin/appS
    echoColor purple "\nDownload completed."
}
'''

def main() -> None:
    if not SRC.exists():
        die(f"找不到 {SRC}。请确认你在仓库根目录运行，并且 server/hy2.sh 已存在。")

    text = SRC.read_text(encoding="utf-8", errors="replace")

    print(f"读取：{SRC}")

    text = patch_top_repo_config(text)
    text = global_simple_patches(text)

    # 插入 helper，避免重复插入
    if "validate_port()" not in text:
        if "shouldStartVersionCheck() {" in text:
            text = text.replace(
                "shouldStartVersionCheck() {",
                NEW_HELPERS.strip() + "\n\nshouldStartVersionCheck() {",
                1,
            )
        else:
            print("WARN: 未找到 shouldStartVersionCheck，无法自动插入 is_uint/validate_port")

    # 替换重点函数
    function_replacements = {
        "downloadToFile": NEW_DOWNLOAD_TO_FILE,
        "installHihyLauncher": NEW_INSTALL_HIHY_LAUNCHER,
        "fetchRemoteBodyFromSources": NEW_FETCH_REMOTE_BODY,
        "getLatestHihyVersion": NEW_GET_LATEST_HIHY_VERSION,
        "displayCachedVersionNotifications": NEW_DISPLAY_CACHED_VERSION_NOTIFICATIONS,
        "shouldStartVersionCheck": NEW_SHOULD_START_VERSION_CHECK,
        "refreshVersionCheckState": NEW_REFRESH_VERSION_CHECK_STATE,
        "hihyUpdate": NEW_HIHY_UPDATE,
        "downloadHysteriaCore": NEW_DOWNLOAD_HYSTERIA_CORE,
    }

    for name, new_func in function_replacements.items():
        text = replace_bash_function(text, name, new_func)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding="utf-8")
    OUT.chmod(0o755)

    print()
    print(f"完成：已生成 {OUT}")
    print()
    print("下一步建议执行：")
    print(f"  bash -n {OUT}")
    print()
    print("如果没有报错，再执行：")
    print(f"  cp {SRC} {SRC}.bak")
    print(f"  mv {OUT} {SRC}")
    print(f"  chmod +x {SRC}")
    print()
    print("检查更新源：")
    print(f"  grep -n \"lansepeach\\|HIHY_REPO_URL\\|HIHY_REMOTE_SCRIPT_URL\" {SRC}")
    print()
    print("提交上传：")
    print("  git add server/hy2.sh")
    print("  git commit -m \"Switch hihy update source to lansepeach repo\"")
    print("  git push")

if __name__ == "__main__":
    main()
