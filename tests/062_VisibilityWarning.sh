#!/bin/bash
# VisibilityWarning

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "VisibilityWarning" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

kt_test_start "private access warns once and still works"
declareClass "VaultWarn" ""
privateSection
field "FSecret"
property "Secret" read "FSecret" write "FSecret"
func "Reveal"
endClass
implement "VaultWarn.Reveal" 'RESULT="$FSecret"'
endImplementation "VaultWarn"

VaultWarn.new vault_warn
warnings="$({
    vault_warn.Secret = "42"
    vault_warn.Secret >/dev/null
    vault_warn.Reveal >/dev/null
    vault_warn.Reveal >/dev/null
} 2>&1)"

if [[ "$warnings" == *"private property 'VaultWarn.Secret' accessed from 'external'"* ]] && [[ "$warnings" == *"private method 'VaultWarn.Reveal' accessed from 'external'"* ]]; then
    kt_test_pass "private access warns once and still works"
else
    kt_test_fail "private access warns once and still works"
fi

kt_test_start "protected access from child method does not warn"
declareClass "BaseWarn" ""
protectedSection
func "Hidden"
publicSection
endClass
implement "BaseWarn.Hidden" 'RESULT="hidden"'
endImplementation "BaseWarn"

declareClass "ChildWarn" "BaseWarn"
publicSection
func "ReadHidden"
endClass
implement "ChildWarn.ReadHidden" 'RESULT="$($__inst__.call Hidden)"'
endImplementation "ChildWarn"

ChildWarn.new child_warn
result_and_warnings="$(child_warn.ReadHidden 2>&1)"
if [[ "$result_and_warnings" == "hidden" ]]; then
    kt_test_pass "protected access from child method does not warn"
else
    kt_test_fail "protected access from child method does not warn"
fi