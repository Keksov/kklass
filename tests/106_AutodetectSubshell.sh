#!/bin/bash
# 106_AutodetectSubshell.sh - Test automatic subshell detection in kk._return()

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

init_test_tmpdir "106_AutodetectSubshell"

test_section "Testing Automatic Subshell Detection"

# Define a simple test class with a function that returns a value  
defineClass "TestClass" "" \
    "function" "GetIndex" 'RESULT="42"'

# Create instance
TestClass.new mytest

# Test 1: Direct variable assignment (main shell) - should be fast, no echo
test_start "Direct variable assignment (main shell context)"
mytest.GetIndex
index=$RESULT
if [[ "$index" == "42" ]]; then
    test_pass "Direct variable assignment (main shell context)"
else
    test_fail "Direct variable assignment (main shell context) - got '$index'"
fi

# Test 2: Real subshell assignment with $() - should use echo automatically
test_start "Real subshell assignment with command substitution"
index=$(mytest.GetIndex)
if [[ "$index" == "42" ]]; then
    test_pass "Real subshell assignment with command substitution"
else
    test_fail "Real subshell assignment with command substitution - got '$index'"
fi

# Test 3: Real subshell with backticks - should also use echo automatically
test_start "Real subshell with backticks"
index=`mytest.GetIndex`
if [[ "$index" == "42" ]]; then
    test_pass "Real subshell with backticks"
else
    test_fail "Real subshell with backticks - got '$index'"
fi

# Test 4: Explicit echo result enabled
test_start "Explicit echo result enabled (KK_ECHO_RESULT=true)"
export KK_ECHO_RESULT=true
output=$(mytest.GetIndex 2>&1)
if [[ "$output" == "42" ]]; then
    test_pass "Explicit echo result enabled (KK_ECHO_RESULT=true)"
else
    test_fail "Explicit echo result enabled (KK_ECHO_RESULT=true) - got '$output'"
fi

# Test 5: Explicit echo result disabled (should override auto-detect)
test_start "Explicit echo result disabled (KK_ECHO_RESULT=false)"
export KK_ECHO_RESULT=false
output=$(mytest.GetIndex 2>&1)
if [[ -z "$output" ]]; then
    test_pass "Explicit echo result disabled (KK_ECHO_RESULT=false)"
else
    test_fail "Explicit echo result disabled (KK_ECHO_RESULT=false) - got '$output'"
fi

# Reset KK_ECHO_RESULT for following tests
unset KK_ECHO_RESULT

# Test 6: Real nested subshell
test_start "Nested subshell context"
index=$(
    mytest.GetIndex
)
if [[ "$index" == "42" ]]; then
    test_pass "Nested subshell context"
else
    test_fail "Nested subshell context - got '$index'"
fi

# Cleanup
unset KK_ECHO_RESULT
mytest.delete
