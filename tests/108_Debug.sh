#!/bin/bash
# Debug
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "Debug" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

init_test_tmpdir "108_Debug"

test_section "Testing kk._return Debug Behavior"

# Create a test class
defineClass "DebugTest" "" \
    "function" "GetValue" 'RESULT="debug_result"'

DebugTest.new debug_inst

# Test 1: Main shell call
test_start "Main shell method call"
debug_inst.GetValue
if [[ "$RESULT" == "debug_result" ]]; then
    test_pass "Main shell method call"
else
    test_fail "Main shell method call - got $RESULT"
fi

# Test 2: Subshell call
test_start "Subshell method call"
result=$(debug_inst.GetValue 2>&1)
if [[ "$result" == "debug_result" ]]; then
    test_pass "Subshell method call"
else
    test_fail "Subshell method call - got '$result'"
fi

# Test 3: Direct kk._return
test_start "Direct kk._return call"
kk._return "direct_test" "direct_value"
if [[ "${DIRECT_TEST}" == "direct_value" ]]; then
    test_pass "Direct kk._return call"
else
    test_fail "Direct kk._return call - got ${DIRECT_TEST}"
fi

# Test 4: Subshell kk._return with echo capture
test_start "Subshell kk._return with output capture"
result=$(bash -c 'source "$(dirname "${BASH_SOURCE[0]}")/../kklass.sh"; kk._return "subshell_test" "subshell_value"; echo "$SUBSHELL_TEST"')
if [[ -n "$result" ]]; then
    test_pass "Subshell kk._return with output capture"
else
    test_fail "Subshell kk._return with output capture - got empty result"
fi

# Test 5: Variable is set after call
test_start "Variable persists after kk._return"
kk._return "persist_test" "persist_value"
unset RESULT
debug_inst.GetValue
if [[ "$RESULT" == "debug_result" && "${PERSIST_TEST}" == "persist_value" ]]; then
    test_pass "Variable persists after kk._return"
else
    test_fail "Variable persists after kk._return"
fi

debug_inst.delete

# TODO: Migrate this test completely:
# - Replace test_start() with kk_test_start()
# - Replace test_pass() with kk_test_pass()
# - Replace test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
