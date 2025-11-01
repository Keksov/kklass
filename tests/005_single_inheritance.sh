#!/bin/bash
# 005_single_inheritance.sh - Test single inheritance

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Test 5: Single inheritance
test_start "Single inheritance"
defineClass "Animal" "" \
    "property" "species" \
    "method" "speak" 'echo "Some generic sound"'

defineClass "Dog" "Animal" \
    "property" "breed" \
    "method" "speak" 'echo "Woof!"'

Dog.new dog1
dog1.species = "Canine"
dog1.breed = "Golden Retriever"

if [[ "$(dog1.species)" == "Canine" ]] && [[ "$(dog1.breed)" == "Golden Retriever" ]]; then
    test_pass "Single inheritance"
else
    test_fail "Single inheritance"
fi