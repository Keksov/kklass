#!/bin/bash
# 035_complex_property_names.sh - Test complex property names

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

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