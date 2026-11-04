#!/bin/bash
# ============= N1 第三方插件与源配置库 =============

# 动态获取架构 (N1 会是 aarch64_generic)
ARCH=$(source /home/build/immortalwrt/.config 2>/dev/null; echo "${CONFIG_TARGET_ARCH_PACKAGES}" | tr -d '"')
if [ -z "$ARCH" ]; then
    ARCH="aarch64_generic"
fi
echo "✅ 识别到软件包架构: ${ARCH}"

mkdir -p /home/build/immortalwrt/files/etc/apk/keys
mkdir -p /home/build/immortalwrt/files/etc/apk/repositories.d

# ============= 1. PassWall =============
if [ "$INCLUDE_PASSWALL" = "yes" ]; then
    echo "🔄 正在配置 PassWall APK 源..."
    
    wget -q -O /home/build/immortalwrt/files/etc/apk/keys/openwrt-passwall-build.pem \
      https://master.dl.sourceforge.net/project/openwrt-passwall-build/apk.pub

    cat > /home/build/immortalwrt/files/etc/apk/repositories.d/customfeeds.list << EOF
https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-25.12/${ARCH}/passwall_luci/packages.adb
https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-25.12/${ARCH}/passwall_packages/packages.adb
https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-25.12/${ARCH}/passwall2/packages.adb
EOF

    PACKAGES="$PACKAGES luci-app-passwall luci-i18n-passwall-zh-cn xray-core sing-box"
    PACKAGES="$PACKAGES kmod-nft-socket kmod-nft-tproxy kmod-nft-nat"
fi

# ============= 2. SmartDNS =============
if [ "$INCLUDE_SMARTDNS" = "yes" ]; then
    echo "✅ 已选择集成 SmartDNS 及原生 WebUI"
    PACKAGES="$PACKAGES luci-app-smartdns luci-i18n-smartdns-zh-cn smartdns-ui"
fi

# ============= 3. Aurora 主题 =============
if [ "$INCLUDE_AURORA" = "yes" ]; then
    echo "✅ 已选择集成 Aurora 主题，正在通过官方脚本配置源..."
    
    # 调用作者官方安装脚本，它会自动识别 apk/opkg 并添加正确的源
    # 使用 -s 参数只安装主题本体，避免脚本交互式地安装其他无关插件
    wget -qO- https://openwrt.eamonxg.fun/install.sh | sh -s -- -s luci-theme-aurora luci-app-aurora-config luci-i18n-aurora-config-zh-cn

    # 将包名加入安装列表
    PACKAGES="$PACKAGES luci-theme-aurora luci-app-aurora-config luci-i18n-aurora-config-zh-cn"
fi
