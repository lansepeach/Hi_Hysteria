#!/usr/bin/env python3
"""Retired one-time migration tool; current server/hy2.sh includes these fixes."""
import sys


def main() -> int:
    print(
        "此历史迁移工具已停用：当前 server/hy2.sh 已包含相关优化。\n"
        "旧版替换模板会移除下载校验和更新保护，因此不再生成 optimized 脚本。\n"
        "请直接使用并维护 server/hy2.sh，不要用历史生成文件覆盖它。",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
