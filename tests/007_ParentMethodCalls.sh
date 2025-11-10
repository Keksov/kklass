#!/bin/bash
# 007_parent_method_calls.sh - Test parent method calls

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Setup: Create Animal base class first
defineClass "Animal" "" \
    "property" "species" \
    "method" "speak" 'echo "Some generic sound"'

# Test 7: Parent method calls
test_start "Parent method calls"
defineClass "Cat" "Animal" \
    "method" "speak" 'echo "Meow!"' \
    "method" "speakAsAnimal" 'echo -n "Cat sound: "; $this.speak; echo -n "Animal sound: "; $this.parent speak'

Cat.new cat1
result=$(cat1.speakAsAnimal)
expected="Cat sound: Meow!Animal sound: Some generic sound"
if [[ "$result" == "$expected" ]]; then
    test_pass "Parent method calls"
else
    test_fail "Parent method calls (expected: '$expected', got: '$result')"
fi