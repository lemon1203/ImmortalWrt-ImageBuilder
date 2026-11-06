#!/bin/bash
# ===========================================================================
# 从 GitHub Release / 外部地址下载的本地 APK。
#
# 由 n1/build-firmware.sh 在 ImageBuilder 容器内 source。
# 父脚本已提供：THEME / INCLUDE_OPENCLASH / PACKAGES / curl_gh / log / warn / die。
# 所有 APK 下载到 extra-packages/<组件>/，再由 apk-prepare-packages.sh 收集。
# ===========================================================================

# ============= 1. Aurora 主题 =============
THEME="${THEME:-default}"
case "$THEME" in
    default)
        log "LuCI 主题：使用发行版默认主题"
        ;;
    aurora)
        aurora_dir="./extra-packages/aurora"
        rm -rf "$aurora_dir"
        mkdir -p "$aurora_dir"

        download_aurora_asset() {
            local repo="$1"
            local tag="$2"
            local asset_name="$3"
            local local_name="$4"
            local expected_sha256="$5"
            local response urls url output actual_sha256

            response="$(mktemp)"
            if ! curl_gh -o "$response" "https://api.github.com/repos/${repo}/releases/tags/${tag}"; then
                rm -f "$response"
                die "无法查询 ${repo} 的 Release ${tag}"
            fi

            urls="$(mktemp)"
            grep -oE '"browser_download_url":[[:space:]]*"[^"]+"' "$response" \
                | cut -d'"' -f4 > "$urls" || true
            url="$(awk -F/ -v name="$asset_name" '$NF == name { print; exit }' "$urls")"
            rm -f "$response" "$urls"

            [ -n "$url" ] || die "${repo} 的 ${tag} 中没有找到 ${asset_name}"
            output="${aurora_dir}/${local_name}"
            log "下载 Aurora 组件：${asset_name}"
            curl_gh -o "$output" "$url" || die "下载失败：${url}"

            actual_sha256="$(sha256sum "$output" | awk '{print $1}')"
            if [ "$actual_sha256" != "$expected_sha256" ]; then
                rm -f "$output"
                die "${asset_name} 的 SHA256 不匹配，拒绝使用未验证的 APK"
            fi
        }

        # 版本和哈希固定；升级 Aurora 时须同步更新版本、资源名与校验和。
        download_aurora_asset \
            "eamonxg/luci-theme-aurora" "v1.4.0" \
            "luci-theme-aurora-1.4.0-r20260920.apk" \
            "luci-theme-aurora-1.4.0-r20260920.apk" \
            "05f9015e0a4e2859f6a153f69e472f2984481490d4ce6db19b8a41bba7264f1e"
        download_aurora_asset \
            "eamonxg/luci-app-aurora-config" "v1.2.5" \
            "luci-app-aurora-config-1.2.5-r20260920.apk" \
            "luci-app-aurora-config-1.2.5-r20260920.apk" \
            "e290ef9465615d92b5d8baaeacb68a0b5f59edcc647895fa691fc2a3c81b6669"
        # Release 文件名用 .，但 APK 内部版本用 ~；本地名须匹配内部版本。
        download_aurora_asset \
            "eamonxg/luci-app-aurora-config" "v1.2.5" \
            "luci-i18n-aurora-config-zh-cn-26.262.58276.362887a.apk" \
            "luci-i18n-aurora-config-zh-cn-26.262.58276~362887a.apk" \
            "65de0bfda210c1e13df54749627342aea555fa9a01b363f4263ddba7d257b46b"

        PACKAGES="$PACKAGES luci-theme-aurora luci-app-aurora-config luci-i18n-aurora-config-zh-cn"
        log "LuCI 主题：Aurora（主题、配置页、中文包）"
        ;;
    *)
        die "THEME 只能是 default / aurora"
        ;;
esac

# ============= 2. OpenClash =============
if [ "${INCLUDE_OPENCLASH:-no}" = "yes" ]; then
    openclash_repo="vernesong/OpenClash"
    openclash_dir="./extra-packages/openclash"
    rm -rf "$openclash_dir"
    mkdir -p "$openclash_dir"

    log "查询 ${openclash_repo} 的最新 release ..."
    openclash_response="$(mktemp)"
    if ! curl_gh -o "$openclash_response" "https://api.github.com/repos/${openclash_repo}/releases/latest"; then
        rm -f "$openclash_response"
        die "无法查询 OpenClash 的最新 Release"
    fi

    # 每个 Release 资产对象含 name、browser_download_url、digest；只接受 APK，排除 IPK。
    openclash_asset="$(tr '{' '\n' < "$openclash_response" \
        | grep -E '"name":"luci-app-openclash-[^"]+\.apk"' \
        | sort -V \
        | tail -n 1)"
    rm -f "$openclash_response"

    openclash_url="$(printf '%s\n' "$openclash_asset" | sed -n 's/.*"browser_download_url":"\([^"]*\)".*/\1/p')"
    openclash_digest="$(printf '%s\n' "$openclash_asset" | sed -n 's/.*"digest":"sha256:\([0-9a-f]\{64\}\)".*/\1/p')"
    [ -n "$openclash_url" ] || die "OpenClash Latest Release 中没有 luci-app-openclash 的 APK 资产"
    [ -n "$openclash_digest" ] || die "OpenClash Release 没有提供 APK 的 SHA-256 摘要"

    openclash_file="${openclash_dir}/$(basename "$openclash_url")"
    log "下载 $(basename "$openclash_url")"
    curl_gh -o "$openclash_file" "$openclash_url" || die "OpenClash APK 下载失败：${openclash_url}"

    openclash_actual_sha256="$(sha256sum "$openclash_file" | awk '{print $1}')"
    if [ "$openclash_actual_sha256" != "$openclash_digest" ]; then
        rm -f "$openclash_file"
        die "OpenClash APK 的 SHA-256 不匹配，拒绝使用未验证文件"
    fi

    PACKAGES="$PACKAGES luci-app-openclash"
    log "集成 OpenClash（插件与 Firewall4 依赖；不含 Mihomo 内核）"
fi

# ============= 3. 晶晨宝盒 =============
amlogic_repo="ophub/luci-app-amlogic"
amlogic_dir="./extra-packages/amlogic"
rm -rf "$amlogic_dir"
mkdir -p "$amlogic_dir"

log "查询 ${amlogic_repo} 的最新 release ..."
amlogic_response="$(mktemp)"
if ! curl_gh -o "$amlogic_response" "https://api.github.com/repos/${amlogic_repo}/releases/latest"; then
    die "无法访问 GitHub API（多半是未认证限流）。请确认工作流已传入 GITHUB_TOKEN。"
fi

grep -oE '"browser_download_url":[[:space:]]*"[^"]+\.apk"' "$amlogic_response" \
    | cut -d'"' -f4 | sort -u > /tmp/amlogic-apk-urls.txt || true
rm -f "$amlogic_response"

if [ ! -s /tmp/amlogic-apk-urls.txt ]; then
    die "GitHub API 没有返回晶晨宝盒的 .apk 资产"
fi

pick_amlogic_asset() {
    { grep -E "$1" /tmp/amlogic-apk-urls.txt || true; } | sort -V | tail -n 1
}

amlogic_main_url="$(pick_amlogic_asset '/luci-app-amlogic-[^/]*\.apk$')"
[ -n "$amlogic_main_url" ] || die "release 里找不到 luci-app-amlogic 的 APK 资产"
log "下载 $(basename "$amlogic_main_url")"
curl_gh -o "${amlogic_dir}/$(basename "$amlogic_main_url")" "$amlogic_main_url" || die "晶晨宝盒 APK 下载失败"

amlogic_i18n_url="$(pick_amlogic_asset '/luci-i18n-amlogic-zh-cn[^/]*\.apk$')"
if [ -n "$amlogic_i18n_url" ]; then
    log "下载 $(basename "$amlogic_i18n_url")"
    curl_gh -o "${amlogic_dir}/$(basename "$amlogic_i18n_url")" "$amlogic_i18n_url" || die "晶晨宝盒中文包下载失败"
fi

# 防止把错误页之类的小文件当成安装包。
find "$amlogic_dir" -type f -name '*.apk' -size -1k -delete
shopt -s nullglob
amlogic_apks=("${amlogic_dir}"/luci-app-amlogic-*.apk)
[ "${#amlogic_apks[@]}" -gt 0 ] || die "晶晨宝盒主程序没有下载成功"
PACKAGES="$PACKAGES luci-app-amlogic"

amlogic_i18n_apks=("${amlogic_dir}"/luci-i18n-amlogic-zh-cn-*.apk)
if [ "${#amlogic_i18n_apks[@]}" -gt 0 ]; then
    PACKAGES="$PACKAGES luci-i18n-amlogic-zh-cn"
else
    warn "release 里没有 luci-i18n-amlogic-zh-cn 的 APK，跳过中文语言包"
fi
ls -lh "$amlogic_dir"
rm -f /tmp/amlogic-apk-urls.txt
