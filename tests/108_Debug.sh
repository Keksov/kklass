#!/bin/bash
# Debug
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "Debug" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

kt_test_section "Testing kk._return Debug Behavior"

# Create a test class
defineClass "DebugTest" "" \
    "function" "GetValue" 'RESULT="debug_result"'

DebugTest.new debug_inst

# Test 1: Main shell call
kt_test_start "Main shell method call"
debug_inst.GetValue
if [[ "$RESULT" == "debug_result" ]]; then
    kt_test_pass "Main shell method call"
else
    kt_test_fail "Main shell method call - got $RESULT"
fi

# Test 2: Subshell call
kt_test_start "Subshell method call"
result=$(debug_inst.GetValue 2>&1)
if [[ "$result" == "debug_result" ]]; then
    kt_test_pass "Subshell method call"
else
    kt_test_fail "Subshell method call - got '$result'"
fi

# Test 3: Cleanup
debug_inst.delete
kt_test_pass "Debug tests completed"
