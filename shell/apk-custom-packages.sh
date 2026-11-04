#!/bin/bash
# ============= N1 专属第三方插件库（官方源+防限流下载 完整版） =============

# 确保目录存在
mkdir -p /home/build/immortalwrt/files/etc/apk/keys
mkdir -p /home/build/immortalwrt/files/etc/apk/repositories.d
mkdir -p /home/build/immortalwrt/extra-packages/aurora
mkdir -p /home/build/immortalwrt/extra-packages/amlogic

ARCH="aarch64_generic"

# ==========================================
# 1. PassWall 集成
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

    # 写入 Feed 源 (添加 base 和 luci 两个可能的目录以确保万无一失)
    cat > /home/build/immortalwrt/files/etc/apk/repositories.d/eamonxg.list << EOF
https://openwrt.eamonxg.fun/releases/packages-25.12/${ARCH}/luci
https://openwrt.eamonxg.fun/releases/packages-25.12/${ARCH}/base
EOF

    # 加入包名列表 (apk 会自动从上面的源里拉取最新版和依赖)
    PACKAGES="$PACKAGES luci-theme-aurora luci-app-aurora-config luci-i18n-aurora-config-zh-cn"
fi

# ==========================================
# 4. 晶晨宝盒集成 (通过 API 动态抓取最新版)
# ==========================================
echo "📥 正在获取晶晨宝盒最新版本..."
AMLOGIC_API="https://api.github.com/repos/ophub/luci-app-amlogic/releases/latest"

# 带上 GITHUB_TOKEN 请求，防止被限流封禁
AMLOGIC_URL=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" "$AMLOGIC_API" | grep "browser_download_url.*luci-app-amlogic.*\.apk" | cut -d '"' -f 4 | head -n 1)
AMLOGIC_I18N_URL=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" "$AMLOGIC_API" | grep "browser_download_url.*luci-i18n-amlogic-zh-cn.*\.apk" | cut -d '"' -f 4 | head -n 1)

if [ -n "$AMLOGIC_URL" ]; then
    echo "下载晶晨宝盒主程序..."
    wget -q "$AMLOGIC_URL" -P "/home/build/immortalwrt/extra-packages/amlogic/"
else
    echo "❌ 获取晶晨宝盒最新链接失败！"
    exit 1
fi

if [ -n "$AMLOGIC_I18N_URL" ]; then
    wget -q "$AMLOGIC_I18N_URL" -P "/home/build/immortalwrt/extra-packages/amlogic/"
fi

# 追加宝盒相关的底层依赖
PACKAGES="$PACKAGES perlbase-base perlbase-file perlbase-time perlbase-utf8 perlbase-xsloader"
PACKAGES="$PACKAGES bash jq pv uuidgen rpcd-mod-ucode dosfstools fdisk lsblk parted"
PACKAGES="$PACKAGES luci-app-amlogic luci-i18n-amlogic-zh-cn"

# ==========================================
# 5. 整理本地下载的 apk (宝盒)
# ==========================================
echo "📦 整理并注入本地 apk 文件..."
sh shell/apk-prepare-packages.sh
