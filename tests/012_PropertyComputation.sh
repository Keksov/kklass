#!/bin/bash
# PropertyComputation
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "PropertyComputation" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 12: Property access and computation in methods
test_start "Property access and computation in methods"
defineClass "Calculator2" "" \
    "property" "value" \
    "method" "double" 'echo $((value * 2))' \
    "method" "triple" 'echo $((value * 3))'

Calculator2.new calc2
calc2.value = "7"
result1=$(calc2.double)
result2=$(calc2.triple)
if [[ "$result1" == "14" ]] && [[ "$result2" == "21" ]]; then
    test_pass "Property access and computation in methods"
else
    test_fail "Property access and computation in methods (expected: '14' and '21', got: '$result1' and '$result2')"
fi

# TODO: Migrate this test completely:
# - Replace test_start() with kk_test_start()
# - Replace test_pass() with kk_test_pass()
# - Replace test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
