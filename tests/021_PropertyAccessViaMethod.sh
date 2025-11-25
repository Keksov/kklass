#!/bin/bash
# PropertyAccessViaMethod
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "PropertyAccessViaMethod" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 21: Property access via .property method
kk_test_start "Property access via .property method"
defineClass "TestProp" "" \
    "property" "data"

TestProp.new testprop
testprop.property "data" = "test_value"
result=$(testprop.property "data")
if [[ "$result" == "test_value" ]]; then
    kk_test_pass "Property access via .property method"
else
    kk_test_fail "Property access via .property method (expected: 'test_value', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
