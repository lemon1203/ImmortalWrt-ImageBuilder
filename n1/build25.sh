#!/bin/bash
# 斐讯 N1 (Amlogic S905D) ImmortalWrt 25.12.x 极简核心构建脚本

LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting 25.12 N1 build at $(date)" >> $LOGFILE

# ============= 1. 基础纯净包 =============
PACKAGES=""
PACKAGES="$PACKAGES curl fdisk unzip"
PACKAGES="$PACKAGES luci-i18n-base-zh-cn"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"
PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"
PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"
PACKAGES="$PACKAGES openssh-sftp-server"

# ============= 2. 剔除无线和拨号 =============
if [ "$INCLUDE_PPPOE" = "no" ]; then
    PACKAGES="$PACKAGES -ppp -ppp-mod-pppoe -luci-proto-ppp -kmod-ppp"
fi

if [ "$INCLUDE_WIRELESS" = "no" ]; then
    PACKAGES="$PACKAGES -kmod-brcmfmac -wpad-basic-mbedtls -iw -iwinfo"
    # 隐藏菜单并删除无线配置
    mkdir -p /home/build/immortalwrt/files/etc/uci-defaults
    cat > /home/build/immortalwrt/files/etc/uci-defaults/99-remove-wireless << 'EOF'
#!/bin/sh
rm -f /etc/config/wireless
exit 0
EOF
    chmod +x /home/build/immortalwrt/files/etc/uci-defaults/99-remove-wireless
fi

# ============= 3. 核心大招：注入所有第三方内容 (源、插件、宝盒、主题) =============
echo "🚀 正在加载第三方插件与源配置..."
source shell/apk-custom-packages.sh

# ============= 4. 执行构建 =============
echo "$(date '+%Y-%m-%d %H:%M:%S') - Building image with the following packages:"
echo "$PACKAGES"

make image PROFILE=$PROFILE PACKAGES="$PACKAGES" FILES="/home/build/immortalwrt/files" ROOTFS_PARTSIZE=$ROOTFS_PARTSIZE

if [ $? -ne 0 ]; then
    echo "❌ Error: Build failed!"
    exit 1
fi
echo "✅ Build completed successfully."
