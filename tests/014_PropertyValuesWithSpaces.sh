#!/bin/bash
# PropertyValuesWithSpaces
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "PropertyValuesWithSpaces" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 14: Property values with spaces
test_start "Property values with spaces"
defineClass "Person" "" \
    "property" "fullName" \
    "method" "introduce" 'echo "My name is $fullName"'

Person.new person1
person1.fullName = "John Doe Smith"
result=$(person1.introduce)
expected="My name is John Doe Smith"
if [[ "$result" == "$expected" ]]; then
    test_pass "Property values with spaces"
else
    test_fail "Property values with spaces (expected: '$expected', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace test_start() with kk_test_start()
# - Replace test_pass() with kk_test_pass()
# - Replace test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
