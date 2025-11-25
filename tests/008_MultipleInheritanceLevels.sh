#!/bin/bash
# MultipleInheritanceLevels
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "MultipleInheritanceLevels" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 8: Multiple inheritance levels
kk_test_start "Multiple inheritance levels"
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
    kk_test_pass "Multiple inheritance levels"
else
    kk_test_fail "Multiple inheritance levels (expected: '$expected', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
