#### 自签证书

#### 多服务器共享通配符证书

`hihy cert` 可以将一台服务器配置为证书中心。证书中心使用 Cloudflare DNS Challenge 申请主域通配符证书，只有证书中心保存 DNS API Token。其他节点通过受限 SSH forced-command 接收证书，部署密钥不能获得远程 Shell。

证书中心使用版本化目录原子发布证书，接收节点会校验证书格式、有效期、SAN 和私钥匹配后再切换。systemd timer 每天检查剩余有效期，并在需要时续期和重新分发。

##### 分发后的证书位置

证书中心和每台接收端都使用以下稳定路径：

```text
/etc/hihy/cert/shared/current/fullchain.pem
/etc/hihy/cert/shared/current/privkey.pem
```

`current` 是指向当前证书版本目录的软链接。实际版本保存在：

```text
/etc/hihy/cert/shared/releases/<发布时间>/fullchain.pem
/etc/hihy/cert/shared/releases/<发布时间>/privkey.pem
/etc/hihy/cert/shared/releases/<发布时间>/fingerprint
```

目录结构示例：

```text
/etc/hihy/cert/shared/
├── current -> releases/20260101T000000Z
└── releases/
    └── 20260101T000000Z/
        ├── fullchain.pem
        ├── privkey.pem
        └── fingerprint
```

Hysteria 服务端配置使用 `current` 下的稳定路径：

```yaml
tls:
  cert: /etc/hihy/cert/shared/current/fullchain.pem
  key: /etc/hihy/cert/shared/current/privkey.pem
```

证书文件和目录权限如下：

```text
fullchain.pem  644
privkey.pem    600
fingerprint    600
release 目录   700
```

脚本保留最近 3 个证书版本并自动清理更早的版本。证书中心由 Lego 申请的原始文件保存在 `/etc/hihy/cert-manager/lego/certificates/`，但实际分发和 Hysteria 使用的是 `/etc/hihy/cert/shared/current/` 下的文件。

可以在中心端或接收端检查当前证书：

```bash
ls -l /etc/hihy/cert/shared/current
ls -l /etc/hihy/cert/shared/current/
openssl x509 \
  -in /etc/hihy/cert/shared/current/fullchain.pem \
  -noout -subject -issuer -dates -fingerprint -sha256
```

共享通配符私钥意味着任意节点失陷都会影响全部一级子域。发现节点被入侵后应立即重新签发新私钥和证书，并分发到所有节点。

没有证据表明自签证书会被GFW所针对，不过不推荐自签某些特殊的域名，比如 `wechat.com`

特殊域名会被你本地运营商所阻断，如果自签请避开这些敏感域名，防止您的服务器遭受损失

自签证书时的**允许不安全连接**时会有MIMT(Man-in-the-middle attack, 中间人攻击)风险。现在脚本默认情况下允许不安全连接(~~我反正觉得被攻击的概率极小，自己判断吧~~

如果你想防止中间人攻击，请参考:

```
tls:
  sni: another.example.com 
  insecure: false 
  pinSHA256: BA:88:45:17:A1... 
  ca: custom_ca.crt
```

添加 ca字段，所需要的ca证书将在您用hihy配置完成自签证书之后放到`/etc/hihy/result`

## 续期与失败节点重试（1.0.18）

已有证书使用 Lego `renew --days`，续期阈值来自中心端配置的 `renew_days`（默认 30 天）。定时任务每次都会检查节点分发状态，不再因为中心证书尚未到期而跳过失败节点。

节点状态同时记录证书 SHA-256：已成功接收当前证书的节点会跳过；失败、缺少状态记录或仍持有旧证书的节点会重试。升级前没有摘要的旧成功记录会重新分发一次。手动执行 `hihy cert deploy` 仍会向所有节点分发。

从证书子菜单选择 **11**，或执行 `hihy cert deploy pending`，可以立即只重试未同步节点。节点列表中的“已同步”表示上次成功分发的摘要与当前证书一致；旧成功记录显示“待同步”。这些状态来自本机分发记录，并非实时远程检查。每次分发都会汇总成功、失败和跳过数量，一个节点失败后仍继续尝试其他节点。

SSH 连接超时为 10 秒，只尝试一次；连接建立后每 10 秒发送保活，连续两次无响应则退出。每个节点发送的证书和私钥取自同一个发布版本，状态记录中的摘要对应实际发送的证书。

## 操作保护（1.0.23）

证书子菜单会显示本机角色，执行操作后留在子菜单，选择 `0` 返回主菜单。接收端无需申请或分发证书。已有中心端和接收端配置不能相互覆盖；历史上同时存在两种角色配置时会提示冲突，申请和分发会中止。

- 重设已有中心端需输入 `RECONFIGURE`，同一中心端不能直接更换主域名；普通续期用选项 3。
- 中心端复用已有 Token，验证成功后才写入设置。ACME 配置只有明确的通配符域名才用作默认主域，不会把 `example.co.uk` 截成 `co.uk`。
- 添加节点时拒绝同名覆盖。要迁移同名节点，先备份并删除旧记录，再添加；只需补发证书时使用选项 11。
- 删除节点需再次输入节点名称，只删除本机分发记录，不删除远端证书或撤销远端 SSH 公钥。若要撤销部署权限，应在接收端移除对应的受限公钥。
- 导入中心端配置包先验证字段、部署私钥和 Token，再展示主域和节点数量，输入 `IMPORT` 后替换中心端配置及完整节点列表；写入失败会恢复原配置，成功后清除旧节点分发状态。缺少 GPG 时会提示安装。

证书归档只能包含规定的普通文件，拒绝符号链接、硬链接、路径越界及重复成员；单文件上限 2 MiB、总内容上限 16 MiB、最多 4096 个成员。解包需要 Python 3。

证书申请、接收、分发、初始化和配置包操作共用互斥锁，定时续期与手动操作不会同时写配置。正常退出会清理锁；强制终止或断电后若遗留锁，应先确认相关任务已结束再处理。这个锁不覆盖主菜单 9 的完整重新配置，维护期间应避免同时执行两类操作。

主菜单 2 卸载会同时删除本机证书管理配置、Token、部署私钥和节点记录，需要输入 `UNINSTALL`。中心端卸载前应导出配置包并将续期职责转移到其他机器；不会卸载远端节点。

## 连接域名与证书迁移

共享证书只覆盖主域下的一级子域名。例如 `*.example.com` 可用于 `node.example.com`，不能用于 `example.com` 或 `a.b.example.com`。初始化中心端时，如果当前自签域名不匹配，脚本会要求填写实际连接域名。

接收端可显式指定本机客户端 SNI：

```bash
hihy cert receiver-init example.com node.example.com
```

中心端添加 SSH 节点时会把填写的节点域名传给接收端。旧接收端缺少连接域名且原 SNI 不匹配时，会拒绝切换证书；执行上述命令补齐后可重新分发。

迁移同步服务端配置和客户端导出元数据，关闭跳过证书验证；保留原 IP/Realm 连接地址以及服务启停状态，启动失败则恢复原配置。迁移后请运行 `hihy 8` 重新导出并更新客户端中的配置。
