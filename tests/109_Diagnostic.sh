#!/bin/bash
# Diagnostic
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "Diagnostic" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

kk_test_section "Testing BASH_SUBSHELL Diagnostic Behavior"

# Test function for detecting subshell context
test_bash_subshell() {
    echo "Inside function BASH_SUBSHELL: $BASH_SUBSHELL"
    
    # Test kk._return from function context
    kk._return "diag_test" "diag_value"
    echo "Variable DIAG_TEST: ${DIAG_TEST}"
}

# Test 1: Function call in main shell
kk_test_start "Function call in main shell"
test_bash_subshell > "$KK_TEST_TMPDIR/test_output.txt" 2>&1
output=$(head -1 "$KK_TEST_TMPDIR/test_output.txt")
expected_value="Inside function BASH_SUBSHELL: 0"
if [[ "$output" == "$expected_value" ]]; then
    kk_test_pass "Function call in main shell"
else
    kk_test_fail "Function call in main shell - got '$output'"
fi

# Test 2: Function call in subshell
kk_test_start "Function call in subshell"
output=$( ( test_bash_subshell 2>&1 ) | head -1 )
if [[ "$output" =~ "Inside function BASH_SUBSHELL" ]]; then
    kk_test_pass "Function call in subshell"
else
    kk_test_fail "Function call in subshell - got '$output'"
fi

# Test 3: kk._return in diagnostic context
kk_test_start "kk._return in diagnostic context"
kk._return "diag_result" "test_value"
if [[ "${DIAG_RESULT}" == "test_value" ]]; then
    kk_test_pass "kk._return in diagnostic context"
else
    kk_test_fail "kk._return in diagnostic context - got ${DIAG_RESULT}"
fi

kk_test_pass "Diagnostic tests completed"
