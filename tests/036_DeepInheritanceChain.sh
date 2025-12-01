#!/bin/bash
# DeepInheritanceChain
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "DeepInheritanceChain" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 36: Deep inheritance chain with properties
kt_test_start "Deep inheritance chain with properties"
defineClass "A" "" \
    "property" "propA" \
    "method" "showA" 'kl.write "A:$propA"'

defineClass "B" "A" \
    "property" "propB" \
    "method" "showB" 'kl.write "B:$propB"'

defineClass "C" "B" \
    "property" "propC" \
    "method" "showAll" '$this.showA; $this.showB; kl.write "C:$propC"'

C.new obj_c
obj_c.propA = "1"
obj_c.propB = "2"
obj_c.propC = "3"
result=$(obj_c.showAll)
expected="A:1B:2C:3"
if [[ "$result" == "$expected" ]]; then
    kt_test_pass "Deep inheritance chain with properties"
else
    kt_test_fail "Deep inheritance chain with properties (expected: '$expected', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
