#!/bin/sh
# ==========================================================================
# 把 extra-packages/ 下的 .apk 整理到 ImageBuilder 的本地包目录 packages/
# 支持两种形式：
#   extra-packages/xxx.run           -> 先解压（--noexec），再收集
#   extra-packages/<子目录>/*.apk     -> 直接收集（只查一级子目录）
# ==========================================================================
set -eu

BASE_DIR="extra-packages"
TEMP_DIR="$BASE_DIR/temp-unpack"
TARGET_DIR="packages"

rm -rf "$TEMP_DIR" "$TARGET_DIR"
mkdir -p "$TEMP_DIR" "$TARGET_DIR"

count=0

# 解压 .run 文件
for run_file in "$BASE_DIR"/*.run; do
    [ -e "$run_file" ] || continue
    echo "解压 $run_file -> $TEMP_DIR"
    sh "$run_file" --target "$TEMP_DIR" --noexec
done

# 1. 收集 run 解压出的 .apk
find "$TEMP_DIR" -type f -name '*.apk' -exec cp -v {} "$TARGET_DIR"/ \;

# 2. 收集 extra-packages/*/ 下的 .apk（只查一级子目录）
find "$BASE_DIR" -mindepth 2 -maxdepth 2 -type f -name '*.apk' ! -path "$TEMP_DIR/*" \
    -exec echo "找到:" {} \; \
    -exec cp -v {} "$TARGET_DIR"/ \;

count=$(find "$TARGET_DIR" -maxdepth 1 -type f -name '*.apk' | wc -l)
echo "本地包整理完成：$TARGET_DIR/ 下共 ${count} 个 .apk"

if [ "$count" -eq 0 ]; then
    echo "WARN: 没有整理到任何本地 .apk（如果不需要本地包可以忽略）" >&2
fi
