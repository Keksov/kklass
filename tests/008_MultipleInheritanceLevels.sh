#!/bin/bash
# 008_multiple_inheritance_levels.sh - Test multiple inheritance levels

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Test 8: Multiple inheritance levels
test_start "Multiple inheritance levels"
defineClass "GrandParent" "" \
    "method" "generation" 'kk.write "GrandParent"'

defineClass "Parent" "GrandParent" \
    "method" "generation" 'kk.write "Parent"; $this.parent generation'

defineClass "Child" "Parent" \
    "method" "generation" 'kk.write "Child"; $this.parent generation'

Child.new child1
result=$(child1.generation)
expected="ChildParentGrandParent"
if [[ "$result" == "$expected" ]]; then
    test_pass "Multiple inheritance levels"
else
    test_fail "Multiple inheritance levels (expected: '$expected', got: '$result')"
fi