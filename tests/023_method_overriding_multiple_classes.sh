#!/bin/bash
# 023_method_overriding_multiple_classes.sh - Test method overriding with multiple derived classes

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

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