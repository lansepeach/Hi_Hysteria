## 支持的客户端

1.0.25 导出规则：

- 原生 Hysteria YAML 保留拥塞控制、窗口、跳跃时间和 ECH 等参数。开启跳跃时，额外输出端口范围位于地址中的官方 URI；第三方兼容 URI 继续使用 `mport`。URI 不包含拥塞控制档位和自定义跳跃时间，完整配置优先使用 YAML。
- Clash/Mihomo YAML 导出 `hop-interval`（固定秒数或 `最小-最大`）及 `bbr-profile`。这些参数需要客户端内置核心支持。Reno 模式导出会提示：服务端下行使用 Reno，Mihomo 客户端上行仍使用 BBR；双向 Reno 使用原生核心。
- 新导出的 Clash 配置默认 `allow-lan: false`，DNS 只监听 `127.0.0.1:1053`。需要向局域网提供代理或 DNS 时，自行显式修改监听设置。
- ECH/Realm 的 Mihomo 导出仍留待专门联调，目前继续提供原生 YAML。

[https://v2.hysteria.network/zh/docs/getting-started/3rd-party-apps/](https://v2.hysteria.network/zh/docs/getting-started/3rd-party-apps/)

### Tips

* V2rayN-windows可以直接扫描屏幕上的二维码。
* v2rayN可在自定义配置里添加hysteria2原生客户端配置文件，给予你原汁原味的体验。**如果使用自定义文件启动hysteria2，那么自定义socks端口请填写20808来使用v2rayN流量统计与分流功能**
v2rayN -> 服务器 ->添加自定义配置

![img](../imgs/v2rayN-new.png)

* 需要发挥hysteria2最佳的性能需要在客户端如实填写当前网络下的下行上行带宽，以及填写客户端QUIC参数，如果该客户端不支持填写**请使用脚本生成的原生hysteria客户端配置**
* v2rayN For Andriod需要填写端口跳跃时间才能启动，不然会出错，默认是30s，推荐120s
* 如果没有使用obfs直接留空就行
* clash.meta目前最佳的方案就是生成一个配置文件，交由用户自行导入。或者你可以找订阅转化将url转成clash.meta可用的订阅
* nekobox/v2rayNForAndriod请在路由里面打开屏蔽QUIC功能，否则无法访问使用了http/3的网站。此问题由于服务器屏蔽了udp/443流量，hysteria对udp无增强的拥塞控制效果
