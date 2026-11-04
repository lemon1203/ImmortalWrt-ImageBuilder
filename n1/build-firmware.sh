#!/bin/bash
# ==========================================
# 斐讯 N1 (Amlogic S905D) 通用固件构建脚本
# ==========================================

cd "$(dirname "$0")" || exit 1

LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting N1 build at $(date)" >> $LOGFILE
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始构建arm64的rootfs.tar.gz"

# ============= 1. 基础纯净包列表 =============
PACKAGES=""
PACKAGES="$PACKAGES curl fdisk unzip"
PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"
PACKAGES="$PACKAGES openssh-sftp-server"

# ============= 2. 注入第三方扩展 =============
source shell/apk-custom-packages.sh

# ============= 3. 晶晨宝盒及依赖 =============
PACKAGES="$PACKAGES perlbase-base perlbase-file perlbase-time perlbase-utf8 perlbase-xsloader"
PACKAGES="$PACKAGES bash jq pv uuidgen rpcd-mod-ucode dosfstools fdisk lsblk parted"
PACKAGES="$PACKAGES luci-app-amlogic luci-i18n-amlogic-zh-cn"

# ============= 4. 下载晶晨宝盒 =============
echo "🔄 正在获取晶晨宝盒最新版本..."
AMLOGIC_REPO="ophub/luci-app-amlogic"
AMLOGIC_TAG=$(curl -s "https://api.github.com/repos/${AMLOGIC_REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$AMLOGIC_TAG" ]; then
    echo "❌ 致命错误：无法从 GitHub API 获取版本号（可能被限流）。"
    exit 1
fi

echo "✅ 获取到最新版本: ${AMLOGIC_TAG}"

AMLOGIC_DIR="./extra-packages/amlogic"
mkdir -p "$AMLOGIC_DIR"

wget -q "https://github.com/${AMLOGIC_REPO}/releases/download/${AMLOGIC_TAG}/luci-app-amlogic-${AMLOGIC_TAG%-*}-r2.apk" -P "$AMLOGIC_DIR/" || \
wget -q "https://github.com/${AMLOGIC_REPO}/releases/download/${AMLOGIC_TAG}/luci-app-amlogic-26.10.2002-r2.apk" -P "$AMLOGIC_DIR/"

wget -q "https://github.com/${AMLOGIC_REPO}/releases/download/${AMLOGIC_TAG}/luci-i18n-amlogic-zh-cn-0.apk" -P "$AMLOGIC_DIR/"

if ! ls "$AMLOGIC_DIR"/luci-app-amlogic-*.apk >/dev/null 2>&1; then
    echo "❌ 致命错误：晶晨宝盒主程序未能下载，停止构建。"
    exit 1
fi
ls -lh "$AMLOGIC_DIR"/*.apk

# ============= 5. 整理本地包 =============
sh shell/apk-prepare-packages.sh

# ============= 6. 构建镜像 =============
echo "$(date '+%Y-%m-%d %H:%M:%S') - Building image with the following packages:"
echo "$PACKAGES"

make image PROFILE=$PROFILE PACKAGES="$PACKAGES" FILES="./files" ROOTFS_PARTSIZE=$ROOTFS_PARTSIZE

if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."
