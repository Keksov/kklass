#!/bin/bash
# DeclarationHygiene (round 3 / P11, findings M1-M3, decisions DR8 + DR9).
#   M1/DR9  a static member can not take a name kklass generates at class level:
#           new, constructor, __decl_new_impl, __static_*, __decl_* (and, for
#           kk.register_static_methods, its own __impl_* helpers); a static
#           property and a static method of the same name clash (both are
#           Class.NAME); in the Pascal DSL a static named like the class's
#           constructor is refused (Class.<ctor> is the constructor body).
#           Every static entry path refuses — before P11 most of them were
#           silently lost (rc 0) or hijacked .new.
#   M2/DR8  a refused member POISONS the open class (${CLASS}_decl_refused):
#           endClass / Pascal end rc 1 naming class + member and closing the
#           class; endImplementation / build refuse it FIRST; a refused
#           defineClass closes its class; a refused REdefinition keeps the old
#           decl tables and abstract flag; the .kkp compile fails.
#   M3/DR9  ONE fork-free identifier helper (kk._is_ident, no =~; since round 4
#           / P12 in kkore/klib.sh: ASCII ranges + a [![:ascii:]] guard,
#           nocasematch off around the core, no locale switch) behind
#           kk.isAbstract, kk.derivesFrom, kk.decl._validate_ident and .new:
#           exact in every locale × globasciiranges × nocasematch combination,
#           BASH_REMATCH untouched.
#   debug   kklass.sh's VERBOSE_KKLASS=debug notes go to stderr (kk.debug).
#   §A M1 static names   §B M2 poison flag   §C M3 identifier helper   §D debug

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "DeclarationHygiene" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"
source "$KKLASS_DIR/kklass_serializable.sh"

TMPD="${TMPDIR:-/tmp}/kk135_$$"
mkdir -p "$TMPD" && TMPD="$(cd "$TMPD" && pwd)"
KK135_HOME="$PWD"
kk135_cleanup() { cd "$KK135_HOME" 2>/dev/null || cd /; rm -rf "$TMPD"; }
kt_fixture_cleanup_register kk135_cleanup
OUTF="$TMPD/out.txt"
ERRF="$TMPD/err.txt"
cd "$TMPD" || exit 1

# Run a command in THIS shell; stdout/stderr/rc land in OUT/ERR/RC.
run() {
    "$@" >"$OUTF" 2>"$ERRF"; RC=$?
    OUT="$(<"$OUTF")"; ERR="$(<"$ERRF")"
}
built() { declare -p "${1}_class_methods" &>/dev/null; }

STATIC_BAD=(new constructor __decl_new_impl __static_x __decl_x method_body_x)

# One static entry path per function: P_<path> CLASS NAME. Each leaves a
# summary in PS (compared against the refusal shape of its path). The class is
# NEVER built on a refusal; no class may stay open afterwards.
P_dc_sm()  { defineClass "$1" "" static_method "$2" 'echo body'; PS="rc=$?"; }
P_dc_sp()  { defineClass "$1" "" static_property "$2"; PS="rc=$?"; }
P_br_sm()  { kk._build_class_runtime "$1" "" static_method "$2" 'echo body'; PS="rc=$?"; }
P_br_sp()  { kk._build_class_runtime "$1" "" static_property "$2"; PS="rc=$?"; }
P_decl() { # VERB CLASS NAME — declareClass; VERB NAME; endClass; implement; endImplementation
    local v e i
    declareClass "$2" ""
    "$1" "$3"; v=$?
    endClass; e=$?
    implement "$2.$3" 'echo body' 2>/dev/null
    endImplementation "$2"; i=$?
    PS="verb=$v end=$e impl=$i"
}
P_cp() { P_decl classProcedure "$@"; }
P_cf() { P_decl classFunction "$@"; }
P_cv() { P_decl classVar "$@"; }
P_reg() {
    eval "$1.$2() { echo user-$2; }"
    kk.register_static_methods "$1" "$1" "$1" "$2"; PS="rc=$?"
}

# check_path LABEL PATHFN WANT — runs PATHFN over STATIC_BAD
check_path() {
    local label="$1" fn="$2" want="$3" nm c bad="" k=0
    for nm in "${STATIC_BAD[@]}"; do
        k=$((k + 1)); c="TSt_${fn#P_}_$k"
        PS=""; run "$fn" "$c" "$nm"
        [[ "$PS" == "$want" ]] || bad+=" [$nm] $PS (want $want);"
        [[ "$ERR" == *"'$nm'"* ]] || bad+=" [$nm] error does not name it: '${ERR//$'\n'/ | }';"
        ! built "$c" || bad+=" [$nm] class built;"
        [[ -z "$KK_DECL_CURRENT_CLASS" ]] || { bad+=" [$nm] class left open ($KK_DECL_CURRENT_CLASS);"; KK_DECL_CURRENT_CLASS=""; }
    done
    kt_test_start "$label"
    if [[ -z "$bad" ]]; then kt_test_pass "${#STATIC_BAD[@]} names refused"; else kt_test_fail "$bad"; fi
}

# ===========================================================================
# §A  M1 / DR9 — static member names
# ===========================================================================
check_path "A1 defineClass static_method new/constructor/__decl_new_impl/__static_x/__decl_x/method_body_x → rc 1, not built" P_dc_sm "rc=1"
check_path "A2 defineClass static_property <reserved> → rc 1, not built" P_dc_sp "rc=1"
check_path "A3 kk._build_class_runtime static_method <reserved> → rc 1, not built" P_br_sm "rc=1"
check_path "A4 kk._build_class_runtime static_property <reserved> → rc 1, not built" P_br_sp "rc=1"
check_path "A5 classProcedure <reserved> → verb rc 1, endClass rc 1, endImplementation rc 1" P_cp "verb=1 end=1 impl=1"
check_path "A6 classFunction <reserved> → verb rc 1, endClass rc 1, endImplementation rc 1" P_cf "verb=1 end=1 impl=1"
check_path "A7 classVar <reserved> → verb rc 1, endClass rc 1, endImplementation rc 1" P_cv "verb=1 end=1 impl=1"

kt_test_start "A8 kk.register_static_methods <reserved> → rc 1, the user's function untouched, no __impl_ helper created"
bad=""; k=0
for nm in "${STATIC_BAD[@]}" __impl_x; do
    k=$((k + 1)); c="TStReg$k"
    PS=""; run P_reg "$c" "$nm"
    [[ "$PS" == "rc=1" ]] || bad+=" [$nm] $PS;"
    [[ "$ERR" == *"'$nm'"* ]] || bad+=" [$nm] err='${ERR//$'\n'/ | }';"
    ! built "$c" || bad+=" [$nm] built;"
    ! declare -F "$c.__impl_$nm" >/dev/null || bad+=" [$nm] $c.__impl_$nm created;"
    o="$("$c.$nm" 2>&1)"; [[ "$o" == "user-$nm" ]] || bad+=" [$nm] $c.$nm now prints '$o';"
    [[ -z "$KK_DECL_CURRENT_CLASS" ]] || { bad+=" [$nm] open;"; KK_DECL_CURRENT_CLASS=""; }
done
if [[ -z "$bad" ]]; then kt_test_pass "$(( ${#STATIC_BAD[@]} + 1 )) names refused before any side effect"; else kt_test_fail "$bad"; fi

kt_test_start "A9 static property + static method of the same name (both are Class.x) → refused, either order, every path"
bad=""
run defineClass TClA "" static_property x static_method x 'echo m'
[[ $RC -eq 1 && "$ERR" == *"'x'"* ]] && ! built TClA || bad+=" dc prop+meth rc=$RC;"
run defineClass TClB "" static_method x 'echo m' static_property x
[[ $RC -eq 1 && "$ERR" == *"'x'"* ]] && ! built TClB || bad+=" dc meth+prop rc=$RC;"
run kk._build_class_runtime TClC "" static_property x static_method x 'echo m'
[[ $RC -eq 1 && "$ERR" == *"'x'"* ]] && ! built TClC || bad+=" br rc=$RC;"
declareClass TClD ""; classVar x; run classProcedure x; v=$RC; run endClass; e=$RC; run endImplementation TClD
[[ "$v:$e:$RC" == 1:1:1 ]] && ! built TClD || bad+=" classVar+classProcedure verb=$v end=$e impl=$RC;"
declareClass TClE ""; classFunction x; run classVar x; v=$RC; run endClass; e=$RC
implement TClE.x 'RESULT=1' 2>/dev/null; run endImplementation TClE
[[ "$v:$e:$RC" == 1:1:1 ]] && ! built TClE || bad+=" classFunction+classVar verb=$v end=$e impl=$RC;"
[[ -z "$KK_DECL_CURRENT_CLASS" ]] || { bad+=" open=$KK_DECL_CURRENT_CLASS;"; KK_DECL_CURRENT_CLASS=""; }
if [[ -z "$bad" ]]; then kt_test_pass "refused"; else kt_test_fail "$bad"; fi

kt_test_start "A10 the clash is also refused against an INHERITED static (parent property / child method and vice versa)"
bad=""
defineClass TClPa "" static_property x
defineClass TClPb "" static_method x 'echo pm'
run defineClass TClKa TClPa static_method x 'echo km'
[[ $RC -eq 1 && "$ERR" == *"'x'"* ]] && ! built TClKa || bad+=" child-method rc=$RC err='$ERR';"
run defineClass TClKb TClPb static_property x
[[ $RC -eq 1 && "$ERR" == *"'x'"* ]] && ! built TClKb || bad+=" child-property rc=$RC err='$ERR';"
run kk._build_class_runtime TClKc TClPa static_method x 'echo km'
[[ $RC -eq 1 ]] && ! built TClKc || bad+=" build_runtime rc=$RC;"
o="$(TClPa.x = 5; TClPa.x)"; [[ "$o" == 5 ]] || bad+=" parent TClPa.x broken ('$o');"
if [[ -z "$bad" ]]; then kt_test_pass "refused, parent intact"; else kt_test_fail "$bad"; fi

kt_test_start "A11 no over-matching: legitimate static names, an overriding static method and a static method next to a same-named INSTANCE METHOD all build (round 4 DR10: never next to an instance PROPERTY, test 136)"
bad=""
run defineClass TStOk "" static_property newest static_property _static_x static_property decl_x \
    static_method constructors 'echo c' static_method impl_new 'echo i' static_method __impl 'echo u' \
    static_method newx 'echo nx' method y 'echo y' static_method y 'echo sy'
if [[ $RC -ne 0 ]]; then
    bad+=" refused rc=$RC err='$ERR';"
else
    TStOk.newest = 1
    o="$(TStOk.newest)|$(TStOk.constructors)|$(TStOk.impl_new)|$(TStOk.__impl)|$(TStOk.newx)|$(TStOk.y)"
    [[ "$o" == "1|c|i|u|nx|sy" ]] || bad+=" statics='$o';"
    TStOk.new sto; o="$(sto.y)"
    [[ "$o" == "y" ]] || bad+=" instance='$o';"
    sto.delete
fi
defineClass TStOvP "" static_method m 'echo parent'
run defineClass TStOvK TStOvP static_method m 'echo child'
o="$(TStOvK.m)|$(TStOvP.m)"
[[ $RC -eq 0 && "$o" == "child|parent" ]] || bad+=" override rc=$RC '$o';"
if [[ -z "$bad" ]]; then kt_test_pass "all build"; else kt_test_fail "$bad"; fi

kt_test_start "A12 register_static_methods still registers ordinary names"
TStRg.a() { echo "a:$*"; }; TStRg.b() { RESULT=bb; kk._return "$RESULT"; }
run kk.register_static_methods TStRg TStRg TStRg a b
o="$(TStRg.a x y)|$(TStRg.b)"
if [[ $RC -eq 0 && "$o" == "a:x y|bb" ]] && built TStRg; then kt_test_pass "ok"; else kt_test_fail "rc=$RC o='$o' err='$ERR'"; fi

# ===========================================================================
# §B  M2 / DR8 — the poison flag (declarative paths; Pascal below)
# ===========================================================================
kt_test_start "B1 declareClass + refused 'procedure delete' → endClass rc 1 naming class + member, class closed, finalized 0"
declareClass TPo ""
run procedure delete; v=$RC
procedure ok
run endClass
fin="TPo_decl_finalized"
if [[ $v -eq 1 && $RC -eq 1 && "$ERR" == *TPo* && "$ERR" == *delete* && -z "$KK_DECL_CURRENT_CLASS" && "${!fin}" == 0 && "${TPo_decl_refused-}" == delete ]]; then
    kt_test_pass "rc 1: $ERR"
else
    kt_test_fail "verb=$v end=$RC err='$ERR' open='$KK_DECL_CURRENT_CLASS' finalized='${!fin}' flag='${TPo_decl_refused-UNSET}'"
    KK_DECL_CURRENT_CLASS=""
fi

kt_test_start "B2 … endImplementation checks the flag FIRST: rc 1, member named, no 'close with endClass' message, no .new"
implement TPo.ok 'echo ok' 2>/dev/null
run endImplementation TPo
if [[ $RC -eq 1 && "$ERR" == *TPo* && "$ERR" == *delete* && "$ERR" != *"must be closed with endClass"* ]] && ! declare -F TPo.new >/dev/null && ! built TPo; then
    kt_test_pass "refused: $ERR"
else
    kt_test_fail "rc=$RC err='$ERR' new=$(declare -F TPo.new)"
fi

kt_test_start "B3 the next class in the same script builds normally"
declareClass TPoNext ""; procedure fine; endClass
implement TPoNext.fine 'echo fine'
run endImplementation TPoNext
if [[ $RC -eq 0 && -z "$ERR" ]] && o="$(TPoNext.new pn && pn.fine)" && [[ "$o" == fine ]]; then kt_test_pass "built"; else kt_test_fail "rc=$RC err='$ERR'"; fi

kt_test_start "B4 declareClass resets the flag: the same class re-declared without the bad member builds"
declareClass TPo ""; procedure ok; endClass; implement TPo.ok 'echo ok2'
run endImplementation TPo
if [[ $RC -eq 0 && -z "${TPo_decl_refused-}" ]] && o="$(TPo.new po && po.ok)" && [[ "$o" == ok2 ]]; then kt_test_pass "built"; else kt_test_fail "rc=$RC err='$ERR' flag='${TPo_decl_refused-}'"; fi

kt_test_start "B5 every declarative verb poisons the open class (field, property, func, classVar, constructor modifier)"
bad=""
declareClass TPv1 ""; field parent 2>/dev/null; run endClass; [[ $RC -eq 1 && "$ERR" == *parent* ]] || bad+=" field($RC);"
declareClass TPv2 ""; property call 2>/dev/null; run endClass; [[ $RC -eq 1 && "$ERR" == *call* ]] || bad+=" property($RC);"
declareClass TPv3 ""; property p bogus 2>/dev/null; run endClass; [[ $RC -eq 1 && "$ERR" == *p* ]] || bad+=" property-token($RC);"
declareClass TPv4 ""; func this 2>/dev/null; run endClass; [[ $RC -eq 1 && "$ERR" == *this* ]] || bad+=" func($RC);"
declareClass TPv5 ""; classVar 'a b' 2>/dev/null; run endClass; [[ $RC -eq 1 && "$ERR" == *"a b"* ]] || bad+=" classVar($RC);"
declareClass TPv6 ""; virtual; constructor 2>/dev/null; run endClass; [[ $RC -eq 1 ]] || bad+=" constructor-modifier($RC);"
declareClass TPv7 ""; virtual; field f 2>/dev/null; run endClass; [[ $RC -eq 1 && "$ERR" == *f* ]] || bad+=" field-modifier($RC);"
declareClass TPv8 ""; procedure '' 2>/dev/null; run endClass; [[ $RC -eq 1 ]] || bad+=" empty-name($RC);"
[[ -z "$KK_DECL_CURRENT_CLASS" ]] || { bad+=" open=$KK_DECL_CURRENT_CLASS"; KK_DECL_CURRENT_CLASS=""; }
for c in TPv1 TPv2 TPv3 TPv4 TPv5 TPv6 TPv7 TPv8; do f="${c}_decl_refused"; [[ -n "${!f-}" ]] || bad+=" $c-no-flag"; done
if [[ -z "$bad" ]]; then kt_test_pass "8 verbs"; else kt_test_fail "$bad"; fi

kt_test_start "B6 kk.decl._error is stateless; a refusal on a NON-declarative path does not poison the open class"
declareClass TPs ""
kk.decl._error "just a message" 2>/dev/null
run kk._build_class_runtime TPsOther "" method delete 'echo x'; br=$RC
procedure ok; run endClass
if [[ $br -eq 1 && $RC -eq 0 && -z "${TPs_decl_refused-}" ]]; then kt_test_pass "flag empty, endClass rc 0"; else kt_test_fail "build=$br end=$RC flag='${TPs_decl_refused-}'"; KK_DECL_CURRENT_CLASS=""; fi

kt_test_start "B7 a refused defineClass closes its class: no open class, a stray 'field' is refused, the flag is set"
run defineClass TPdc '' method delete 'echo x' method ok 'echo ok'; d=$RC
open="$KK_DECL_CURRENT_CLASS"
run field stray; f=$RC
fl="${TPdc_decl_refused-}"
if [[ $d -eq 1 && -z "$open" && $f -eq 1 && "${TPdc_decl_fields[*]-}" != *stray* && "$fl" == delete ]] && ! built TPdc; then
    kt_test_pass "closed"
else
    kt_test_fail "defineClass=$d open='$open' field=$f fields=(${TPdc_decl_fields[*]-}) flag='$fl'"
    KK_DECL_CURRENT_CLASS=""
fi

kt_test_start "B8 … and so does a defineClass refused by a static or lazy token; endImplementation of it stays refused"
bad=""
run defineClass TPdc2 '' property a static_method new 'echo x'; [[ $RC -eq 1 && -z "$KK_DECL_CURRENT_CLASS" ]] || bad+=" static rc=$RC open=$KK_DECL_CURRENT_CLASS;"
KK_DECL_CURRENT_CLASS=""
run defineClass TPdc3 '' lazy_property delete initX method initX 'echo x'; [[ $RC -eq 1 && -z "$KK_DECL_CURRENT_CLASS" ]] || bad+=" lazy rc=$RC open=$KK_DECL_CURRENT_CLASS;"
KK_DECL_CURRENT_CLASS=""
run endImplementation TPdc2; [[ $RC -eq 1 && "$ERR" == *new* ]] || bad+=" endImplementation rc=$RC err='$ERR';"
! built TPdc2 && ! built TPdc3 || bad+=" built;"
if [[ -z "$bad" ]]; then kt_test_pass "closed, refused"; else kt_test_fail "$bad"; fi

kt_test_start "B9 a refused defineClass REdefinition keeps the old class: runtime, decl tables, flag reads"
defineClass TPr "" property a method m 'echo m1'
TPr.new pr1
run defineClass TPr "" property a method delete 'echo x' method extra 'echo e'; d=$RC
if [[ $d -eq 1 && "${TPr_decl_methods[*]}" == m && "${TPr_decl_properties[*]-}${TPr_decl_fields[*]-}" == *a* && "${TPr_decl_method_kind[m]-}" == procedure && "${TPr_class_abstract-}" == 0 && -z "$KK_DECL_CURRENT_CLASS" ]] \
   && TPr.new pr2 && [[ "$(pr2.m)" == m1 && "$(pr1.m)" == m1 ]]; then
    kt_test_pass "old class intact"
else
    kt_test_fail "rc=$d decl_methods=(${TPr_decl_methods[*]-}) kind='${TPr_decl_method_kind[m]-}' abstract='${TPr_class_abstract-}' open='$KK_DECL_CURRENT_CLASS'"
    KK_DECL_CURRENT_CLASS=""
fi

kt_test_start "B10 a refused REdefinition of an ABSTRACT class keeps it abstract (isAbstract rc 0, .new refused, tables intact)"
declareClass TPab ""; abstract; procedure P; procedure Q; endClass
implement TPab.Q 'echo q'; endImplementation TPab
declareClass TPab ""; abstract; procedure P; procedure Q; procedure parent 2>/dev/null; endClass 2>/dev/null
endImplementation TPab 2>/dev/null
ia=0; kk.isAbstract TPab || ia=$?
nr=0; TPab.new pab 2>/dev/null || nr=$?
if [[ $ia -eq 0 && $nr -eq 1 && "${TPab_decl_methods[*]}" == "P Q" && "${TPab_abstract_methods[*]}" == P && "${TPab_decl_method_abstract[P]-}" == 1 && "${TPab_method_abstract[P]-}" == 1 ]]; then
    kt_test_pass "still abstract"
else
    kt_test_fail "isAbstract=$ia new=$nr decl_methods=(${TPab_decl_methods[*]-}) abstract_methods=(${TPab_abstract_methods[*]-}) flag='${TPab_class_abstract-}'"
fi

kt_test_start "B11 an endClass override refusal (override of a non-virtual) closes the class and is named by endImplementation"
defineClass TPovP "" method m 'echo p'
declareClass TPov TPovP; kk.decl._push_next_modifier override; procedure m
run endClass; e=$RC; open="$KK_DECL_CURRENT_CLASS"
implement TPov.m 'echo c' 2>/dev/null
run endImplementation TPov
if [[ $e -eq 1 && -z "$open" && $RC -eq 1 && "$ERR" == *m* && "$ERR" != *"must be closed with endClass"* ]] && ! built TPov; then
    kt_test_pass "closed + named"
else
    kt_test_fail "endClass=$e open='$open' endImplementation=$RC err='$ERR'"
    KK_DECL_CURRENT_CLASS=""
fi

kt_test_start "B12 .kkp: a refused member (procedure delete;) → compile rc 1, nothing written; a reserved class var/procedure → rc 1"
mk_kkp() { # FILE MEMBER-LINE
    cat > "$1" <<EOF
unit U;

interface

type
  KA = class
  public
    $2
    procedure Ok;
  end;

  KB = class
  public
    procedure Fine;
  end;

implementation

procedure KA.Ok;
begin
echo ok
end;

procedure KB.Fine;
begin
echo fine
end;

end.
EOF
}
bad=""
k=0
for line in "procedure delete;" "class var new: Integer;" "class procedure constructor;" "class function __static_x: Integer;"; do
    k=$((k + 1))
    mk_kkp "$TMPD/u$k.kkp" "$line"
    rm -f "$TMPD/u$k.ckk.sh"
    "$BASH" "$KKLASS_DIR/kklass_compiler.sh" "$TMPD/u$k.kkp" "$TMPD/u$k.ckk.sh" > "$TMPD/c$k.out" 2>&1; rc=$?
    [[ $rc -eq 1 ]] || bad+=" [$line] rc=$rc;"
    [[ ! -e "$TMPD/u$k.ckk.sh" ]] || bad+=" [$line] output written;"
    grep -q "KA" "$TMPD/c$k.out" || bad+=" [$line] class not named;"
done
mk_kkp "$TMPD/ok.kkp" "procedure Extra;"
sed -i 's/^procedure KB.Fine;/procedure KA.Extra;\nbegin\necho extra\nend;\n\nprocedure KB.Fine;/' "$TMPD/ok.kkp"
"$BASH" "$KKLASS_DIR/kklass_compiler.sh" "$TMPD/ok.kkp" "$TMPD/ok.ckk.sh" > "$TMPD/ok.out" 2>&1; rc=$?
[[ $rc -eq 0 && -s "$TMPD/ok.ckk.sh" ]] || bad+=" clean unit rc=$rc;"
if [[ -z "$bad" ]]; then kt_test_pass "4 refused, clean unit compiles"; else kt_test_fail "$bad"; fi

# ===========================================================================
# §A/§B continued — the Pascal DSL (its class/end/func/override/abstract shadow
# the declarative verbs, so it is sourced only now)
# ===========================================================================
source "$KKLASS_DIR/kklass_pascal.sh"

P_pas() { # KIND CLASS NAME — class C; static KIND NAME; end; build
    local v e b
    class "$2"
        static "$1" "$3"; v=$?
    end; e=$?
    [[ "$1" == var ]] || eval "$2.$3() { echo body; }"
    build "$2"; b=$?
    PS="verb=$v end=$e build=$b"
}
P_pp() { P_pas proc "$@"; }
P_pf() { P_pas func "$@"; }
P_pv() { P_pas var "$@"; }
check_path "A13 Pascal static proc <reserved> → verb rc 1, end rc 1, build rc 1" P_pp "verb=1 end=1 build=1"
check_path "A14 Pascal static func <reserved> → verb rc 1, end rc 1, build rc 1" P_pf "verb=1 end=1 build=1"
check_path "A15 Pascal static var <reserved> → verb rc 1, end rc 1, build rc 1" P_pv "verb=1 end=1 build=1"

kt_test_start "A16 Pascal: a static named like the class's constructor is refused (either order, proc or var), the constructor body is never lost"
bad=""
class TPcA
    constructor
    static proc Create
run end; e=$RC
TPcA.Create() { echo ctor-or-static; }
run build TPcA; b=$RC
[[ $e -eq 1 && $b -eq 1 && "$ERR" == *Create* ]] && ! built TPcA || bad+=" ctor+static end=$e build=$b err='$ERR';"
unset -f TPcA.Create
class TPcB
    static proc Make
    constructor Make
run end; e=$RC
[[ $e -eq 1 ]] || bad+=" static+ctor end=$e;"
class TPcC
    static var Create
run end; e=$RC
[[ $e -eq 1 && "$ERR" == *Create* ]] || bad+=" static var Create (default ctor name) end=$e;"
[[ -z "$KK_DECL_CURRENT_CLASS" ]] || { bad+=" open;"; KK_DECL_CURRENT_CLASS=""; }
class TPcOk
    var v
    constructor Init
    static proc Create
end
TPcOk.Init() { v=from-init; }
TPcOk.Create() { echo static-create; }
run build TPcOk
if [[ $RC -eq 0 ]] && TPcOk.new pco && [[ "$(pco.v)|$(TPcOk.Create)" == "from-init|static-create" ]]; then :; else bad+=" ctor Init + static Create rc=$RC err='$ERR';"; fi
if [[ -z "$bad" ]]; then kt_test_pass "refused; distinct names work"; else kt_test_fail "$bad"; fi

kt_test_start "A17 Pascal static var + static func of the same name → refused"
class TPcl
    static var x
run static func x; v=$RC
run end; e=$RC
if [[ $v -eq 1 && $e -eq 1 && "$ERR" == *x* ]]; then kt_test_pass "refused"; else kt_test_fail "verb=$v end=$e err='$ERR'"; KK_DECL_CURRENT_CLASS=""; fi

kt_test_start "B13 Pascal: class … proc this … end → end rc 1; build rc 1 naming it; the next class in the same file builds"
class TPpa
    proc this 2>/dev/null
    proc ok
run end; e=$RC; open="$KK_DECL_CURRENT_CLASS"
TPpa.ok() { echo ok; }
run build TPpa; b=$RC; berr="$ERR"
class TPpb
    proc fine
end
TPpb.fine() { echo fine; }
run build TPpb; nb=$RC
if [[ $e -eq 1 && -z "$open" && $b -eq 1 && "$berr" == *this* ]] && ! built TPpa && [[ $nb -eq 0 ]] && TPpb.new ppb && [[ "$(ppb.fine)" == fine ]]; then
    kt_test_pass "end=1 build=1, next builds"
else
    kt_test_fail "end=$e open='$open' build=$b err='$berr' next=$nb"
    KK_DECL_CURRENT_CLASS=""
fi
unset -f TPpa.ok

kt_test_start "B14 Pascal: a refused REdefinition of an abstract class keeps it abstract"
class TPpab
    abstract proc Area
    proc Name
end
TPpab.Name() { echo n; }
build TPpab
class TPpab
    abstract proc Area
    proc Name
    var call 2>/dev/null
end 2>/dev/null
TPpab.Name() { echo n2; }
build TPpab 2>/dev/null; b=$?
unset -f TPpab.Name
ia=0; kk.isAbstract TPpab || ia=$?
if [[ $b -eq 1 && $ia -eq 0 && "${TPpab_decl_methods[*]}" == "Area Name" && -z "${TPpab_decl_fields[*]-}" ]]; then kt_test_pass "abstract, tables intact"; else kt_test_fail "build=$b isAbstract=$ia methods=(${TPpab_decl_methods[*]-}) fields=(${TPpab_decl_fields[*]-})"; fi

# ===========================================================================
# §C  M3 / DR9 — the identifier helper
# ===========================================================================
defineClass TIdc "" property x
kt_test_start "C1 BASH_REMATCH survives kk.isAbstract, kk.derivesFrom, .new, defineClass and a refused .new"
bad=""
for cmd in "kk.isAbstract TIdc" "kk.derivesFrom TIdc TIdc" "TIdc.new idc1" "defineClass TIdc2 '' property y" "TIdc.new 'a b'" "kk.isAbstract 'a b'"; do
    [[ "keep-me" =~ (keep)-(me) ]]
    eval "$cmd" >/dev/null 2>&1
    [[ "${BASH_REMATCH[*]}" == "keep-me keep me" ]] || bad+=" [$cmd] BASH_REMATCH=(${BASH_REMATCH[*]});"
done
if [[ -z "$bad" ]]; then kt_test_pass "untouched"; else kt_test_fail "$bad"; fi

kt_test_start "C2 ONE shared helper: no =~ left in kk.isAbstract, kk.derivesFrom, kk.decl._validate_ident or a generated .new"
bad=""
for fn in kk.isAbstract kk.derivesFrom kk.decl._validate_ident TIdc.new TIdc.__decl_new_impl; do
    b="$(declare -f "$fn")" || { bad+=" $fn-missing"; continue; }
    [[ "$b" != *"=~"* ]] || bad+=" $fn-regex"
    [[ "$fn" == TIdc.new || "$b" == *kk._is_ident* ]] || bad+=" $fn-no-helper"
done
if [[ -z "$bad" ]]; then kt_test_pass "one helper"; else kt_test_fail "$bad"; fi

# Every locale × globasciiranges × nocasematch combination, in a child shell
# (an indirect expansion of a non-identifier aborts the caller's command, so
# MARK proves the line ran on). Non-identifiers: rc 2 from the predicates,
# rc 1 from defineClass and .new; identifiers accepted everywhere.
cat > "$TMPD/loc.sh" <<'EOF'
source "$1/kklass.sh" >/dev/null 2>&1
defineClass TLp "" property x
loc="$2" asc="$3" ncm="$4"
export LC_ALL="$loc"
[[ $asc == off ]] && shopt -u globasciiranges
[[ $ncm == on ]] && shopt -s nocasematch
out="" ndone=0
# A non-identifier that slips through ABORTS the whole top-level command (this
# for loop): ndone counts the names that completed.
# dotless i, dotted I, fullwidth A, e-acute, sharp s, a+e-acute, KELVIN SIGN, long s
for nm in $'\xc4\xb1' $'\xc4\xb0' $'\xef\xbc\xa1' $'\xc3\xa9' $'\xc3\x9f' $'a\xc3\xa9' $'\xe2\x84\xaa' $'\xc5\xbf' 'a b' '1a'; do
    M=0; { kk.isAbstract "$nm"; r1=$?; M=1; } 2>/dev/null; [[ $M == 1 && $r1 == 2 ]] || out+=" isAbstract[$nm]=M$M:$r1"
    M=0; { kk.derivesFrom "$nm" TLp; r2=$?; M=1; } 2>/dev/null; [[ $M == 1 && $r2 == 2 ]] || out+=" derivesFrom[$nm]=M$M:$r2"
    M=0; { kk.derivesFrom TLp "$nm"; r3=$?; M=1; } 2>/dev/null; [[ $M == 1 && $r3 == 2 ]] || out+=" derivesFrom2[$nm]=M$M:$r3"
    M=0; { TLp.new "$nm"; r4=$?; M=1; } 2>"$5"; [[ $M == 1 && $r4 == 1 ]] && grep -q "Invalid instance name" "$5" && [[ $(wc -l < "$5") -eq 1 ]] || out+=" new[$nm]=M$M:$r4"
    M=0; { defineClass "$nm" ""; r5=$?; M=1; } 2>/dev/null; [[ $M == 1 && $r5 == 1 ]] || out+=" defineClass[$nm]=M$M:$r5"
    KK_DECL_CURRENT_CLASS=""
    ndone=$((ndone + 1))
done
[[ $ndone == 10 ]] || out+=" ABORTED-at-name-$((ndone + 1))"
for nm in A9_z _ Zz q TLp; do
    kk.isAbstract "$nm"; r=$?; [[ $nm == TLp && $r == 1 || $nm != TLp && $r == 2 ]] || out+=" valid-isAbstract[$nm]=$r"
    kk.derivesFrom "$nm" "$nm" || out+=" valid-derivesFrom[$nm]"
done
TLp.new okName_9 || out+=" valid-new"
# C5 (review R1): .new carries an INLINE copy of the rule (explicit-letter glob,
# kk._is_ident only under nocasematch) — same verdict as kk._is_ident on every
# name, hostile and legal, in this combination.
out5="" n5=0
for nm in "" $'\xc4\xb1' $'\xc4\xb0' $'\xef\xbc\xa1' $'\xc3\xa9' $'\xc3\x9f' $'a\xc3\xa9' $'\xe2\x84\xaa' $'\xc5\xbf' \
          'a b' '1a' 'a-b' 'a.b' 'a[0]' '$(touch pwn)' $'a\nb' $'a\n' '[' ']' '^' '\' '*' '?' 'a*' 'i' 'I' 'k' 'K' 's' 'S' \
          A9_z _ Zz q okA_1 _9 Z9 a_ abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ x0123456789; do
    { TLp.new "$nm"; rn=$?; } 2>/dev/null
    kk._is_ident "$nm"; ri=$?
    [[ $rn == "$ri" ]] || out5+=" differ[$nm]=new$rn/ident$ri"
    if (( rn == 0 )); then "$nm.delete"; fi
    n5=$((n5 + 1))
done
[[ $n5 == 41 ]] || out5+=" ABORTED-after-$n5"
[[ "${LC_ALL-}" == "$loc" ]] || out+=" LC_ALL-not-restored(${LC_ALL-})"
if [[ $ncm == on ]]; then shopt -q nocasematch || out+=" nocasematch-lost"; fi
printf '%s#%s|END' "$out" "$out5"
EOF
bad=""; bad5=""
for loc in C C.UTF-8 en_US.UTF-8; do
    for asc in on off; do
        for ncm in off on; do
            o="$("$BASH" "$TMPD/loc.sh" "$KKLASS_DIR" "$loc" "$asc" "$ncm" "$TMPD/loc_err.txt" 2>&1)"
            [[ "$o" == *"|END" && "${o%%#*}" == "" ]] || bad+=" {$loc/$asc/$ncm:${o%%#*}}"
            [[ "${o#*#}" == "|END" ]] || bad5+=" {$loc/$asc/$ncm:${o#*#}}"
        done
    done
done
kt_test_start "C3 12 combos (LC_ALL C/C.UTF-8/en_US.UTF-8 × globasciiranges × nocasematch): ı İ Ａ é ß … → predicates rc 2, defineClass/.new rc 1, never an abort; identifiers accepted; locale + shopt restored"
if [[ -z "$bad" ]]; then kt_test_pass "exact"; else kt_test_fail "$bad"; fi
kt_test_start "C5 the inline .new guard and kk._is_ident give identical verdicts on 41 hostile + legal names in all 12 combos"
if [[ -z "$bad5" ]]; then kt_test_pass "identical"; else kt_test_fail "$bad5"; fi

kt_test_start "C4 the helper is fork-free and leaves the caller's LC_ALL unset when it was unset"
bad=""
b="$(declare -f kk._is_ident)" || bad+=" missing"
case "$b" in *'$('*|*'`'*|*' | '*|*'<('*) bad+=" forks" ;; esac
o="$("$BASH" -c 'source "$1/kklass.sh" >/dev/null 2>&1; unset LC_ALL; kk._is_ident abc; r=$?; printf "%s:%s" "$r" "${LC_ALL-UNSET}"' _ "$KKLASS_DIR")"
[[ "$o" == "0:UNSET" ]] || bad+=" '$o'"
if [[ -z "$bad" ]]; then kt_test_pass "ok"; else kt_test_fail "$bad"; fi

# ===========================================================================
# §E  review remarks R2 (constructor/destructor names) and R3 (static storage
#     names, instance/class method name clash in the decl tables)
# ===========================================================================
kt_test_start "E1 constructor NAME / Pascal destructor NAME / implementConstructor CLASS are validated BEFORE any eval: a \$( ) name runs nothing, the class is refused"
bad=""
rm -f "$TMPD"/pwn_*
declareClass TEc1 ""
run constructor '$(touch pwn_c1)'; v=$RC
run endClass; e=$RC
[[ $v -eq 1 && $e -eq 1 && "$ERR" == *'pwn_c1'* ]] && ! built TEc1 || bad+=" constructor verb=$v end=$e err='$ERR';"
declareClass TEc2 ""; run constructor 'a b'; v=$RC; endClass 2>/dev/null; e=$?
[[ $v -eq 1 && $e -eq 1 ]] || bad+=" constructor-space verb=$v end=$e;"
class TEc3
    run constructor '`touch pwn_c3`'; v=$RC
run end; e=$RC
[[ $v -eq 1 && $e -eq 1 ]] || bad+=" pascal-constructor verb=$v end=$e;"
class TEd1
    run destructor '$(touch pwn_d1)'; v=$RC
run end; e=$RC
[[ $v -eq 1 && $e -eq 1 && "$ERR" == *pwn_d1* ]] || bad+=" pascal-destructor verb=$v end=$e err='$ERR';"
class TEd2
    run destructor delete; v=$RC
run end; e=$RC
[[ $v -eq 1 && $e -eq 1 ]] || bad+=" destructor-reserved verb=$v end=$e;"
run implementConstructor 'x;touch pwn_i1' 'echo body'
[[ $RC -eq 1 ]] || bad+=" implementConstructor rc=$RC;"
ls "$TMPD"/pwn_* >/dev/null 2>&1 && bad+=" PWN: $(cd "$TMPD" && echo pwn_*);"
[[ -z "$KK_DECL_CURRENT_CLASS" ]] || { bad+=" open=$KK_DECL_CURRENT_CLASS;"; KK_DECL_CURRENT_CLASS=""; }
if [[ -z "$bad" ]]; then kt_test_pass "refused, nothing executed"; else kt_test_fail "$bad"; fi

kt_test_start "E2 legitimate constructor/destructor names still work (declarative constructor Create, Pascal constructor Init + destructor Done)"
bad=""
declareClass TEok ""; field v; constructor Create; endClass
implementConstructor TEok 'v=made'
run endImplementation TEok
{ [[ $RC -eq 0 ]] && TEok.new eo && [[ "$(eo.v)" == made ]]; } || bad+=" declarative rc=$RC;"
class TEpk
    var v
    constructor Init
    destructor Done
end
TEpk.Init() { v=init; }
TEpk.Done() { echo done-ran; }
run build TEpk
if [[ $RC -eq 0 ]] && TEpk.new ep && [[ "$(ep.v)" == init && "$(ep.delete)" == done-ran ]]; then :; else bad+=" pascal rc=$RC err='$ERR';"; fi
if [[ -z "$bad" ]]; then kt_test_pass "ok"; else kt_test_fail "$bad"; fi

kt_test_start "E3 .kkp: a constructor name with a command substitution → compile rc 1, nothing executed, nothing written"
cat > "$TMPD/ck.kkp" <<'EOF'
unit U;

interface

type
  KC = class
  public
    constructor `touch pwn_k1`;
  end;

implementation

end.
EOF
rm -f "$TMPD"/pwn_* "$TMPD/ck.ckk.sh"
"$BASH" "$KKLASS_DIR/kklass_compiler.sh" "$TMPD/ck.kkp" "$TMPD/ck.ckk.sh" > "$TMPD/ck.out" 2>&1; rc=$?
if [[ $rc -eq 1 && ! -e "$TMPD/ck.ckk.sh" ]] && ! ls "$TMPD"/pwn_* >/dev/null 2>&1 && ! ls "$KKLASS_DIR"/pwn_* >/dev/null 2>&1; then
    kt_test_pass "refused"
else
    kt_test_fail "rc=$rc out='$(tr '\n' ' ' < "$TMPD/ck.out")' pwn=$(ls "$TMPD"/pwn_* 2>/dev/null)"
fi

kt_test_start "E4 R3 repro: static property method_body_m next to static method m → refused; m and a subclass's inherited m keep working when it is not declared"
bad=""
run defineClass TEs "" static_method m 'echo body-m' static_property method_body_m
[[ $RC -eq 1 && "$ERR" == *method_body_m* ]] && ! built TEs || bad+=" refused? rc=$RC err='$ERR';"
defineClass TEs2 "" static_method m 'echo body-m' static_property p
defineClass TEs2K TEs2
o="$(TEs2.m)|$(TEs2K.m)"; [[ "$o" == "body-m|body-m" ]] || bad+=" inherited='$o';"
if [[ -z "$bad" ]]; then kt_test_pass "ok"; else kt_test_fail "$bad"; fi

kt_test_start "E5 R3: an instance and a class method of the same name in one declarative class (one decl-table entry per name) → refused, either order, Pascal too"
bad=""
declareClass TEm1 ""; procedure y; run classProcedure y; v=$RC; run endClass; e=$RC
[[ $v -eq 1 && $e -eq 1 && "$ERR" == *y* ]] || bad+=" proc+classProc verb=$v end=$e;"
declareClass TEm2 ""; classFunction y; run func y; v=$RC; run endClass; e=$RC
[[ $v -eq 1 && $e -eq 1 ]] || bad+=" classFunc+func verb=$v end=$e;"
class TEm3
    proc y
    run static proc y; v=$RC
run end; e=$RC
[[ $v -eq 1 && $e -eq 1 ]] || bad+=" pascal verb=$v end=$e;"
declareClass TEm4 ""; procedure y; run procedure y; v=$RC; classFunction z; run classFunction z; w=$RC; endClass; e=$?
[[ $v -eq 0 && $w -eq 0 && $e -eq 0 ]] || bad+=" same-kind redeclaration refused ($v $w $e);"
[[ -z "$KK_DECL_CURRENT_CLASS" ]] || { bad+=" open;"; KK_DECL_CURRENT_CLASS=""; }
if [[ -z "$bad" ]]; then kt_test_pass "refused"; else kt_test_fail "$bad"; fi

# ===========================================================================
# §D  debug notes go to stderr
# ===========================================================================
kt_test_start "D1 VERBOSE_KKLASS=debug: addSerializable / defineClass / defineMethod print nothing on stdout, the notes are on stderr"
defineClass TDbg "" property a
VERBOSE_KKLASS=debug addSerializable TDbg ":" string > "$OUTF" 2> "$ERRF"; r1=$?
o1="$(<"$OUTF")"; e1="$(<"$ERRF")"
VERBOSE_KKLASS=debug defineClass TDbg2 "" property a method m 'echo m' > "$OUTF" 2> "$ERRF"; r2=$?
o2="$(<"$OUTF")"; e2="$(<"$ERRF")"
VERBOSE_KKLASS=debug defineMethod TDbg2 n 'echo n' > "$OUTF" 2> "$ERRF"; r3=$?
o3="$(<"$OUTF")"; e3="$(<"$ERRF")"
if [[ $r1$r2$r3 == 000 && -z "$o1$o2$o3" && "$e1" == *"Method 'toString' added to class 'TDbg'"* && "$e2" == *"TDbg2 class created"* && "$e3" == *"Method 'n' added to class 'TDbg2'"* ]]; then
    kt_test_pass "stdout empty"
else
    kt_test_fail "rc=$r1$r2$r3 out1='$o1' out2='$o2' out3='$o3' err1='$e1' err2='$e2' err3='$e3'"
fi

kt_test_start "D2 without debug the notes are silent on both channels"
defineClass TDbg3 "" property a > "$OUTF" 2> "$ERRF"
defineMethod TDbg3 n 'echo n' >> "$OUTF" 2>> "$ERRF"
if [[ ! -s "$OUTF" && ! -s "$ERRF" ]]; then kt_test_pass "silent"; else kt_test_fail "out='$(<"$OUTF")' err='$(<"$ERRF")'"; fi

kt_test_start "D3 KKLASS_EXPORT_FUNCTIONS=1: every module sources without an export error and kk._is_ident reaches a child shell"
o="$(KKLASS_EXPORT_FUNCTIONS=1 "$BASH" -c 'source "$1/kklass_pascal.sh" && source "$1/kklass_serializable.sh" && "$BASH" -c "kk._is_ident ok_1 && ! kk._is_ident \"a b\" && echo child-ok"' _ "$KKLASS_DIR" 2>&1)"
if [[ "$o" == child-ok ]]; then kt_test_pass "clean"; else kt_test_fail "'$o'"; fi

cd / || :
kt_test_log "135_DeclarationHygiene.sh completed"
