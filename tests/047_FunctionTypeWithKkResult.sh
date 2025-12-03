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

# Test 1: Function type should output the RESULT value (via kk._return in subshell)
kt_test_start "Function type outputs RESULT"
# The function should set RESULT and call kk._return which echoes in subshell
result=$(calc.add 5 2>&1)
expected="15"  # 10 + 5 = 15
if [[ "$result" == "$expected" ]]; then
    kt_test_pass "Function type outputs RESULT"
else
    kt_test_fail "Function type should output 15 (got: '$result')"
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
result=$(mult.multiply 6 7)
if [[ "$result" == "42" ]]; then
    kt_test_pass "Function type with multiple arguments"
else
    kt_test_fail "Function type should output 42 (got: '$result')"
fi
mult.delete

# Test 4: Function type with string operations
defineClass "StringOps" "" \
    "property" "prefix" \
    "function" "concat" 'RESULT="${prefix}$1"'

StringOps.new str
str.prefix = "Hello"
kt_test_start "Function type with string operations"
result=$(str.concat " World")
if [[ "$result" == "Hello World" ]]; then
    kt_test_pass "Function type with string operations"
else
    kt_test_fail "Function type should output 'Hello World' (got: '$result')"
fi
str.delete

# Cleanup
calc.delete

