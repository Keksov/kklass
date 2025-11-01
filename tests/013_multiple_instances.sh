#!/bin/bash
# 013_multiple_instances.sh - Test multiple instances of same class

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Test 13: Multiple instances of same class
test_start "Multiple instances of same class"
defineClass "Point" "" \
    "property" "x" \
    "property" "y" \
    "method" "coordinates" 'echo "($x,$y)"'

Point.new point1
Point.new point2
point1.x = "10"
point1.y = "20"
point2.x = "30"
point2.y = "40"

if [[ "$(point1.coordinates)" == "(10,20)" ]] && [[ "$(point2.coordinates)" == "(30,40)" ]]; then
    test_pass "Multiple instances of same class"
else
    test_fail "Multiple instances of same class"
fi