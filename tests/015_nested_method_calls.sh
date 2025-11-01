#!/bin/bash
# 015_nested_method_calls.sh - Test nested method calls with $this

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Test 15: Nested method calls with $this
test_start "Nested method calls with \$this"
defineClass "Nested" "" \
    "method" "a" 'echo "A"' \
    "method" "b" 'echo -n "B:"; $this.a' \
    "method" "c" 'echo -n "C:"; $this.b'

Nested.new nested1
result=$(nested1.c)
expected="C:B:A"
if [[ "$result" == "$expected" ]]; then
    test_pass "Nested method calls with \$this"
else
    test_fail "Nested method calls with \$this (expected: '$expected', got: '$result')"
fi