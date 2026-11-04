#!/bin/bash
# ============= N1 专属第三方插件库 =============

ARCH="aarch64_generic"

# 在 ImageBuilder 根目录创建 keys 文件夹，让编译系统信任第三方源
mkdir -p keys

# ==========================================
# 1. PassWall 集成
# ==========================================
if [ "$INCLUDE_PASSWALL" = "yes" ]; then
    echo "✅ 已选择集成 PassWall..."
    
    # 下载公钥到根目录 keys/
    wget -q -O keys/openwrt-passwall-build.pem \
      https://master.dl.sourceforge.net/project/openwrt-passwall-build/apk.pub

    # 写入源目录（不要写 packages.adb，写到 feed 目录即可）
    for feed in passwall_luci passwall_packages passwall2; do
        echo "https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-25.12/${ARCH}/${feed}" >> repositories
    done

    PACKAGES="$PACKAGES luci-app-passwall luci-i18n-passwall-zh-cn xray-core sing-box"
    PACKAGES="$PACKAGES kmod-nft-socket kmod-nft-tproxy kmod-nft-nat"
fi

# ==========================================
# 2. SmartDNS 集成
# ==========================================
if [ "$INCLUDE_SMARTDNS" = "yes" ]; then
    echo "✅ 已选择集成 SmartDNS 及原生 WebUI"
    PACKAGES="$PACKAGES luci-app-smartdns luci-i18n-smartdns-zh-cn smartdns-ui"
fi

# ==========================================
# 3. Aurora 主题集成
# ==========================================
if [ "$INCLUDE_AURORA" = "yes" ]; then
    echo "✅ 已选择集成 Aurora 主题..."
    
    # 下载公钥到根目录 keys/
    wget -q -O keys/eamonxg.pub https://openwrt.eamonxg.fun/public.key

    # 写入源目录
    echo "https://openwrt.eamonxg.fun/releases/packages-25.12/${ARCH}/luci" >> repositories
    echo "https://openwrt.eamonxg.fun/releases/packages-25.12/${ARCH}/base" >> repositories

    PACKAGES="$PACKAGES luci-theme-aurora luci-app-aurora-config luci-i18n-aurora-config-zh-cn"
fi

# ==========================================
# 4. 晶晨宝盒集成
# ==========================================
echo "🔄 正在获取晶晨宝盒最新版本..."
AMLOGIC_REPO="ophub/luci-app-amlogic"
AMLOGIC_TAG=$(curl -s "https://api.github.com/repos/${AMLOGIC_REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [ -z "$AMLOGIC_TAG" ]; then
    echo "⚠️ 无法获取最新版本，使用备用版本..."
    AMLOGIC_TAG="26.10.2002-js"
fi
echo "✅ 晶晨宝盒版本: ${AMLOGIC_TAG}"

AMLOGIC_DIR="/home/build/immortalwrt/extra-packages/amlogic"
mkdir -p "$AMLOGIC_DIR"

echo "📥 正在下载晶晨宝盒原始 apk 文件..."
wget -q "https://github.com/${AMLOGIC_REPO}/releases/download/${AMLOGIC_TAG}/luci-app-amlogic-${AMLOGIC_TAG%-*}-r2.apk" -P "$AMLOGIC_DIR/" || \
wget -q "https://github.com/${AMLOGIC_REPO}/releases/download/${AMLOGIC_TAG}/luci-app-amlogic-26.10.2002-r2.apk" -P "$AMLOGIC_DIR/"

wget -q "https://github.com/${AMLOGIC_REPO}/releases/download/${AMLOGIC_TAG}/luci-i18n-amlogic-zh-cn-0.apk" -P "$AMLOGIC_DIR/"

if ! ls "$AMLOGIC_DIR"/luci-app-amlogic-*.apk >/dev/null 2>&1; then
    echo "❌ 致命错误：晶晨宝盒主程序未能下载，停止构建。"
    exit 1
fi

PACKAGES="$PACKAGES perlbase-base perlbase-file perlbase-time perlbase-utf8 perlbase-xsloader"
PACKAGES="$PACKAGES bash jq pv uuidgen rpcd-mod-ucode dosfstools fdisk lsblk parted"
PACKAGES="$PACKAGES luci-app-amlogic luci-i18n-amlogic-zh-cn"

# ==========================================
# 5. 整理本地下载的 apk
# ==========================================
echo "📦 整理并注入本地 apk 文件..."
sh shell/apk-prepare-packages.sh
