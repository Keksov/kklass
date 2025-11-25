#!/bin/bash
# SingleInheritance
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "SingleInheritance" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 5: Single inheritance
kk_test_start "Single inheritance"
defineClass "Animal" "" \
    "property" "species" \
    "method" "speak" 'echo "Some generic sound"'

defineClass "Dog" "Animal" \
    "property" "breed" \
    "method" "speak" 'echo "Woof!"'

Dog.new dog1
dog1.species = "Canine"
dog1.breed = "Golden Retriever"

if [[ "$(dog1.species)" == "Canine" ]] && [[ "$(dog1.breed)" == "Golden Retriever" ]]; then
    kk_test_pass "Single inheritance"
else
    kk_test_fail "Single inheritance"
fi

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
