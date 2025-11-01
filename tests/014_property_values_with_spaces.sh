#!/bin/bash
# 014_property_values_with_spaces.sh - Test property values with spaces

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Test 14: Property values with spaces
test_start "Property values with spaces"
defineClass "Person" "" \
    "property" "fullName" \
    "method" "introduce" 'echo "My name is $fullName"'

Person.new person1
person1.fullName = "John Doe Smith"
result=$(person1.introduce)
expected="My name is John Doe Smith"
if [[ "$result" == "$expected" ]]; then
    test_pass "Property values with spaces"
else
    test_fail "Property values with spaces (expected: '$expected', got: '$result')"
fi