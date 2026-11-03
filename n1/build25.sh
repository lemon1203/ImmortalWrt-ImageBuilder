#!/bin/bash
# 斐讯 N1 (Amlogic S905D) ImmortalWrt 25.12.x 极致纯净版构建脚本
source shell/apk-custom-packages.sh

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

# ============= 动态下载晶晨宝盒 apk =============
echo "🔄 正在获取晶晨宝盒最新版本..."
AMLOGIC_REPO="ophub/luci-app-amlogic"
# 尝试通过 GitHub API 获取最新 Tag
AMLOGIC_TAG=$(curl -s "https://api.github.com/repos/${AMLOGIC_REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

# 如果 API 获取失败（比如被限流），使用一个已知的较新备用版本
if [ -z "$AMLOGIC_TAG" ]; then
    echo "⚠️ 无法获取最新版本，使用备用版本..."
    AMLOGIC_TAG="26.10.2002-js"
fi
echo "✅ 晶晨宝盒版本: ${AMLOGIC_TAG}"

AMLOGIC_DIR="/home/build/immortalwrt/extra-packages/amlogic"
mkdir -p "$AMLOGIC_DIR"

# 下载主程序 apk
echo "📥 正在下载 luci-app-amlogic..."
wget -q "https://github.com/${AMLOGIC_REPO}/releases/download/${AMLOGIC_TAG}/luci-app-amlogic-${AMLOGIC_TAG%-*}-r2.apk" -O "$AMLOGIC_DIR/luci-app-amlogic.apk" || \
wget -q "https://github.com/${AMLOGIC_REPO}/releases/download/${AMLOGIC_TAG}/luci-app-amlogic-26.10.2002-r2.apk" -O "$AMLOGIC_DIR/luci-app-amlogic.apk" || \
echo "❌ 下载主程序失败，请检查 Release 文件命名"

# 下载中文语言包 apk
echo "📥 正在下载中文语言包..."
wget -q "https://github.com/${AMLOGIC_REPO}/releases/download/${AMLOGIC_TAG}/luci-i18n-amlogic-zh-cn-0.apk" -O "$AMLOGIC_DIR/luci-i18n-amlogic-zh-cn.apk" || \
wget -q "https://github.com/${AMLOGIC_REPO}/releases/download/${AMLOGIC_TAG}/luci-i18n-amlogic-zh-cn.apk" -O "$AMLOGIC_DIR/luci-i18n-amlogic-zh-cn.apk" || \
echo "❌ 下载语言包失败"

# 检查是否成功下载
if [ ! -s "$AMLOGIC_DIR/luci-app-amlogic.apk" ]; then
    echo "❌ 致命错误：晶晨宝盒主程序未能下载，停止构建。"
    exit 1
fi
ls -lh "$AMLOGIC_DIR"

# 解压并拷贝 apk 到 packages 目录供 ImageBuilder 使用
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
