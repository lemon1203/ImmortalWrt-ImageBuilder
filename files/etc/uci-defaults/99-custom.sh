#!/bin/sh
# 极简 N1 单网口旁路由初始化脚本

LOGFILE="/etc/config/uci-defaults-log.txt"
echo "Starting custom init at $(date)" >> $LOGFILE

# 1. 强制 LAN 口使用 DHCP 模式 (保持你现在的网络状态)
uci set network.lan.proto='dhcp'
uci delete network.lan.ipaddr
uci delete network.lan.netmask
uci delete network.lan.gateway
uci delete network.lan.dns
uci commit network

# 2. 解决安卓原生 TV 无法联网的问题（劫持时间服务器）
uci add dhcp domain
uci set "dhcp.@domain[-1].name=time.android.com"
uci set "dhcp.@domain[-1].ip=203.107.6.88"
uci commit dhcp

# 3. 允许所有网口可访问网页终端和 SSH
uci delete ttyd.@ttyd[0].interface 2>/dev/null
uci set dropbear.@dropbear[0].Interface=''
uci commit

exit 0
