#!/bin/bash
# FunctionTypeWithKkResult
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "FunctionTypeWithKkResult" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Setup: Create TestClass with function and method
defineClass "Calculator" "" \
    "property" "value" \
    "function" "add" 'RESULT=$((value + $1))' \
    "method" "subtract" 'echo $((value - $1))'

Calculator.new calc
calc.value = "10"

# Test 1: Function type should inject kk._return call and set CALCULATOR_ADD variable
kt_test_start "Function type injects kk._return"
# The function should set RESULT and then call kk._return which sets CALCULATOR_ADD
calc.add 5 2>&1
# Check if kk._return was called and variable was set
if [[ "${CALCULATOR_ADD}" == "15" ]]; then
    kt_test_pass "Function type injects kk._return"
else
    kt_test_fail "Function type should set CALCULATOR_ADD=15 via kk._return (got: '${CALCULATOR_ADD}')"
fi

# Test 2: Verify method type doesn't inject kk._return (method should still work)
kt_test_start "Method type doesn't inject kk._return"
result=$(calc.subtract 3)
expected="7"  # 10 - 3 = 7
if [[ "$result" == "$expected" ]]; then
    kt_test_pass "Method type works correctly"
else
    kt_test_fail "Method type should return echo output (expected: '$expected', got: '$result')"
fi

# Test 3: Function type with multiple arguments
defineClass "Multiplier" "" \
    "function" "multiply" 'RESULT=$((($1) * ($2)))'

Multiplier.new mult
kt_test_start "Function type with multiple arguments"
mult.multiply 6 7
if [[ "${MULTIPLIER_MULTIPLY}" == "42" ]]; then
    kt_test_pass "Function type with multiple arguments"
else
    kt_test_fail "Function type should set MULTIPLIER_MULTIPLY=42 (got: '${MULTIPLIER_MULTIPLY}')"
fi
mult.delete

# Test 4: Function type with string operations
defineClass "StringOps" "" \
    "property" "prefix" \
    "function" "concat" 'RESULT="${prefix}$1"'

StringOps.new str
str.prefix = "Hello"
kt_test_start "Function type with string operations"
str.concat " World"
if [[ "${STRINGOPS_CONCAT}" == "Hello World" ]]; then
    kt_test_pass "Function type with string operations"
else
    kt_test_fail "Function type should set STRINGOPS_CONCAT='Hello World' (got: '${STRINGOPS_CONCAT}')"
fi
str.delete

# Cleanup
calc.delete

# Show results
#show_results

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
