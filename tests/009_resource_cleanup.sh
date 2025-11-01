#!/bin/bash
# 009_resource_cleanup.sh - Test resource cleanup

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Setup: Create TestClass and instance
defineClass "TestClass" "" \
    "property" "name" \
    "property" "value" \
    "method" "greet" 'echo "Hello, I am $name"' \
    "method" "getValue" 'echo "$value"'

TestClass.new myobj

# Test 9: Resource cleanup
test_start "Resource cleanup"
myobj.delete
if ! declare -F | grep -q "myobj\."; then
    test_pass "Resource cleanup"
else
    test_fail "Resource cleanup"
fi