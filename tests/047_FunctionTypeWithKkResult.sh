#!/bin/bash
# 047_FunctionTypeWithKkResult.sh - Test that function type methods append kk._result call

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Setup: Create TestClass with function and method
defineClass "Calculator" "" \
    "property" "value" \
    "function" "add" 'RESULT=$((value + $1))' \
    "method" "subtract" 'echo $((value - $1))'

Calculator.new calc
calc.value = "10"

# Test 1: Function type should inject kk._result call and set CALCULATOR_ADD variable
test_start "Function type injects kk._result"
# The function should set RESULT and then call kk._result which sets CALCULATOR_ADD
calc.add 5 2>&1
# Check if kk._result was called and variable was set
if [[ "${CALCULATOR_ADD}" == "15" ]]; then
    test_pass "Function type injects kk._result"
else
    test_fail "Function type should set CALCULATOR_ADD=15 via kk._result (got: '${CALCULATOR_ADD}')"
fi

# Test 2: Verify method type doesn't inject kk._result (method should still work)
test_start "Method type doesn't inject kk._result"
result=$(calc.subtract 3)
expected="7"  # 10 - 3 = 7
if [[ "$result" == "$expected" ]]; then
    test_pass "Method type works correctly"
else
    test_fail "Method type should return echo output (expected: '$expected', got: '$result')"
fi

# Test 3: Function type with multiple arguments
defineClass "Multiplier" "" \
    "function" "multiply" 'RESULT=$((($1) * ($2)))'

Multiplier.new mult
test_start "Function type with multiple arguments"
mult.multiply 6 7
if [[ "${MULTIPLIER_MULTIPLY}" == "42" ]]; then
    test_pass "Function type with multiple arguments"
else
    test_fail "Function type should set MULTIPLIER_MULTIPLY=42 (got: '${MULTIPLIER_MULTIPLY}')"
fi
mult.delete

# Test 4: Function type with string operations
defineClass "StringOps" "" \
    "property" "prefix" \
    "function" "concat" 'RESULT="${prefix}$1"'

StringOps.new str
str.prefix = "Hello"
test_start "Function type with string operations"
str.concat " World"
if [[ "${STRINGOPS_CONCAT}" == "Hello World" ]]; then
    test_pass "Function type with string operations"
else
    test_fail "Function type should set STRINGOPS_CONCAT='Hello World' (got: '${STRINGOPS_CONCAT}')"
fi
str.delete

# Cleanup
calc.delete

# Show results
#show_results
