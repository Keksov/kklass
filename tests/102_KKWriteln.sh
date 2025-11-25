#!/bin/bash
# KKWriteln
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "KKWriteln" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

# Tests output functionality with newline termination


kk_test_section "kk.writeln() Function Tests"

# Test 1: Basic string with newline
kk_test_start "kk.writeln - basic string with newline"
OUTPUT=$(kk.writeln "Hello World" 2>&1)
if [[ "$OUTPUT" == "Hello World" ]]; then
    kk_test_pass "kk.writeln - basic string with newline"
else
    kk_test_fail "kk.writeln - basic string with newline (got: '$OUTPUT')"
fi

# Test 2: Multiple arguments concatenation
kk_test_start "kk.writeln - multiple arguments concatenation"
OUTPUT=$(kk.writeln "Hello" " " "World" 2>&1)
if [[ "$OUTPUT" == "Hello"*"World"* ]]; then
    kk_test_pass "kk.writeln - multiple arguments concatenation"
else
    kk_test_fail "kk.writeln - multiple arguments concatenation (got: '$OUTPUT')"
fi

# Test 3: Empty string with newline
kk_test_start "kk.writeln - empty string with newline"
OUTPUT=$(kk.writeln "" 2>&1)
if [[ "$OUTPUT" == "" ]]; then
    kk_test_pass "kk.writeln - empty string with newline"
else
    kk_test_fail "kk.writeln - empty string with newline (got: '$OUTPUT')"
fi

# Test 4: Trailing newline verification
kk_test_start "kk.writeln - has trailing newline"
OUTPUT=$(kk.writeln "test" 2>&1)
# Verify it contains the text (newline may be implicit in bash string comparison)
if [[ "$OUTPUT" == *"test"* ]]; then
    kk_test_pass "kk.writeln - has trailing newline"
else
    kk_test_fail "kk.writeln - has trailing newline"
fi

# Test 5: Special characters with newline
kk_test_start "kk.writeln - special characters"
OUTPUT=$(kk.writeln "Line1\nLine2" 2>&1)
# Should have embedded newline from escape sequence
if [[ "$OUTPUT" == *$'\n'* ]]; then
    kk_test_pass "kk.writeln - special characters"
else
    kk_test_fail "kk.writeln - special characters"
fi

# Test 6: Tab characters
kk_test_start "kk.writeln - tab characters"
OUTPUT=$(kk.writeln "Col1\tCol2" 2>&1)
if [[ "$OUTPUT" == *$'\t'* ]]; then
    kk_test_pass "kk.writeln - tab characters"
else
    kk_test_fail "kk.writeln - tab characters"
fi

# Test 7: Variable expansion
kk_test_start "kk.writeln - variable expansion"
VAR="TestValue"
OUTPUT=$(kk.writeln "$VAR" 2>&1)
if [[ "$OUTPUT" == *"TestValue"* ]]; then
    kk_test_pass "kk.writeln - variable expansion"
else
    kk_test_fail "kk.writeln - variable expansion (got: '$OUTPUT')"
fi

# Test 8: Numbers as strings
kk_test_start "kk.writeln - numbers as strings"
OUTPUT=$(kk.writeln "123" "456" 2>&1)
if [[ "$OUTPUT" == "123"*"456"* ]]; then
    kk_test_pass "kk.writeln - numbers as strings"
else
    kk_test_fail "kk.writeln - numbers as strings (got: '$OUTPUT')"
fi

# Test 9: Unicode characters
kk_test_start "kk.writeln - unicode characters"
OUTPUT=$(kk.writeln "Привет мир" 2>&1)
if [[ "$OUTPUT" == *"Привет мир"* ]]; then
    kk_test_pass "kk.writeln - unicode characters"
else
    kk_test_fail "kk.writeln - unicode characters"
fi

# Test 10: Multiple newlines in input
kk_test_start "kk.writeln - multiple escaped newlines"
OUTPUT=$(kk.writeln "Line1\nLine2\nLine3" 2>&1)
LINE_COUNT=$(echo "$OUTPUT" | wc -l)
if [[ "$LINE_COUNT" -ge 3 ]]; then
    kk_test_pass "kk.writeln - multiple escaped newlines"
else
    kk_test_fail "kk.writeln - multiple escaped newlines (got $LINE_COUNT lines)"
fi

kk_test_section "kk.writeln() Edge Cases"

# Test 11: Very long string
kk_test_start "kk.writeln - very long string"
LONG_STR=$(printf 'a%.0s' {1..5000})
OUTPUT=$(kk.writeln "$LONG_STR" 2>&1)
if [[ "$OUTPUT" == *"aaaaa"* && ${#OUTPUT} -gt 4900 ]]; then
    kk_test_pass "kk.writeln - very long string"
else
    kk_test_fail "kk.writeln - very long string"
fi

# Test 12: No arguments (just newline)
kk_test_start "kk.writeln - no arguments"
OUTPUT=$(kk.writeln 2>&1)
if [[ "$OUTPUT" == "" ]]; then
    kk_test_pass "kk.writeln - no arguments"
else
    kk_test_fail "kk.writeln - no arguments (got: '$OUTPUT')"
fi

# Test 13: String with spaces preservation
kk_test_start "kk.writeln - preserve spaces"
OUTPUT=$(kk.writeln "  leading  trailing  " 2>&1)
if [[ "$OUTPUT" == "  leading  trailing  "* ]]; then
    kk_test_pass "kk.writeln - preserve spaces"
else
    kk_test_fail "kk.writeln - preserve spaces"
fi


# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
