#!/bin/bash
# DeepInheritanceChain
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "DeepInheritanceChain" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 36: Deep inheritance chain with properties
kk_test_start "Deep inheritance chain with properties"
defineClass "A" "" \
    "property" "propA" \
    "method" "showA" 'kk.write "A:$propA"'

defineClass "B" "A" \
    "property" "propB" \
    "method" "showB" 'kk.write "B:$propB"'

defineClass "C" "B" \
    "property" "propC" \
    "method" "showAll" '$this.showA; $this.showB; kk.write "C:$propC"'

C.new obj_c
obj_c.propA = "1"
obj_c.propB = "2"
obj_c.propC = "3"
result=$(obj_c.showAll)
expected="A:1B:2C:3"
if [[ "$result" == "$expected" ]]; then
    kk_test_pass "Deep inheritance chain with properties"
else
    kk_test_fail "Deep inheritance chain with properties (expected: '$expected', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
