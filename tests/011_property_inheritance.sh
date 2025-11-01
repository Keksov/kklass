#!/bin/bash
# 011_property_inheritance.sh - Test property inheritance

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

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