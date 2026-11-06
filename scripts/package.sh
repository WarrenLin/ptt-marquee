#!/bin/bash
# 打包 Release 版（Apple Silicon + Intel universal、ad-hoc 簽章）到 dist/：
#   dist/PTTMarquee-<版本>.zip   解壓即用
#   dist/PTTMarquee-<版本>.dmg   拖到「應用程式」安裝
# 版本號取自 project.yml 的 MARKETING_VERSION（從 build 出的 Info.plist 讀取）。未經 Apple 公證，首次開啟需右鍵 →「打開」。
set -euo pipefail
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

APP="build/DerivedData/Build/Products/Release/PTTMarquee.app"
STAGE="build/dmg-staging"

echo "🔨 Building PTT Marquee (Release, universal)..."
xcodebuild -project PTTMarquee.xcodeproj -scheme PTTMarquee -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath build/DerivedData \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build > build/package.log 2>&1 \
  || { tail -30 build/package.log; exit 1; }
codesign --verify --deep --strict "$APP"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")

mkdir -p dist
rm -rf "$STAGE" && mkdir -p "$STAGE"
ditto "$APP" "$STAGE/PTTMarquee.app"
ln -s /Applications "$STAGE/Applications"

ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/PTTMarquee-$VERSION.zip"
hdiutil create -volname "PTT Marquee $VERSION" -srcfolder "$STAGE" -ov -format UDZO \
  "dist/PTTMarquee-$VERSION.dmg" > /dev/null

echo "✅ 完成："
ls -lh dist/PTTMarquee-$VERSION.*
shasum -a 256 dist/PTTMarquee-$VERSION.*
