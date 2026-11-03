#!/bin/bash
# 斐讯 N1 (Amlogic S905D) ImmortalWrt 25.12.x 旁路由 (PassWall + SmartDNS)

LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting 25.12 N1 build at $(date)" >> $LOGFILE

echo "Building for profile: $PROFILE"
echo "Building for ROOTFS_PARTSIZE: $ROOTFS_PARTSIZE"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始构建arm64的rootfs.tar.gz"

# ============= 配置 PassWall 的 APK 源 =============
echo "🔄 正在配置 PassWall APK 源..."
mkdir -p /home/build/immortalwrt/files/etc/apk/keys
mkdir -p /home/build/immortalwrt/files/etc/apk/repositories.d

# 下载 PassWall 公钥
wget -q -O /home/build/immortalwrt/files/etc/apk/keys/openwrt-passwall-build.pem \
  https://master.dl.sourceforge.net/project/openwrt-passwall-build/apk.pub

# 动态获取架构并写入源
# 从固件信息中读取架构，N1 会是 aarch64_generic
ARCH=$(source /home/build/immortalwrt/.config 2>/dev/null; echo "${CONFIG_TARGET_ARCH_PACKAGES}" | tr -d '"')
if [ -z "$ARCH" ]; then
    # 兜底：如果从 config 里没读到，用标准路径里的架构名
    ARCH="aarch64_generic"
fi
echo "✅ 识别到软件包架构: ${ARCH}"

cat > /home/build/immortalwrt/files/etc/apk/repositories.d/customfeeds.list << EOF
https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-25.12/${ARCH}/passwall_luci/packages.adb
https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-25.12/${ARCH}/passwall_packages/packages.adb
https://master.dl.sourceforge.net/project/openwrt-passwall-build/releases/packages-25.12/${ARCH}/passwall2/packages.adb
EOF

# ============= 基础纯净包列表 =============
PACKAGES=""
PACKAGES="$PACKAGES curl fdisk unzip"
PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"
PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"
PACKAGES="$PACKAGES openssh-sftp-server"

# ============= 增加 PassWall 和 SmartDNS =============
PACKAGES="$PACKAGES luci-app-passwall luci-i18n-passwall-zh-cn xray-core sing-box"
PACKAGES="$PACKAGES luci-app-smartdns luci-i18n-smartdns-zh-cn"
PACKAGES="$PACKAGES kmod-nft-socket kmod-nft-tproxy kmod-nft-nat"

# ============= 剔除无线和拨号 =============
PACKAGES="$PACKAGES -ppp -ppp-mod-pppoe -luci-proto-ppp -kmod-ppp"
PACKAGES="$PACKAGES -kmod-brcmfmac -wpad-basic-mbedtls -iw -iwinfo"

if [ "$INCLUDE_DOCKER" = "yes" ]; then
    PACKAGES="$PACKAGES luci-i18n-dockerman-zh-cn"
    echo "✅ 已选择docker : luci-i18n-dockerman-zh-cn"
fi

# ============= 晶晨宝盒及依赖 =============
PACKAGES="$PACKAGES perlbase-base perlbase-file perlbase-time perlbase-utf8 perlbase-xsloader"
PACKAGES="$PACKAGES bash jq pv uuidgen rpcd-mod-ucode dosfstools fdisk lsblk parted"
PACKAGES="$PACKAGES luci-app-amlogic luci-i18n-amlogic-zh-cn"

# ============= 下载晶晨宝盒 apk =============
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

wget -q "https://github.com/${AMLOGIC_REPO}/releases/download/${AMLOGIC_TAG}/luci-app-amlogic-${AMLOGIC_TAG%-*}-r2.apk" -P "$AMLOGIC_DIR/" || \
wget -q "https://github.com/${AMLOGIC_REPO}/releases/download/${AMLOGIC_TAG}/luci-app-amlogic-26.10.2002-r2.apk" -P "$AMLOGIC_DIR/"

wget -q "https://github.com/${AMLOGIC_REPO}/releases/download/${AMLOGIC_TAG}/luci-i18n-amlogic-zh-cn-0.apk" -P "$AMLOGIC_DIR/"

if ! ls "$AMLOGIC_DIR"/luci-app-amlogic-*.apk >/dev/null 2>&1; then
    echo "❌ 致命错误：晶晨宝盒主程序未能下载，停止构建。"
    exit 1
fi
ls -lh "$AMLOGIC_DIR"/*.apk

sh shell/apk-prepare-packages.sh

# ============= 构建镜像 =============
echo "$(date '+%Y-%m-%d %H:%M:%S') - Building image with the following packages:"
echo "$PACKAGES"

make image PROFILE=$PROFILE PACKAGES="$PACKAGES" FILES="/home/build/immortalwrt/files" ROOTFS_PARTSIZE=$ROOTFS_PARTSIZE

if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."
