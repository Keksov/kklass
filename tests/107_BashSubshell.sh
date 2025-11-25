#!/bin/bash
# BashSubshell
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "BashSubshell" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

init_test_tmpdir "107_BashSubshell"

test_section "Testing BASH_SUBSHELL Detection"

# Test BASH_SUBSHELL behavior
test_start "Main shell BASH_SUBSHELL is 0"
if [[ $BASH_SUBSHELL -eq 0 ]]; then
    test_pass "Main shell BASH_SUBSHELL is 0"
else
    test_fail "Main shell BASH_SUBSHELL is 0 - got $BASH_SUBSHELL"
fi

# Test subshell
test_start "Subshell BASH_SUBSHELL detection"
result=$( echo $BASH_SUBSHELL )
if [[ "$result" -gt 0 ]]; then
    test_pass "Subshell BASH_SUBSHELL detection"
else
    test_fail "Subshell BASH_SUBSHELL detection - got $result"
fi

# Test kk._return in main shell
test_start "kk._return in main shell"
kk._return "test_main" "main_value"
if [[ "${TEST_MAIN}" == "main_value" ]]; then
    test_pass "kk._return in main shell"
else
    test_fail "kk._return in main shell - got ${TEST_MAIN}"
fi

# Test kk._return in subshell
test_start "kk._return in subshell"
result=$( kk._return "test_sub" "sub_value" )
if [[ "$result" == "sub_value" ]]; then
    test_pass "kk._return in subshell"
else
    test_fail "kk._return in subshell - got '$result'"
fi

test_section "Testing Method Calls"

# Define test class
defineClass "SimpleTest" "" \
    "function" "GetValue" 'RESULT="success"'

SimpleTest.new test_inst

# Main shell call
test_start "Main shell method call"
test_inst.GetValue
if [[ "$RESULT" == "success" ]]; then
    test_pass "Main shell method call"
else
    test_fail "Main shell method call - got $RESULT"
fi

# Subshell call
test_start "Subshell method call"
result=$(test_inst.GetValue)
if [[ "$result" == "success" ]]; then
    test_pass "Subshell method call"
else
    test_fail "Subshell method call - got '$result'"
fi

test_inst.delete

# TODO: Migrate this test completely:
# - Replace test_start() with kk_test_start()
# - Replace test_pass() with kk_test_pass()
# - Replace test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
