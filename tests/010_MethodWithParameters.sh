#!/bin/bash
# 010_method_with_parameters.sh - Test method with parameters

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Test 10: Method with parameters
test_start "Method with parameters"
defineClass "Calculator" "" \
    "method" "add" 'echo $(($1 + $2))' \
    "method" "multiply" 'echo $(($1 * $2))'

Calculator.new calc
result=$(calc.add 5 3)
if [[ "$result" == "8" ]]; then
    test_pass "Method with parameters"
else
    test_fail "Method with parameters (expected: '8', got: '$result')"
fi