#!/bin/bash
# ============= N1 第三方插件与源配置库 =============

# 使用相对路径读取架构，确保在任何容器下都能用
ARCH=$(source .config 2>/dev/null; echo "${CONFIG_TARGET_ARCH_PACKAGES}" | tr -d '"')
if [ -z "$ARCH" ]; then ARCH="aarch64_generic"; fi
echo "✅ 识别到软件包架构: ${ARCH}"

# ============= 1. PassWall =============
if [ "$INCLUDE_PASSWALL" = "yes" ]; then
    echo "🔄 正在配置 PassWall APK 源..."
    
    mkdir -p files/etc/apk/keys files/etc/apk/repositories.d
    wget -q -O files/etc/apk/keys/openwrt-passwall-build.pem \
      https://master.dl.sourceforge.net/project/openwrt-passwall-build/apk.pub
      
    cat > files/etc/apk/repositories.d/customfeeds.list << EOF
https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-25.12/${ARCH}/passwall_luci/packages.adb
https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-25.12/${ARCH}/passwall_packages/packages.adb
https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-25.12/${ARCH}/passwall2/packages.adb
EOF

    mkdir -p keys
    cp files/etc/apk/keys/openwrt-passwall-build.pem keys/
    
    if [ -f "repositories" ]; then
        cat files/etc/apk/repositories.d/customfeeds.list >> repositories
    else
        cp files/etc/apk/repositories.d/customfeeds.list repositories
    fi

    PACKAGES="$PACKAGES luci-app-passwall luci-i18n-passwall-zh-cn xray-core sing-box"
    PACKAGES="$PACKAGES kmod-nft-socket kmod-nft-tproxy kmod-nft-nat"
fi

# ============= 2. SmartDNS =============
if [ "$INCLUDE_SMARTDNS" = "yes" ]; then
    echo "✅ 已选择集成 SmartDNS"
    PACKAGES="$PACKAGES luci-app-smartdns luci-i18n-smartdns-zh-cn"
    
    # 官方 OpenWrt 源没有 smartdns-ui，只有 ImmortalWrt 才有
    if [ "$TARGET_OS" = "ImmortalWrt" ]; then
        PACKAGES="$PACKAGES smartdns-ui"
    fi
fi
