#!/bin/bash
# 036_deep_inheritance_chain.sh - Test deep inheritance chain with properties

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Test 36: Deep inheritance chain with properties
test_start "Deep inheritance chain with properties"
defineClass "A" "" \
    "property" "propA" \
    "method" "showA" 'echo "A:$propA"'

defineClass "B" "A" \
    "property" "propB" \
    "method" "showB" 'echo "B:$propB"'

defineClass "C" "B" \
    "property" "propC" \
    "method" "showAll" '$this.showA; $this.showB; echo "C:$propC"'

C.new obj_c
obj_c.propA = "1"
obj_c.propB = "2"
obj_c.propC = "3"
result=$(obj_c.showAll)
expected="A:1B:2C:3"
if [[ "$result" == "$expected" ]]; then
    test_pass "Deep inheritance chain with properties"
else
    test_fail "Deep inheritance chain with properties (expected: '$expected', got: '$result')"
fi