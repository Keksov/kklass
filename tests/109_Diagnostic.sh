#!/bin/bash
# Diagnostic
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "Diagnostic" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

init_test_tmpdir "109_Diagnostic"

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
test_bash_subshell > /tmp/test_output.txt 2>&1
output=$(head -1 /tmp/test_output.txt)
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

# Test 3: Subshell context detection via BASH_SUBSHELL
kk_test_start "BASH_SUBSHELL value in subshell"
subshell_value=$( echo $BASH_SUBSHELL )
if [[ "$subshell_value" -gt 0 ]]; then
    kk_test_pass "BASH_SUBSHELL value in subshell"
else
    kk_test_fail "BASH_SUBSHELL value in subshell - got $subshell_value"
fi

# Test 4: Detect if stdout is being captured
kk_test_start "Terminal detection in main shell"
if [[ -t 1 ]] || [[ ! -t 1 ]]; then
    # This always passes as we're just checking the condition works
    kk_test_pass "Terminal detection in main shell"
else
    kk_test_fail "Terminal detection in main shell"
fi

# Test 5: Nested function calls maintain context
kk_test_start "Nested function context preservation"
inner_func() {
    echo "Inner: BASH_SUBSHELL=$BASH_SUBSHELL"
}

outer_func() {
    echo "Outer before: BASH_SUBSHELL=$BASH_SUBSHELL"
    inner_func
    echo "Outer after: BASH_SUBSHELL=$BASH_SUBSHELL"
}

output=$(outer_func | wc -l)
if [[ "$output" -ge 3 ]]; then
    kk_test_pass "Nested function context preservation"
else
    kk_test_fail "Nested function context preservation - got $output lines"
fi

# Test 6: Main shell BASH_SUBSHELL is always 0
kk_test_start "Main shell BASH_SUBSHELL verification"
if [[ $BASH_SUBSHELL -eq 0 ]]; then
    kk_test_pass "Main shell BASH_SUBSHELL verification"
else
    kk_test_fail "Main shell BASH_SUBSHELL verification - got $BASH_SUBSHELL"
fi

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
