# 斐讯 N1 固件构建（GitHub Actions）

用 GitHub Actions 一键构建适用于 **斐讯 N1（Amlogic S905D）** 的 OpenWrt / ImmortalWrt 固件：

- 底包：对应发行版的官方 **ImageBuilder**（armvirt / armsr-armv8）
- 内核 / u-boot / 启动文件：**ophub** 或 **flippy** 的打包脚本
- 输出：可直接刷写的 `.img.gz`（附 `.sha256`）

Fork 自 [wukongdaily/ImmortalWrt-ImageBuilder](https://github.com/wukongdaily/ImmortalWrt-ImageBuilder)，
只保留 N1 一个设备，不预装多余插件。

## 怎么用

1. Fork 本仓库。
2. 打开 **Actions**，左侧选 `Build OpenWrt N1` 或 `Build ImmortalWrt N1`。
3. 点 **Run workflow**，按需要选择参数：

| 输入 | 说明 |
| --- | --- |
| `luci_version` | 底包版本，对应 ImageBuilder 的镜像 tag（如 `25.12.6`） |
| `openwrt_kernel` | 内核系列。**注意**：ophub 路线会把该板型支持的几套内核都打一遍，这里决定最终上传哪个系列 |
| `packaging_tool` | `ophub`（晶晨宝盒路线，btrfs + 快照）或 `flippy` |
| `kernel_usage` | 内核来源，**只对 `ophub` 打包生效**：`stable` = ophub 稳定内核，`flippy` = ophub 转存的 flippy 内核（主内核出怪问题时可以换这个试） |
| `include_passwall` | 是否集成 PassWall（含 xray / sing-box 核心与源） |
| `include_smartdns` | 是否集成 SmartDNS |
| `disable_wifi` | **关闭无线射频**（默认 `yes`，旁路由推荐）。开着射频但没接入网络时，LuCI 取无线状态会等 `iwinfo` 超时，表现为后台页面一直「视图加载中」；关掉后明显变快。需要恢复见 [如何重新开启无线](#如何重新开启无线) |
| `theme` | `default` 使用发行版默认 LuCI 主题；`aurora` 安装并在首次开机自动启用 Aurora 主题、主题配置页及中文包 |
| `dry_run` | 只构建、不上传 Release，用来测试参数 |

4. 构建完成后，固件出现在 **Releases**（和同名 `.sha256` 一起），
   同时在 **Actions → 该次运行 → Artifacts** 里保留 7 天。

## 固件默认行为

首次开机会执行 [files/etc/uci-defaults/99-custom.sh](files/etc/uci-defaults/99-custom.sh)：

- 唯一网口作为 LAN，走 **DHCP 客户端**（去主路由查 IP，没有固定后台地址）
- **关闭本机 DHCP 服务**，避免和主路由抢着发地址（旁路由经典坑）
- 防火墙 LAN 区放行 + `masq`，开启软件流量分载
- **关闭无线射频**（`disable_wifi=yes` 时；避免 LuCI 后台因 `iwinfo` 超时而卡顿）
- 启用 TCP BBR 拥塞控制
- 主机名 `N1`、时区 `Asia/Shanghai`、中文界面
- `theme=aurora` 时自动切换为 Aurora 主题，并提供「系统 -> Aurora」配置页
- root 密码 `password`

更多说明见 [n1/info.md](n1/info.md)（每次构建时会作为 Release 说明的一部分）。

## 如何重新开启无线

固件默认把无线射频关了（旁路由用不到，而且会让 LuCI 后台变卡）。要用的时候按顺序来：

**1. SSH 登录后开射频**

```sh
uci set wireless.radio0.disabled='0'
uci commit wireless
wifi reload
```

**2. 先去 LuCI 给 SSID 设密码**

打开「网络 → 无线」，点 SSID 那行的「编辑」，把加密方式设成 **WPA2-PSK** 并设置密码。

> 自动生成的 SSID 默认是**开放网络**，而且桥接在 `lan` 上——不设密码等于把整个局域网敞开。

**3. 再启用 SSID**

保存后回到无线概况，点 SSID 那行的「启用」，再「保存并应用」。

**想再关回去**：

```sh
uci set wireless.radio0.disabled='1'
uci commit wireless
wifi down
```

> 如果 SSID 的 section 名不是 `default_radio0`，用 `uci show wireless` 查实际名字。

## 仓库结构

```
.github/workflows/
  build-n1.yml              # 可复用工作流：真正的构建逻辑（两个发行版共用）
  Build-OpenWrt-N1.yml      # 调用方：官方 OpenWrt 的一组参数
  Build-ImmortalWrt-N1.yml  # 调用方：ImmortalWrt 的一组参数
  ci.yml                    # 脚本语法 + 工作流静态检查

n1/
  build-firmware.sh         # 容器内执行：装包 -> 下晶晨宝盒 -> make image -> 自检
  info.md                   # 发布说明模板

shell/
  apk-custom-packages.sh    # PassWall / SmartDNS 源配置（被 build-firmware.sh source）
  apk-aurora-theme.sh       # Aurora Release APK 下载、SHA256 校验和装包配置
  apk-prepare-packages.sh   # 把 extra-packages 里的 .apk 整理到 ImageBuilder 的 packages/

files/                      # 直接覆盖进 rootfs 的文件
  etc/banner
  etc/uci-defaults/99-custom.sh
```

**为什么入口还是两个文件？** 两个发行版的稳定版数量不一样：官方 OpenWrt 目前
`25.12.0`～`25.12.6` 都有，ImmortalWrt 只到 `25.12.2`。版本下拉框必须各管各的，
所以入口保留两个文件，只有构建步骤共用一份（避免两份 YAML 越改越不像）。

写错版本也不会难查：构建前会去 Docker Hub 查这个发行版**实际发布了哪些版本**，
不存在时直接报错并列出可用版本，例如：

```
ImmortalWrt 目前没有 25.12.6 这个稳定版底包。该发行版可用版本：25.12.0 25.12.1 25.12.2
```

## 想改什么去哪里

| 需求 | 改这里 |
| --- | --- |
| 增删预装软件包 | [n1/build-firmware.sh](n1/build-firmware.sh) 里的 `PACKAGES` |
| 改默认网络 / 密码 / 时区 | [files/etc/uci-defaults/99-custom.sh](files/etc/uci-defaults/99-custom.sh) |
| 加自己的配置文件 | 放到 `files/` 下对应路径（整个目录会覆盖进 rootfs） |
| 改开机 banner | [files/etc/banner](files/etc/banner) |
| 改发布说明 | [n1/info.md](n1/info.md) |

## 常见问题

**构建成功但找不到后台地址？**
设备是 DHCP 客户端，地址由主路由分配。在主路由的 DHCP 客户端列表里找主机名 `N1`
（或按 MAC 找 Amlogic 前缀）。也可以接串口 / HDMI 看启动日志。

**构建失败怎么查？**
1. 看失败那一步的日志；
2. `构建 rootfs` 失败时，多半是软件包名不存在或第三方源拉取失败；
3. 下载 Actions Artifacts 里的产物，或本地用同一 ImageBuilder 镜像复现。

**为什么 `openwrt_kernel` 选了 6.12，ophub 路线日志里还在打 6.18？**
ophub 的 `remake` 在 `auto_kernel=true` 时会把该板型支持的整个内核列表都打一遍，
显式传入的系列会被它忽略。本仓库的做法是照常让它打，然后按你选的系列筛选并上传，
另一套留在 Artifacts 里。flippy 路线则只打你选的那一个系列。

**升级内核 / 底包后 kmod 会不会不匹配？**
打包脚本会整体替换 `/lib/modules`，所以镜像里的内核模块以打包内核为准；
ImageBuilder 阶段装的 `kmod-*` 只保证依赖关系完整。

**文件名里的 `ophub` / `flippy` 是什么意思？**
固件名按「发行版-底包版本-n1-**打包工具**-**内核来源**-内核版本-日期-构建编号」拼，
例如 `openwrt-25.12.6-n1-ophub-stable-k6.18.60-20261105-r123.img.gz`：

| 段 | 含义 |
| --- | --- |
| `ophub` / `flippy` | 用哪套打包脚本（不一定是内核作者） |
| `stable` / `flippy` | 内核来源：`ophub/kernel` 的 `kernel_stable` / `kernel_flippy` |
| `k6.18.60` | 实际打进去的内核版本 |
| `20261105` | 构建日期 |
| `r123` | GitHub Actions 构建编号，避免同日构建互相覆盖 |

flippy 打包路线的文件名是 `...-n1-flippy-k6.18.60-...`（内核固定来自 flippy）。

## 已知限制

- 固件未签名，下载后请用同名 `.sha256` 校验。
- N1 的板载无线是可用的，只是性能比较一般（信号和速率别当主力 AP 使）：
  固件默认带了 `kmod-brcmfmac` / `wpad-basic-mbedtls`。确定只用有线的话，
  可以在 `build-firmware.sh` 里把那一行注释掉，省一点空间。
- ophub 与 flippy 的产物格式不完全一样（如 btrfs 快照、分区布局），
  两种路线不要混着刷同一台机器的升级包。
