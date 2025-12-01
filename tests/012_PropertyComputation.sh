#!/bin/bash
# PropertyComputation
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "PropertyComputation" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 12: Property access and computation in methods
kt_test_start "Property access and computation in methods"
defineClass "Calculator2" "" \
    "property" "value" \
    "method" "double" 'echo $((value * 2))' \
    "method" "triple" 'echo $((value * 3))'

Calculator2.new calc2
calc2.value = "7"
result1=$(calc2.double)
result2=$(calc2.triple)
if [[ "$result1" == "14" ]] && [[ "$result2" == "21" ]]; then
    kt_test_pass "Property access and computation in methods"
else
    kt_test_fail "Property access and computation in methods (expected: '14' and '21', got: '$result1' and '$result2')"
fi

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
