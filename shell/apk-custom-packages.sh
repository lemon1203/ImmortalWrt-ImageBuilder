#!/bin/bash
# ==========================================================================
# N1 第三方插件与软件源配置
#
# 由 n1/build-firmware.sh 以 source 方式加载（共用同一个 shell），
# 所以这里直接追加 PACKAGES 即可。
# 父脚本已提供：ARCH / FEED_SERIES / TARGET_OS / PACKAGES
# ==========================================================================

ARCH="${ARCH:-aarch64_generic}"
FEED_SERIES="${FEED_SERIES:-25.12}"
PASSWALL_MIRROR="${PASSWALL_MIRROR:-https://master.dl.sourceforge.net/project/openwrt-passwall-build}"

# 下载重试：镜像偶尔 5xx / 超时，单次失败直接放弃会让整个构建白跑
fetch() {
    local url="$1"
    local out="$2"
    local i
    for i in 1 2 3; do
        if wget -q --timeout=30 --tries=2 -O "$out" "$url"; then
            return 0
        fi
        echo "  第 ${i} 次下载失败，5 秒后重试：${url}" >&2
        sleep 5
    done
    return 1
}

# ============= 1. PassWall =============
if [ "${INCLUDE_PASSWALL:-no}" = "yes" ]; then
    echo "配置 PassWall 源：packages-${FEED_SERIES}/${ARCH}"

    mkdir -p files/etc/apk/keys files/etc/apk/repositories.d keys

    PEM="files/etc/apk/keys/openwrt-passwall-build.pem"
    rm -f "$PEM"
    if ! fetch "${PASSWALL_MIRROR}/apk.pub" "$PEM"; then
        echo "ERROR: PassWall 公钥下载失败，构建中止（否则后面会在 apk 阶段报看不懂的签名错误）" >&2
        exit 1
    fi
    if ! grep -q 'BEGIN PUBLIC KEY' "$PEM"; then
        echo "ERROR: PassWall 公钥内容异常（镜像可能返回了错误页面）" >&2
        exit 1
    fi
    cp -f "$PEM" keys/

    cat > files/etc/apk/repositories.d/customfeeds.list <<EOF
${PASSWALL_MIRROR}/releases/packages-${FEED_SERIES}/${ARCH}/passwall_luci/packages.adb
${PASSWALL_MIRROR}/releases/packages-${FEED_SERIES}/${ARCH}/passwall_packages/packages.adb
${PASSWALL_MIRROR}/releases/packages-${FEED_SERIES}/${ARCH}/passwall2/packages.adb
EOF

    # 运行期源（设备上 apk 用）+ 构建期源（ImageBuilder 用）。
    # 构建期这份是 ImageBuilder 根目录下的 repositories 文件。
    while read -r repo; do
        [ -n "$repo" ] || continue
        grep -qxF "$repo" repositories 2>/dev/null || echo "$repo" >> repositories
    done < files/etc/apk/repositories.d/customfeeds.list

    PACKAGES="$PACKAGES luci-app-passwall luci-i18n-passwall-zh-cn"
    # 显式带上核心：PassWall 的运行依赖，缺了能装上但跑不起来
    PACKAGES="$PACKAGES xray-core sing-box"
    PACKAGES="$PACKAGES kmod-nft-socket kmod-nft-tproxy kmod-nft-nat"
fi

# ============= 2. SmartDNS =============
if [ "${INCLUDE_SMARTDNS:-no}" = "yes" ]; then
    echo "集成 SmartDNS"
    PACKAGES="$PACKAGES luci-app-smartdns luci-i18n-smartdns-zh-cn"

    # smartdns-ui 只有 ImmortalWrt 的源里有，官方 OpenWrt 没有
    if [ "${TARGET_OS:-}" = "ImmortalWrt" ]; then
        PACKAGES="$PACKAGES smartdns-ui"
    fi
fi
