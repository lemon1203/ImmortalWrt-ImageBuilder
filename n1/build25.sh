#!/bin/bash
# 斐讯 N1 (Amlogic S905D) ImmortalWrt 25.12.x 极致纯净版构建脚本 (apk 软件体系)
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
# 晶晨宝盒：N1 刷写 eMMC / 在线升级固件与内核的必备 GUI
PACKAGES="$PACKAGES perlbase-base perlbase-file perlbase-time perlbase-utf8 perlbase-xsloader"
PACKAGES="$PACKAGES bash jq pv uuidgen rpcd-mod-ucode dosfstools fdisk lsblk parted"
PACKAGES="$PACKAGES luci-app-amlogic luci-i18n-amlogic-zh-cn"

# 下载晶晨宝盒的 apk 文件（直接从 ophub 官方下载，不引入第三方杂乱仓库）
echo "🔄 正在下载 晶晨宝盒 apk..."
mkdir -p /home/build/immortalwrt/extra-packages/amlogic
AMLOGIC_TAG="26.10.2002-js"
AMLOGIC_URL="https://github.com/ophub/luci-app-amlogic/releases/download/${AMLOGIC_TAG}"
AMLOGIC_DIR="/home/build/immortalwrt/extra-packages/amlogic"

for apk in luci-app-amlogic-26.10.2002-r2.apk luci-i18n-amlogic-zh-cn-0.apk; do
    if [ -f "$AMLOGIC_DIR/$apk" ]; then
        echo "✅ 已存在 $apk"
        continue
    fi
    wget -q "$AMLOGIC_URL/$apk" -P "$AMLOGIC_DIR/" || echo "❌ 下载 $apk 失败"
done
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