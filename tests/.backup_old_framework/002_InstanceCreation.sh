#!/bin/bash
# 002_instance_creation.sh - Test instance creation

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Setup: Create TestClass first
defineClass "TestClass" "" \
    "property" "name" \
    "property" "value" \
    "method" "greet" 'echo "Hello, I am $name"' \
    "method" "getValue" 'echo "$value"'

# Test 2: Instance creation
test_start "Instance creation"
TestClass.new myobj
if declare -F | grep -q "myobj\."; then
    test_pass "Instance creation"
else
    test_fail "Instance creation"
fi