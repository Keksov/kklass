#!/bin/bash
# MultipleParametersPropertyAccess
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "MultipleParametersPropertyAccess" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 20: Method with multiple parameters and property access
kk_test_start "Method with multiple parameters and property access"
defineClass "MathOps" "" \
    "property" "base" \
    "method" "addToBase" 'echo $((base + $1))' \
    "method" "multiplyBase" 'echo $((base * $1))'

MathOps.new math1
math1.base = "10"
result1=$(math1.addToBase 5)
result2=$(math1.multiplyBase 3)
if [[ "$result1" == "15" ]] && [[ "$result2" == "30" ]]; then
    kk_test_pass "Method with multiple parameters and property access"
else
    kk_test_fail "Method with multiple parameters and property access"
fi

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
