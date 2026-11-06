#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

echo "🔨 Building PTT Marquee..."
xcodebuild -project PTTMarquee.xcodeproj -scheme PTTMarquee -destination 'platform=macOS' build > /dev/null

APP_PATH="$(xcodebuild -project PTTMarquee.xcodeproj -scheme PTTMarquee -showBuildSettings | grep -m 1 " TARGET_BUILD_DIR =" | awk '{print $3}')/PTTMarquee.app"

echo "🚀 Launching PTT Marquee from $APP_PATH"
open "$APP_PATH"
