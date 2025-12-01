#!/bin/bash
# ComplexPropertyNames
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "ComplexPropertyNames" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 35: Complex property names
kt_test_start "Complex property names"
defineClass "ComplexTest" "" \
    "property" "file_name" \
    "property" "file_size"

ComplexTest.new complextest
complextest.file_name = "test.txt"
complextest.file_size = "1024"

if [[ "$(complextest.file_name)" == "test.txt" ]] && [[ "$(complextest.file_size)" == "1024" ]]; then
    kt_test_pass "Complex property names"
else
    kt_test_fail "Complex property names"
fi

# Test 35b: Modify property from method
kt_test_start "Modify property from method"
defineClass "PropertyModifier" "" \
    "property" "counter"

defineMethod "PropertyModifier" "increment" '
    counter=$((counter + 1))
'

PropertyModifier.new modifier
modifier.counter = "10"
#echo "Before increment: $(modifier.counter)" >&2
modifier.increment
#echo "After increment: $(modifier.counter)" >&2
if [[ "$(modifier.counter)" == "11" ]]; then
    kt_test_pass "Modify property from method"
else
    kt_test_fail "Modify property from method"
fi

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
