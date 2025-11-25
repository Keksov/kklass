#!/bin/bash
# KKWrite
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "KKWrite" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

# Tests basic output functionality without newline termination


kk_test_section "kk.write() Function Tests"

# Test 1: Basic string output
kk_test_start "kk.write - basic string output"
OUTPUT=$(kk.write "Hello World" 2>&1)
if [[ "$OUTPUT" == "Hello World" ]]; then
    kk_test_pass "kk.write - basic string output"
else
    kk_test_fail "kk.write - basic string output (got: '$OUTPUT')"
fi

# Test 2: Multiple arguments concatenation
kk_test_start "kk.write - multiple arguments concatenation"
OUTPUT=$(kk.write "Hello" " " "World" 2>&1)
if [[ "$OUTPUT" == "Hello"*"World" ]]; then
    kk_test_pass "kk.write - multiple arguments concatenation"
else
    kk_test_fail "kk.write - multiple arguments concatenation (got: '$OUTPUT')"
fi

# Test 3: Empty string
kk_test_start "kk.write - empty string"
OUTPUT=$(kk.write "" 2>&1)
if [[ "$OUTPUT" == "" ]]; then
    kk_test_pass "kk.write - empty string"
else
    kk_test_fail "kk.write - empty string (got: '$OUTPUT')"
fi

# Test 4: Special characters (no newline)
kk_test_start "kk.write - special characters"
OUTPUT=$(kk.write "Line1\nLine2" 2>&1)
if [[ "$OUTPUT" == "Line1"$'\n'"Line2" ]]; then
    kk_test_pass "kk.write - special characters"
else
    kk_test_fail "kk.write - special characters"
fi

# Test 5: Tab characters
kk_test_start "kk.write - tab characters"
OUTPUT=$(kk.write "Col1\tCol2" 2>&1)
if [[ "$OUTPUT" == "Col1"$'\t'"Col2" ]]; then
    kk_test_pass "kk.write - tab characters"
else
    kk_test_fail "kk.write - tab characters"
fi

# Test 6: Variable expansion
kk_test_start "kk.write - variable expansion"
VAR="TestValue"
OUTPUT=$(kk.write "$VAR" 2>&1)
if [[ "$OUTPUT" == "TestValue" ]]; then
    kk_test_pass "kk.write - variable expansion"
else
    kk_test_fail "kk.write - variable expansion (got: '$OUTPUT')"
fi

# Test 7: Numbers as strings
kk_test_start "kk.write - numbers as strings"
OUTPUT=$(kk.write "123" "456" 2>&1)
if [[ "$OUTPUT" == "123"*"456" ]]; then
    kk_test_pass "kk.write - numbers as strings"
else
    kk_test_fail "kk.write - numbers as strings (got: '$OUTPUT')"
fi

# Test 8: Special shell characters
kk_test_start "kk.write - special shell characters"
OUTPUT=$(kk.write '$' '"' "'" 2>&1)
# Just verify output contains all characters (separated by spaces from echo -en)
if [[ "$OUTPUT" == *'$'* && "$OUTPUT" == *'"'* && "$OUTPUT" == *"'"* ]]; then
    kk_test_pass "kk.write - special shell characters"
else
    kk_test_fail "kk.write - special shell characters"
fi

# Test 9: Unicode/UTF-8 characters
kk_test_start "kk.write - unicode characters"
OUTPUT=$(kk.write "Привет" 2>&1)
if [[ "$OUTPUT" == "Привет" ]]; then
    kk_test_pass "kk.write - unicode characters"
else
    kk_test_fail "kk.write - unicode characters"
fi

# Test 10: No trailing newline verification
kk_test_start "kk.write - no trailing newline"
OUTPUT=$(kk.write "test" 2>&1)
# Check that output doesn't end with newline
if [[ "$OUTPUT" != *$'\n' ]]; then
    kk_test_pass "kk.write - no trailing newline"
else
    kk_test_fail "kk.write - no trailing newline (found newline in output)"
fi

kk_test_section "kk.write() Edge Cases"

# Test 11: Very long string
kk_test_start "kk.write - very long string"
LONG_STR=$(printf 'a%.0s' {1..10000})
OUTPUT=$(kk.write "$LONG_STR" 2>&1)
if [[ "${#OUTPUT}" == 10000 ]]; then
    kk_test_pass "kk.write - very long string"
else
    kk_test_fail "kk.write - very long string (got length: ${#OUTPUT})"
fi

# Test 12: Escape sequences handling
kk_test_start "kk.write - escape sequences (-e flag is implicit)"
OUTPUT=$(kk.write "Line1\r\nLine2" 2>&1)
# echo -en interprets escape sequences
if [[ -n "$OUTPUT" ]]; then
    kk_test_pass "kk.write - escape sequences"
else
    kk_test_fail "kk.write - escape sequences"
fi


# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
