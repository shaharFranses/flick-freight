#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <deployment-url>"
    echo "Example: $0 https://flick-freight-abc123.vercel.app"
    exit 1
fi

URL="$1"

echo "════════════════════════════════════════"
echo "🌐 DEPLOYMENT VERIFICATION"
echo "════════════════════════════════════════"
echo "URL: $URL"
echo ""

FAILED=0

# Test 1: Check if index.html exists
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📄 Test 1: index.html exists"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
if [ "$HTTP_CODE" -eq 200 ]; then
    echo "✅ index.html returned HTTP $HTTP_CODE"
else
    echo "❌ index.html returned HTTP $HTTP_CODE (expected 200)"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 2: Check if index.pck exists
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Test 2: index.pck exists"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL/index.pck")
if [ "$HTTP_CODE" -eq 200 ]; then
    echo "✅ index.pck returned HTTP $HTTP_CODE"
else
    echo "❌ index.pck returned HTTP $HTTP_CODE (expected 200)"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 3: Check if index.wasm exists
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Test 3: index.wasm exists"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL/index.wasm")
if [ "$HTTP_CODE" -eq 200 ]; then
    echo "✅ index.wasm returned HTTP $HTTP_CODE"
else
    echo "❌ index.wasm returned HTTP $HTTP_CODE (expected 200)"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 4: Check if index.js exists
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📜 Test 4: index.js exists"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL/index.js")
if [ "$HTTP_CODE" -eq 200 ]; then
    echo "✅ index.js returned HTTP $HTTP_CODE"
else
    echo "❌ index.js returned HTTP $HTTP_CODE (expected 200)"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 5: Check HTML title
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 Test 5: HTML title is 'Flick Freight'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
TITLE=$(curl -s "$URL" | grep -oP '(?<=<title>).*?(?=</title>)' || true)
if [ "$TITLE" = "Flick Freight" ]; then
    echo "✅ Title is 'Flick Freight'"
else
    echo "❌ Title is '$TITLE' (expected 'Flick Freight')"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 6: Check for CORS headers (ensureCrossOriginIsolationHeaders=false)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔒 Test 6: CORS headers check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
HTML_CONTENT=$(curl -s "$URL")
if echo "$HTML_CONTENT" | grep -q "ensureCrossOriginIsolationHeaders.*false"; then
    echo "✅ ensureCrossOriginIsolationHeaders = false"
else
    echo "⚠️  ensureCrossOriginIsolationHeaders setting not found or not false"
fi
echo ""

# Test 7: Check for Godot config
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎮 Test 7: Godot config present"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if echo "$HTML_CONTENT" | grep -q "GODOT_CONFIG"; then
    echo "✅ GODOT_CONFIG found in HTML"
else
    echo "❌ GODOT_CONFIG not found in HTML"
    FAILED=$((FAILED + 1))
fi
echo ""

# Summary
echo "════════════════════════════════════════"
if [ $FAILED -eq 0 ]; then
    echo "✅ ALL DEPLOYMENT CHECKS PASSED"
    echo "════════════════════════════════════════"
    exit 0
else
    echo "❌ $FAILED CHECK(S) FAILED"
    echo "════════════════════════════════════════"
    exit 1
fi
