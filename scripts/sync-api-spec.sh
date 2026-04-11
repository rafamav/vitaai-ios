#!/bin/bash
# sync-api-spec.sh — Syncs OpenAPI spec from GitHub and regenerates Swift models
# Usage: ./scripts/sync-api-spec.sh

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GENERATED_API="$REPO_ROOT/Generated/API"
GENERATED_MODELS="$REPO_ROOT/VitaAI/Generated/Models"
GENERATED_INFRA="$REPO_ROOT/VitaAI/Generated/Infrastructure"

echo "[1/4] Pulling latest openapi.yaml from GitHub..."
cd "$REPO_ROOT"
git fetch origin main --quiet
git checkout origin/main -- openapi.yaml 2>/dev/null || {
    echo "  openapi.yaml not in git yet. Copying from monstro via Tailscale..."
    scp monstro:openapi.yaml "$REPO_ROOT/openapi.yaml"
}

echo "[2/4] Generating Swift models from OpenAPI..."
openapi-generator generate     -i openapi.yaml     -g swift6     -o "$GENERATED_API"     --global-property models,supportingFiles     --additional-properties projectName=VitaAPI,useSPMFileStructure=true,library=urlsession     2>&1 | grep -c 'writing file' | xargs -I{} echo "  Generated {} files"

echo "[3/4] Copying models to project..."
mkdir -p "$GENERATED_MODELS" "$GENERATED_INFRA"

# Copy infrastructure (only JSONValue needed)
cp "$GENERATED_API/Sources/VitaAPI/Infrastructure/JSONValue.swift" "$GENERATED_INFRA/"

# Copy all models that are currently in use
for f in "$GENERATED_MODELS"/*.swift; do
    basename="$(basename "$f")"
    src="$GENERATED_API/Sources/VitaAPI/Models/$basename"
    if [ -f "$src" ]; then
        cp "$src" "$f"
    fi
done

echo "[4/4] Regenerating Xcode project..."
cd "$REPO_ROOT"
xcodegen generate 2>&1 | tail -1

echo ""
echo "Done! Run a build to verify:"
echo "  xcodebuild -project VitaAI.xcodeproj -scheme VitaAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build"
