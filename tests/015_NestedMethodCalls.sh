#!/bin/bash
# NestedMethodCalls
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "NestedMethodCalls" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 15: Nested method calls with $this
kt_test_start "Nested method calls with \$this"
defineClass "Nested" "" \
    "method" "a" 'echo "A"' \
    "method" "b" 'echo -n "B:"; $this.a' \
    "method" "c" 'echo -n "C:"; $this.b'

Nested.new nested1
result=$(nested1.c)
expected="C:B:A"
if [[ "$result" == "$expected" ]]; then
    kt_test_pass "Nested method calls with \$this"
else
    kt_test_fail "Nested method calls with \$this (expected: '$expected', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
