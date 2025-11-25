#!/bin/bash
# PropertyInheritance
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "PropertyInheritance" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 11: Property inheritance
test_start "Property inheritance"
defineClass "BaseWithProps" "" \
    "property" "baseProp"

defineClass "DerivedWithProps" "BaseWithProps" \
    "property" "derivedProp"

DerivedWithProps.new derived
derived.baseProp = "inherited"
derived.derivedProp = "own"

if [[ "$(derived.baseProp)" == "inherited" ]] && [[ "$(derived.derivedProp)" == "own" ]]; then
    test_pass "Property inheritance"
else
    test_fail "Property inheritance"
fi

# TODO: Migrate this test completely:
# - Replace test_start() with kk_test_start()
# - Replace test_pass() with kk_test_pass()
# - Replace test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
