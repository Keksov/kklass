#!/bin/bash
# MethodModifyingProperties
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "MethodModifyingProperties" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 22: Method modifying properties
kk_test_start "Method modifying properties"
defineClass "ModifyTest" "" \
    "property" "name" \
    "property" "value" \
    "method" "greet" 'echo "Hello, I am $name"' \
    "method" "getValue" 'echo "$value"' \
    "method" "setName" 'name="$1"'

ModifyTest.new modtest
modtest.name = "InitialName"

# Call setName to modify property
modtest.setName "UpdatedName"

# Verify property was updated
result=$(modtest.greet)
expected="Hello, I am UpdatedName"
if [[ "$result" == "$expected" ]]; then
    kk_test_pass "Method modifying properties"
else
    kk_test_fail "Method modifying properties (expected: '$expected', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
