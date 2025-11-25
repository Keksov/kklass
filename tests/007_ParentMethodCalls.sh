#!/bin/bash
# ParentMethodCalls
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "ParentMethodCalls" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Setup: Create Animal base class first
defineClass "Animal" "" \
    "property" "species" \
    "method" "speak" 'kk.write "Some generic sound"'

# Test 7: Parent method calls
test_start "Parent method calls"
defineClass "Cat" "Animal" \
    "method" "speak" 'kk.write "Meow!"' \
    "method" "speakAsAnimal" 'kk.write "Cat sound: "; $this.speak; kk.write "Animal sound: "; $this.parent speak'

Cat.new cat1
result=$(cat1.speakAsAnimal)
expected="Cat sound: Meow!Animal sound: Some generic sound"
if [[ "$result" == "$expected" ]]; then
    test_pass "Parent method calls"
else
    test_fail "Parent method calls (expected: '$expected', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace test_start() with kk_test_start()
# - Replace test_pass() with kk_test_pass()
# - Replace test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
