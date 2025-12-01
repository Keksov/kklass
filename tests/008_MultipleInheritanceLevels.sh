#!/bin/bash
# MultipleInheritanceLevels
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "MultipleInheritanceLevels" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 8: Multiple inheritance levels
kt_test_start "Multiple inheritance levels"
defineClass "GrandParent" "" \
    "method" "generation" 'kl.write "GrandParent"'

defineClass "Parent" "GrandParent" \
    "method" "generation" 'kl.write "Parent"; $this.parent generation'

defineClass "Child" "Parent" \
    "method" "generation" 'kl.write "Child"; $this.parent generation'

Child.new child1
result=$(child1.generation)
expected="ChildParentGrandParent"
if [[ "$result" == "$expected" ]]; then
    kt_test_pass "Multiple inheritance levels"
else
    kt_test_fail "Multiple inheritance levels (expected: '$expected', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
