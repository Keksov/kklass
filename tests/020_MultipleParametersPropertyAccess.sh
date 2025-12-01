#!/bin/bash
# MultipleParametersPropertyAccess
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "MultipleParametersPropertyAccess" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 20: Method with multiple parameters and property access
kt_test_start "Method with multiple parameters and property access"
defineClass "MathOps" "" \
    "property" "base" \
    "method" "addToBase" 'echo $((base + $1))' \
    "method" "multiplyBase" 'echo $((base * $1))'

MathOps.new math1
math1.base = "10"
result1=$(math1.addToBase 5)
result2=$(math1.multiplyBase 3)
if [[ "$result1" == "15" ]] && [[ "$result2" == "30" ]]; then
    kt_test_pass "Method with multiple parameters and property access"
else
    kt_test_fail "Method with multiple parameters and property access"
fi

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
