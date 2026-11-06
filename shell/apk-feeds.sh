#!/bin/bash
# ===========================================================================
# 需要额外 APK 软件源与公钥的可选组件。
#
# 由 n1/build-firmware.sh 在 ImageBuilder 容器内 source。
# 父脚本已提供：ARCH / FEED_SERIES / PACKAGES。
# ===========================================================================

ARCH="${ARCH:-aarch64_generic}"
FEED_SERIES="${FEED_SERIES:-25.12}"
PASSWALL_MIRROR="${PASSWALL_MIRROR:-https://master.dl.sourceforge.net/project/openwrt-passwall-build}"

fetch_feed_file() {
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

    passwall_key="files/etc/apk/keys/openwrt-passwall-build.pem"
    rm -f "$passwall_key"
    if ! fetch_feed_file "${PASSWALL_MIRROR}/apk.pub" "$passwall_key"; then
        echo "ERROR: PassWall 公钥下载失败，构建中止" >&2
        exit 1
    fi
    if ! grep -q 'BEGIN PUBLIC KEY' "$passwall_key"; then
        echo "ERROR: PassWall 公钥内容异常（镜像可能返回了错误页面）" >&2
        exit 1
    fi
    cp -f "$passwall_key" keys/

    cat > files/etc/apk/repositories.d/customfeeds.list <<EOF
${PASSWALL_MIRROR}/releases/packages-${FEED_SERIES}/${ARCH}/passwall_luci/packages.adb
${PASSWALL_MIRROR}/releases/packages-${FEED_SERIES}/${ARCH}/passwall_packages/packages.adb
${PASSWALL_MIRROR}/releases/packages-${FEED_SERIES}/${ARCH}/passwall2/packages.adb
EOF
    while read -r repo; do
        [ -n "$repo" ] || continue
        grep -qxF "$repo" repositories 2>/dev/null || echo "$repo" >> repositories
    done < files/etc/apk/repositories.d/customfeeds.list

    PACKAGES="$PACKAGES luci-app-passwall luci-i18n-passwall-zh-cn"
    PACKAGES="$PACKAGES xray-core sing-box kmod-nft-socket kmod-nft-tproxy kmod-nft-nat"
fi

# ============= 2. Honk =============
if [ "${INCLUDE_HONK:-no}" = "yes" ]; then
    echo "配置 Honk 源：${FEED_SERIES}/${ARCH}"
    mkdir -p files/etc/apk/keys files/etc/apk/repositories.d keys

    honk_key="files/etc/apk/keys/daeuniverse.pem"
    rm -f "$honk_key"
    if ! fetch_feed_file "https://openwrt.daeuniverse.org/public-key.pem" "$honk_key"; then
        echo "ERROR: Honk 公钥下载失败，构建中止" >&2
        exit 1
    fi
    if ! grep -q 'BEGIN PUBLIC KEY' "$honk_key"; then
        echo "ERROR: Honk 公钥内容异常（软件源可能返回了错误页面）" >&2
        exit 1
    fi
    cp -f "$honk_key" keys/

    honk_repo="@daeuniverse https://openwrt.daeuniverse.org/${FEED_SERIES}/packages/${ARCH}/packages.adb"
    printf '%s\n' "$honk_repo" > files/etc/apk/repositories.d/daeuniverse.list
    grep -qxF "$honk_repo" repositories 2>/dev/null || echo "$honk_repo" >> repositories

    PACKAGES="$PACKAGES honk@daeuniverse luci-app-honk@daeuniverse luci-i18n-daeuniverse-zh-cn@daeuniverse"
fi
