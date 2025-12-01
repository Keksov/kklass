#!/bin/bash
# ParentMethodCalls
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "ParentMethodCalls" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Setup: Create Animal base class first
defineClass "Animal" "" \
    "property" "species" \
    "method" "speak" 'kl.write "Some generic sound"'

# Test 7: Parent method calls
kt_test_start "Parent method calls"
defineClass "Cat" "Animal" \
    "method" "speak" 'kl.write "Meow!"' \
    "method" "speakAsAnimal" 'kl.write "Cat sound: "; $this.speak; kl.write "Animal sound: "; $this.parent speak'

Cat.new cat1
result=$(cat1.speakAsAnimal)
expected="Cat sound: Meow!Animal sound: Some generic sound"
if [[ "$result" == "$expected" ]]; then
    kt_test_pass "Parent method calls"
else
    kt_test_fail "Parent method calls (expected: '$expected', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
