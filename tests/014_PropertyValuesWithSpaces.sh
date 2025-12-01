#!/bin/bash
# PropertyValuesWithSpaces
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "PropertyValuesWithSpaces" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 14: Property values with spaces
kt_test_start "Property values with spaces"
defineClass "Person" "" \
    "property" "fullName" \
    "method" "introduce" 'echo "My name is $fullName"'

Person.new person1
person1.fullName = "John Doe Smith"
result=$(person1.introduce)
expected="My name is John Doe Smith"
if [[ "$result" == "$expected" ]]; then
    kt_test_pass "Property values with spaces"
else
    kt_test_fail "Property values with spaces (expected: '$expected', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
