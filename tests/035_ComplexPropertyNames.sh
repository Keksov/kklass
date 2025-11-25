#!/bin/bash
# ComplexPropertyNames
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "ComplexPropertyNames" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 35: Complex property names
kk_test_start "Complex property names"
defineClass "ComplexTest" "" \
    "property" "file_name" \
    "property" "file_size"

ComplexTest.new complextest
complextest.file_name = "test.txt"
complextest.file_size = "1024"

if [[ "$(complextest.file_name)" == "test.txt" ]] && [[ "$(complextest.file_size)" == "1024" ]]; then
    kk_test_pass "Complex property names"
else
    kk_test_fail "Complex property names"
fi

# Test 35b: Modify property from method
kk_test_start "Modify property from method"
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
    kk_test_pass "Modify property from method"
else
    kk_test_fail "Modify property from method"
fi

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
