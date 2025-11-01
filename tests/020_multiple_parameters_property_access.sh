#!/bin/bash
# 020_multiple_parameters_property_access.sh - Test method with multiple parameters and property access

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Test 20: Method with multiple parameters and property access
test_start "Method with multiple parameters and property access"
defineClass "MathOps" "" \
    "property" "base" \
    "method" "addToBase" 'echo $((base + $1))' \
    "method" "multiplyBase" 'echo $((base * $1))'

MathOps.new math1
math1.base = "10"
result1=$(math1.addToBase 5)
result2=$(math1.multiplyBase 3)
if [[ "$result1" == "15" ]] && [[ "$result2" == "30" ]]; then
    test_pass "Method with multiple parameters and property access"
else
    test_fail "Method with multiple parameters and property access"
fi