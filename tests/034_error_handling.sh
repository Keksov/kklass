#!/bin/bash
# 034_error_handling.sh - Test error handling - non-existent method

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Test 34: Error handling - non-existent method
test_start "Error handling - non-existent method"
defineClass "ErrorTest" "" \
    "method" "existingMethod" 'echo "exists"'

ErrorTest.new errortest
if ! errortest.nonExistentMethod 2>/dev/null; then
    test_pass "Error handling - non-existent method"
else
    test_fail "Error handling - non-existent method"
fi