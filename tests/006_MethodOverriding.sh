#!/bin/bash
# MethodOverriding
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "MethodOverriding" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Setup: Create Animal and Dog classes
defineClass "Animal" "" \
    "property" "species" \
    "method" "speak" 'echo "Some generic sound"'

defineClass "Dog" "Animal" \
    "property" "breed" \
    "method" "speak" 'echo "Woof!"'

Dog.new dog1
dog1.species = "Canine"
dog1.breed = "Golden Retriever"

# Test 6: Method overriding
test_start "Method overriding"
result=$(dog1.speak)
if [[ "$result" == "Woof!" ]]; then
    test_pass "Method overriding"
else
    test_fail "Method overriding (expected: 'Woof!', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace test_start() with kk_test_start()
# - Replace test_pass() with kk_test_pass()
# - Replace test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
