#!/bin/bash
# 021_property_access_via_method.sh - Test property access via .property method

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Test 21: Property access via .property method
test_start "Property access via .property method"
defineClass "TestProp" "" \
    "property" "data"

TestProp.new testprop
testprop.property "data" = "test_value"
result=$(testprop.property "data")
if [[ "$result" == "test_value" ]]; then
    test_pass "Property access via .property method"
else
    test_fail "Property access via .property method (expected: 'test_value', got: '$result')"
fi