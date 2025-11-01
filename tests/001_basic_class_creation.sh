#!/bin/bash
# 001_basic_class_creation.sh - Test basic class creation

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Test 1: Basic class creation
test_start "Basic class creation"
defineClass "TestClass" "" \
    "property" "name" \
    "property" "value" \
    "method" "greet" 'echo "Hello, I am $name"' \
    "method" "getValue" 'echo "$value"'

echo 1111
if declare -F | grep -q "1TestClass.new"; then
    test_pass "Basic class creation"
else
    test_fail "Basic class creation"
fi