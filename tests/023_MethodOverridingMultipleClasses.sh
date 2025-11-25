#!/bin/bash
# MethodOverridingMultipleClasses
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "MethodOverridingMultipleClasses" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 23: Method overriding with multiple derived classes
test_start "Method overriding with multiple derived classes"
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
    test_pass "Method overriding with multiple derived classes"
else
    test_fail "Method overriding with multiple derived classes (expected: 'Woof! Woof!' and 'Meow!', got: '$dog_sound' and '$cat_sound')"
fi

dogtest.delete
cattest.delete

# TODO: Migrate this test completely:
# - Replace test_start() with kk_test_start()
# - Replace test_pass() with kk_test_pass()
# - Replace test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
