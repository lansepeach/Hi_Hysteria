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
