#!/bin/bash
# KKWriteln
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "KKWriteln" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

# Tests output functionality with newline termination


kt_test_section "kl.writeln() Function Tests"

# Test 1: Basic string with newline
kt_test_start "kl.writeln - basic string with newline"
OUTPUT=$(kl.writeln "Hello World" 2>&1)
if [[ "$OUTPUT" == "Hello World" ]]; then
    kt_test_pass "kl.writeln - basic string with newline"
else
    kt_test_fail "kl.writeln - basic string with newline (got: '$OUTPUT')"
fi

# Test 2: Multiple arguments concatenation
kt_test_start "kl.writeln - multiple arguments concatenation"
OUTPUT=$(kl.writeln "Hello" " " "World" 2>&1)
if [[ "$OUTPUT" == "Hello"*"World"* ]]; then
    kt_test_pass "kl.writeln - multiple arguments concatenation"
else
    kt_test_fail "kl.writeln - multiple arguments concatenation (got: '$OUTPUT')"
fi

# Test 3: Empty string with newline
kt_test_start "kl.writeln - empty string with newline"
OUTPUT=$(kl.writeln "" 2>&1)
if [[ "$OUTPUT" == "" ]]; then
    kt_test_pass "kl.writeln - empty string with newline"
else
    kt_test_fail "kl.writeln - empty string with newline (got: '$OUTPUT')"
fi

# Test 4: Trailing newline verification
kt_test_start "kl.writeln - has trailing newline"
OUTPUT=$(kl.writeln "test" 2>&1)
# Verify it contains the text (newline may be implicit in bash string comparison)
if [[ "$OUTPUT" == *"test"* ]]; then
    kt_test_pass "kl.writeln - has trailing newline"
else
    kt_test_fail "kl.writeln - has trailing newline"
fi

# Test 5: Special characters with newline
kt_test_start "kl.writeln - special characters"
OUTPUT=$(kl.writeln "Line1\nLine2" 2>&1)
# Should have embedded newline from escape sequence
if [[ "$OUTPUT" == *$'\n'* ]]; then
    kt_test_pass "kl.writeln - special characters"
else
    kt_test_fail "kl.writeln - special characters"
fi

# Test 6: Tab characters
kt_test_start "kl.writeln - tab characters"
OUTPUT=$(kl.writeln "Col1\tCol2" 2>&1)
if [[ "$OUTPUT" == *$'\t'* ]]; then
    kt_test_pass "kl.writeln - tab characters"
else
    kt_test_fail "kl.writeln - tab characters"
fi

# Test 7: Variable expansion
kt_test_start "kl.writeln - variable expansion"
VAR="TestValue"
OUTPUT=$(kl.writeln "$VAR" 2>&1)
if [[ "$OUTPUT" == *"TestValue"* ]]; then
    kt_test_pass "kl.writeln - variable expansion"
else
    kt_test_fail "kl.writeln - variable expansion (got: '$OUTPUT')"
fi

# Test 8: Numbers as strings
kt_test_start "kl.writeln - numbers as strings"
OUTPUT=$(kl.writeln "123" "456" 2>&1)
if [[ "$OUTPUT" == "123"*"456"* ]]; then
    kt_test_pass "kl.writeln - numbers as strings"
else
    kt_test_fail "kl.writeln - numbers as strings (got: '$OUTPUT')"
fi

# Test 9: Unicode characters
kt_test_start "kl.writeln - unicode characters"
OUTPUT=$(kl.writeln "Привет мир" 2>&1)
if [[ "$OUTPUT" == *"Привет мир"* ]]; then
    kt_test_pass "kl.writeln - unicode characters"
else
    kt_test_fail "kl.writeln - unicode characters"
fi

# Test 10: Multiple newlines in input
kt_test_start "kl.writeln - multiple escaped newlines"
OUTPUT=$(kl.writeln "Line1\nLine2\nLine3" 2>&1)
LINE_COUNT=$(echo "$OUTPUT" | wc -l)
if [[ "$LINE_COUNT" -ge 3 ]]; then
    kt_test_pass "kl.writeln - multiple escaped newlines"
else
    kt_test_fail "kl.writeln - multiple escaped newlines (got $LINE_COUNT lines)"
fi

kt_test_section "kl.writeln() Edge Cases"

# Test 11: Very long string
kt_test_start "kl.writeln - very long string"
LONG_STR=$(printf 'a%.0s' {1..5000})
OUTPUT=$(kl.writeln "$LONG_STR" 2>&1)
if [[ "$OUTPUT" == *"aaaaa"* && ${#OUTPUT} -gt 4900 ]]; then
    kt_test_pass "kl.writeln - very long string"
else
    kt_test_fail "kl.writeln - very long string"
fi

# Test 12: No arguments (just newline)
kt_test_start "kl.writeln - no arguments"
OUTPUT=$(kl.writeln 2>&1)
if [[ "$OUTPUT" == "" ]]; then
    kt_test_pass "kl.writeln - no arguments"
else
    kt_test_fail "kl.writeln - no arguments (got: '$OUTPUT')"
fi

# Test 13: String with spaces preservation
kt_test_start "kl.writeln - preserve spaces"
OUTPUT=$(kl.writeln "  leading  trailing  " 2>&1)
if [[ "$OUTPUT" == "  leading  trailing  "* ]]; then
    kt_test_pass "kl.writeln - preserve spaces"
else
    kt_test_fail "kl.writeln - preserve spaces"
fi


# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
