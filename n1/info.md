## 斐讯 N1（Amlogic S905D）OpenWrt / ImmortalWrt 固件

### 刷写前必读

- 开机默认是 **DHCP 客户端**，没有固定后台地址：请到主路由的客户端列表里找 N1 分到的 IP。
- 后台地址 `http://<N1 的 IP>/`，用户名 `root`，密码 `password`。
- 首次启动会执行 `/etc/uci-defaults/99-custom.sh`，自动完成：LAN 改 DHCP、关闭本机
  DHCP 服务、放行防火墙并开 masq、关闭无线射频、启用 TCP BBR、设置中文界面、
  时区 `Asia/Shanghai`。选择 `theme=aurora` 时，Aurora 主题及其配置页会自动启用。
- 写入 eMMC：LuCI → `系统` → `Amlogic 服务` → `安装 OpenWrt`（晶晨宝盒已内置）。

### 无线默认是关闭的

N1 的无线只有 WiFi 5（BCM43455，2×2），当 AP 用远不如独立路由器；而且射频开着
却没接入时，LuCI 取无线状态会等 `iwinfo` 超时，后台页面会一直"视图加载中"。
所以固件默认把射频和 SSID 都关了（构建时 `disable_wifi=no` 可以保留）。

需要开启时（**先设密码再启用**，默认是开放网络且桥接在 lan 上）：

```sh
# 1. 开射频
uci set wireless.radio0.disabled='0'
uci commit wireless
wifi reload

# 2. 到 LuCI →「网络 → 无线」编辑 SSID，设 WPA2-PSK 和密码
# 3. 再点 SSID 那行的「启用」，保存并应用
```

想再关回去：`uci set wireless.radio0.disabled='1'; uci commit wireless; wifi down`

### Aurora 主题

构建时选择 `theme=aurora` 会安装 Aurora 主题、主题配置页与中文语言包，首次启动后
自动切换主题。可在 LuCI 的「系统 -> Aurora」调整主题外观；选择 `default` 则保留发行版默认主题。

### 关于默认关闭 DHCP

N1 和主路由处在同一个二层网络里，两边都发 DHCP 时，客户端会随机把网关指向 N1，
表现为"有的设备能上网有的不能"。所以本固件默认关掉 N1 自己的 DHCP：

- 想让客户端走 N1：在主路由上把 DHCP 的网关改成 N1 的地址，或客户端手动指网关。
- 想让 N1 发地址：把 `/etc/config/dhcp` 里 `lan` 段的 `option ignore` 改成 `0`。

### 说明

- 底包由对应发行版的官方 ImageBuilder 生成，内核 / u-boot / 启动文件由
  ophub 或 flippy 的打包脚本替换。
- 打包会整体替换 `/lib/modules`，所以内核模块以打包内核自带的那套为准。
- 固件未签名，下载后请用同目录的 `.sha256` 校验：

```sh
sha256sum -c *.sha256
```

### 已知限制

- 单网口 + 旁路由拓扑，没有 WAN 口；IPv6 行为取决于主路由的 RA/DHCPv6 配置。
- ophub 路线会把这个板型支持的整套内核都打一遍，本仓库只上传你选择的那一个系列
  （另一套仍保留在 Actions 的 Artifacts 里）。
