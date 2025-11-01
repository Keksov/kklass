#!/bin/bash
# 018_parent_method_with_properties.sh - Test method calling parent and using properties

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Test 18: Method calling parent and using properties
test_start "Method calling parent and using properties"
defineClass "Shape" "" \
    "property" "name" \
    "method" "describe" 'echo "Shape: $name"'

defineClass "Rectangle" "Shape" \
    "property" "width" \
    "property" "height" \
    "method" "describe" 'echo -n "Rectangle "; $this.parent describe; echo -n " ($width x $height)"'

Rectangle.new rect1
rect1.name = "MyRect"
rect1.width = "10"
rect1.height = "5"
result=$(rect1.describe)
expected="Rectangle Shape: MyRect (10 x 5)"
if [[ "$result" == "$expected" ]]; then
    test_pass "Method calling parent and using properties"
else
    test_fail "Method calling parent and using properties (expected: '$expected', got: '$result')"
fi