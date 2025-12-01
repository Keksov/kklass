#!/bin/bash
# AutodetectSubshell
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "AutodetectSubshell" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

kt_test_section "Testing Automatic Subshell Detection"

# Define a simple test class with a function that returns a value  
defineClass "TestClass" "" \
    "function" "GetIndex" 'RESULT="42"'

# Create instance
TestClass.new mytest

# Test 1: Direct variable assignment (main shell) - should be fast, no echo
kt_test_start "Direct variable assignment (main shell context)"
mytest.GetIndex
index=$RESULT
if [[ "$index" == "42" ]]; then
    kt_test_pass "Direct variable assignment (main shell context)"
else
    kt_test_fail "Direct variable assignment (main shell context) - got '$index'"
fi

# Test 2: Real subshell assignment with $() - should use echo automatically
kt_test_start "Real subshell assignment with command substitution"
index=$(mytest.GetIndex)
if [[ "$index" == "42" ]]; then
    kt_test_pass "Real subshell assignment with command substitution"
else
    kt_test_fail "Real subshell assignment with command substitution - got '$index'"
fi

# Test 3: Real subshell with backticks - should also use echo automatically
kt_test_start "Real subshell with backticks"
index=`mytest.GetIndex`
if [[ "$index" == "42" ]]; then
    kt_test_pass "Real subshell with backticks"
else
    kt_test_fail "Real subshell with backticks - got '$index'"
fi

# Test 4: Real nested subshell
kt_test_start "Nested subshell context"
index=$(
    mytest.GetIndex
)
if [[ "$index" == "42" ]]; then
    kt_test_pass "Nested subshell context"
else
    kt_test_fail "Nested subshell context - got '$index'"
fi

# Cleanup
mytest.delete
