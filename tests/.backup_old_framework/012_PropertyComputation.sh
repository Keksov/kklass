#!/bin/bash
# 012_property_computation.sh - Test property access and computation in methods

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Test 12: Property access and computation in methods
test_start "Property access and computation in methods"
defineClass "Calculator2" "" \
    "property" "value" \
    "method" "double" 'echo $((value * 2))' \
    "method" "triple" 'echo $((value * 3))'

Calculator2.new calc2
calc2.value = "7"
result1=$(calc2.double)
result2=$(calc2.triple)
if [[ "$result1" == "14" ]] && [[ "$result2" == "21" ]]; then
    test_pass "Property access and computation in methods"
else
    test_fail "Property access and computation in methods (expected: '14' and '21', got: '$result1' and '$result2')"
fi