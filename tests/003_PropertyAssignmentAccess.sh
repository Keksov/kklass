#!/bin/bash
# PropertyAssignmentAccess
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "PropertyAssignmentAccess" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Setup: Create TestClass and instance
defineClass "TestClass" "" \
    "property" "name" \
    "property" "value" \
    "method" "greet" 'echo "Hello, I am $name"' \
    "method" "getValue" 'echo "$value"'

TestClass.new myobj

# Test 3: Property assignment and access
kk_test_start "Property assignment and access"
myobj.name = "TestObject"
myobj.value = "42"

if [[ "$(myobj.name)" == "TestObject" ]] && [[ "$(myobj.value)" == "42" ]]; then
    kk_test_pass "Property assignment and access"
else
    kk_test_fail "Property assignment and access"
fi

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
