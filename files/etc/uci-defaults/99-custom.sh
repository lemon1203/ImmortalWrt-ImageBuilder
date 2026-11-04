#!/bin/sh
# 极简 N1 单网口旁路由初始化脚本

LOGFILE="/etc/config/uci-defaults-log.txt"
echo "Starting custom init at $(date)" >> $LOGFILE

# ==========================================
# 1. 强制 LAN 口使用 DHCP 模式 (保持旁路由状态)
# ==========================================
uci set network.lan.proto='dhcp'
uci delete network.lan.ipaddr
uci delete network.lan.netmask
uci delete network.lan.gateway
uci delete network.lan.dns
uci commit network

# ==========================================
# 2. 解决安卓原生 TV 无法联网的问题（劫持时间服务器）
# ==========================================
uci add dhcp domain
uci set "dhcp.@domain[-1].name=time.android.com"
uci set "dhcp.@domain[-1].ip=203.107.6.88"
uci commit dhcp

# ==========================================
# 3. 允许所有网口可访问网页终端和 SSH
# ==========================================
uci delete ttyd.@ttyd[0].interface 2>/dev/null
uci set dropbear.@dropbear[0].Interface=''
uci commit

# ==========================================
# 4. 暴力解除防火墙拦截，并设置默认密码
# ==========================================
# 强制把唯一的网口纳入 lan 区域，防止被识别为 wan
uci set firewall.@zone[0].name='lan'
uci set firewall.@zone[0].input='ACCEPT'
uci set firewall.@zone[0].output='ACCEPT'
uci set firewall.@zone[0].forward='ACCEPT'
uci set firewall.@zone[0].masq='1'
uci commit firewall

# 顺手把 SSH 的 root 默认密码设为 password，防止空密码被拒
echo "root:password" | chpasswd

# 重启网络和防火墙，让配置立即生效
/etc/init.d/network restart
/etc/init.d/firewall restart

# 强制设置 LuCI 网页界面默认语言为简体中文
uci set luci.main.lang='zh_cn'
uci commit luci

exit 0
