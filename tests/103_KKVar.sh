#!/bin/bash
# 103_kklib_kk_var.sh - Unit tests for kk.var() function
# Tests variable name normalization (uppercase, space to underscore, dot to underscore)

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

test_section "kk.var() Function Tests"

# Test 1: Basic lowercase to uppercase conversion
test_start "kk.var - lowercase to uppercase"
kk.var "hello"
if [[ "$KK_VAR" == "HELLO" ]]; then
    test_pass "kk.var - lowercase to uppercase"
else
    test_fail "kk.var - lowercase to uppercase (got: $KK_VAR)"
fi

# Test 2: Mixed case to uppercase
test_start "kk.var - mixed case to uppercase"
kk.var "HelloWorld"
if [[ "$KK_VAR" == "HELLOWORLD" ]]; then
    test_pass "kk.var - mixed case to uppercase"
else
    test_fail "kk.var - mixed case to uppercase (got: $KK_VAR)"
fi

# Test 3: Spaces to underscores
test_start "kk.var - spaces to underscores"
kk.var "hello world test"
if [[ "$KK_VAR" == "HELLO_WORLD_TEST" ]]; then
    test_pass "kk.var - spaces to underscores"
else
    test_fail "kk.var - spaces to underscores (got: $KK_VAR)"
fi

# Test 4: Dots to underscores
test_start "kk.var - dots to underscores"
kk.var "my.property.name"
if [[ "$KK_VAR" == "MY_PROPERTY_NAME" ]]; then
    test_pass "kk.var - dots to underscores"
else
    test_fail "kk.var - dots to underscores (got: $KK_VAR)"
fi

# Test 5: Combined spaces and dots
test_start "kk.var - combined spaces and dots"
kk.var "my.property name.value"
if [[ "$KK_VAR" == "MY_PROPERTY_NAME_VALUE" ]]; then
    test_pass "kk.var - combined spaces and dots"
else
    test_fail "kk.var - combined spaces and dots (got: $KK_VAR)"
fi

# Test 6: Already uppercase
test_start "kk.var - already uppercase"
kk.var "HELLO"
if [[ "$KK_VAR" == "HELLO" ]]; then
    test_pass "kk.var - already uppercase"
else
    test_fail "kk.var - already uppercase (got: $KK_VAR)"
fi

# Test 7: Single character
test_start "kk.var - single character"
kk.var "a"
if [[ "$KK_VAR" == "A" ]]; then
    test_pass "kk.var - single character"
else
    test_fail "kk.var - single character (got: $KK_VAR)"
fi

# Test 8: Numbers in variable name
test_start "kk.var - numbers in variable name"
kk.var "var123"
if [[ "$KK_VAR" == "VAR123" ]]; then
    test_pass "kk.var - numbers in variable name"
else
    test_fail "kk.var - numbers in variable name (got: $KK_VAR)"
fi

# Test 9: Underscore preservation
test_start "kk.var - underscore preservation"
kk.var "my_var_name"
if [[ "$KK_VAR" == "MY_VAR_NAME" ]]; then
    test_pass "kk.var - underscore preservation"
else
    test_fail "kk.var - underscore preservation (got: $KK_VAR)"
fi

test_section "kk.var() Edge Cases"

# Test 10: Multiple consecutive spaces
test_start "kk.var - multiple consecutive spaces"
kk.var "hello    world"
if [[ "$KK_VAR" == "HELLO____WORLD" ]]; then
    test_pass "kk.var - multiple consecutive spaces"
else
    test_fail "kk.var - multiple consecutive spaces (got: $KK_VAR)"
fi

# Test 11: Multiple consecutive dots
test_start "kk.var - multiple consecutive dots"
kk.var "hello..world"
if [[ "$KK_VAR" == "HELLO__WORLD" ]]; then
    test_pass "kk.var - multiple consecutive dots"
else
    test_fail "kk.var - multiple consecutive dots (got: $KK_VAR)"
fi

# Test 12: Leading space
test_start "kk.var - leading space"
kk.var " hello"
if [[ "$KK_VAR" == "_HELLO" ]]; then
    test_pass "kk.var - leading space"
else
    test_fail "kk.var - leading space (got: $KK_VAR)"
fi

# Test 13: Trailing space
test_start "kk.var - trailing space"
kk.var "hello "
if [[ "$KK_VAR" == "HELLO_" ]]; then
    test_pass "kk.var - trailing space"
else
    test_fail "kk.var - trailing space (got: $KK_VAR)"
fi

# Test 14: Leading dot
test_start "kk.var - leading dot"
kk.var ".property"
if [[ "$KK_VAR" == "_PROPERTY" ]]; then
    test_pass "kk.var - leading dot"
else
    test_fail "kk.var - leading dot (got: $KK_VAR)"
fi

# Test 15: Trailing dot
test_start "kk.var - trailing dot"
kk.var "property."
if [[ "$KK_VAR" == "PROPERTY_" ]]; then
    test_pass "kk.var - trailing dot"
else
    test_fail "kk.var - trailing dot (got: $KK_VAR)"
fi

# Test 16: Very long variable name
test_start "kk.var - very long variable name"
LONG_VAR=$(printf 'a%.0s' {1..100})
kk.var "$LONG_VAR"
if [[ ${#KK_VAR} == 100 && "$KK_VAR" == "${LONG_VAR^^}" ]]; then
    test_pass "kk.var - very long variable name"
else
    test_fail "kk.var - very long variable name"
fi

# Test 17: Empty string
test_start "kk.var - empty string"
kk.var ""
if [[ "$KK_VAR" == "" ]]; then
    test_pass "kk.var - empty string"
else
    test_fail "kk.var - empty string (got: $KK_VAR)"
fi

# Test 18: CamelCase conversion
test_start "kk.var - camelCase conversion"
kk.var "myPropertyName"
if [[ "$KK_VAR" == "MYPROPERTYNAME" ]]; then
    test_pass "kk.var - camelCase conversion"
else
    test_fail "kk.var - camelCase conversion (got: $KK_VAR)"
fi

# Test 19: Mixed separators
test_start "kk.var - mixed separators"
kk.var "my.property name_value"
if [[ "$KK_VAR" == "MY_PROPERTY_NAME_VALUE" ]]; then
    test_pass "kk.var - mixed separators"
else
    test_fail "kk.var - mixed separators (got: $KK_VAR)"
fi

# Test 20: Special characters with valid ones
test_start "kk.var - special characters handling"
kk.var "hello world"
if [[ "$KK_VAR" == "HELLO_WORLD" ]]; then
    test_pass "kk.var - special characters handling"
else
    test_fail "kk.var - special characters handling (got: $KK_VAR)"
fi

cleanup
