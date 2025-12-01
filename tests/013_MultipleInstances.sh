#!/bin/bash
# MultipleInstances
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "MultipleInstances" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 13: Multiple instances of same class
kt_test_start "Multiple instances of same class"
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
    kt_test_pass "Multiple instances of same class"
else
    kt_test_fail "Multiple instances of same class"
fi

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
