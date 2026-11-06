#!/bin/sh
# ==========================================================================
# 斐讯 N1 单网口旁路由初始化（首次开机执行一次）
#
# 说明：/etc/init.d/boot 会 source /etc/uci-defaults/ 下的脚本，执行成功
# 后自动删除。它运行在 network（START=20）之前，所以这里不需要、也不应该
# 手动 restart network / firewall。
# ==========================================================================

LOGFILE="/tmp/uci-defaults.log"
log() { echo "$(date '+%F %T') - $*" >>"$LOGFILE"; }

log "开始应用 N1 初始化配置"

# ==========================================
# 1. 主机名 / 时区 / 时间同步
# ==========================================
uci set system.@system[0].hostname=N1
uci set system.@system[0].zonename=Asia/Shanghai
uci set system.@system[0].timezone=CST-8
if uci -q get system.ntp >/dev/null 2>&1; then
    uci -q delete system.ntp.server
    uci add_list system.ntp.server=ntp.aliyun.com
    uci add_list system.ntp.server=cn.pool.ntp.org
fi
uci commit system

# ==========================================
# 2. 唯一网口作为 LAN，用 DHCP 从上级路由获取地址
#    （上游分配了什么地址，就去主路由里看，没有固定后台地址）
# ==========================================
uci set network.lan.proto=dhcp
uci -q delete network.lan.ipaddr
uci -q delete network.lan.netmask
uci -q delete network.lan.gateway
uci -q delete network.lan.broadcast
uci -q delete network.lan.dns
uci commit network
log "LAN 已切换为 DHCP 客户端"

# ==========================================
# 3. 关闭本机 DHCP 服务
#    N1 和主路由在同一层网络里，如果两台都发 DHCP，
#    客户端会随机拿到"网关=N1"的租约，这是旁路由最经典的一个坑。
#    真的想让 N1 发地址的人，把 ignore 改成 0 即可。
# ==========================================
if uci -q get dhcp.lan >/dev/null 2>&1; then
    uci set dhcp.lan.ignore=1
    uci -q set dhcp.lan.dhcpv6=disabled
else
    uci set dhcp.lan=dhcp
    uci set dhcp.lan.interface=lan
    uci set dhcp.lan.ignore=1
fi
uci commit dhcp
log "已关闭 LAN 侧 DHCP 服务"

# ==========================================
# 4. 安卓电视盒子的时间同步（部分盒子只认 time.android.com）
# ==========================================
uci add dhcp domain
uci set dhcp.@domain[-1].name=time.android.com
uci set dhcp.@domain[-1].ip=203.107.6.88
uci commit dhcp

# ==========================================
# 5. 允许所有网口访问 SSH / 终端
# ==========================================
if uci -q get ttyd.@ttyd[0] >/dev/null 2>&1; then
    uci -q delete ttyd.@ttyd[0].interface
fi
if uci -q get dropbear.@dropbear[0] >/dev/null 2>&1; then
    uci set dropbear.@dropbear[0].Interface=
fi
uci commit

# ==========================================
# 6. 唯一网口归入 LAN 区并开启 NAT
#    按名字找 lan 区，不再假设它一定是 @zone[0]（配置顺序变了会改错区）
# ==========================================
LAN_ZONE=""
i=0
while uci -q get "firewall.@zone[$i]" >/dev/null 2>&1; do
    if [ "$(uci -q get "firewall.@zone[$i].name")" = "lan" ]; then
        LAN_ZONE="firewall.@zone[$i]"
        break
    fi
    i=$((i + 1))
done
[ -n "$LAN_ZONE" ] || LAN_ZONE="firewall.@zone[0]"

uci set "${LAN_ZONE}.input=ACCEPT"
uci set "${LAN_ZONE}.output=ACCEPT"
uci set "${LAN_ZONE}.forward=ACCEPT"
uci set "${LAN_ZONE}.masq=1"

# 软件流量分载：千兆宽带下必须开，否则 S905D 的 A53 跑 NAT 只能到 500-600Mbps。
#   代价是 conntrack 统计（nlbwmon）会不准——已建立的流转发时绕过 netfilter；
#   代理流量走 TPROXY 到本地 xray，不走 forward 链，不受影响。
#   S905D 没有硬件 offload 引擎，只开软件（flow_offloading_hw 保持 0）。
if uci -q get firewall.@defaults[0] >/dev/null 2>&1; then
    uci set firewall.@defaults[0].flow_offloading=1
    uci -q set firewall.@defaults[0].flow_offloading_hw=0
fi
uci commit firewall
log "防火墙 LAN 区已放行并开启 masq（${LAN_ZONE}）"

# ==========================================
# 7. TCP BBR 拥塞控制
#
# ophub 的内核把 tcp_bbr 编成模块，但默认不加载——不加载时
# tcp_available_congestion_control 只有 reno cubic。跨境链路 RTT 高、
# 容易丢包，BBR 比 cubic 更能顶住；xray 到节点那段 TCP 是由本机终结的，
# 所以这个设置直接影响代理吞吐。
# ==========================================
modprobe tcp_bbr 2>/dev/null || true
if grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control; then
    echo tcp_bbr > /etc/modules.d/99-tcp-bbr
    modprobe sch_fq 2>/dev/null || true
    echo fq > /proc/sys/net/core/default_qdisc 2>/dev/null || true
    echo bbr > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || true

    # rc.local 每次开机都会执行，用它保证重启后依然生效
    if [ -f /etc/rc.local ] && ! grep -q 'tcp_congestion_control' /etc/rc.local; then
        sed -i '/^exit 0/i \echo fq > /proc/sys/net/core/default_qdisc' /etc/rc.local
        sed -i '/^exit 0/i \echo bbr > /proc/sys/net/ipv4/tcp_congestion_control' /etc/rc.local
    fi
    log "已启用 BBR 拥塞控制"
else
    log "内核未提供 tcp_bbr，跳过 BBR"
fi

# ==========================================
# 8. 关闭无线（旁路由用不到）
#
# 只关 SSID 不够：射频（radio）还开着时，LuCI 取无线状态会等 iwinfo
# 超时，表现为点开后台页面一直"视图加载中"。所以 radio 和 iface 一起关。
# 构建时的环境变量不会保留到设备启动，这里读取打进 rootfs 的开关文件。
# 需要重新开启时见 README「如何重新开启无线」。
# ==========================================
DISABLE_WIFI=yes
if [ -r /etc/n1-defaults/disable-wifi ]; then
    IFS= read -r DISABLE_WIFI < /etc/n1-defaults/disable-wifi || true
fi
case "$DISABLE_WIFI" in
    yes|no) ;;
    *)
        log "无线开关配置无效（${DISABLE_WIFI}），按 yes 处理"
        DISABLE_WIFI=yes
        ;;
esac

if [ "$DISABLE_WIFI" = "yes" ] && [ -f /etc/config/wireless ]; then
    # 关所有射频（wifi-device 段）
    for _radio in $(uci show wireless 2>/dev/null | grep '=wifi-device$' | cut -d. -f2 | cut -d= -f1); do
        uci set "wireless.${_radio}.disabled=1"
        log "无线射频已禁用: ${_radio}"
    done
    # 关所有无线接口（wifi-iface 段）
    for _iface in $(uci show wireless 2>/dev/null | grep '=wifi-iface$' | cut -d. -f2 | cut -d= -f1); do
        uci set "wireless.${_iface}.disabled=1"
    done
    uci commit wireless
else
    log "保持无线启用（DISABLE_WIFI=${DISABLE_WIFI:-yes}）"
fi

# ==========================================
# 9. root 密码与默认语言
# ==========================================
printf 'password\npassword\n' | passwd root >/dev/null 2>&1
uci set luci.main.lang=zh_cn
uci commit luci

log "初始化完成"
exit 0
