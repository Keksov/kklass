#!/bin/bash
# BashSubshell
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "BashSubshell" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

kt_test_section "Testing BASH_SUBSHELL Detection"

# Test BASH_SUBSHELL behavior
kt_test_start "Main shell BASH_SUBSHELL is 0"
if [[ $BASH_SUBSHELL -eq 0 ]]; then
    kt_test_pass "Main shell BASH_SUBSHELL is 0"
else
    kt_test_fail "Main shell BASH_SUBSHELL is 0 - got $BASH_SUBSHELL"
fi

# Test subshell
kt_test_start "Subshell BASH_SUBSHELL detection"
result=$( echo $BASH_SUBSHELL )
if [[ "$result" -gt 0 ]]; then
    kt_test_pass "Subshell BASH_SUBSHELL detection"
else
    kt_test_fail "Subshell BASH_SUBSHELL detection - got $result"
fi

# Test nested subshell
kt_test_start "Nested subshell BASH_SUBSHELL detection"
result=$( echo $( echo $BASH_SUBSHELL ) )
if [[ "$result" -gt 1 ]]; then
    kt_test_pass "Nested subshell BASH_SUBSHELL detection"
else
    kt_test_fail "Nested subshell BASH_SUBSHELL detection - got $result"
fi
