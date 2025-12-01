#!/bin/bash
# MethodOverriding
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "MethodOverriding" "$(dirname "$0")" "$@"

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
kt_test_start "Method overriding"
result=$(dog1.speak)
if [[ "$result" == "Woof!" ]]; then
    kt_test_pass "Method overriding"
else
    kt_test_fail "Method overriding (expected: 'Woof!', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
