#!/bin/bash
# 斐讯 N1 (Amlogic S905D) ImmortalWrt 25.12.x 极致纯净版构建脚本

LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting 25.12 N1 build at $(date)" >> $LOGFILE

echo "Building for profile: $PROFILE"
echo "Building for ROOTFS_PARTSIZE: $ROOTFS_PARTSIZE"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始构建arm64的rootfs.tar.gz"

# ============= 基础纯净包列表 =============
PACKAGES=""
PACKAGES="$PACKAGES curl fdisk"
PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"
PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"
PACKAGES="$PACKAGES openssh-sftp-server"

# 判断是否需要编译 Docker 插件 (由 yml 的 include_docker 控制)
if [ "$INCLUDE_DOCKER" = "yes" ]; then
    PACKAGES="$PACKAGES luci-i18n-dockerman-zh-cn"
    echo "✅ 已选择docker : luci-i18n-dockerman-zh-cn"
fi

# 斐讯N1 无线网卡驱动
PACKAGES="$PACKAGES kmod-brcmfmac wpad-basic-mbedtls iw iwinfo"

# ============= 晶晨宝盒及依赖 =============
PACKAGES="$PACKAGES perlbase-base perlbase-file perlbase-time perlbase-utf8 perlbase-xsloader"
PACKAGES="$PACKAGES bash jq pv uuidgen rpcd-mod-ucode dosfstools fdisk lsblk parted"
PACKAGES="$PACKAGES luci-app-amlogic luci-i18n-amlogic-zh-cn"

# ============= 下载晶晨宝盒 apk（保留原始文件名） =============
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

# 直接下载到 extra-packages 目录，保留原始文件名，以适配 APK 的元数据校验
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

# 让 ImageBuilder 索引这些原始文件
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
