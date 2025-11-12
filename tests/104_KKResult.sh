#!/bin/bash
# 104_kklib_kk_result.sh - Unit tests for kk.result() function
# Tests variable assignment via kk.result (uses kk.var internally)

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

test_section "kk.result() Function Tests"

# Test 1: Basic result assignment
test_start "kk.result - basic assignment"
kk.result "myVar" "value123"
if [[ "${MYVAR}" == "value123" ]]; then
    test_pass "kk.result - basic assignment"
else
    test_fail "kk.result - basic assignment (got: ${MYVAR})"
fi

# Test 2: Result with spaces in variable name
test_start "kk.result - variable name with spaces"
kk.result "my var" "testvalue"
if [[ "${MY_VAR}" == "testvalue" ]]; then
    test_pass "kk.result - variable name with spaces"
else
    test_fail "kk.result - variable name with spaces (got: ${MY_VAR})"
fi

# Test 3: Result with dots in variable name
test_start "kk.result - variable name with dots"
kk.result "my.property.name" "dotvalue"
if [[ "${MY_PROPERTY_NAME}" == "dotvalue" ]]; then
    test_pass "kk.result - variable name with dots"
else
    test_fail "kk.result - variable name with dots (got: ${MY_PROPERTY_NAME})"
fi

# Test 4: Result with empty value
test_start "kk.result - empty value assignment"
kk.result "emptyVar" ""
if [[ "${EMPTYVAR}" == "" ]]; then
    test_pass "kk.result - empty value assignment"
else
    test_fail "kk.result - empty value assignment (got: ${EMPTYVAR})"
fi

# Test 5: Result with numeric value
test_start "kk.result - numeric value"
kk.result "numVar" "42"
if [[ "${NUMVAR}" == "42" ]]; then
    test_pass "kk.result - numeric value"
else
    test_fail "kk.result - numeric value (got: ${NUMVAR})"
fi

# Test 6: Result with special characters
test_start "kk.result - special characters in value"
kk.result "specialVar" "!@#$%^&*()"
if [[ "${SPECIALVAR}" == "!@#\$%^&*()" ]]; then
    test_pass "kk.result - special characters in value"
else
    test_fail "kk.result - special characters in value"
fi

# Test 7: Result with spaces in value
test_start "kk.result - spaces in value"
kk.result "spacedVar" "hello world test"
if [[ "${SPACEDVAR}" == "hello world test" ]]; then
    test_pass "kk.result - spaces in value"
else
    test_fail "kk.result - spaces in value (got: ${SPACEDVAR})"
fi

# Test 8: Result overwrites previous value
test_start "kk.result - overwrites previous value"
kk.result "overwriteTest" "first"
kk.result "overwriteTest" "second"
if [[ "${OVERWRITETEST}" == "second" ]]; then
    test_pass "kk.result - overwrites previous value"
else
    test_fail "kk.result - overwrites previous value (got: ${OVERWRITETEST})"
fi

# Test 9: Result with newlines
test_start "kk.result - value with newlines"
kk.result "multilineVar" "line1\nline2\nline3"
if [[ "${MULTILINEVAR}" == *$'line1'* ]]; then
    test_pass "kk.result - value with newlines"
else
    test_fail "kk.result - value with newlines"
fi

# Test 10: Result with tabs
test_start "kk.result - value with tabs"
kk.result "tabbedVar" "col1	col2	col3"
if [[ "${TABBEDVAR}" == *"col1"* && "${TABBEDVAR}" == *"col2"* ]]; then
    test_pass "kk.result - value with tabs"
else
    test_fail "kk.result - value with tabs"
fi

test_section "kk.result() Edge Cases"

# Test 11: Variable name conversion verification
test_start "kk.result - variable name conversion"
kk.result "CamelCaseVar" "value"
if [[ "${CAMELCASEVAR}" == "value" ]]; then
    test_pass "kk.result - variable name conversion"
else
    test_fail "kk.result - variable name conversion"
fi

# Test 12: Result with very long value
test_start "kk.result - very long value"
LONG_VAL=$(printf 'a%.0s' {1..5000})
kk.result "longVar" "$LONG_VAL"
if [[ "${#LONGVAR}" == 5000 ]]; then
    test_pass "kk.result - very long value"
else
    test_fail "kk.result - very long value (got length: ${#LONGVAR})"
fi

# Test 13: Multiple result assignments
test_start "kk.result - multiple assignments"
kk.result "var1" "value1"
kk.result "var2" "value2"
kk.result "var3" "value3"
if [[ "${VAR1}" == "value1" && "${VAR2}" == "value2" && "${VAR3}" == "value3" ]]; then
    test_pass "kk.result - multiple assignments"
else
    test_fail "kk.result - multiple assignments"
fi

# Test 14: Result with single character value
test_start "kk.result - single character value"
kk.result "singleChar" "X"
if [[ "${SINGLECHAR}" == "X" ]]; then
    test_pass "kk.result - single character value"
else
    test_fail "kk.result - single character value"
fi

# Test 15: Result with unicode value
test_start "kk.result - unicode value"
kk.result "unicodeVar" "Привет мир"
if [[ "${UNICODEVAR}" == "Привет мир" ]]; then
    test_pass "kk.result - unicode value"
else
    test_fail "kk.result - unicode value"
fi

# Test 16: Variable name with mixed case and separators
test_start "kk.result - complex variable name"
kk.result "My.Complex Property.Name" "complexValue"
if [[ "${MY_COMPLEX_PROPERTY_NAME}" == "complexValue" ]]; then
    test_pass "kk.result - complex variable name"
else
    test_fail "kk.result - complex variable name"
fi

# Test 17: Result sets global variable
test_start "kk.result - sets global variable"
{
    kk.result "globalVar" "global_value"
}
if [[ "${GLOBALVAR}" == "global_value" ]]; then
    test_pass "kk.result - sets global variable"
else
    test_fail "kk.result - sets global variable"
fi

# Test 18: KK_VAR is set by kk.result
test_start "kk.result - KK_VAR is set"
kk.result "testVar" "testValue"
if [[ "$KK_VAR" == "TESTVAR" ]]; then
    test_pass "kk.result - KK_VAR is set"
else
    test_fail "kk.result - KK_VAR is set (got: $KK_VAR)"
fi

# Test 19: Result with path-like value
test_start "kk.result - path-like value"
kk.result "pathVar" "/usr/local/bin/program"
if [[ "${PATHVAR}" == "/usr/local/bin/program" ]]; then
    test_pass "kk.result - path-like value"
else
    test_fail "kk.result - path-like value"
fi

# Test 20: Result preserves value whitespace
test_start "kk.result - preserves value whitespace"
kk.result "wsVar" "  leading  internal  trailing  "
if [[ "${WSVAR}" == "  leading  internal  trailing  " ]]; then
    test_pass "kk.result - preserves value whitespace"
else
    test_fail "kk.result - preserves value whitespace"
fi

cleanup
