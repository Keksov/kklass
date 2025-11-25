#!/bin/bash
# PropertyInheritedMethod
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "PropertyInheritedMethod" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 17: Property used in inherited method
kk_test_start "Property used in inherited method"
defineClass "Vehicle" "" \
    "property" "speed" \
    "method" "getSpeed" 'kk.write "Speed: $speed km/h"'

defineClass "Car" "Vehicle" \
    "property" "brand" \
    "method" "info" 'kk.write "Brand: $brand"; $this.getSpeed'

Car.new car1
car1.brand = "Toyota"
car1.speed = "120"
result=$(car1.info)
expected="Brand: ToyotaSpeed: 120 km/h"
if [[ "$result" == "$expected" ]]; then
    kk_test_pass "Property used in inherited method"
else
    kk_test_fail "Property used in inherited method (expected: '$expected', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
