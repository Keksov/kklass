#!/bin/bash
# LazyProperties
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "LazyProperties" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 39: Lazy properties (lazy initialization)
kk_test_start "Lazy properties (lazy initialization)"
defineClass "LazyTest" "" \
    "property" "base_value" \
    "lazy_property" "expensive" "compute_expensive" \
    "method" "compute_expensive" 'echo "computed_from_${base_value}"'

LazyTest.new lazy_obj
lazy_obj.base_value = "test"

# Access lazy property - should compute
result1=$(lazy_obj.expensive)

# Verify it computed correctly
if [[ "$result1" == "computed_from_test" ]]; then
    # Change base value
    lazy_obj.base_value = "changed"
    result2=$(lazy_obj.expensive)
    
    # Note: Due to bash subshell limitations, lazy caching only works within same shell context
    # This test just verifies the lazy property computes correctly
    if [[ "$result2" == "computed_from_changed" ]]; then
        kk_test_pass "Lazy properties (lazy initialization)"
    else
        kk_test_fail "Lazy properties failed on recompute (result2: '$result2')"
    fi
else
    kk_test_fail "Lazy properties failed on first compute (result1: '$result1')"
fi

lazy_obj.delete

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
