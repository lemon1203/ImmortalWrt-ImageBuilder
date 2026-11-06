#!/bin/bash
# ==========================================================================
# 斐讯 N1 (Amlogic S905D) rootfs 构建脚本
#
# 在 ImageBuilder 容器内运行：/bin/bash build.sh
# 需要的工作目录里包含：
#   files/   覆盖层（banner、uci-defaults）
#   shell/   第三方源 / 本地 apk 整理脚本
#
# 环境变量：
#   PROFILE            ImageBuilder profile（默认 generic）
#   ROOTFS_PARTSIZE    rootfs 分区大小 MB（默认 1024）
#   TARGET_OS          OpenWrt / ImmortalWrt
#   INCLUDE_PASSWALL   yes / no
#   INCLUDE_SMARTDNS   yes / no
#   INCLUDE_HONK       yes / no
#   INCLUDE_OPENCLASH  yes / no
#   THEME              default / aurora
#   LUCI_VERSION       底包版本，如 25.12.6
#   FEED_SERIES        PassWall 源分支，如 25.12
#   GITHUB_TOKEN       可选，用于 GitHub API 认证（避免 60 次/小时限流）
# ==========================================================================
set -euo pipefail

cd "$(dirname "$0")"

LOGFILE="/tmp/build-firmware.log"
: > "$LOGFILE"

log()  { echo "$(date '+%F %T') - $*" | tee -a "$LOGFILE"; }
warn() { echo "$(date '+%F %T') - [WARN] $*" | tee -a "$LOGFILE" >&2; }
die()  { echo "$(date '+%F %T') - [FAIL] $*" | tee -a "$LOGFILE" >&2; exit 1; }

log "开始构建 ${TARGET_OS:-OpenWrt} rootfs（底包 ${LUCI_VERSION:-unknown}）"

# ============= 0. 目标架构 =============
# 第一次 make 之前 .config 可能还不存在，而且不能直接 source 它
# （set -u 下缺变量、里面有非赋值语句都会让脚本直接退出），只做安全提取。
ARCH="aarch64_generic"
if [ -f .config ]; then
    _arch="$(awk -F'"' '/^CONFIG_TARGET_ARCH_PACKAGES=/{print $2; exit}' .config)"
    if [ -n "${_arch}" ]; then
        ARCH="${_arch}"
    fi
fi
export ARCH
log "软件包架构: ${ARCH}"

# ============= 1. 基础纯净包列表 =============
PACKAGES=""
PACKAGES="$PACKAGES curl fdisk unzip"
PACKAGES="$PACKAGES luci"
# 官方 ImageBuilder 没有 luci 的默认 web 服务，需要显式装
PACKAGES="$PACKAGES uhttpd uhttpd-mod-ubus"
PACKAGES="$PACKAGES luci-i18n-base-zh-cn"
PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"
PACKAGES="$PACKAGES openssh-sftp-server"
# 时区由 99-custom.sh 写进 system.timezone（OpenWrt 会据此生成 /etc/TZ），
# 不额外装 zoneinfo-*，避免不同底包里包名差异导致构建失败。

# 无线网卡驱动：N1 的板载无线是可用的，只是性能一般，驱动默认保留。
# 如果确定只用有线，可以整段注释掉，能省一点空间、也少一层 wpad 冲突风险。
PACKAGES="$PACKAGES kmod-brcmfmac wpad-basic-mbedtls iw iwinfo"

# ============= 2. 写入首次启动参数 / 注入第三方扩展 =============
# ImageBuilder 容器的环境变量不会带到设备首次启动；把无线开关作为
# 只含 yes/no 的普通文件放进 rootfs，由 uci-defaults 脚本读取。
DISABLE_WIFI="${DISABLE_WIFI:-yes}"
case "$DISABLE_WIFI" in
    yes|no) ;;
    *) die "DISABLE_WIFI 只能是 yes / no" ;;
esac
mkdir -p files/etc/n1-defaults
printf '%s\n' "$DISABLE_WIFI" > files/etc/n1-defaults/disable-wifi

# ============= 3. 晶晨宝盒及依赖 =============
PACKAGES="$PACKAGES perlbase-base perlbase-file perlbase-time perlbase-utf8 perlbase-xsloader"
PACKAGES="$PACKAGES bash jq pv uuidgen rpcd-mod-ucode dosfstools lsblk parted"
PACKAGES="$PACKAGES block-mount btrfs-progs e2fsprogs kmod-usb-storage kmod-fs-ext4 kmod-fs-vfat"
# ↑ 官方 OpenWrt 需要这些依赖，否则无法写入 eMMC。
#   注意：ophub/flippy 打包时会删掉 /lib/modules 换成自己的内核模块，
#   所以 kmod-* 的实际文件以打包内核为准，这里主要保证 opkg/apk 层面的依赖完整。

# 带 token 的 API 请求：未认证时 GitHub 只给 60 次/小时/IP，
# 共享 runner 上很容易撞到 403，所以工作流会传 GITHUB_TOKEN 进来。
curl_gh() {
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        curl -fsSL --retry 3 --retry-delay 5 --connect-timeout 20 \
            -H "Authorization: Bearer ${GITHUB_TOKEN}" \
            -H "X-GitHub-Api-Version: 2022-11-28" "$@"
    else
        curl -fsSL --retry 3 --retry-delay 5 --connect-timeout 20 "$@"
    fi
}

# 可选组件按安装来源拆分：第三方源、发行版官方源、本地下载 APK。
# shellcheck source=/dev/null
source shell/apk-feeds.sh
# shellcheck source=/dev/null
source shell/apk-official-packages.sh
# shellcheck source=/dev/null
source shell/apk-downloads.sh

# ============= 4. 整理本地包 =============
sh shell/apk-prepare-packages.sh

# ============= 5. 构建镜像 =============
log "开始 make image（profile=${PROFILE:-generic}，rootfs=${ROOTFS_PARTSIZE:-1024}MB）"
log "软件包列表: ${PACKAGES}"

if ! make image \
        PROFILE="${PROFILE:-generic}" \
        PACKAGES="$PACKAGES" \
        FILES="./files" \
        ROOTFS_PARTSIZE="${ROOTFS_PARTSIZE:-1024}" 2>&1 | tee -a "$LOGFILE"; then
    die "make image 失败"
fi

# ============= 6. 产物自检 =============
# 这一步专门用来抓"覆盖层没挂上""第三方包没装上"这类静默失败，
# 比等用户刷完机再发现问题要便宜得多。
ROOTFS="$(find bin/targets/armsr/armv8 -maxdepth 1 -type f -name '*rootfs.tar.gz' -print -quit 2>/dev/null || true)"
[ -n "$ROOTFS" ] || die "没有生成 rootfs.tar.gz"

ROOTFS_MB=$(( $(stat -c %s "$ROOTFS") / 1048576 ))
log "rootfs: ${ROOTFS} (${ROOTFS_MB} MB)"

ROOTFS_LIST="$(tar -tzf "$ROOTFS")"

check_hard() {
    grep -q "$1" <<<"$ROOTFS_LIST" || die "rootfs 中缺少 $1（覆盖层或软件包没有生效）"
    log "[OK] $1"
}

check_soft() {
    if grep -q "$1" <<<"$ROOTFS_LIST"; then
        log "[OK] $1"
    else
        warn "rootfs 中没看到 $1，请确认对应软件包是否装上"
    fi
}

check_hard 'etc/uci-defaults/99-custom.sh'
check_hard 'etc/banner'
check_hard 'etc/n1-defaults/disable-wifi'

if [ "${INCLUDE_PASSWALL:-no}" = "yes" ]; then
    check_hard 'etc/apk/repositories.d/customfeeds.list'
    check_soft 'etc/config/passwall'
fi
if [ "${INCLUDE_SMARTDNS:-no}" = "yes" ]; then
    check_soft 'etc/config/smartdns'
fi
if [ "${INCLUDE_HONK:-no}" = "yes" ]; then
    check_hard 'etc/apk/repositories.d/daeuniverse.list'
    check_soft 'etc/init.d/honk'
    check_soft 'usr/share/luci/menu.d/luci-app-honk.json'
fi
if [ "${INCLUDE_OPENCLASH:-no}" = "yes" ]; then
    check_soft 'etc/init.d/openclash'
    check_soft 'usr/share/luci/menu.d/luci-app-openclash.json'
fi
if [ "$THEME" = "aurora" ]; then
    check_hard 'www/luci-static/aurora/main.css'
    check_hard 'usr/share/luci/menu.d/luci-app-aurora.json'
    check_hard 'usr/lib/lua/luci/i18n/aurora-config.zh-cn.lmo'
fi

log "构建完成"
