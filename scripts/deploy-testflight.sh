#!/bin/bash
# deploy-testflight.sh — One-command TestFlight deploy (revamped 2026-04-18)
# Usage: ./scripts/deploy-testflight.sh [marketing_version]
# Example: ./scripts/deploy-testflight.sh 1.2.0
#
# Fixes encoded from incidents 2026-04-18_testflight-build-number-creep.md and
# today's HealthKit purpose-string rejection:
#
#   1. PRE-FLIGHT validation: check Info.plist for every purpose-string Apple
#      requires for our current SDKs (Sentry, PostHog, HealthKit, etc). If any
#      is missing, FAIL BEFORE touching build number — no wasted uploads.
#
#   2. Build number: query ASC API for the last uploaded build and set
#      CURRENT_PROJECT_VERSION to (asc_max + 1). No local-vs-ASC drift; no
#      creep from aborted deploys. Called ONLY after pre-flight passes.
#
#   3. NO rm -rf DerivedData before archive. Previous version deleted the SPM
#      artifact cache which produced "Could not resolve package dependencies"
#      errors repeatedly. xcodebuild manages its own cache.
#
#   4. Rollback on failure: if archive OR export fails, restore the
#      pre-deploy build number so we don't burn slots.
#
#   5. Final output reports the actual uploaded build number + links to the
#      TestFlight processing page.
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

SCHEME="VitaAI"
PROJECT="VitaAI.xcodeproj"
INFO_PLIST="VitaAI/Info.plist"
ARCHIVE_PATH="/tmp/VitaAI.xcarchive"
EXPORT_PATH="/tmp/VitaAI-export"
EXPORT_PLIST="$PROJECT_DIR/scripts/ExportOptions.plist"

# ASC API config
ASC_KEY_ID="4KYZTCFPWX"
ASC_KEY_FILE="$HOME/.private_keys/AuthKey_${ASC_KEY_ID}.p8"
ASC_ISSUER_ID="6fc1df15-2bd3-4fcf-8251-0a12be7d26d3"
ASC_APP_ID="6759848167"

# Required Info.plist purpose strings. Keep this list in sync with the SDKs
# and capabilities we actually ship. Missing => FAIL pre-flight, don't burn
# a build number or wait 3 minutes for Apple to reject the upload.
REQUIRED_PURPOSE_KEYS=(
    "NSMicrophoneUsageDescription"         # transcrição (usado)
    "NSSpeechRecognitionUsageDescription"  # transcrição (usado)
    "NSCameraUsageDescription"             # foto de prova (usado)
    "NSPhotoLibraryUsageDescription"       # upload de material (usado)
    "NSPhotoLibraryAddUsageDescription"    # salvar screenshot (usado)
    # Indirect via SDKs (not used in code, required because frameworks reference APIs):
    "NSHealthShareUsageDescription"        # Sentry/PostHog — any HealthKit API ref
    "NSHealthUpdateUsageDescription"       # same (required since ~Sentry 8.58)
    "NSUserTrackingUsageDescription"       # ATT required if any SDK uses IDFA
)

echo "=============================="
echo "  VitaAI TestFlight Deploy"
echo "=============================="

# 0. Unlock keychain (avoids errSecInternalComponent)
security unlock-keychain -p "" ~/Library/Keychains/login.keychain-db 2>/dev/null || true

# -------------------------------------------------------------------------
# STEP 1: PRE-FLIGHT — validate Info.plist requirements BEFORE any work
# -------------------------------------------------------------------------
echo ""
echo "[1/5] Pre-flight validation..."
MISSING=()
for key in "${REQUIRED_PURPOSE_KEYS[@]}"; do
    if ! /usr/libexec/PlistBuddy -c "Print :$key" "$INFO_PLIST" > /dev/null 2>&1; then
        MISSING+=("$key")
    fi
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "       FAIL — missing Info.plist keys:"
    for k in "${MISSING[@]}"; do echo "         - $k"; done
    echo ""
    echo "       Add each to VitaAI/Info.plist AND project.yml, then retry."
    echo "       Apple rejects uploads that reference these APIs (even via SDKs)"
    echo "       without a user-facing purpose string."
    exit 1
fi
echo "       Info.plist OK (${#REQUIRED_PURPOSE_KEYS[@]} purpose strings validated)"

# -------------------------------------------------------------------------
# STEP 2: Build number — ASC-as-source-of-truth, rollback on failure
# -------------------------------------------------------------------------
echo ""
echo "[2/5] Resolving build number from ASC..."
ORIGINAL_BUILD=$(agvtool what-version -terse 2>/dev/null || echo "0")

HIGHEST_ASC_BUILD=$(python3 - <<PYEOF 2>/dev/null || echo "0"
import jwt, time, json, urllib.request, ssl
with open("${ASC_KEY_FILE}", "r") as f: pk = f.read()
token = jwt.encode({"iss": "${ASC_ISSUER_ID}", "iat": int(time.time()), "exp": int(time.time()) + 600, "aud": "appstoreconnect-v1"}, pk, algorithm="ES256", headers={"kid": "${ASC_KEY_ID}"})
ctx = ssl.create_default_context()
url = "https://api.appstoreconnect.apple.com/v1/builds?filter%5Bapp%5D=${ASC_APP_ID}&sort=-uploadedDate&limit=10"
req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
resp = urllib.request.urlopen(req, context=ctx)
data = json.loads(resp.read())
nums = [int(b["attributes"]["version"]) for b in data.get("data", []) if (b.get("attributes") or {}).get("version", "").isdigit()]
print(max(nums) if nums else 0)
PYEOF
)

MAX_BUILD=$((HIGHEST_ASC_BUILD > ORIGINAL_BUILD ? HIGHEST_ASC_BUILD : ORIGINAL_BUILD))
NEW_BUILD=$((MAX_BUILD + 1))
agvtool new-version -all "$NEW_BUILD" > /dev/null 2>&1

# Rollback on failure — restore original build number so aborted deploys don't
# permanently burn slots and create gaps in git history.
rollback_build() {
    if [[ "${DEPLOY_SUCCESS:-0}" != "1" ]]; then
        echo ""
        echo "       Rolling back build number $NEW_BUILD -> $ORIGINAL_BUILD (deploy aborted)"
        agvtool new-version -all "$ORIGINAL_BUILD" > /dev/null 2>&1 || true
    fi
}
trap rollback_build EXIT

if [[ -n "${1:-}" ]]; then
    agvtool new-marketing-version "$1" > /dev/null 2>&1
fi
VERSION=$(agvtool what-marketing-version -terse1 2>/dev/null || echo "1.0.0")

echo "       ASC highest: $HIGHEST_ASC_BUILD  |  local: $ORIGINAL_BUILD  ->  new: $NEW_BUILD"
echo "       v$VERSION ($NEW_BUILD)"

# -------------------------------------------------------------------------
# STEP 3: Archive (no DerivedData wipe — xcodebuild manages cache)
# -------------------------------------------------------------------------
echo ""
echo "[3/5] Archiving... (60-90s)"
find "$ARCHIVE_PATH" -delete 2>/dev/null || true
set +e
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -sdk iphoneos \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    archive \
    -allowProvisioningUpdates \
    -quiet 2>&1 | tail -20
ARCHIVE_RC=${PIPESTATUS[0]}
set -e

if [[ $ARCHIVE_RC -ne 0 || ! -d "$ARCHIVE_PATH" ]]; then
    echo "       FAIL — archive exit=$ARCHIVE_RC"
    echo "       Common causes:"
    echo "        - SPM artifact cache corrupted: run 'find ~/Library/Caches/org.swift.swiftpm -name sentry\\* -delete' and retry"
    echo "        - DerivedData stale: run 'find ~/Library/Developer/Xcode/DerivedData/VitaAI-\\* -delete' and retry"
    exit 1
fi
echo "       Archive OK"

# -------------------------------------------------------------------------
# STEP 4: Export + Upload
# -------------------------------------------------------------------------
echo ""
echo "[4/5] Uploading to ASC... (30-60s)"
find "$EXPORT_PATH" -delete 2>/dev/null || true
set +e
OUTPUT=$(xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_PLIST" \
    -exportPath "$EXPORT_PATH" \
    -allowProvisioningUpdates 2>&1)
EXPORT_RC=$?
set -e

if [[ $EXPORT_RC -ne 0 ]] || ! echo "$OUTPUT" | grep -q "Upload succeeded"; then
    echo "       FAIL — export exit=$EXPORT_RC"
    echo "$OUTPUT" | grep -iE "error:|failed|missing.*purpose|code = 90" | head -5 || true
    echo "       Tip: add any missing Info.plist key to REQUIRED_PURPOSE_KEYS in this script."
    exit 1
fi
echo "       Upload succeeded"

# Mark deploy successful — prevents rollback trap from restoring build number
DEPLOY_SUCCESS=1

# -------------------------------------------------------------------------
# STEP 5: Auto-resolve export compliance + report final state
# -------------------------------------------------------------------------
echo ""
echo "[5/5] Waiting for ASC to process build $NEW_BUILD (up to 3min)..."
python3 - <<PYEOF
import jwt, time, json, urllib.request, ssl, sys
with open("${ASC_KEY_FILE}", "r") as f: pk = f.read()
token = jwt.encode({"iss": "${ASC_ISSUER_ID}", "iat": int(time.time()), "exp": int(time.time()) + 1800, "aud": "appstoreconnect-v1"}, pk, algorithm="ES256", headers={"kid": "${ASC_KEY_ID}"})
ctx = ssl.create_default_context()
url = "https://api.appstoreconnect.apple.com/v1/builds?filter%5Bapp%5D=${ASC_APP_ID}&filter%5Bversion%5D=${NEW_BUILD}&filter%5BpreReleaseVersion.platform%5D=IOS"

for i in range(36):  # 36 * 5s = 180s max
    try:
        req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
        resp = urllib.request.urlopen(req, context=ctx)
        data = json.loads(resp.read())
        if data.get("data"):
            b = data["data"][0]
            state = b["attributes"]["processingState"]
            if state == "VALID":
                # set compliance flag automatically
                body = json.dumps({"data": {"type": "builds", "id": b["id"], "attributes": {"usesNonExemptEncryption": False}}}).encode()
                req2 = urllib.request.Request(f"https://api.appstoreconnect.apple.com/v1/builds/{b['id']}", data=body, method="PATCH",
                    headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
                urllib.request.urlopen(req2, context=ctx)
                print(f"       VALID — compliance set, build live in TestFlight")
                sys.exit(0)
            elif state in ("FAILED", "INVALID"):
                print(f"       ASC rejected build: state={state}")
                sys.exit(1)
            print(f"       ASC state: {state} ({(i+1)*5}s elapsed)", flush=True)
        else:
            print(f"       Build not indexed yet ({(i+1)*5}s)", flush=True)
    except Exception as e:
        print(f"       Poll error ({(i+1)*5}s): {str(e)[:80]}", flush=True)
    time.sleep(5)
print("       Still processing after 3min — check TestFlight manually. Build was uploaded OK.")
PYEOF

echo ""
echo "=============================="
echo "  DONE: v$VERSION ($NEW_BUILD)"
echo "  - TestFlight: open on iPhone and wait for push"
echo "  - ASC: https://appstoreconnect.apple.com/apps/${ASC_APP_ID}/testflight/ios"
echo "=============================="
