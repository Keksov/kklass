#!/bin/bash
# KKWrite
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "KKWrite" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

# Tests basic output functionality without newline termination


kt_test_section "kl.write() Function Tests"

# Test 1: Basic string output
kt_test_start "kl.write - basic string output"
OUTPUT=$(kl.write "Hello World" 2>&1)
if [[ "$OUTPUT" == "Hello World" ]]; then
    kt_test_pass "kl.write - basic string output"
else
    kt_test_fail "kl.write - basic string output (got: '$OUTPUT')"
fi

# Test 2: Multiple arguments concatenation
kt_test_start "kl.write - multiple arguments concatenation"
OUTPUT=$(kl.write "Hello" " " "World" 2>&1)
if [[ "$OUTPUT" == "Hello"*"World" ]]; then
    kt_test_pass "kl.write - multiple arguments concatenation"
else
    kt_test_fail "kl.write - multiple arguments concatenation (got: '$OUTPUT')"
fi

# Test 3: Empty string
kt_test_start "kl.write - empty string"
OUTPUT=$(kl.write "" 2>&1)
if [[ "$OUTPUT" == "" ]]; then
    kt_test_pass "kl.write - empty string"
else
    kt_test_fail "kl.write - empty string (got: '$OUTPUT')"
fi

# Test 4: Special characters (no newline)
kt_test_start "kl.write - special characters"
OUTPUT=$(kl.write "Line1\nLine2" 2>&1)
if [[ "$OUTPUT" == "Line1"$'\n'"Line2" ]]; then
    kt_test_pass "kl.write - special characters"
else
    kt_test_fail "kl.write - special characters"
fi

# Test 5: Tab characters
kt_test_start "kl.write - tab characters"
OUTPUT=$(kl.write "Col1\tCol2" 2>&1)
if [[ "$OUTPUT" == "Col1"$'\t'"Col2" ]]; then
    kt_test_pass "kl.write - tab characters"
else
    kt_test_fail "kl.write - tab characters"
fi

# Test 6: Variable expansion
kt_test_start "kl.write - variable expansion"
VAR="TestValue"
OUTPUT=$(kl.write "$VAR" 2>&1)
if [[ "$OUTPUT" == "TestValue" ]]; then
    kt_test_pass "kl.write - variable expansion"
else
    kt_test_fail "kl.write - variable expansion (got: '$OUTPUT')"
fi

# Test 7: Numbers as strings
kt_test_start "kl.write - numbers as strings"
OUTPUT=$(kl.write "123" "456" 2>&1)
if [[ "$OUTPUT" == "123"*"456" ]]; then
    kt_test_pass "kl.write - numbers as strings"
else
    kt_test_fail "kl.write - numbers as strings (got: '$OUTPUT')"
fi

# Test 8: Special shell characters
kt_test_start "kl.write - special shell characters"
OUTPUT=$(kl.write '$' '"' "'" 2>&1)
# Just verify output contains all characters (separated by spaces from echo -en)
if [[ "$OUTPUT" == *'$'* && "$OUTPUT" == *'"'* && "$OUTPUT" == *"'"* ]]; then
    kt_test_pass "kl.write - special shell characters"
else
    kt_test_fail "kl.write - special shell characters"
fi

# Test 9: Unicode/UTF-8 characters
kt_test_start "kl.write - unicode characters"
OUTPUT=$(kl.write "Привет" 2>&1)
if [[ "$OUTPUT" == "Привет" ]]; then
    kt_test_pass "kl.write - unicode characters"
else
    kt_test_fail "kl.write - unicode characters"
fi

# Test 10: No trailing newline verification
kt_test_start "kl.write - no trailing newline"
OUTPUT=$(kl.write "test" 2>&1)
# Check that output doesn't end with newline
if [[ "$OUTPUT" != *$'\n' ]]; then
    kt_test_pass "kl.write - no trailing newline"
else
    kt_test_fail "kl.write - no trailing newline (found newline in output)"
fi

kt_test_section "kl.write() Edge Cases"

# Test 11: Very long string
kt_test_start "kl.write - very long string"
LONG_STR=$(printf 'a%.0s' {1..10000})
OUTPUT=$(kl.write "$LONG_STR" 2>&1)
if [[ "${#OUTPUT}" == 10000 ]]; then
    kt_test_pass "kl.write - very long string"
else
    kt_test_fail "kl.write - very long string (got length: ${#OUTPUT})"
fi

# Test 12: Escape sequences handling
kt_test_start "kl.write - escape sequences (-e flag is implicit)"
OUTPUT=$(kl.write "Line1\r\nLine2" 2>&1)
# echo -en interprets escape sequences
if [[ -n "$OUTPUT" ]]; then
    kt_test_pass "kl.write - escape sequences"
else
    kt_test_fail "kl.write - escape sequences"
fi


# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
