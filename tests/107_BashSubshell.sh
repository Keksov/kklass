#!/bin/bash
# BashSubshell
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "BashSubshell" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

kk_test_section "Testing BASH_SUBSHELL Detection"

# Test BASH_SUBSHELL behavior
kk_test_start "Main shell BASH_SUBSHELL is 0"
if [[ $BASH_SUBSHELL -eq 0 ]]; then
    kk_test_pass "Main shell BASH_SUBSHELL is 0"
else
    kk_test_fail "Main shell BASH_SUBSHELL is 0 - got $BASH_SUBSHELL"
fi

# Test subshell
kk_test_start "Subshell BASH_SUBSHELL detection"
result=$( echo $BASH_SUBSHELL )
if [[ "$result" -gt 0 ]]; then
    kk_test_pass "Subshell BASH_SUBSHELL detection"
else
    kk_test_fail "Subshell BASH_SUBSHELL detection - got $result"
fi

# Test nested subshell
kk_test_start "Nested subshell BASH_SUBSHELL detection"
result=$( echo $( echo $BASH_SUBSHELL ) )
if [[ "$result" -gt 1 ]]; then
    kk_test_pass "Nested subshell BASH_SUBSHELL detection"
else
    kk_test_fail "Nested subshell BASH_SUBSHELL detection - got $result"
fi
