#!/bin/bash
# dev-sim.sh — Build + deploy VitaAI to simulator, gold standard.
# Usage: ./scripts/dev-sim.sh [sim-name]   (default: "iPhone 17 Pro")
#
# Why this script exists: `xcodebuild build` puts the .app in DerivedData
# but does NOT install it in the simulator. Agents that forget to reinstall
# see stale builds and think features are broken. This script always
# guarantees the sim runs the freshly-built binary.
set -euo pipefail

SIM_NAME="${1:-iPhone 17 Pro}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "🔨 Build $SIM_NAME"
xcodebuild \
    -project VitaAI.xcodeproj \
    -scheme VitaAI \
    -sdk iphonesimulator \
    -destination "platform=iOS Simulator,name=$SIM_NAME" \
    -derivedDataPath build/DerivedData \
    build 2>&1 | tail -5

APP_PATH="build/DerivedData/Build/Products/Debug-iphonesimulator/VitaAI.app"
[ -d "$APP_PATH" ] || { echo "❌ .app not found at $APP_PATH"; exit 1; }

SIM_UUID=$(xcrun simctl list devices available | grep "$SIM_NAME (" | head -1 | grep -oE '[A-F0-9-]{36}')
[ -n "$SIM_UUID" ] || { echo "❌ sim '$SIM_NAME' not found"; exit 1; }

xcrun simctl boot "$SIM_UUID" 2>/dev/null || true
xcrun simctl uninstall "$SIM_UUID" com.bymav.vitaai 2>/dev/null || true
xcrun simctl install "$SIM_UUID" "$APP_PATH"
xcrun simctl launch "$SIM_UUID" com.bymav.vitaai

# Verify sim has the fresh binary (sanity check)
INSTALLED=$(xcrun simctl get_app_container "$SIM_UUID" com.bymav.vitaai)
INSTALLED_MTIME=$(stat -f %m "$INSTALLED/VitaAI")
BUILT_MTIME=$(stat -f %m "$APP_PATH/VitaAI")
[ "$INSTALLED_MTIME" -ge "$BUILT_MTIME" ] || { echo "❌ sim has stale binary"; exit 1; }

echo "✅ $SIM_NAME running $(date -r "$INSTALLED_MTIME" '+%Y-%m-%d %H:%M:%S')"
