## 斐讯 N1（Amlogic S905D）OpenWrt / ImmortalWrt 固件

### 刷写前必读

- 开机默认是 **DHCP 客户端**，没有固定后台地址：请到主路由的客户端列表里找 N1 分到的 IP。
- 后台地址 `http://<N1 的 IP>/`，用户名 `root`，密码 `password`。
- 首次启动会执行 `/etc/uci-defaults/99-custom.sh`，自动完成：LAN 改 DHCP、关闭本机
  DHCP 服务、放行防火墙并开 masq、设置中文界面、时区 `Asia/Shanghai`。
- 写入 eMMC：LuCI → `系统` → `Amlogic 服务` → `安装 OpenWrt`（晶晨宝盒已内置）。

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
