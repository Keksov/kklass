#!/bin/bash
# 003_property_assignment_access.sh - Test property assignment and access

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Setup: Create TestClass and instance
defineClass "TestClass" "" \
    "property" "name" \
    "property" "value" \
    "method" "greet" 'echo "Hello, I am $name"' \
    "method" "getValue" 'echo "$value"'

TestClass.new myobj

# Test 3: Property assignment and access
test_start "Property assignment and access"
myobj.name = "TestObject"
myobj.value = "42"

if [[ "$(myobj.name)" == "TestObject" ]] && [[ "$(myobj.value)" == "42" ]]; then
    test_pass "Property assignment and access"
else
    test_fail "Property assignment and access"
fi