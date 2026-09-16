# ECH 与 Hysteria v2.12.3

脚本 1.0.17 支持 ECH（Encrypted Client Hello），用来加密 QUIC/TLS 握手中的真实 SNI。外层公开域名仍以明文可见。ECH 默认关闭，适合未开启 Salamander/Gecko 混淆的连接；已开启混淆时通常没有额外收益。

## 升级核心

更新脚本后运行 `hihy 7`。脚本从 HyNetworks/hysteria 获取最新正式版，优先验证 GitHub 资产的 SHA-256；API 限流或未提供摘要时，改用官方 `hashes.txt`，无法取得校验值则停止更新。校验核心可执行版本后才替换文件和重启原服务。下载超时默认为 180 秒，可通过 `HIHY_CORE_DOWNLOAD_TIMEOUT` 调整。

运行中的服务会在替换后启动，并持续 5 秒检查进程是否存活、是否发生重启；启动失败则恢复旧核心并尝试启动。此检查不能替代客户端连通性测试。原本停止的服务会保持停止。旧核心保存在 `/etc/hihy/bin/appS.rollback`，下一次升级会替换这份备份。更新使用目录锁防止并发替换；若进程被强制终止而遗留 `.core-update.lock`，先确认没有更新任务仍在执行，再清理这个空锁目录。

v2.12.3 修复了 Linux 原生端口跳跃错误重定向本机出站 UDP 的问题。仅获取该修复无需运行 `hihy 9`。明文 HTTP 经 HTTP 代理传输超过 10 秒断开的修复位于客户端，需更新相应客户端核心。

## 开启 ECH

运行 `hihy 9` 重新配置（会重新询问其他服务端设置），在 ECH 提示中选择启用，填写外层公开域名，例如 `decoy.example.com`。生成命令要求核心 v2.12.3 或更高版本。

脚本把密钥保存到 `/etc/hihy/cert/ech.pem`，权限为 `600`，并写入服务端配置：

```yaml
ech:
  keyPath: /etc/hihy/cert/ech.pem
```

ECH 不替代现有 TLS 证书，也不改变客户端用于验证证书的真实 `tls.sni`。开启 ECH 的服务端仍允许普通客户端连接；这不意味着普通客户端也获得了 ECH 保护。

## 客户端导出

`hihy 8` 导出原生 Hysteria YAML 的 `tls.ech`，以及分享 URI 的 `ech` 参数。只导出公开的配置列表，不导出私钥。使用支持 ECH 的 Hysteria 客户端核心，并确认第三方应用导入时不会丢弃该参数。

ECH 模式暂不生成 Clash Meta 配置，避免未经验证的参数兼容性问题。此前生成的 Clash Meta 文件不会自动删除，也不会自动获得 ECH；请使用本次生成的原生 YAML。Realms 模式仍使用原生 YAML，不生成分享 URI。

## 密钥保留与关闭

重新配置已启用 ECH 的服务时，默认保留 ECH 并复用原密钥。关闭 ECH 不删除密钥；再次开启时复用脚本保存的密钥。不要把完整的 `ech.pem` 发给客户端，其中的 `ECH KEYS` 是私钥。

不要直接覆盖正在使用的密钥。轮换后必须向客户端分发新的公开配置；当服务端不再接受旧配置时，旧客户端配置会连接失败。客户端设置了 ECH 而服务端拒绝时，不会静默降级，`tls.insecure` 也不能绕过 ECH 拒绝。

手动提供密钥时，使用绝对 `ech.keyPath`，并确保文件包含有效的 `ECH CONFIGS` 公共配置块（官方生成命令默认包含）。脚本不会在找不到原密钥时自动轮换。

参考：[v2.12.3 发布说明](https://github.com/HyNetworks/hysteria/releases/tag/app%2Fv2.12.3)、[官方 ECH 文档](https://hysteria.network/zh/docs/advanced/ECH/)。

## 验证与已知上游日志问题

仓库回归测试：`bash tests/hy2_regression.sh`（需要 Bash、yq v4、常用 Linux 工具）。真实核心联调：`python3 tests/ech_integration.py /path/to/hysteria`（另需 Python 3 和 openssl），仅使用临时目录及本机回环地址。若机器已有端口跳跃规则，可通过 `HIHY_TEST_UDP_PORT` 指定规则范围外的空闲 UDP 端口。

v2.12.3 默认 ChromeParrot 路径的客户端日志可能显示 `ech: false`：其 quic-go 的 [uTLS 状态转换](https://github.com/apernet/quic-go/blob/73339f7edbb9/internal/handshake/tls_conn_utls.go) 没有复制 `ECHAccepted` 字段。因此不能单凭这个日志字段判断 ECH 是否生效。联调测试覆盖默认路径的匹配密钥通信及错误密钥拒绝，并通过标准 TLS 路径确认 `ech: true`。脚本保留核心的默认 ChromeParrot 设置。
