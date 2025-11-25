#!/bin/bash
# MultipleInstances
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "MultipleInstances" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



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

# TODO: Migrate this test completely:
# - Replace test_start() with kk_test_start()
# - Replace test_pass() with kk_test_pass()
# - Replace test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
