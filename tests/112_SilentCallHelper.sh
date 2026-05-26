#!/bin/bash
# SilentCallHelper

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "SilentCallHelper" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"

defineClass "SilentCallSample" "" \
    "function" "Inner" '
        RESULT="$1"
        kk._return "$RESULT"
        return 0
    ' \
    "function" "Outer" '
        kk.call_silent "$this" Inner "$1"
        local inner_result="$RESULT"
        RESULT="outer:$inner_result"
    '

kt_test_start "kk.call_silent preserves nested RESULT without stdout leakage"
SilentCallSample.new silent_sample
outer_output=$(silent_sample.Outer "value")
outer_status=$?

if [[ "$outer_status" -eq 0 && "$outer_output" == "outer:value" ]]; then
    kt_test_pass "kk.call_silent preserves nested RESULT without stdout leakage"
else
    kt_test_fail "kk.call_silent leaked output or wrong status: status=$outer_status output='$outer_output'"
fi

kt_test_start "kk.call_silent restores existing silent flag"
__kk_return_silent="existing"
kk.call_silent "silent_sample" Inner "direct"
silent_result="$RESULT"
restored_silent="$__kk_return_silent"
unset __kk_return_silent

if [[ "$silent_result" == "direct" && "$restored_silent" == "existing" ]]; then
    kt_test_pass "kk.call_silent restores existing silent flag"
else
    kt_test_fail "kk.call_silent failed to restore silent flag: result=$silent_result silent=$restored_silent"
fi

silent_sample.delete