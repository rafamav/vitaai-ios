#!/bin/bash
# Validates that every endpoint in VitaAPI.swift exists in the backend.
# Compares against actual route files in vitaai-web/src/app/api/
# Run: ./scripts/lint-api-endpoints.sh

set -euo pipefail

VITA_API="VitaAI/Core/Network/VitaAPI.swift"
BACKEND_DIR="/Users/mav/conductor/repos/vitaai-web/src/app/api"
OPENAPI="/Users/mav/conductor/repos/vitaai-web/openapi.yaml"

if [ ! -f "$VITA_API" ]; then
    echo "ERROR: $VITA_API not found. Run from vitaai-ios root."
    exit 1
fi

# Extract all endpoint paths from VitaAPI.swift
ios_endpoints=$(grep -oE '\.(get|post|put|patch|delete|downloadText|downloadRaw|postRaw|uploadMultipart)\("[a-zA-Z0-9/_.-]+"' "$VITA_API" \
    | sed 's/^[^"]*"//;s/"$//' \
    | sort -u)

errors=0
ok=0

echo "Checking iOS API endpoints against backend routes..."
echo ""

for ep in $ios_endpoints; do
    # Check if route file exists in backend
    if [ -f "$BACKEND_DIR/$ep/route.ts" ]; then
        ok=$((ok + 1))
        continue
    fi

    # Check if it's in openapi.yaml
    if grep -q "  /api/$ep:" "$OPENAPI" 2>/dev/null; then
        ok=$((ok + 1))
        continue
    fi
    if grep -q "  /api/${ep}:" "$OPENAPI" 2>/dev/null; then
        ok=$((ok + 1))
        continue
    fi

    # Check parent for catch-all/dynamic routes
    parent=$(dirname "$ep")
    if [ "$parent" != "." ] && [ -d "$BACKEND_DIR/$parent" ]; then
        if ls "$BACKEND_DIR/$parent/" 2>/dev/null | grep -q '^\['; then
            ok=$((ok + 1))
            continue
        fi
    fi

    echo "  DEAD: $ep"
    errors=$((errors + 1))
done

echo ""
echo "Results: $ok valid, $errors dead"

if [ $errors -gt 0 ]; then
    echo ""
    echo "FAILED: $errors endpoints in VitaAPI.swift have no backend route."
    echo "Fix: remove the dead function or create the backend route + openapi entry first."
    exit 1
fi

echo "PASSED"
exit 0
