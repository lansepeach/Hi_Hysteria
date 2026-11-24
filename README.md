# Hi Hysteria

个人维护版 Hysteria2 一键安装与管理脚本，基于 [emptysuns/Hi_Hysteria](https://github.com/emptysuns/Hi_Hysteria) 修改，面向自用和学习场景。

当前脚本版本：`1.0.32`

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
- 支持实时监控：按客户端来源 IP 显示连接数、流量、速率、TCP 访问目标与时间
- 安装/卸载需输入确认词；已有配置阻止重装，并防止多个终端同时安装或卸载
- 证书管理支持节点防覆盖、删除确认、分发结果汇总和仅重试未同步节点
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

### 安装中断后怎么继续？

如果域名、端口和密码已经保存，但启动服务或生成客户端文件时失败，**不要先卸载**。先看终端报错；服务安装失败的日志通常在 `/etc/hihy/result/service-install.log`，systemd 主机也可以用 `journalctl -u hihy.service -n 50 --no-pager` 查看原因。处理报错后，用 root 执行：

```bash
hihy repair-install
```

输入 `REPAIR` 才会继续。此命令只处理脚本已记录的启动器、服务或安装收尾失败，不会重新下载核心、重跑配置向导或更换端口和密码。若服务尚未就绪，修复会启动或重启它；如果只是导出失败且服务仍正常运行，则不重启。成功后用 `hihy 6` 查看状态，用 `hihy 8` 查看客户端配置。

如果提示核心或配置缺失、安装阶段无法自动恢复，请先保留 `/etc/hihy` 和终端报错，按提示排查；重复跑 `hihy install` 不会覆盖已存在的配置。

## 从旧版升级（不重装）

如果服务器已经在跑 **Hysteria 2**，不要卸载，也不用重新输入域名、端口或密码。升级分三件事：更新 **hihy 管理脚本**、更新 **Hysteria 内核**、迁移 **开机启动方式**。下面先做第一件，后两件按需操作。

### 菜单能更新：直接用选项 11

如果旧脚本的更新地址已经指向本仓库，切到 root 后运行 `hihy 11`。升级完成后会载入新版菜单；不会重启当前服务，也不会改端口、防火墙、证书或客户端配置。

### 菜单不能更新：用独立入口

早期脚本可能还指向原上游仓库，也可能因换源或下载失败而打不开。遇到这些情况，不需要先补装某个中间版本。用 root 执行：

```bash
curl -fsSL https://raw.githubusercontent.com/lansepeach/Hi_Hysteria/refs/heads/main/server/install.sh \
    -o /root/hihy-upgrade.sh &&
bash /root/hihy-upgrade.sh --upgrade &&
hihy version
```

`--upgrade` 只校验并替换 `/usr/bin/hihy`，不会打开菜单或执行安装向导；即使旧启动器已丢失，只要服务和配置还在，也可以用它补回启动器。**这不是 Hysteria 1 到 Hysteria 2 的迁移工具**，也不适用于第三方自定义目录或配置结构未经确认的安装。

### 升完要做什么？怎么回退？

- 运行 `hihy version` 看脚本版本，运行 `hihy 6` 查看服务。原有客户端应继续使用原地址、端口和密码。只是更新脚本，不需要运行 `hihy 1` 或 `hihy 9`。
- 想使用新版内核功能（如 ACL 预览），再运行 `hihy 7`。这一步是单独的核心更新，正在运行的服务会重启验证；建议选空闲时间。
- systemd 主机若提示旧版 `rc.local`/SysV 启动方式，可以先选“暂不迁移”。确认要切换启动方式时，再执行 `hihy migrate-service`。迁移会启用开机启动，但**原来停着的服务不会立即启动**；若服务正在运行，会切换到新服务并验证，安排在空闲时间操作。更新脚本本身不会执行迁移。
- 尚未迁移的 SysV 主机，请用 `hihy stop` 或 `hihy restart` 管理服务。新版命令会先确认 PID 属于本机 Hysteria 核心；旧的 `/etc/rc.d/hihy` 不会在只更新启动器时被重写。
- 成功替换前会把旧脚本留在 `/usr/bin/hihy.previous`。如果只想退回管理脚本，先确认没有 hihy 操作在运行，再执行下面的命令；它不会回退核心或配置。

```bash
cp -p -- /usr/bin/hihy.previous /usr/bin/hihy.rollback.tmp &&
mv -Tf -- /usr/bin/hihy.rollback.tmp /usr/bin/hihy
```

下载失败、脚本校验失败，或识别出下载版本低于已安装版本时，更新会拒绝替换当前脚本。

## 常用命令

```bash
hihy              # 打开交互菜单
hihy install      # 安装 Hysteria2
hihy repair-install # 保留已有配置，接着完成上次失败的安装
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
hihy version      # 只显示管理脚本版本，不打开菜单
hihy 12           # ACL 域名分流管理
hihy 12 test example.com:443 udp # 预览 UDP 请求命中的规则与出站（核心 v2.14.0+）
hihy 13           # 查看统计信息
hihy 14           # 查看实时日志
hihy 15           # 添加 socks5 出站
hihy 16           # 多服务器证书管理（中心端申请、接收端部署）
hihy 17           # 实时监控（首次启用时提示重启服务）
hihy monitor      # 实时监控，每 2 秒刷新，q 退出，j/k 滚动
hihy monitor --once # 输出一次监控快照
hihy monitor enable # 启用按 IP 统计，重启正在运行的服务
hihy monitor disable # 关闭按 IP 统计，恢复原密码认证并重启正在运行的服务
hihy monitor secure # 统计 API 迁移为回环监听与独立密钥，保留认证方式
hihy cert status  # 查看通配符证书和节点部署状态
hihy cert nodes   # 查看所有 SSH 证书节点
hihy cert deploy pending # 仅重试失败、旧证书或尚未分发的节点
hihy migrate-service # 将旧版启动方式迁移到原生 systemd
```

脚本更新完成后会自动重新载入新版菜单。远程版本由仓库根目录的 `VERSION` 提供，完整脚本下载失败时不会覆盖当前安装。

安装需输入 `INSTALL`，卸载需输入 `UNINSTALL`；回车、其他输入或输入结束均取消。已有配置不会被选项 1 覆盖，更新核心用选项 7，修改配置用选项 9。卸载会删除本机证书管理凭据和节点记录，中心端请先从选项 16 导出配置包并安排后续续期。安装与卸载共用操作锁，正常结束或收到退出信号时自动释放。

## ACL 分流：升级后怎么用

ACL 是服务端的分流规则。它可以让指定域名走 IPv4 或 IPv6 出站，也可以拒绝访问。**规则从上往下检查，第一条匹配的规则生效**。例如，`direct(all)` 的意思是“其它流量直连”；如果把它写在最前面，后面的域名规则就可能永远用不到。

### 已有配置需要迁移吗？

**不需要。** Hysteria `v2.14.0` 仍支持旧式 `acl.file`（文件）和 `acl.inline`（写在配置里的文本规则）。要使用新的 ACL 预览，运行 `hihy 7` 更新核心即可，不用为了升级再跑一遍 `hihy 9`。旧核心仍可用原来的托管 ACL，并继续使用菜单增删规则；只是不能用预览。

新版核心另外支持表达式 ACL：`acl.rules` 写在服务端 YAML 中，`acl.rulesFile` 则指向外部的规则文件。四种入口只能启用一种。运行 `hihy 9` 重配置时：

- **使用旧式 ACL**：保留原来的规则顺序；外部旧式 ACL 或内联规则会复制到 hihy 托管文件，外部源文件不改。向导的 HTTP/3 开关只增删它负责的 `reject(all, udp/443)`。
- **使用表达式 ACL**：保留原来的 `acl.rules` 或 `acl.rulesFile`、规则顺序和外部文件，不会转换成旧式。向导会跳过 HTTP/3 开关；如果要改变是否拒绝 UDP/443，请改你原来的规则。
- **路径提示**：`acl.file` 和 `acl.rulesFile` 指向外部文件时请使用可读的绝对路径，例如 `/etc/hihy/acl/my-rules.yaml`。相对路径依赖服务从哪个目录启动，向导不会猜测。

### 我改了一条规则，怎么知道有没有生效？

1. 运行 `hihy 12`，选 **3 查看当前配置的 ACL**。这里显示的是服务端 YAML 引用的规则，而不是碰巧留在磁盘上的旧文件。
2. 选 **1 添加**或 **2 删除**来管理 hihy 托管的旧式域名规则。只有配置实际引用 hihy 托管的 ACL 文件（默认 `/etc/hihy/acl/acl.txt`）时才允许写入。外部文件、内联规则和表达式规则可查看和预览，但应在原处编辑；菜单不会替你修改。
3. 选 **4 预览规则命中**，或者直接运行下面的命令。新增域名规则会放在普通的全匹配兜底规则（如 `direct(all)`）前面。更早的具体规则、端口规则和用户自定义的顺序不会被重排，因此改完最好做一次预览。

```bash
hihy 12 test example.com:443       # 不写协议时按 TCP 检查
hihy 12 test example.com:443 udp   # 用同一目标检查 UDP，例如排查 HTTP/3
hihy 12 test '[2001:db8::1]:443'   # IPv6 地址用方括号括起来
```

结果中，`Rule` 是命中的规则，`Outbound` 是选择的出站。例如下面两条规则会让 UDP/443 显示 `reject`，同一个目标的 TCP 请求则显示 `direct`：

```text
reject(all, udp/443)
direct(all)
```

要是本来想屏蔽某个域名却看到 `direct`，先看是不是前面的规则已经匹配，不要只看列表里有没有那条屏蔽规则。

预览读取磁盘上的服务端配置，不修改配置、不重启服务，也不会连接你填的目标。它不做 DNS 解析、不模拟嗅探，也不传入客户端认证 ID 或来源地址，所以依赖这些信息的规则可能与真实连接的结果不同。要测试这类规则，请用核心自带的 `acl test --help` 查看 `--ipv4`、`--ipv6`、`--auth` 和 `--client` 等选项。如果规则使用 GeoIP 或 GeoSite，核心仍可能按配置下载或刷新地理数据缓存。手工修改文件后，预览通过不等于运行中的服务已经加载了改动。

## 文档

- [防火墙问题](md/firewall.md)
- [证书配置与多服务器分发](md/certificate.md)
- [ECH 配置与核心升级](md/ech.md)
- [实时监控](md/monitor.md)
- [2026-09-22 代码审查与复盘](md/audit-2026-09-22.md)
- [UDP 服务商排雷列表](md/blacklist.md)
- [延迟和上下行速度设置](md/speed.md)
- [支持的客户端](md/client.md)
- [常见问题](md/issues.md)
- [伪装网站](md/masquerade.md)

## 1.0.28 修复说明

- 原生和 Clash/Mihomo 客户端配置先写入权限为 `600` 的临时文件，完整生成后再替换；ECH 读取、YAML 解析或写入失败时保留该格式的旧导出文件。
- 导出不跟随目标文件的符号链接，失败清理临时文件并返回错误，避免半成品被误报为成功。
- 伪装 TCP 提示读取实际 `masquerade.listenHTTPS`，不再根据是否开启端口跳跃判断。
- 增加导出失败场景回归并接入 CI，移除 Mihomo 导出中无用的窗口配置读取。

## 1.0.27 更新说明

- 核对 Hysteria v2.13.0 配置兼容性，注明 `sniff.timeout` 仅对 TCP 生效。
- 真实核心 CI 同时覆盖 v2.12.3 和 v2.13.0，新增新版默认 Chrome 指纹模仿下的 ECH 日志验证。
- 更新核心升级建议和 ECH 文档，说明 QUIC 嗅探修复及客户端更新范围。

## 1.0.26 修复说明

- 证书接收成功后才清理旧版本，连续失败重试保留回滚证书。
- 完整重配置同步 systemd 防火墙依赖，切换 Realm 后不再依赖已删除的服务；失败恢复原 unit。
- 跳跃间隔支持输入 `30` 或 `30s`，统一导出为带单位的时间；旧配置执行 `hihy 8` 可修复纯数字间隔。
- 导入证书中心配置后自动安装续期 timer/cron，安装失败会明确报错；修复后可重新导入重试。

## 1.0.25 修复说明

- 完整重配置在录入结束后才停服，保留 ACL、SOCKS5/WARP 出站、DNS resolver 和嗅探设置；成功后旧配置留在 `/etc/hihy/result/snapshots/`。
- 安装、卸载、核心更新、完整重配置、出口/ACL/监控修改、启停服务和证书管理共用操作锁。
- 统计 API 使用独立管理密钥并只监听 `127.0.0.1`。旧安装更新脚本后执行 `hihy monitor secure`；需要修改时会重启正在运行的服务，原本停止的服务保持停止。菜单 13 和 SSH 实时监控用法不变。
- 修正 Brutal 窗口的字节换算，并加入上下限；配置过程不再修改全局 sysctl 或开启 IP forwarding。
- Clash/Mihomo 导出保留固定/随机跳跃间隔与 BBR 档位，明确提示 Reno 的方向差异；同时提供官方核心可识别端口范围的 URI。新导出默认关闭局域网代理，DNS 监听 `127.0.0.1:1053`。

## 更新说明

建议用 `hihy 7` 更新到 Hysteria v2.14.0 或更高版本。若只是获取内核的 UDP 性能改进、端口跳跃和 QUIC 嗅探修复，不需要运行 `hihy 9` 或重新导出客户端配置。旧式 ACL 也可以直接继续使用。

v2.13.0 修复多包 QUIC ClientHello 的域名嗅探，已有 `sniff.enable: true` 的配置可直接受益；`sniff.timeout` 现在仅对 TCP 生效。若服务端屏蔽了 UDP/443，相关 QUIC 流量仍会被屏蔽。Chrome 154 指纹模仿和 ECH 日志修复需要更新客户端核心。脚本不生成原生 TUN 配置，Clash/Mihomo 的 `tun` 参数不能按官方核心移除 `route.strict` 的改动直接调整。

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
bash tests/management_regression.sh
bash tests/safety_regression.sh
bash tests/audit_regression.sh
bash tests/compatibility_regression.sh
bash tests/review_regression.sh
bash tests/export_regression.sh
sudo env "PATH=$PATH" bash tests/nft_integration.sh
sudo env "PATH=$PATH" bash tests/iptables_integration.sh
python3 tests/ech_integration.py /path/to/hysteria
python3 tests/config_integration.py /path/to/hysteria
python3 tests/monitor_integration.py /path/to/hysteria
```

测试使用临时目录、模拟服务/ACME/SSH 和回环连接，需要 Bash、yq v4、Python 3、openssl 与常见 Linux 工具。GitHub Actions 会在 push 和 pull request 时自动执行这些检查。真实核心联调覆盖 v2.12.3、v2.13.0 和 v2.14.0，并在新版内核检查表达式 ACL 保留、外部规则文件及 TCP/UDP 命中差异；不会调用生产节点或申请真实证书。

nftables 集成测试还需要 root、nftables、iproute2 和网络命名空间支持；它在独立网络命名空间内验证 IPv4/IPv6 通流、重载及卸载清理，不修改主机防火墙。

iptables 集成测试也需要 root、iptables 和挂载命名空间支持，持久化操作写入临时目录。管理回归测试覆盖非法输入、异常退出、证书 SNI、SOCKS5 凭据、卸载失败与安装返回码；配置集成测试使用真实核心验证 Brutal/BBR/Reno 和证书迁移后的握手。

历史迁移工具 `optimize_hihy.py` 已停用，不再生成或覆盖脚本；请直接维护 `server/hy2.sh`。
