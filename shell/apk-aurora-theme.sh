#!/bin/bash
# ===========================================================================
# Aurora LuCI 主题：下载固定 Release 的 APK 并校验内容。
#
# 由 n1/build-firmware.sh 在 ImageBuilder 容器内 source。
# 父脚本已提供：THEME / PACKAGES / curl_gh / log / die。
# ===========================================================================

THEME="${THEME:-default}"
case "$THEME" in
    default)
        log "LuCI 主题：使用发行版默认主题"
        ;;
    aurora)
        AURORA_DIR="./extra-packages/aurora"
        rm -rf "$AURORA_DIR"
        mkdir -p "$AURORA_DIR"

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

            output="${AURORA_DIR}/${local_name}"
            log "下载 Aurora 组件：${asset_name}"
            curl_gh -o "$output" "$url" || die "下载失败：${url}"

            actual_sha256="$(sha256sum "$output" | awk '{print $1}')"
            if [ "$actual_sha256" != "$expected_sha256" ]; then
                rm -f "$output"
                die "${asset_name} 的 SHA256 不匹配，拒绝使用未验证的 APK"
            fi
        }

        # 版本和哈希固定，升级 Aurora 时须同步更新三项版本/校验和。
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
        # Release 资源名用 .，但 APK 内部版本用 ~；本地名必须匹配内部版本。
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
