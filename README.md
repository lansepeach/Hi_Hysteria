# Hi Hysteria

个人维护版 Hysteria2 一键安装与管理脚本，基于 [emptysuns/Hi_Hysteria](https://github.com/emptysuns/Hi_Hysteria) 修改，面向自用和学习场景。

当前脚本版本：`1.0.7`

[历史改进](md/log.md) | [Hysteria V1 版本](https://github.com/emptysuns/Hi_Hysteria/tree/v1)

## 简介

Hysteria2 是一个基于修改版 QUIC 协议的网络工具，适合研究高延迟、高抖动、丢包明显等网络环境下的传输优化方案。

本仓库提供一个交互式 Shell 脚本，用于快速安装、配置和管理 Hysteria2 服务端，并生成常见客户端配置。

> 本项目仅用于学习和研究网络环境优化方案。请遵守所在地区法律法规，禁止用于违法用途。由使用本项目引起的任何问题，作者不承担相关责任。

## 功能

- 安装、卸载、启动、停止、重启 Hysteria2
- 支持 ACME HTTP、ACME DNS、本地证书、自签证书
- 支持 Brutal / BBR / Reno 拥塞控制模式
- 支持 Hysteria2 原生端口跳跃/多端口范围监听
- 支持 masquerade：string / proxy / file
- 支持同时监听 TCP 端口增强伪装访问效果
- 支持 ACL 域名分流和屏蔽规则
- 支持生成 v2rayN、NekoBox、Clash Meta 等客户端配置
- 支持查看在线用户、流量统计、活动连接和实时日志
- 支持添加 socks5 出站，包括 WireProxy/WARP
- 支持安装失败状态恢复、后台版本检查和缓存提示
- 支持 Alpine、Arch、Debian、Ubuntu、RHEL、CentOS、Rocky Linux 等常见发行版
- 支持 x86_64、i386/i686、aarch64/arm64、armv7、s390x、ppc64le、loongarch64 等架构

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
hihy 10           # 切换 IPv4 / IPv6 优先级
hihy 11           # 更新 hihy 脚本
hihy 12           # ACL 域名分流管理
hihy 13           # 查看统计信息
hihy 14           # 查看实时日志
hihy 15           # 添加 socks5 出站
```

## 文档

- [防火墙问题](md/firewall.md)
- [自签证书](md/certificate.md)
- [UDP 服务商排雷列表](md/blacklist.md)
- [延迟和上下行速度设置](md/speed.md)
- [支持的客户端](md/client.md)
- [常见问题](md/issues.md)
- [伪装网站](md/masquerade.md)

## 更新说明

脚本更新后，建议运行：

```bash
hihy 9
```

重新生成服务端配置，以便使用新版脚本支持的新参数和新默认值。

## 鸣谢

- [apernet/hysteria](https://github.com/apernet/hysteria)
- [emptysuns/Hi_Hysteria](https://github.com/emptysuns/Hi_Hysteria)
- [2dust/v2rayN](https://github.com/2dust/v2rayN)
- [MetaCubeX/Clash.Meta](https://github.com/MetaCubeX/Clash.Meta)
- [fscarmen/warp](https://gitlab.com/fscarmen/warp)
