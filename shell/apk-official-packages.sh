#!/bin/bash
# ===========================================================================
# 发行版官方 APK 源中直接可用的可选组件与依赖。
#
# 由 n1/build-firmware.sh 在 ImageBuilder 容器内 source。
# 父脚本已提供：TARGET_OS / PACKAGES。
# ===========================================================================

# ============= 1. SmartDNS =============
if [ "${INCLUDE_SMARTDNS:-no}" = "yes" ]; then
    echo "集成 SmartDNS"
    PACKAGES="$PACKAGES luci-app-smartdns luci-i18n-smartdns-zh-cn"

    # smartdns-ui 只有 ImmortalWrt 的官方源里有。
    if [ "${TARGET_OS:-}" = "ImmortalWrt" ]; then
        PACKAGES="$PACKAGES smartdns-ui"
    fi
fi

# ============= 2. OpenClash 官方依赖 =============
if [ "${INCLUDE_OPENCLASH:-no}" = "yes" ]; then
    # OpenClash 本体由 apk-downloads.sh 下载到本地包目录；这里仅追加底包官方源的依赖。
    PACKAGES="$PACKAGES dnsmasq-full ca-bundle ip-full ruby ruby-yaml"
    PACKAGES="$PACKAGES kmod-tun kmod-inet-diag kmod-nft-tproxy luci-compat"
fi
