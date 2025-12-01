#!/bin/bash
# MethodOverridingMultipleClasses
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "MethodOverridingMultipleClasses" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 23: Method overriding with multiple derived classes
kt_test_start "Method overriding with multiple derived classes"
defineClass "AnimalBase" "" \
    "property" "name" \
    "method" "speak" 'echo "Some generic animal sound"'

defineClass "DogClass" "AnimalBase" \
    "property" "breed" \
    "method" "speak" 'echo "Woof! Woof!"'

defineClass "CatClass" "AnimalBase" \
    "property" "color" \
    "method" "speak" 'echo "Meow!"'

DogClass.new dogtest
CatClass.new cattest

dogtest.name = "Buddy"
dogtest.breed = "Golden Retriever"
cattest.name = "Whiskers"
cattest.color = "Gray"

dog_sound=$(dogtest.speak)
cat_sound=$(cattest.speak)

if [[ "$dog_sound" == "Woof! Woof!" ]] && [[ "$cat_sound" == "Meow!" ]]; then
    kt_test_pass "Method overriding with multiple derived classes"
else
    kt_test_fail "Method overriding with multiple derived classes (expected: 'Woof! Woof!' and 'Meow!', got: '$dog_sound' and '$cat_sound')"
fi

dogtest.delete
cattest.delete

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
