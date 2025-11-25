#!/bin/bash
# MethodWithParameters
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "MethodWithParameters" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 10: Method with parameters
kk_test_start "Method with parameters"
defineClass "Calculator" "" \
    "method" "add" 'echo $(($1 + $2))' \
    "method" "multiply" 'echo $(($1 * $2))'

Calculator.new calc
result=$(calc.add 5 3)
if [[ "$result" == "8" ]]; then
    kk_test_pass "Method with parameters"
else
    kk_test_fail "Method with parameters (expected: '8', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
