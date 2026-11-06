#!/bin/bash
# 重新產生 app 圖示並輸出各尺寸到 AppIcon.appiconset（Contents.json 已對應 icon_<px>.png）。
set -e
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
SET="$DIR/PTTMarquee/Assets.xcassets/AppIcon.appiconset"
TMP="$(mktemp -d)"
swift "$DIR/scripts/AppIcon.swift" "$TMP/AppIcon.png" >/dev/null
for px in 16 32 64 128 256 512 1024; do
  sips -z $px $px "$TMP/AppIcon.png" --out "$SET/icon_$px.png" >/dev/null
done
rm -rf "$TMP"
echo "✅ 已更新 $SET"
