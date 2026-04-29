#!/bin/bash
# regenerate-project.sh — Regenerate Xcode project + restore CocoaPods integration.
#
# Why this script exists: VitaAI uses BOTH xcodegen (project.yml → pbxproj) AND
# CocoaPods (Podfile → Pods/ + xcworkspace + Pods xcconfig refs in pbxproj).
# `xcodegen generate` REWRITES pbxproj entirely from project.yml — wiping out
# Pods xcconfig references → next build fails with "module not found".
#
# Fix: ALWAYS run `pod install` immediately after `xcodegen generate`.
# This script does both. Agents and devs MUST use this script instead of
# calling xcodegen directly.
#
# Background: 2026-04-29 — atlas-laptop-mlkit added CocoaPods (Google ML Kit
# Digital Ink Recognition, no SPM official) while atlas-macmini-materials-f4
# was running xcodegen for QBank work. Each xcodegen wiped Pods refs, builds
# broke. This script enforces the combined workflow permanently.
#
# Refs:
#   - https://github.com/yonaskolb/XcodeGen
#   - https://cocoapods.org/

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "🔧 Regenerating VitaAI.xcodeproj from project.yml..."
xcodegen generate

if [ -f "Podfile" ]; then
    echo "📦 Re-integrating CocoaPods (Google ML Kit + others)..."
    export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
    pod install
    echo "✅ Project + Pods regenerated. Use VitaAI.xcworkspace (NOT VitaAI.xcodeproj)."
else
    echo "⚠️  No Podfile found — only xcodegen ran. Add Podfile if CocoaPods needed."
fi
