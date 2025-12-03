#!/bin/bash
# Diagnostic
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "Diagnostic" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

kt_test_section "Testing BASH_SUBSHELL Diagnostic Behavior"

# Test function for detecting subshell context
test_bash_subshell() {
    echo "Inside function BASH_SUBSHELL: $BASH_SUBSHELL"
}

# Test 1: Function call in main shell
kt_test_start "Function call in main shell"
test_bash_subshell > "$_KT_TMPDIR/test_output.txt" 2>&1
output=$(head -1 "$_KT_TMPDIR/test_output.txt")
expected_value="Inside function BASH_SUBSHELL: 0"
if [[ "$output" == "$expected_value" ]]; then
    kt_test_pass "Function call in main shell"
else
    kt_test_fail "Function call in main shell - got '$output'"
fi

# Test 2: Function call in subshell
kt_test_start "Function call in subshell"
output=$( ( test_bash_subshell 2>&1 ) | head -1 )
if [[ "$output" =~ "Inside function BASH_SUBSHELL" ]]; then
    kt_test_pass "Function call in subshell"
else
    kt_test_fail "Function call in subshell - got '$output'"
fi

# Test 3: BASH_SUBSHELL behavior in nested context
kt_test_start "BASH_SUBSHELL in nested context"
nested_output=$( ( test_bash_subshell 2>&1 ) )
if [[ "$nested_output" =~ "Inside function BASH_SUBSHELL" ]]; then
    kt_test_pass "BASH_SUBSHELL in nested context"
else
    kt_test_fail "BASH_SUBSHELL in nested context - got $nested_output"
fi

kt_test_pass "Diagnostic tests completed"
