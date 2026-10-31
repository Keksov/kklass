#!/usr/bin/env bash
# ControlBytesInBodies (launch L7.2-K) — a method body is byte-faithful: every
# control byte 0x01..0x1F and 0x7F written as an escape ($'\xNN', $'\r', $'\t',
# $'\cA', …) in a method body reaches the running method unchanged, on every
# path that makes a method: the Pascal DSL (`class … end` + `build`, whose
# bodies come from `declare -f`), the declarative API (`implement`),
# defineClass, kk.register_static_methods, a compiled cache
# (kklass_compiler.sh), a .kkp translation, and the namespace snapshot that
# sink mode n restores.
#
# The bug: `declare -f` prints the word $'\r' with its CR RAW ('<CR>'), and the
# MSYS2 / Cygwin bashes drop every raw CR byte of a text they parse (eval,
# source, bash -c; no other control byte). A Pascal DSL body is such a
# re-parsed `declare -f` text, so `local cr=$'\r'` ran as `local cr=''` and
# `[[ $x == *$'\r'* ]]` matched every string. Linux bash keeps the raw CR.
# Fixed by kk._fn_text_cr (kklass.sh), used by every path that re-parses a
# `declare -f` text.
#
# Values are compared in this process or through files: a $( ) drops CRs on
# MSYS. A failure prints the values with printf %q.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "ControlBytesInBodies" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
W="$(cd "$(kt_fixture_tmpdir)" && pwd)"
source "$KKLASS_DIR/kklass_pascal.sh" || exit 1

# ---------------------------------------------------------------------------
# The bytes, the expected value, and the body text that writes them as escapes.
HEX=(01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f 10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f 7f)
WANT="" ESC="''" q="'"
for h in "${HEX[@]}"; do
    printf -v c "\\x$h"; WANT+=$c
    ESC+="\$$q\\x$h$q"                     # -> ''$'\x01'$'\x02'…  (escape TEXT, no raw byte)
done
# the named escapes, the control-letter, octal and hex forms: BEL BS TAB LF VT FF CR ESC ^A CR CR
NAMED_ESC="\$'\\a\\b\\t\\n\\v\\f\\r\\e\\cA\\015\\x0D'"
printf -v NAMED_WANT '\a\b\t\n\v\f\r\033\001\r\r'
CR=""; printf -v CR '\r'

# slurp FILE VAR — VAR = FILE's bytes (no $( ), no CR lost)
slurp() { local __s=""; IFS= read -r -N 1048576 __s <"$1" || :; printf -v "$2" '%s' "$__s"; }
# same NAME GOT WANT — pass or fail with both values quoted
same() {
    if [[ "$2" == "$3" ]]; then kt_test_pass "$1"; else kt_test_fail "$1: got $(printf '%q' "$2") want $(printf '%q' "$3")"; fi
}
# the parser of this bash: does it keep a raw CR?
DROPS_CR=0; __p=""; eval "__p='$CR'"; [[ -n $__p ]] || DROPS_CR=1

# ---------------------------------------------------------------------------
kt_test_start "R1 the root cause on this bash: a raw byte 0x01..0x1F/0x7F other than CR survives eval and source; \`declare -f\` prints a CR escape word with the CR raw (this bash $( ((DROPS_CR)) && echo drops || echo keeps ) a raw CR)"
bad=""
for h in "${HEX[@]}"; do
    [[ $h == 0a ]] && continue
    printf -v c "\\x$h"
    v=""; eval "v='a${c}b'"
    printf "v='a%sb'\n" "$c" >"$W/r1.sh"; v2=""; source "$W/r1.sh"; v2=$v
    if [[ $h == 0d ]]; then
        if (( DROPS_CR )); then [[ $v == ab && $v2 == ab ]] || bad+=" 0d-dropper:$(printf %q "$v")"
        else [[ $v == "a${c}b" && $v2 == "a${c}b" ]] || bad+=" 0d-keeper:$(printf %q "$v")"; fi
    else
        [[ $v == "a${c}b" && $v2 == "a${c}b" ]] || bad+=" $h"
    fi
done
r1f() { local x=$'\r'; }
kk._fn_text r1f t; [[ $t == *"'$CR'"* ]] || bad+=" declare-f:$(printf %q "$t")"
if [[ -z $bad ]]; then kt_test_pass "only CR is special"; else kt_test_fail "$bad"; fi

# ---------------------------------------------------------------------------
# P: the Pascal DSL — instance proc, func, static func, constructor,
# destructor, a negative match, and an override with a bare `inherited`.
class TCbP
    public
        constructor Create
        destructor Destroy
        proc All
        func Named
        proc Neg
        static func SAll
end
eval "TCbP.All() { CB_OUT=$ESC; }"
eval "TCbP.Named() { RESULT=$NAMED_ESC; }"
TCbP.Neg() { local x=ab; if [[ $x == *$'\r'* ]]; then CB_NEG=match; else CB_NEG=nomatch; fi; }
eval "TCbP.SAll() { RESULT=$ESC; }"
TCbP.Create() { CB_CTOR=$'<\r\x01\x7f>'; }
TCbP.Destroy() { CB_DTOR=$'<\r>'; }
build TCbP
class TCbQ : TCbP
    public
        override proc All
end
TCbQ.All() { inherited; CB_OUT2=$'[\r]'"$CB_OUT"; }
build TCbQ

kt_test_start "P1 Pascal DSL instance proc: all 32 control bytes (written as hex escapes) reach the method"
CB_OUT=""; TCbP.new cbp; cbp.All; same "P1" "$CB_OUT" "$WANT"
kt_test_start "P2 Pascal DSL func: the named escapes (BEL BS TAB LF VT FF CR ESC, control-A, octal and hex CR)"
RESULT=""; cbp.Named; same "P2" "$RESULT" "$NAMED_WANT"
kt_test_start "P3 Pascal DSL: a glob holding a CR escape does NOT match a string without a CR"
CB_NEG=""; cbp.Neg; same "P3" "$CB_NEG" "nomatch"
kt_test_start "P4 Pascal DSL static func: all 32 control bytes"
RESULT=""; TCbP.SAll >/dev/null; same "P4" "$RESULT" "$WANT"     # (a static func also prints RESULT)
kt_test_start "P5 Pascal DSL constructor and destructor bodies keep CR, 0x01, 0x7F"
CB_DTOR=""; cbp.delete
printf -v w5 '<\r\001\177>|<\r>'
same "P5" "$CB_CTOR|$CB_DTOR" "$w5"
kt_test_start "P6 Pascal DSL override with a bare inherited: the child's CR and the parent's 32 bytes"
CB_OUT="" CB_OUT2=""; TCbQ.new cbq; cbq.All; same "P6" "$CB_OUT2" "[$CR]$WANT"
cbq.delete

# ---------------------------------------------------------------------------
# C: quoting contexts — a Pascal method and a plain function with the same
# body must print the same bytes (bash's own behaviour is the reference, e.g.
# MSYS's $( ) and compound-array quirks apply to both alike).
cat >"$W/ctx.tpl" <<'EOF'
@@c01() { local x=$'\r'; printf '[%s]' "$x"; }
@@c02() { local x=$'a\rb' y=ab; [[ $x == *$'\r'* ]] && printf yes || printf no; [[ $y == *$'\r'* ]] && printf yes || printf no; }
@@c03() { case $'a\rb' in *$'\r'*) printf case-yes ;; *) printf case-no ;; esac; case ab in *$'\r'*) printf case-yes ;; *) printf case-no ;; esac; }
@@c04() { local x=$'a\rb'; printf '[%s]' "${x//$'\r'/R}"; }
@@c05() { local x=$'a\r'; printf '[%s]%s' "${x%$'\r'}" "${#x}"; }
@@c06() { local x=''; printf '[%s]' "${x:-$'\r'}" "${x:=$'a\rb'}"; }
@@c07() { printf '[%s]' "$(printf %s $'a\rb')"; }
@@c08() { local y; IFS= read -r y <<< $'a\rb'; printf '[%s]' "$y"; }
@@c09() { printf '[%s]' $'it\'s\r'; }
@@c10() { local -a a=($'x\ry'); printf '[%s]' "${a[@]}"; }
@@c11() { printf '[%s]' "pre"$'\r'"post"; }
@@c12() { cat <<EOT
[$'\r']
EOT
}
@@c13() { local x=$'\r'; printf '[%s]' "${x/$'\r'/"$'\r'"}"; }
@@c14() { printf '[%s]' $'\r\r\x01\x7f\t'; }
@@c15() { local x=$'a\rb' re=$'\r'; [[ $x =~ $re ]] && printf re-yes || printf re-no; [[ $x =~ $'\r' ]] && printf re-yes || printf re-no; }
@@c16() { local x="${y:-"$'\r'"}"; printf '[%s]' "$x"; }
@@c17() { local x=$'a\rb'; printf '[%s]' "${x#*$'\r'}" "${x/#a$'\r'/X}"; }
@@c18() { printf '[%s]' `printf %s $'a\rb'`; }
@@c19() { local a=$'\r' b=''; printf '[%s]' "${a}${b:-$'\r'}" "$a" "${b:+$'\r'}" "${b-$'\r'}"; }
@@c20() { local -A m=([$'k\r']=$'v\r'); local k; for k in "${!m[@]}"; do printf '[%s=%s]' "$k" "${m[$k]}"; done; }
EOF
CTX=(c01 c02 c03 c04 c05 c06 c07 c08 c09 c10 c11 c12 c13 c14 c15 c16 c17 c18 c19 c20)
ref_src="" cls_src=""
while IFS= read -r line; do ref_src+=${line//@@/ref_}$'\n'; cls_src+=${line//@@/TCbX.}$'\n'; done <"$W/ctx.tpl"
eval "$ref_src"
{
    printf 'class TCbX\n    public\n'
    for c in "${CTX[@]}"; do printf '        proc %s\n' "$c"; done
    printf 'end\n'
} >"$W/ctx_decl.sh"
source "$W/ctx_decl.sh"
eval "$cls_src"
build TCbX
TCbX.new cbx

kt_test_start "C1 ${#CTX[@]} quoting contexts of a CR escape (patterns, \${x:-…}, here-string, \$( ), backquotes, arrays, mixed in one body): a Pascal method prints what the plain function prints"
bad=""
for c in "${CTX[@]}"; do
    "ref_$c" >"$W/r_$c" 2>&1; "cbx.$c" >"$W/m_$c" 2>&1
    slurp "$W/r_$c" a; slurp "$W/m_$c" b
    [[ $a == "$b" ]] || bad+=" $c: ref=$(printf %q "$a") method=$(printf %q "$b");"
done
if [[ -z $bad ]]; then kt_test_pass "${#CTX[@]} contexts"; else kt_test_fail "$bad"; fi

kt_test_start "C2 the contexts with a known answer: CR kept in a local, a non-CR string does not match, a CR escape as a \${x:-…} default gives a CR"
slurp "$W/m_c01" a; slurp "$W/m_c02" b; slurp "$W/m_c06" c
same "C2" "$a|$b|$c" "[$CR]|yesno|[$CR][a${CR}b]"

# ---------------------------------------------------------------------------
kt_test_start "D1 declarative API: implement with an escape-text body — all 32 bytes"
declareClass TCbD ""
    procedure All
endClass
implement TCbD.All "CB_OUT=$ESC"
endImplementation TCbD
CB_OUT=""; TCbD.new cbd; cbd.All; same "D1" "$CB_OUT" "$WANT"

kt_test_start "D2 defineClass with an escape-text method body — all 32 bytes"
defineClass TCbE "" method All "CB_OUT=$ESC"
CB_OUT=""; TCbE.new cbe; cbe.All; same "D2" "$CB_OUT" "$WANT"

kt_test_start "D3 kk.register_static_methods (the body is re-parsed from declare -f) — all 32 bytes"
eval "cbreg.All() { CB_OUT=$ESC; }"
kk.register_static_methods TCbR cbreg TCbR All
CB_OUT=""; cbreg.All; a=$CB_OUT
CB_OUT=""; TCbR.All; same "D3" "$a|$CB_OUT" "$WANT|$WANT"

# ---------------------------------------------------------------------------
kt_test_start "K1 compiled cache (kklass_compiler.sh) of a Pascal class: no raw CR in the cache (on a CR-dropping bash), and sourced alone the methods keep all 32 bytes"
{
    printf '%s\n' 'kk.uses kklass_pascal' 'class TCbK' '    public' '        constructor Create' '        proc All' \
                  '        static func SAll' 'end'
    printf '%s\n' "TCbK.All() { CB_OUT=$ESC; }" "TCbK.SAll() { RESULT=$ESC; }" "TCbK.Create() { CB_CTOR=$ESC; }" 'build TCbK'
} >"$W/k1.kk"
( cd "$W" && "$BASH" "$KKLASS_DIR/kklass_compiler.sh" k1.kk k1.ckk.sh >"$W/k1.out" 2>"$W/k1.err" ); krc=$?
ncr=$(tr -cd '\r' <"$W/k1.ckk.sh" 2>/dev/null | wc -c); ncr=${ncr//[!0-9]/}
"$BASH" -c '
source "$1/kklass.sh" || exit 1
source "$2/k1.ckk.sh" || exit 1
CB_OUT="" CB_CTOR=""; TCbK.new o; o.All; printf "%s" "$CB_OUT" >"$2/k1.all"; printf "%s" "$CB_CTOR" >"$2/k1.ctor"
RESULT=""; TCbK.SAll >/dev/null; printf "%s" "$RESULT" >"$2/k1.sall"
' _ "$KKLASS_DIR" "$W" 2>"$W/k1.err2"
slurp "$W/k1.all" a; slurp "$W/k1.ctor" b; slurp "$W/k1.sall" c
(( DROPS_CR )) || ncr=0                    # a CR-keeping bash sources a raw CR as it is
if (( krc == 0 )) && [[ $ncr == 0 && $a == "$WANT" && $b == "$WANT" && $c == "$WANT" ]]; then
    kt_test_pass "compiled"
else
    kt_test_fail "rc=$krc rawCR=$ncr all=$(printf %q "$a") ctor=$(printf %q "$b") sall=$(printf %q "$c") err=$(<"$W/k1.err") err2=$(<"$W/k1.err2")"
fi

kt_test_start "K2 .kkp translation: a method body with escapes keeps all 32 bytes"
{
    printf '%s\n' 'interface' '' 'type' '  TCbKp = class' '  public' '    procedure All;' '  end;' '' 'implementation' '' \
                  'procedure TCbKp.All;' 'begin'
    printf '%s\n' "CB_OUT=$ESC"
    printf '%s\n' 'end;' '' 'end.'
} >"$W/k2.kkp"
"$BASH" "$KKLASS_DIR/kklass_kkp.sh" "$W/k2.kkp" "$W/k2.sh" >"$W/k2.out" 2>&1; k2rc=$?
"$BASH" -c '
source "$1/kklass.sh" || exit 1
source "$2/k2.sh" || exit 1
CB_OUT=""; TCbKp.new o; o.All; printf "%s" "$CB_OUT" >"$2/k2.all"
' _ "$KKLASS_DIR" "$W" 2>"$W/k2.err"
slurp "$W/k2.all" a
if (( k2rc == 0 )) && [[ $a == "$WANT" ]]; then kt_test_pass "kkp"; else kt_test_fail "rc=$k2rc all=$(printf %q "$a") out=$(<"$W/k2.out") err=$(<"$W/k2.err")"; fi

# ---------------------------------------------------------------------------
kt_test_start "S1 sink mode n: a namespace function with a CR, snapshotted by a refused imposter class and restored at its build, keeps its bytes"
cat >"$W/s1imp.sh" <<'EOF'
class cbns
    public
        proc go
end
cbns.go() { CB_OUT=IMPOSTER; }
build cbns
EOF
"$BASH" -c '
source "$1/kklass_pascal.sh" || exit 1
kk.namespace cbns || exit 1
eval "cbns.go() { CB_OUT=$3; }"
source "$2/s1imp.sh" 2>"$2/s1.imp_err"
CB_OUT=""; cbns.go; printf "%s" "$CB_OUT" >"$2/s1.out"
' _ "$KKLASS_DIR" "$W" "$ESC" 2>"$W/s1.err"
slurp "$W/s1.out" a
if [[ $a == "$WANT" ]] && grep -q "function namespace" "$W/s1.imp_err"; then
    kt_test_pass "restored"
else
    kt_test_fail "out=$(printf %q "$a") imp_err=$(<"$W/s1.imp_err") err=$(<"$W/s1.err")"
fi

# ---------------------------------------------------------------------------
# F: kk._fn_text_cr itself
kt_test_start "F1 kk._fn_text_cr: rc 2 for a bad VAR or its own prefix; rc 0 and the text untouched without a CR"
f1() { local x=$'\t\x01'; echo "$x"; }
kk._fn_text f1 t; t0=$t
r=""; for n in "" 1x a-b __kk_fc_t "é"; do kk._fn_text_cr "$n"; r+=$?; done
kk._fn_text_cr t; r0=$?
same "F1" "$r|$r0|$t" "22222|0|$t0"

kt_test_start "F2 kk._fn_text_cr: a CR the printer does not keep (a comment) — on a CR-dropping bash rc 1 and VAR unchanged; on a CR-keeping bash rc 0 and unchanged"
t="fx () "$'\n'"{ "$'\n'"    : # a${CR}b"$'\n'"}"; t0=$t
kk._fn_text_cr t; r=$?
if (( DROPS_CR )); then same "F2" "$r|$t" "1|$t0"; else same "F2" "$r|$t" "0|$t0"; fi

kt_test_start "F3 kk._fn_text_cr: the rewritten text, eval'd, captured and rewritten again (a compiled cache of a built class), still holds the same bytes; on a CR-keeping bash the text is not touched"
f3() { CB_OUT=$'<\r>'"${y:-$'\r'}"; }
kk._fn_text f3 t; t0=$t; kk._fn_text_cr t
if (( DROPS_CR )); then
    eval "${t/#f3 /f3b }"; kk._fn_text f3b t2; kk._fn_text_cr t2; eval "${t2/#f3b /f3c }"
    y="" CB_OUT=""; f3c; same "F3" "$CB_OUT|$([[ $t != *"$CR"* ]] && echo noraw)" "<$CR>$CR|noraw"
else
    same "F3" "$t" "$t0"
fi

kt_test_start "F4 under set -Eeuo pipefail with an ERR trap: a Pascal build whose body needs both rewrite forms (the CR-by-CR search) fires no ERR, does not abort, and keeps the bytes"
cat >"$W/f4.sh" <<'EOF'
set -Eeuo pipefail
trap 'echo "ERR at $LINENO: $BASH_COMMAND" >&2' ERR
source "$1/kklass_pascal.sh"
class TCbF
    public
        proc Go
end
TCbF.Go() { local a=$'\r' b=''; CB_OUT="<${a}${b:-$'\r'}>"; }
build TCbF
TCbF.new o
CB_OUT=""; o.Go
printf '%s' "$CB_OUT" >"$2/f4.out"
echo done
EOF
o=$("$BASH" "$W/f4.sh" "$KKLASS_DIR" "$W" 2>"$W/f4.err"); r=$?
slurp "$W/f4.out" a
if [[ $r == 0 && $o == done && ! -s "$W/f4.err" && $a == "<$CR$CR>" ]]; then
    kt_test_pass "strict mode"
else
    kt_test_fail "rc=$r out=$o value=$(printf %q "$a") err=$(<"$W/f4.err")"
fi
