#!/bin/bash
# MethodModifyingProperties
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "MethodModifyingProperties" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 22: Method modifying properties
kt_test_start "Method modifying properties"
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
    kt_test_pass "Method modifying properties"
else
    kt_test_fail "Method modifying properties (expected: '$expected', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
