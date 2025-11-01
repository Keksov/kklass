#!/bin/bash
# 017_property_inherited_method.sh - Test property used in inherited method

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Test 17: Property used in inherited method
test_start "Property used in inherited method"
defineClass "Vehicle" "" \
    "property" "speed" \
    "method" "getSpeed" 'echo "Speed: $speed km/h"'

defineClass "Car" "Vehicle" \
    "property" "brand" \
    "method" "info" 'echo "Brand: $brand"; $this.getSpeed'

Car.new car1
car1.brand = "Toyota"
car1.speed = "120"
result=$(car1.info)
expected="Brand: ToyotaSpeed: 120 km/h"
if [[ "$result" == "$expected" ]]; then
    test_pass "Property used in inherited method"
else
    test_fail "Property used in inherited method (expected: '$expected', got: '$result')"
fi