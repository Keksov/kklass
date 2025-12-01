#!/bin/bash
# PropertyInheritedMethod
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "PropertyInheritedMethod" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 17: Property used in inherited method
kt_test_start "Property used in inherited method"
defineClass "Vehicle" "" \
    "property" "speed" \
    "method" "getSpeed" 'kl.write "Speed: $speed km/h"'

defineClass "Car" "Vehicle" \
    "property" "brand" \
    "method" "info" 'kl.write "Brand: $brand"; $this.getSpeed'

Car.new car1
car1.brand = "Toyota"
car1.speed = "120"
result=$(car1.info)
expected="Brand: ToyotaSpeed: 120 km/h"
if [[ "$result" == "$expected" ]]; then
    kt_test_pass "Property used in inherited method"
else
    kt_test_fail "Property used in inherited method (expected: '$expected', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
