#!/bin/bash
# ============= N1 第三方插件与源配置库 =============

# 动态获取架构
ARCH=$(source /home/build/immortalwrt/.config 2>/dev/null; echo "${CONFIG_TARGET_ARCH_PACKAGES}" | tr -d '"')
if [ -z "$ARCH" ]; then ARCH="aarch64_generic"; fi
echo "✅ 识别到软件包架构: ${ARCH}"

mkdir -p /home/build/immortalwrt/files/etc/apk/keys
mkdir -p /home/build/immortalwrt/files/etc/apk/repositories.d

# ============= 1. PassWall =============
if [ "$INCLUDE_PASSWALL" = "yes" ]; then
    echo "🔄 正在配置 PassWall APK 源..."
    
    # 下载公钥
    wget -q -O /home/build/immortalwrt/files/etc/apk/keys/openwrt-passwall-build.pem \
      https://master.dl.sourceforge.net/project/openwrt-passwall-build/apk.pub

    # 写入源
    cat > /home/build/immortalwrt/files/etc/apk/repositories.d/customfeeds.list << EOF
https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-25.12/${ARCH}/passwall_luci/packages.adb
https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-25.12/${ARCH}/passwall_packages/packages.adb
https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-25.12/${ARCH}/passwall2/packages.adb
EOF

    # 追加包名
    PACKAGES="$PACKAGES luci-app-passwall luci-i18n-passwall-zh-cn xray-core sing-box"
    PACKAGES="$PACKAGES kmod-nft-socket kmod-nft-tproxy kmod-nft-nat"
fi

# ============= 2. SmartDNS =============
if [ "$INCLUDE_SMARTDNS" = "yes" ]; then
    echo "✅ 已选择集成 SmartDNS 及原生 WebUI"
    PACKAGES="$PACKAGES luci-app-smartdns luci-i18n-smartdns-zh-cn smartdns-ui"
fi
