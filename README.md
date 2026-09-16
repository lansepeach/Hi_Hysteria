# Hi Hysteria

个人维护版 Hysteria2 一键安装与管理脚本，基于 [emptysuns/Hi_Hysteria](https://github.com/emptysuns/Hi_Hysteria) 修改，面向自用和学习场景。

当前脚本版本：`1.0.19`

[历史改进](md/log.md) | [Hysteria V1 版本](https://github.com/emptysuns/Hi_Hysteria/tree/v1)

## 简介

Hysteria2 是一个基于修改版 QUIC 协议的网络工具，适合研究高延迟、高抖动、丢包明显等网络环境下的传输优化方案。

本仓库提供一个交互式 Shell 脚本，用于快速安装、配置和管理 Hysteria2 服务端，并生成常见客户端配置。

> 本项目仅用于学习和研究网络环境优化方案。请遵守所在地区法律法规，禁止用于违法用途。由使用本项目引起的任何问题，作者不承担相关责任。

## 功能

- 安装、卸载、启动、停止、重启 Hysteria2
- 支持 ACME HTTP、ACME DNS、本地证书、自签证书
- ACME DNS 支持 Cloudflare、Duck DNS、Gandi、GoDaddy、Namecheap、Njalla、Porkbun、Vultr
- 支持中心端申请通配符证书，并通过受限 SSH 自动分发给多台接收端服务器
- 支持可选 ECH：内置密钥生成、密钥复用、原生客户端配置和分享链接导出
- 支持 Brutal / BBR / Reno 拥塞控制模式
- 支持 Hysteria2 原生端口跳跃/多端口范围监听
- 支持 masquerade：string / proxy / file
- 支持同时监听 TCP 端口增强伪装访问效果
- 支持 ACL 域名分流和屏蔽规则
- 支持生成 v2rayN、NekoBox、Clash Meta 等客户端配置
- 支持查看在线用户、流量统计、活动连接和实时日志
- 支持添加 socks5 出站，包括 WireProxy/WARP
- 支持安装失败状态恢复、后台版本检查和缓存提示
- 核心更新强制校验 SHA-256，检查启动稳定性，失败时回滚，并保留原服务启停状态
- 支持 Alpine、Arch、Debian、Ubuntu、RHEL、CentOS、Rocky Linux 等常见发行版
- 支持 x86_64、i386/i686、aarch64/arm64、ARMv6/ARMv7、MIPSLE、RISC-V、s390x、loongarch64 等官方发布架构
- ARMv5 核心可用，但需预装兼容该 CPU 的 yq v4；官方当前 yq ARM 包要求 ARMv6
- systemd 系统使用原生服务，旧版 rc.local/SysV 安装可确认后安全迁移
- 防火墙规则采用所有权记录，卸载只删除脚本实际新增的规则
- 重新配置失败时恢复旧配置、证书与防火墙；恢复不完整时保留备份
- 证书定时任务独立检查续期和分发，自动重试失败节点
- 端口跳跃优先使用 Hysteria 官方内置端口范围和自动重定向

## 安装

切换到完整 root 环境：

```bash
su - root
```

执行安装脚本：

```bash
bash <(curl -fsSL https://github.com/lansepeach/Hi_Hysteria/raw/refs/heads/main/server/install.sh)
```

安装完成后运行：

```bash
hihy
```

## 常用命令

```bash
hihy              # 打开交互菜单
hihy install      # 安装 Hysteria2
hihy uninstall    # 卸载
hihy start        # 启动
hihy stop         # 停止
hihy restart      # 重启
hihy 6            # 查看运行状态
hihy 7            # 更新 Hysteria2 Core
hihy 8            # 查看/重新生成客户端配置
hihy 9            # 重新配置服务端
hihy 10           # 切换自动、IPv4/IPv6 优先或仅 IPv4/IPv6 出口
hihy 11           # 更新 hihy 脚本
hihy 12           # ACL 域名分流管理
hihy 13           # 查看统计信息
hihy 14           # 查看实时日志
hihy 15           # 添加 socks5 出站
hihy 16           # 多服务器证书管理（中心端申请、接收端部署）
hihy cert status  # 查看通配符证书和节点部署状态
hihy cert nodes   # 查看所有 SSH 证书节点
hihy migrate-service # 将旧版启动方式迁移到原生 systemd
```

脚本更新完成后会自动重新载入新版菜单。远程版本由仓库根目录的 `VERSION` 提供，完整脚本下载失败时不会覆盖当前安装。

## 文档

- [防火墙问题](md/firewall.md)
- [证书配置与多服务器分发](md/certificate.md)
- [ECH 配置与 v2.12.3 升级](md/ech.md)
- [UDP 服务商排雷列表](md/blacklist.md)
- [延迟和上下行速度设置](md/speed.md)
- [支持的客户端](md/client.md)
- [常见问题](md/issues.md)
- [伪装网站](md/masquerade.md)

## 更新说明

升级至本版脚本后，先运行 `hihy 7` 更新核心（建议 v2.12.3 或更高版本）。仅获取端口跳跃修复不需要重新配置。

如需启用 ECH 或修改其他配置，再运行：

```bash
hihy 9
```

重新生成服务端配置，以便使用新版脚本支持的新参数和新默认值。

## 鸣谢

- [HyNetworks/hysteria](https://github.com/HyNetworks/hysteria)
- [emptysuns/Hi_Hysteria](https://github.com/emptysuns/Hi_Hysteria)
- [2dust/v2rayN](https://github.com/2dust/v2rayN)
- [MetaCubeX/Clash.Meta](https://github.com/MetaCubeX/Clash.Meta)
- [fscarmen/warp](https://gitlab.com/fscarmen/warp)

## 开发验证

```bash
bash tests/hy2_regression.sh
bash tests/reliability_regression.sh
sudo env "PATH=$PATH" bash tests/nft_integration.sh
python3 tests/ech_integration.py /path/to/hysteria
```

测试使用临时目录、模拟服务/ACME/SSH 和回环连接，需要 Bash、yq v4、Python 3、openssl 与常见 Linux 工具。GitHub Actions 会在 push 和 pull request 时自动执行这些检查，不会调用生产节点或申请真实证书。

nftables 集成测试还需要 root、nftables、iproute2 和网络命名空间支持；它在独立网络命名空间内验证 IPv4/IPv6 通流、重载及卸载清理，不修改主机防火墙。
