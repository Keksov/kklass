#!/bin/bash
# KKVar
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "KKVar" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

# Tests variable name normalization (uppercase, space to underscore, dot to underscore)


kt_test_section "kk._var() Function Tests"

# Test 1: Basic lowercase to uppercase conversion
kt_test_start "kk._var - lowercase to uppercase"
kk._var "hello"
if [[ "$KK_VAR" == "HELLO" ]]; then
    kt_test_pass "kk._var - lowercase to uppercase"
else
    kt_test_fail "kk._var - lowercase to uppercase (got: $KK_VAR)"
fi

# Test 2: Mixed case to uppercase
kt_test_start "kk._var - mixed case to uppercase"
kk._var "HelloWorld"
if [[ "$KK_VAR" == "HELLOWORLD" ]]; then
    kt_test_pass "kk._var - mixed case to uppercase"
else
    kt_test_fail "kk._var - mixed case to uppercase (got: $KK_VAR)"
fi

# Test 3: Spaces to underscores
kt_test_start "kk._var - spaces to underscores"
kk._var "hello world test"
if [[ "$KK_VAR" == "HELLO_WORLD_TEST" ]]; then
    kt_test_pass "kk._var - spaces to underscores"
else
    kt_test_fail "kk._var - spaces to underscores (got: $KK_VAR)"
fi

# Test 4: Dots to underscores
kt_test_start "kk._var - dots to underscores"
kk._var "my.property.name"
if [[ "$KK_VAR" == "MY_PROPERTY_NAME" ]]; then
    kt_test_pass "kk._var - dots to underscores"
else
    kt_test_fail "kk._var - dots to underscores (got: $KK_VAR)"
fi

# Test 5: Combined spaces and dots
kt_test_start "kk._var - combined spaces and dots"
kk._var "my.property name.value"
if [[ "$KK_VAR" == "MY_PROPERTY_NAME_VALUE" ]]; then
    kt_test_pass "kk._var - combined spaces and dots"
else
    kt_test_fail "kk._var - combined spaces and dots (got: $KK_VAR)"
fi

# Test 6: Already uppercase
kt_test_start "kk._var - already uppercase"
kk._var "HELLO"
if [[ "$KK_VAR" == "HELLO" ]]; then
    kt_test_pass "kk._var - already uppercase"
else
    kt_test_fail "kk._var - already uppercase (got: $KK_VAR)"
fi

# Test 7: Single character
kt_test_start "kk._var - single character"
kk._var "a"
if [[ "$KK_VAR" == "A" ]]; then
    kt_test_pass "kk._var - single character"
else
    kt_test_fail "kk._var - single character (got: $KK_VAR)"
fi

# Test 8: Numbers in variable name
kt_test_start "kk._var - numbers in variable name"
kk._var "var123"
if [[ "$KK_VAR" == "VAR123" ]]; then
    kt_test_pass "kk._var - numbers in variable name"
else
    kt_test_fail "kk._var - numbers in variable name (got: $KK_VAR)"
fi

# Test 9: Underscore preservation
kt_test_start "kk._var - underscore preservation"
kk._var "my_var_name"
if [[ "$KK_VAR" == "MY_VAR_NAME" ]]; then
    kt_test_pass "kk._var - underscore preservation"
else
    kt_test_fail "kk._var - underscore preservation (got: $KK_VAR)"
fi

kt_test_section "kk._var() Edge Cases"

# Test 10: Multiple consecutive spaces
kt_test_start "kk._var - multiple consecutive spaces"
kk._var "hello    world"
if [[ "$KK_VAR" == "HELLO____WORLD" ]]; then
    kt_test_pass "kk._var - multiple consecutive spaces"
else
    kt_test_fail "kk._var - multiple consecutive spaces (got: $KK_VAR)"
fi

# Test 11: Multiple consecutive dots
kt_test_start "kk._var - multiple consecutive dots"
kk._var "hello..world"
if [[ "$KK_VAR" == "HELLO__WORLD" ]]; then
    kt_test_pass "kk._var - multiple consecutive dots"
else
    kt_test_fail "kk._var - multiple consecutive dots (got: $KK_VAR)"
fi

# Test 12: Leading space
kt_test_start "kk._var - leading space"
kk._var " hello"
if [[ "$KK_VAR" == "_HELLO" ]]; then
    kt_test_pass "kk._var - leading space"
else
    kt_test_fail "kk._var - leading space (got: $KK_VAR)"
fi

# Test 13: Trailing space
kt_test_start "kk._var - trailing space"
kk._var "hello "
if [[ "$KK_VAR" == "HELLO_" ]]; then
    kt_test_pass "kk._var - trailing space"
else
    kt_test_fail "kk._var - trailing space (got: $KK_VAR)"
fi

# Test 14: Leading dot
kt_test_start "kk._var - leading dot"
kk._var ".property"
if [[ "$KK_VAR" == "_PROPERTY" ]]; then
    kt_test_pass "kk._var - leading dot"
else
    kt_test_fail "kk._var - leading dot (got: $KK_VAR)"
fi

# Test 15: Trailing dot
kt_test_start "kk._var - trailing dot"
kk._var "property."
if [[ "$KK_VAR" == "PROPERTY_" ]]; then
    kt_test_pass "kk._var - trailing dot"
else
    kt_test_fail "kk._var - trailing dot (got: $KK_VAR)"
fi

# Test 16: Very long variable name
kt_test_start "kk._var - very long variable name"
LONG_VAR=$(printf 'a%.0s' {1..100})
kk._var "$LONG_VAR"
if [[ ${#KK_VAR} == 100 && "$KK_VAR" == "${LONG_VAR^^}" ]]; then
    kt_test_pass "kk._var - very long variable name"
else
    kt_test_fail "kk._var - very long variable name"
fi

# Test 17: Empty string
kt_test_start "kk._var - empty string"
kk._var ""
if [[ "$KK_VAR" == "" ]]; then
    kt_test_pass "kk._var - empty string"
else
    kt_test_fail "kk._var - empty string (got: $KK_VAR)"
fi

# Test 18: CamelCase conversion
kt_test_start "kk._var - camelCase conversion"
kk._var "myPropertyName"
if [[ "$KK_VAR" == "MYPROPERTYNAME" ]]; then
    kt_test_pass "kk._var - camelCase conversion"
else
    kt_test_fail "kk._var - camelCase conversion (got: $KK_VAR)"
fi

# Test 19: Mixed separators
kt_test_start "kk._var - mixed separators"
kk._var "my.property name_value"
if [[ "$KK_VAR" == "MY_PROPERTY_NAME_VALUE" ]]; then
    kt_test_pass "kk._var - mixed separators"
else
    kt_test_fail "kk._var - mixed separators (got: $KK_VAR)"
fi

# Test 20: Special characters with valid ones
kt_test_start "kk._var - special characters handling"
kk._var "hello world"
if [[ "$KK_VAR" == "HELLO_WORLD" ]]; then
    kt_test_pass "kk._var - special characters handling"
else
    kt_test_fail "kk._var - special characters handling (got: $KK_VAR)"
fi


# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
