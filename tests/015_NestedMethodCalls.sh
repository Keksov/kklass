#!/bin/bash
# NestedMethodCalls
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "NestedMethodCalls" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 15: Nested method calls with $this
kk_test_start "Nested method calls with \$this"
defineClass "Nested" "" \
    "method" "a" 'echo "A"' \
    "method" "b" 'echo -n "B:"; $this.a' \
    "method" "c" 'echo -n "C:"; $this.b'

Nested.new nested1
result=$(nested1.c)
expected="C:B:A"
if [[ "$result" == "$expected" ]]; then
    kk_test_pass "Nested method calls with \$this"
else
    kk_test_fail "Nested method calls with \$this (expected: '$expected', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
