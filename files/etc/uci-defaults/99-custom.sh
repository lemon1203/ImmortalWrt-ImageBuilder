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

# 软件流量分载，S905D 上没有硬件 offload，只开软件即可
if uci -q get firewall.@defaults[0] >/dev/null 2>&1; then
    uci set firewall.@defaults[0].flow_offloading=1
    uci -q set firewall.@defaults[0].flow_offloading_hw=0
fi
uci commit firewall
log "防火墙 LAN 区已放行并开启 masq（${LAN_ZONE}）"

# ==========================================
# 7. root 密码与默认语言
# ==========================================
printf 'password\npassword\n' | passwd root >/dev/null 2>&1
uci set luci.main.lang=zh_cn
uci commit luci

log "初始化完成"
exit 0
