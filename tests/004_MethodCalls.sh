#!/bin/bash
# 004_method_calls.sh - Test method calls

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Setup: Create TestClass and instance with properties
defineClass "TestClass" "" \
    "property" "name" \
    "property" "value" \
    "method" "greet" 'echo "Hello, I am $name"' \
    "method" "getValue" 'echo "$value"'

TestClass.new myobj
myobj.name = "TestObject"
myobj.value = "42"

# Test 4: Method calls
test_start "Method calls"
result=$(myobj.greet)
expected="Hello, I am TestObject"
if [[ "$result" == "$expected" ]]; then
    test_pass "Method calls"
else
    test_fail "Method calls (expected: '$expected', got: '$result')"
fi