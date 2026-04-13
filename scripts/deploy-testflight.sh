#!/bin/bash
# deploy-testflight.sh — One-command TestFlight deploy
# Usage: ./scripts/deploy-testflight.sh
#
# Archive → Export → Upload to App Store Connect
# ~2-3 min on Mac Mini. Zero config needed.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

SCHEME="VitaAI"
PROJECT="VitaAI.xcodeproj"
ARCHIVE_PATH="/tmp/VitaAI.xcarchive"
EXPORT_PATH="/tmp/VitaAI-export"
EXPORT_PLIST="$PROJECT_DIR/scripts/ExportOptions.plist"

echo "🚀 VitaAI TestFlight Deploy"
echo "==========================="

# 1. Increment build number
CURRENT_BUILD=$(agvtool what-version -terse 2>/dev/null || echo "0")
NEW_BUILD=$((CURRENT_BUILD + 1))
agvtool new-version -all "$NEW_BUILD" > /dev/null 2>&1
VERSION=$(agvtool what-marketing-version -terse1 2>/dev/null || echo "1.0.0")
echo "📦 v$VERSION ($NEW_BUILD)"

# 2. Archive
echo "🔨 Archiving..."
rm -rf "$ARCHIVE_PATH"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -sdk iphoneos \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    archive \
    -allowProvisioningUpdates \
    -quiet 2>&1 | grep -E "error:|ARCHIVE" || true

if [[ ! -d "$ARCHIVE_PATH" ]]; then
    echo "❌ Archive failed"
    exit 1
fi
echo "✅ Archive OK"

# 3. Export + Upload
echo "☁️  Uploading to TestFlight..."
rm -rf "$EXPORT_PATH"
OUTPUT=$(xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_PLIST" \
    -exportPath "$EXPORT_PATH" \
    -allowProvisioningUpdates 2>&1)

if echo "$OUTPUT" | grep -q "Upload succeeded"; then
    echo ""
    echo "✅ TestFlight v$VERSION ($NEW_BUILD) — uploaded"
    echo "⏳ Apple processes 5-15 min → TestFlight app"
else
    echo "$OUTPUT" | grep -E "error:|Upload" || true
    echo "❌ Upload failed"
    exit 1
fi
