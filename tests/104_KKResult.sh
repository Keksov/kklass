#!/bin/bash
# 104_kklib_kk_result.sh - Unit tests for kk._result() function
# Tests variable assignment via kk._result (uses kk._var internally)

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

test_section "kk._result() Function Tests"

# Test 1: Basic result assignment
test_start "kk._result - basic assignment"
kk._result "myVar" "value123"
if [[ "${MYVAR}" == "value123" ]]; then
    test_pass "kk._result - basic assignment"
else
    test_fail "kk._result - basic assignment (got: ${MYVAR})"
fi

# Test 2: Result with spaces in variable name
test_start "kk._result - variable name with spaces"
kk._result "my var" "testvalue"
if [[ "${MY_VAR}" == "testvalue" ]]; then
    test_pass "kk._result - variable name with spaces"
else
    test_fail "kk._result - variable name with spaces (got: ${MY_VAR})"
fi

# Test 3: Result with dots in variable name
test_start "kk._result - variable name with dots"
kk._result "my.property.name" "dotvalue"
if [[ "${MY_PROPERTY_NAME}" == "dotvalue" ]]; then
    test_pass "kk._result - variable name with dots"
else
    test_fail "kk._result - variable name with dots (got: ${MY_PROPERTY_NAME})"
fi

# Test 4: Result with empty value
test_start "kk._result - empty value assignment"
kk._result "emptyVar" ""
if [[ "${EMPTYVAR}" == "" ]]; then
    test_pass "kk._result - empty value assignment"
else
    test_fail "kk._result - empty value assignment (got: ${EMPTYVAR})"
fi

# Test 5: Result with numeric value
test_start "kk._result - numeric value"
kk._result "numVar" "42"
if [[ "${NUMVAR}" == "42" ]]; then
    test_pass "kk._result - numeric value"
else
    test_fail "kk._result - numeric value (got: ${NUMVAR})"
fi

# Test 6: Result with special characters
test_start "kk._result - special characters in value"
kk._result "specialVar" "!@#$%^&*()"
if [[ "${SPECIALVAR}" == "!@#\$%^&*()" ]]; then
    test_pass "kk._result - special characters in value"
else
    test_fail "kk._result - special characters in value"
fi

# Test 7: Result with spaces in value
test_start "kk._result - spaces in value"
kk._result "spacedVar" "hello world test"
if [[ "${SPACEDVAR}" == "hello world test" ]]; then
    test_pass "kk._result - spaces in value"
else
    test_fail "kk._result - spaces in value (got: ${SPACEDVAR})"
fi

# Test 8: Result overwrites previous value
test_start "kk._result - overwrites previous value"
kk._result "overwriteTest" "first"
kk._result "overwriteTest" "second"
if [[ "${OVERWRITETEST}" == "second" ]]; then
    test_pass "kk._result - overwrites previous value"
else
    test_fail "kk._result - overwrites previous value (got: ${OVERWRITETEST})"
fi

# Test 9: Result with newlines
test_start "kk._result - value with newlines"
kk._result "multilineVar" "line1\nline2\nline3"
if [[ "${MULTILINEVAR}" == *$'line1'* ]]; then
    test_pass "kk._result - value with newlines"
else
    test_fail "kk._result - value with newlines"
fi

# Test 10: Result with tabs
test_start "kk._result - value with tabs"
kk._result "tabbedVar" "col1	col2	col3"
if [[ "${TABBEDVAR}" == *"col1"* && "${TABBEDVAR}" == *"col2"* ]]; then
    test_pass "kk._result - value with tabs"
else
    test_fail "kk._result - value with tabs"
fi

test_section "kk._result() Edge Cases"

# Test 11: Variable name conversion verification
test_start "kk._result - variable name conversion"
kk._result "CamelCaseVar" "value"
if [[ "${CAMELCASEVAR}" == "value" ]]; then
    test_pass "kk._result - variable name conversion"
else
    test_fail "kk._result - variable name conversion"
fi

# Test 12: Result with very long value
test_start "kk._result - very long value"
LONG_VAL=$(printf 'a%.0s' {1..5000})
kk._result "longVar" "$LONG_VAL"
if [[ "${#LONGVAR}" == 5000 ]]; then
    test_pass "kk._result - very long value"
else
    test_fail "kk._result - very long value (got length: ${#LONGVAR})"
fi

# Test 13: Multiple result assignments
test_start "kk._result - multiple assignments"
kk._result "var1" "value1"
kk._result "var2" "value2"
kk._result "var3" "value3"
if [[ "${VAR1}" == "value1" && "${VAR2}" == "value2" && "${VAR3}" == "value3" ]]; then
    test_pass "kk._result - multiple assignments"
else
    test_fail "kk._result - multiple assignments"
fi

# Test 14: Result with single character value
test_start "kk._result - single character value"
kk._result "singleChar" "X"
if [[ "${SINGLECHAR}" == "X" ]]; then
    test_pass "kk._result - single character value"
else
    test_fail "kk._result - single character value"
fi

# Test 15: Result with unicode value
test_start "kk._result - unicode value"
kk._result "unicodeVar" "Привет мир"
if [[ "${UNICODEVAR}" == "Привет мир" ]]; then
    test_pass "kk._result - unicode value"
else
    test_fail "kk._result - unicode value"
fi

# Test 16: Variable name with mixed case and separators
test_start "kk._result - complex variable name"
kk._result "My.Complex Property.Name" "complexValue"
if [[ "${MY_COMPLEX_PROPERTY_NAME}" == "complexValue" ]]; then
    test_pass "kk._result - complex variable name"
else
    test_fail "kk._result - complex variable name"
fi

# Test 17: Result sets global variable
test_start "kk._result - sets global variable"
{
    kk._result "globalVar" "global_value"
}
if [[ "${GLOBALVAR}" == "global_value" ]]; then
    test_pass "kk._result - sets global variable"
else
    test_fail "kk._result - sets global variable"
fi

# Test 18: KK_VAR is set by kk._result
test_start "kk._result - KK_VAR is set"
kk._result "testVar" "testValue"
if [[ "$KK_VAR" == "TESTVAR" ]]; then
    test_pass "kk._result - KK_VAR is set"
else
    test_fail "kk._result - KK_VAR is set (got: $KK_VAR)"
fi

# Test 19: Result with path-like value
test_start "kk._result - path-like value"
kk._result "pathVar" "/usr/local/bin/program"
if [[ "${PATHVAR}" == "/usr/local/bin/program" ]]; then
    test_pass "kk._result - path-like value"
else
    test_fail "kk._result - path-like value"
fi

# Test 20: Result preserves value whitespace
test_start "kk._result - preserves value whitespace"
kk._result "wsVar" "  leading  internal  trailing  "
if [[ "${WSVAR}" == "  leading  internal  trailing  " ]]; then
    test_pass "kk._result - preserves value whitespace"
else
    test_fail "kk._result - preserves value whitespace"
fi

cleanup
