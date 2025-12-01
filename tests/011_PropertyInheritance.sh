#!/bin/bash
# PropertyInheritance
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "PropertyInheritance" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 11: Property inheritance
kt_test_start "Property inheritance"
defineClass "BaseWithProps" "" \
    "property" "baseProp"

defineClass "DerivedWithProps" "BaseWithProps" \
    "property" "derivedProp"

DerivedWithProps.new derived
derived.baseProp = "inherited"
derived.derivedProp = "own"

if [[ "$(derived.baseProp)" == "inherited" ]] && [[ "$(derived.derivedProp)" == "own" ]]; then
    kt_test_pass "Property inheritance"
else
    kt_test_fail "Property inheritance"
fi

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
