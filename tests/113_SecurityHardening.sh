#!/bin/bash
# SecurityHardening - regression guards for the kklass hardening:
#   P1.1 identifier validation in kk._build_class_runtime (name injection)
#   P1.4 property values round-trip verbatim (no echo -e mangling)

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "SecurityHardening" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

# P1.1: an injecting class name must be rejected without executing code.
kt_test_start "kk._build_class_runtime rejects an injecting class name"
_pwn="${TMPDIR:-/tmp}/.kk_cls_pwn_$$"
rm -f "$_pwn"
kk._build_class_runtime 'X;touch '"$_pwn"';Y' "" >/dev/null 2>&1
if [[ ! -f "$_pwn" ]]; then
    kt_test_pass "kk._build_class_runtime rejects an injecting class name"
else
    rm -f "$_pwn"
    kt_test_fail "injecting class name executed code"
fi

# P1.1: an injecting method name must be rejected too.
kt_test_start "kk._build_class_runtime rejects an injecting method name"
_pwn2="${TMPDIR:-/tmp}/.kk_meth_pwn_$$"
rm -f "$_pwn2"
kk._build_class_runtime "SafeCls" "" "method" 'm;touch '"$_pwn2" 'echo hi' >/dev/null 2>&1
if [[ ! -f "$_pwn2" ]]; then
    kt_test_pass "kk._build_class_runtime rejects an injecting method name"
else
    rm -f "$_pwn2"
    kt_test_fail "injecting method name executed code"
fi

# A valid class still builds after the rejections above.
kt_test_start "a valid class still builds normally"
defineClass GoodCls "" "property" "x" "method" "hi" 'echo hello' >/dev/null 2>&1
if declare -f GoodCls.new >/dev/null 2>&1; then
    kt_test_pass "a valid class still builds normally"
else
    kt_test_fail "valid class failed to build"
fi

# P1.4: a property value with backslashes must round-trip verbatim (echo -e would
# have interpreted \n / \t and mangled it).
kt_test_start "property value round-trips backslashes verbatim"
defineClass RTClass "" "property" "data" >/dev/null 2>&1
RTClass.new rt_obj >/dev/null 2>&1
rt_obj.data = 'C:\new\table'
_got="$(rt_obj.data)"
if [[ "$_got" == 'C:\new\table' ]]; then
    kt_test_pass "property value round-trips backslashes verbatim"
else
    kt_test_fail "property value corrupted: got '$_got'"
fi

# P1.4: a value that looks like an echo flag must survive too.
kt_test_start "property value round-trips a leading -n verbatim"
rt_obj.data = '-n'
_got2="$(rt_obj.data)"
if [[ "$_got2" == '-n' ]]; then
    kt_test_pass "property value round-trips a leading -n verbatim"
else
    kt_test_fail "property value '-n' corrupted: got '$_got2'"
fi
rt_obj.delete >/dev/null 2>&1
