#!/bin/bash
# 022_method_modifying_properties.sh - Test method modifying properties

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Test 22: Method modifying properties
test_start "Method modifying properties"
defineClass "ModifyTest" "" \
    "property" "name" \
    "property" "value" \
    "method" "greet" 'echo "Hello, I am $name"' \
    "method" "getValue" 'echo "$value"' \
    "method" "setName" 'name="$1"'

ModifyTest.new modtest
modtest.name = "InitialName"

# Call setName to modify property
modtest.setName "UpdatedName"

# Verify property was updated
result=$(modtest.greet)
expected="Hello, I am UpdatedName"
if [[ "$result" == "$expected" ]]; then
    test_pass "Method modifying properties"
else
    test_fail "Method modifying properties (expected: '$expected', got: '$result')"
fi