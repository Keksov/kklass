#!/bin/bash
# 035_complex_property_names.sh - Test complex property names

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Test 35: Complex property names
test_start "Complex property names"
defineClass "ComplexTest" "" \
    "property" "file_name" \
    "property" "file_size"

ComplexTest.new complextest
complextest.file_name = "test.txt"
complextest.file_size = "1024"

if [[ "$(complextest.file_name)" == "test.txt" ]] && [[ "$(complextest.file_size)" == "1024" ]]; then
    test_pass "Complex property names"
else
    test_fail "Complex property names"
fi

# Test 35b: Modify property from method
test_start "Modify property from method"
defineClass "PropertyModifier" "" \
    "property" "counter"

defineMethod "PropertyModifier" "increment" '
    counter=$((counter + 1))
'

PropertyModifier.new modifier
modifier.counter = "10"
echo "Before increment: $(modifier.counter)" >&2
modifier.increment
echo "After increment: $(modifier.counter)" >&2
if [[ "$(modifier.counter)" == "11" ]]; then
    test_pass "Modify property from method"
else
    test_fail "Modify property from method"
fi