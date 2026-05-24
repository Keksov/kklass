#!/bin/bash
# ClassVarPascal

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "ClassVarPascal" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

kt_test_start "classVar stores shared class state"
declareClass "CounterClassVar" ""
field "FValue"
property "Value" read "FValue" write "FValue"
classVar "Total"
constructor "Create"
procedure "Increment"
classFunction "GetTotal"
endClass
implementConstructor "CounterClassVar" 'FValue="${1:-0}"; Total=$((Total + 1))'
implement "CounterClassVar.Increment" 'FValue=$((FValue + ${1:-1})); Total=$((Total + ${1:-1}))'
implement "CounterClassVar.GetTotal" 'RESULT="$Total"'
endImplementation "CounterClassVar"

CounterClassVar.Total = "0"
CounterClassVar.new counter_cv_1 5
CounterClassVar.new counter_cv_2 10
counter_cv_1.Increment 3

result_total="$(CounterClassVar.GetTotal)"
if [[ "$result_total" == "5" ]]; then
    kt_test_pass "classVar stores shared class state"
else
    kt_test_fail "classVar stores shared class state (got: '$result_total')"
fi

kt_test_start "classVar accessor works directly"
CounterClassVar.Total = "9"
result_total="$(CounterClassVar.Total)"
if [[ "$result_total" == "9" ]]; then
    kt_test_pass "classVar accessor works directly"
else
    kt_test_fail "classVar accessor works directly (got: '$result_total')"
fi

counter_cv_1.delete
counter_cv_2.delete