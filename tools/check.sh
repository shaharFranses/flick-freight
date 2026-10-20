#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "════════════════════════════════════════"
echo "🧪 FLICK FREIGHT TEST SUITE"
echo "════════════════════════════════════════"

# Check for Godot
if ! command -v godot &> /dev/null; then
    echo "❌ ERROR: godot command not found"
    echo "   Install Godot 4.3+ or add it to PATH"
    exit 1
fi

GODOT_VERSION=$(godot --version 2>&1 | head -n1)
echo "Godot version: $GODOT_VERSION"
echo ""

FAILED=0

# Test 1: Layout test
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📐 Test 1: Layout test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if godot --headless --script tools/layout_test.gd 2>&1; then
    echo "✅ Layout test passed"
else
    echo "❌ Layout test failed"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 2: Runtime test
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚙️  Test 2: Runtime test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if godot --headless --script tools/runtime_test.gd 2>&1; then
    echo "✅ Runtime test passed"
else
    echo "❌ Runtime test failed"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 3: QA test
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Test 3: QA test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if godot --headless --script tools/qa_test.gd 2>&1; then
    echo "✅ QA test passed"
else
    echo "❌ QA test failed"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 4: Tap target test
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎯 Test 4: Tap target test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if godot --headless --script tools/tap_target_test.gd 2>&1; then
    echo "✅ Tap target test passed"
else
    echo "❌ Tap target test failed"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 5: Boot pause test
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Test 5: Boot pause test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if godot --headless --script tools/boot_pause_test.gd 2>&1; then
    echo "✅ Boot pause test passed"
else
    echo "❌ Boot pause test failed"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 6: Bay ramp test (ITEM 1)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚚 Test 6: Bay ramp test (ITEM 1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if godot --headless --script tools/bay_ramp_test.gd 2>&1; then
    echo "✅ Bay ramp test passed"
else
    echo "❌ Bay ramp test failed"
    FAILED=$((FAILED + 1))
fi
echo ""

# Test 7: Miss shake test (ITEM 2)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💥 Test 7: Miss shake test (ITEM 2)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if godot --headless --script tools/miss_shake_test.gd 2>&1; then
    echo "✅ Miss shake test passed"
else
    echo "❌ Miss shake test failed"
    FAILED=$((FAILED + 1))
fi
echo ""

# Check export for test files (must be stripped in release)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Test 8: Export cleanliness check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f export/index.pck ]; then
    TEST_FILE_COUNT=$(strings export/index.pck | grep -c -E 'qa_test|runtime_test|layout_test|tap_target_test|boot_pause|bay_ramp_test|miss_shake_test' || true)
    if [ "$TEST_FILE_COUNT" -eq 0 ]; then
        echo "✅ Export is clean (no test files found)"
    else
        echo "❌ Export contains test files (found $TEST_FILE_COUNT references)"
        FAILED=$((FAILED + 1))
    fi
else
    echo "⚠️  No export/index.pck found (skipping export check)"
fi
echo ""

# Summary
echo "════════════════════════════════════════"
if [ $FAILED -eq 0 ]; then
    echo "✅ ALL TESTS PASSED"
    echo "════════════════════════════════════════"
    exit 0
else
    echo "❌ $FAILED TEST(S) FAILED"
    echo "════════════════════════════════════════"
    exit 1
fi
