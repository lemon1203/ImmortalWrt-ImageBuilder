#!/bin/sh
# N1 单网口旁路由初始化脚本

LOGFILE="/etc/config/uci-defaults-log.txt"
echo "Starting custom init at $(date)" >> $LOGFILE

# ==========================================
# 1. 强制 LAN 口使用 DHCP 模式
# ==========================================
uci set network.lan.proto='dhcp'
uci delete network.lan.ipaddr
uci delete network.lan.netmask
uci delete network.lan.gateway
uci delete network.lan.dns
uci commit network

# ==========================================
# 2. 解决安卓原生 TV 无法联网的问题
# ==========================================
uci add dhcp domain
uci set "dhcp.@domain[-1].name=time.android.com"
uci set "dhcp.@domain[-1].ip=203.107.6.88"
uci commit dhcp

# ==========================================
# 3. 允许所有网口访问终端和 SSH
# ==========================================
uci delete ttyd.@ttyd[0].interface 2>/dev/null
uci set dropbear.@dropbear[0].Interface=''
uci commit

# ==========================================
# 4. 解除防火墙锁死，将唯一网口归入LAN区并开启NAT
# ==========================================
uci set firewall.@zone[0].name='lan'
uci set firewall.@zone[0].input='ACCEPT'
uci set firewall.@zone[0].output='ACCEPT'
uci set firewall.@zone[0].forward='ACCEPT'
uci set firewall.@zone[0].masq='1'
uci commit firewall

# ==========================================
# 5. 强制设置 root 密码为 password (兼容性最强)
# ==========================================
printf "password\npassword\n" | passwd root

# ==========================================
# 6. 强制设置网页为中文
# ==========================================
uci set luci.main.lang='zh_cn'
uci commit luci

# 让网络和防火墙配置立刻生效
/etc/init.d/network restart
/etc/init.d/firewall restart

exit 0
