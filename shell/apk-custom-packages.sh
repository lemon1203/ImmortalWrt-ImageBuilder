#!/bin/bash
# ============= N1 专属第三方插件库（官方源+稳定下载版） =============

# 基础架构
ARCH="aarch64_generic"

# 确保 APK 配置目录存在
mkdir -p /home/build/immortalwrt/files/etc/apk/keys
mkdir -p /home/build/immortalwrt/files/etc/apk/repositories.d

# ==========================================
# 1. PassWall 集成 (官方源)
# ==========================================
if [ "$INCLUDE_PASSWALL" = "yes" ]; then
    echo "✅ 已选择集成 PassWall，正在配置官方源..."
    
    wget -q -O /home/build/immortalwrt/files/etc/apk/keys/openwrt-passwall-build.pem \
      https://master.dl.sourceforge.net/project/openwrt-passwall-build/apk.pub

    cat > /home/build/immortalwrt/files/etc/apk/repositories.d/passwall.list << EOF
https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-25.12/${ARCH}/passwall_luci/packages.adb
https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-25.12/${ARCH}/passwall_packages/packages.adb
https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-25.12/${ARCH}/passwall2/packages.adb
EOF

    PACKAGES="$PACKAGES luci-app-passwall luci-i18n-passwall-zh-cn xray-core sing-box"
    PACKAGES="$PACKAGES kmod-nft-socket kmod-nft-tproxy kmod-nft-nat"
fi

# ==========================================
# 2. SmartDNS 集成 (包含原生 WebUI)
# ==========================================
if [ "$INCLUDE_SMARTDNS" = "yes" ]; then
    echo "✅ 已选择集成 SmartDNS 及原生 WebUI"
    PACKAGES="$PACKAGES luci-app-smartdns luci-i18n-smartdns-zh-cn smartdns-ui"
fi

# ==========================================
# 3. Aurora 主题集成 (通过作者官方源)
# ==========================================
if [ "$INCLUDE_AURORA" = "yes" ]; then
    echo "✅ 已选择集成 Aurora 主题，正在配置作者官方源..."
    
    # 下载作者的公钥
    wget -q -O /home/build/immortalwrt/files/etc/apk/keys/eamonxg.pub https://openwrt.eamonxg.fun/public.key

    # 写入 Feed 源
    cat > /home/build/immortalwrt/files/etc/apk/repositories.d/eamonxg.list << EOF
https://openwrt.eamonxg.fun/releases/packages-25.12/${ARCH}/luci
https://openwrt.eamonxg.fun/releases/packages-25.12/${ARCH}/base
EOF

    # 加入包名列表
    PACKAGES="$PACKAGES luci-theme-aurora luci-app-aurora-config luci-i18n-aurora-config-zh-cn"
fi

# ==========================================
# 4. 晶晨宝盒集成 (恢复老版本稳定提取逻辑)
# ==========================================
echo "🔄 正在获取晶晨宝盒最新版本..."
AMLOGIC_REPO="ophub/luci-app-amlogic"
# 提取 tag_name
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

# 检查是否下载到主程序
if ! ls "$AMLOGIC_DIR"/luci-app-amlogic-*.apk >/dev/null 2>&1; then
    echo "❌ 致命错误：晶晨宝盒主程序未能下载，停止构建。"
    exit 1
fi

echo "✅ 已下载的 apk 文件（原始名称）："
ls -lh "$AMLOGIC_DIR"/*.apk

# 追加宝盒相关的底层依赖
PACKAGES="$PACKAGES perlbase-base perlbase-file perlbase-time perlbase-utf8 perlbase-xsloader"
PACKAGES="$PACKAGES bash jq pv uuidgen rpcd-mod-ucode dosfstools fdisk lsblk parted"
PACKAGES="$PACKAGES luci-app-amlogic luci-i18n-amlogic-zh-cn"

# ==========================================
# 5. 整理本地下载的 apk
# ==========================================
echo "📦 整理并注入本地 apk 文件..."
sh shell/apk-prepare-packages.sh
