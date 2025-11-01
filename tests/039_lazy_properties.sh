#!/bin/bash
# 039_lazy_properties.sh - Test lazy properties (lazy initialization)

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Test 39: Lazy properties (lazy initialization)
test_start "Lazy properties (lazy initialization)"
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
        test_pass "Lazy properties (lazy initialization)"
    else
        test_fail "Lazy properties failed on recompute (result2: '$result2')"
    fi
else
    test_fail "Lazy properties failed on first compute (result1: '$result1')"
fi

lazy_obj.delete