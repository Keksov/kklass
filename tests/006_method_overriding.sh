#!/bin/bash
# 006_method_overriding.sh - Test method overriding

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Setup: Create Animal and Dog classes
defineClass "Animal" "" \
    "property" "species" \
    "method" "speak" 'echo "Some generic sound"'

defineClass "Dog" "Animal" \
    "property" "breed" \
    "method" "speak" 'echo "Woof!"'

Dog.new dog1
dog1.species = "Canine"
dog1.breed = "Golden Retriever"

# Test 6: Method overriding
test_start "Method overriding"
result=$(dog1.speak)
if [[ "$result" == "Woof!" ]]; then
    test_pass "Method overriding"
else
    test_fail "Method overriding (expected: 'Woof!', got: '$result')"
fi