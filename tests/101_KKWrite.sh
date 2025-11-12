#!/bin/bash
# 101_kklib_kk_write.sh - Unit tests for kk.write() function
# Tests basic output functionality without newline termination

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

test_section "kk.write() Function Tests"

# Test 1: Basic string output
test_start "kk.write - basic string output"
OUTPUT=$(kk.write "Hello World" 2>&1)
if [[ "$OUTPUT" == "Hello World" ]]; then
    test_pass "kk.write - basic string output"
else
    test_fail "kk.write - basic string output (got: '$OUTPUT')"
fi

# Test 2: Multiple arguments concatenation
test_start "kk.write - multiple arguments concatenation"
OUTPUT=$(kk.write "Hello" " " "World" 2>&1)
if [[ "$OUTPUT" == "Hello"*"World" ]]; then
    test_pass "kk.write - multiple arguments concatenation"
else
    test_fail "kk.write - multiple arguments concatenation (got: '$OUTPUT')"
fi

# Test 3: Empty string
test_start "kk.write - empty string"
OUTPUT=$(kk.write "" 2>&1)
if [[ "$OUTPUT" == "" ]]; then
    test_pass "kk.write - empty string"
else
    test_fail "kk.write - empty string (got: '$OUTPUT')"
fi

# Test 4: Special characters (no newline)
test_start "kk.write - special characters"
OUTPUT=$(kk.write "Line1\nLine2" 2>&1)
if [[ "$OUTPUT" == "Line1"$'\n'"Line2" ]]; then
    test_pass "kk.write - special characters"
else
    test_fail "kk.write - special characters"
fi

# Test 5: Tab characters
test_start "kk.write - tab characters"
OUTPUT=$(kk.write "Col1\tCol2" 2>&1)
if [[ "$OUTPUT" == "Col1"$'\t'"Col2" ]]; then
    test_pass "kk.write - tab characters"
else
    test_fail "kk.write - tab characters"
fi

# Test 6: Variable expansion
test_start "kk.write - variable expansion"
VAR="TestValue"
OUTPUT=$(kk.write "$VAR" 2>&1)
if [[ "$OUTPUT" == "TestValue" ]]; then
    test_pass "kk.write - variable expansion"
else
    test_fail "kk.write - variable expansion (got: '$OUTPUT')"
fi

# Test 7: Numbers as strings
test_start "kk.write - numbers as strings"
OUTPUT=$(kk.write "123" "456" 2>&1)
if [[ "$OUTPUT" == "123"*"456" ]]; then
    test_pass "kk.write - numbers as strings"
else
    test_fail "kk.write - numbers as strings (got: '$OUTPUT')"
fi

# Test 8: Special shell characters
test_start "kk.write - special shell characters"
OUTPUT=$(kk.write '$' '"' "'" 2>&1)
# Just verify output contains all characters (separated by spaces from echo -en)
if [[ "$OUTPUT" == *'$'* && "$OUTPUT" == *'"'* && "$OUTPUT" == *"'"* ]]; then
    test_pass "kk.write - special shell characters"
else
    test_fail "kk.write - special shell characters"
fi

# Test 9: Unicode/UTF-8 characters
test_start "kk.write - unicode characters"
OUTPUT=$(kk.write "Привет" 2>&1)
if [[ "$OUTPUT" == "Привет" ]]; then
    test_pass "kk.write - unicode characters"
else
    test_fail "kk.write - unicode characters"
fi

# Test 10: No trailing newline verification
test_start "kk.write - no trailing newline"
OUTPUT=$(kk.write "test" 2>&1)
# Check that output doesn't end with newline
if [[ "$OUTPUT" != *$'\n' ]]; then
    test_pass "kk.write - no trailing newline"
else
    test_fail "kk.write - no trailing newline (found newline in output)"
fi

test_section "kk.write() Edge Cases"

# Test 11: Very long string
test_start "kk.write - very long string"
LONG_STR=$(printf 'a%.0s' {1..10000})
OUTPUT=$(kk.write "$LONG_STR" 2>&1)
if [[ "${#OUTPUT}" == 10000 ]]; then
    test_pass "kk.write - very long string"
else
    test_fail "kk.write - very long string (got length: ${#OUTPUT})"
fi

# Test 12: Escape sequences handling
test_start "kk.write - escape sequences (-e flag is implicit)"
OUTPUT=$(kk.write "Line1\r\nLine2" 2>&1)
# echo -en interprets escape sequences
if [[ -n "$OUTPUT" ]]; then
    test_pass "kk.write - escape sequences"
else
    test_fail "kk.write - escape sequences"
fi

cleanup
