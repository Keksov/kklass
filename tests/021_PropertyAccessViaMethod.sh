#!/bin/bash
# PropertyAccessViaMethod
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "PropertyAccessViaMethod" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 21: Property access via .property method
kt_test_start "Property access via .property method"
defineClass "TestProp" "" \
    "property" "data"

TestProp.new testprop
testprop.property "data" = "test_value"
result=$(testprop.property "data")
if [[ "$result" == "test_value" ]]; then
    kt_test_pass "Property access via .property method"
else
    kt_test_fail "Property access via .property method (expected: 'test_value', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
