#!/bin/bash
# KKResult
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "KKResult" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

# Tests variable assignment via kk._return (uses kk._var internally)


kt_test_section "kk._return() Function Tests"

# Test 1: Basic result assignment
kt_test_start "kk._return - basic assignment"
kk._return "myVar" "value123"
if [[ "${MYVAR}" == "value123" ]]; then
    kt_test_pass "kk._return - basic assignment"
else
    kt_test_fail "kk._return - basic assignment (got: ${MYVAR})"
fi

# Test 2: Result with spaces in variable name
kt_test_start "kk._return - variable name with spaces"
kk._return "my var" "testvalue"
if [[ "${MY_VAR}" == "testvalue" ]]; then
    kt_test_pass "kk._return - variable name with spaces"
else
    kt_test_fail "kk._return - variable name with spaces (got: ${MY_VAR})"
fi

# Test 3: Result with dots in variable name
kt_test_start "kk._return - variable name with dots"
kk._return "my.property.name" "dotvalue"
if [[ "${MY_PROPERTY_NAME}" == "dotvalue" ]]; then
    kt_test_pass "kk._return - variable name with dots"
else
    kt_test_fail "kk._return - variable name with dots (got: ${MY_PROPERTY_NAME})"
fi

# Test 4: Result with empty value
kt_test_start "kk._return - empty value assignment"
kk._return "emptyVar" ""
if [[ "${EMPTYVAR}" == "" ]]; then
    kt_test_pass "kk._return - empty value assignment"
else
    kt_test_fail "kk._return - empty value assignment (got: ${EMPTYVAR})"
fi

# Test 5: Result with numeric value
kt_test_start "kk._return - numeric value"
kk._return "numVar" "42"
if [[ "${NUMVAR}" == "42" ]]; then
    kt_test_pass "kk._return - numeric value"
else
    kt_test_fail "kk._return - numeric value (got: ${NUMVAR})"
fi

# Test 6: Result with special characters
kt_test_start "kk._return - special characters in value"
kk._return "specialVar" "!@#$%^&*()"
if [[ "${SPECIALVAR}" == "!@#\$%^&*()" ]]; then
    kt_test_pass "kk._return - special characters in value"
else
    kt_test_fail "kk._return - special characters in value"
fi

# Test 7: Result with spaces in value
kt_test_start "kk._return - spaces in value"
kk._return "spacedVar" "hello world test"
if [[ "${SPACEDVAR}" == "hello world test" ]]; then
    kt_test_pass "kk._return - spaces in value"
else
    kt_test_fail "kk._return - spaces in value (got: ${SPACEDVAR})"
fi

# Test 8: Result overwrites previous value
kt_test_start "kk._return - overwrites previous value"
kk._return "overwriteTest" "first"
kk._return "overwriteTest" "second"
if [[ "${OVERWRITETEST}" == "second" ]]; then
    kt_test_pass "kk._return - overwrites previous value"
else
    kt_test_fail "kk._return - overwrites previous value (got: ${OVERWRITETEST})"
fi

# Test 9: Result with newlines
kt_test_start "kk._return - value with newlines"
kk._return "multilineVar" "line1\nline2\nline3"
if [[ "${MULTILINEVAR}" == *$'line1'* ]]; then
    kt_test_pass "kk._return - value with newlines"
else
    kt_test_fail "kk._return - value with newlines"
fi

# Test 10: Result with tabs
kt_test_start "kk._return - value with tabs"
kk._return "tabbedVar" "col1	col2	col3"
if [[ "${TABBEDVAR}" == *"col1"* && "${TABBEDVAR}" == *"col2"* ]]; then
    kt_test_pass "kk._return - value with tabs"
else
    kt_test_fail "kk._return - value with tabs"
fi

kt_test_section "kk._return() Edge Cases"

# Test 11: Variable name conversion verification
kt_test_start "kk._return - variable name conversion"
kk._return "CamelCaseVar" "value"
if [[ "${CAMELCASEVAR}" == "value" ]]; then
    kt_test_pass "kk._return - variable name conversion"
else
    kt_test_fail "kk._return - variable name conversion"
fi

# Test 12: Result with very long value
kt_test_start "kk._return - very long value"
LONG_VAL=$(printf 'a%.0s' {1..5000})
kk._return "longVar" "$LONG_VAL"
if [[ "${#LONGVAR}" == 5000 ]]; then
    kt_test_pass "kk._return - very long value"
else
    kt_test_fail "kk._return - very long value (got length: ${#LONGVAR})"
fi

# Test 13: Multiple result assignments
kt_test_start "kk._return - multiple assignments"
kk._return "var1" "value1"
kk._return "var2" "value2"
kk._return "var3" "value3"
if [[ "${VAR1}" == "value1" && "${VAR2}" == "value2" && "${VAR3}" == "value3" ]]; then
    kt_test_pass "kk._return - multiple assignments"
else
    kt_test_fail "kk._return - multiple assignments"
fi

# Test 14: Result with single character value
kt_test_start "kk._return - single character value"
kk._return "singleChar" "X"
if [[ "${SINGLECHAR}" == "X" ]]; then
    kt_test_pass "kk._return - single character value"
else
    kt_test_fail "kk._return - single character value"
fi

# Test 15: Result with unicode value
kt_test_start "kk._return - unicode value"
kk._return "unicodeVar" "Привет мир"
if [[ "${UNICODEVAR}" == "Привет мир" ]]; then
    kt_test_pass "kk._return - unicode value"
else
    kt_test_fail "kk._return - unicode value"
fi

# Test 16: Variable name with mixed case and separators
kt_test_start "kk._return - complex variable name"
kk._return "My.Complex Property.Name" "complexValue"
if [[ "${MY_COMPLEX_PROPERTY_NAME}" == "complexValue" ]]; then
    kt_test_pass "kk._return - complex variable name"
else
    kt_test_fail "kk._return - complex variable name"
fi

# Test 17: Result sets global variable
kt_test_start "kk._return - sets global variable"
{
    kk._return "globalVar" "global_value"
}
if [[ "${GLOBALVAR}" == "global_value" ]]; then
    kt_test_pass "kk._return - sets global variable"
else
    kt_test_fail "kk._return - sets global variable"
fi

# Test 18: KK_VAR is set by kk._return
kt_test_start "kk._return - KK_VAR is set"
kk._return "testVar" "testValue"
if [[ "$KK_VAR" == "TESTVAR" ]]; then
    kt_test_pass "kk._return - KK_VAR is set"
else
    kt_test_fail "kk._return - KK_VAR is set (got: $KK_VAR)"
fi

# Test 19: Result with path-like value
kt_test_start "kk._return - path-like value"
kk._return "pathVar" "/usr/local/bin/program"
if [[ "${PATHVAR}" == "/usr/local/bin/program" ]]; then
    kt_test_pass "kk._return - path-like value"
else
    kt_test_fail "kk._return - path-like value"
fi

# Test 20: Result preserves value whitespace
kt_test_start "kk._return - preserves value whitespace"
kk._return "wsVar" "  leading  internal  trailing  "
if [[ "${WSVAR}" == "  leading  internal  trailing  " ]]; then
    kt_test_pass "kk._return - preserves value whitespace"
else
    kt_test_fail "kk._return - preserves value whitespace"
fi


# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
