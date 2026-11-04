#!/bin/bash
# ============= N1 专属第三方插件库（源配置 + 动态最新版下载 + 包名注入） =============

# 1. PassWall (配置源，由 apk 自动解析拉取最新版)
if [ "$INCLUDE_PASSWALL" = "yes" ]; then
    echo "✅ 已选择集成 PassWall，正在配置官方源..."
    mkdir -p /home/build/immortalwrt/files/etc/apk/keys
    mkdir -p /home/build/immortalwrt/files/etc/apk/repositories.d

    wget -q -O /home/build/immortalwrt/files/etc/apk/keys/openwrt-passwall-build.pem \
      https://master.dl.sourceforge.net/project/openwrt-passwall-build/apk.pub

    ARCH="aarch64_generic"
    cat > /home/build/immortalwrt/files/etc/apk/repositories.d/passwall.list << EOF
https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-25.12/${ARCH}/passwall_luci/packages.adb
https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-25.12/${ARCH}/passwall_packages/packages.adb
https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-25.12/${ARCH}/passwall2/packages.adb
EOF

    PACKAGES="$PACKAGES luci-app-passwall luci-i18n-passwall-zh-cn xray-core sing-box"
    PACKAGES="$PACKAGES kmod-nft-socket kmod-nft-tproxy kmod-nft-nat"
fi

# 2. SmartDNS (官方源自带，自动拉取最新，包含原生 WebUI)
if [ "$INCLUDE_SMARTDNS" = "yes" ]; then
    echo "✅ 已选择集成 SmartDNS 及原生 WebUI"
    # smartdns-ui 是 SmartDNS 原生的独立 Web 面板
    PACKAGES="$PACKAGES luci-app-smartdns luci-i18n-smartdns-zh-cn smartdns-ui"
fi

# 3. Aurora 主题 (通过 API 动态抓取最新 URL)
if [ "$INCLUDE_AURORA" = "yes" ]; then
    echo "✅ 已选择集成 Aurora 主题，正在下载最新版..."
    AURORA_API="https://api.github.com/repos/eamonxg/luci-theme-aurora/releases/latest"
    
    THEME_URL=$(curl -s "$AURORA_API" | grep "browser_download_url.*luci-theme-aurora.*\.apk" | cut -d '"' -f 4 | head -n1)
    CONFIG_URL=$(curl -s "$AURORA_API" | grep "browser_download_url.*luci-app-aurora-config.*\.apk" | cut -d '"' -f 4 | head -n1)
    I18N_URL=$(curl -s "$AURORA_API" | grep "browser_download_url.*i18n.*zh-cn.*\.apk" | cut -d '"' -f 4 | head -n1)
    
    mkdir -p /home/build/immortalwrt/packages/
    # 保留原文件名下载，防止 APK 签名校验失败
    if [ -n "$THEME_URL" ]; then wget -q "$THEME_URL" -P /home/build/immortalwrt/packages/; fi
    if [ -n "$CONFIG_URL" ]; then wget -q "$CONFIG_URL" -P /home/build/immortalwrt/packages/; fi
    if [ -n "$I18N_URL" ]; then wget -q "$I18N_URL" -P /home/build/immortalwrt/packages/; fi
    
    PACKAGES="$PACKAGES luci-theme-aurora luci-app-aurora-config luci-i18n-aurora-config-zh-cn"
fi

# 4. 晶晨宝盒 (通过 API 动态抓取最新绝对链接，杜绝任何硬编码)
echo "📥 正在获取晶晨宝盒最新版本..."
AMLOGIC_API="https://api.github.com/repos/ophub/luci-app-amlogic/releases/latest"
AMLOGIC_DIR="/home/build/immortalwrt/extra-packages/amlogic"
mkdir -p "$AMLOGIC_DIR"

# 动态获取包含文件名的完整下载链接
AMLOGIC_URL=$(curl -s "$AMLOGIC_API" | grep "browser_download_url.*luci-app-amlogic.*\.apk" | cut -d '"' -f 4 | head -n 1)
AMLOGIC_I18N_URL=$(curl -s "$AMLOGIC_API" | grep "browser_download_url.*luci-i18n-amlogic-zh-cn.*\.apk" | cut -d '"' -f 4 | head -n 1)

if [ -n "$AMLOGIC_URL" ]; then
    echo "下载主程序: $AMLOGIC_URL"
    wget -q "$AMLOGIC_URL" -P "$AMLOGIC_DIR/"
else
    echo "❌ 获取晶晨宝盒最新链接失败！"
    exit 1
fi

if [ -n "$AMLOGIC_I18N_URL" ]; then
    wget -q "$AMLOGIC_I18N_URL" -P "$AMLOGIC_DIR/"
fi

# 追加晶晨宝盒相关依赖和包名
PACKAGES="$PACKAGES perlbase-base perlbase-file perlbase-time perlbase-utf8 perlbase-xsloader"
PACKAGES="$PACKAGES bash jq pv uuidgen rpcd-mod-ucode dosfstools fdisk lsblk parted"
PACKAGES="$PACKAGES luci-app-amlogic luci-i18n-amlogic-zh-cn"

# 5. 统一整理下载的本地 apk 到 packages 目录
echo "📦 整理本地下载的 apk 文件..."
sh shell/apk-prepare-packages.sh
cp "$AMLOGIC_DIR"/*.apk /home/build/immortalwrt/packages/ 2>/dev/null || true
