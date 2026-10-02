#!/bin/bash
# IsAbstract (round 2 / R2_P9, finding K4, decision DR3).
# Up to P9 there was no public way to ask "can CLASS.new succeed?": thttpserver
# read the internal flag `${CLASS}_class_abstract` and called the
# underscore-internal `kk._class_derives_from`. The flag is subtle (C10): it is
# 1 for a still-abstract class, 0 for a concrete one AND for a class that is
# declared but not finalized (no CLASS.new yet), and UNSET both for a class
# built directly by kk._build_class_runtime (instantiable) and for a name that
# was never declared. P9 adds two public predicates:
#   kk.isAbstract CLASS        rc 0 abstract · 1 built + concrete · 2 not an
#                              identifier / not a built class
#   kk.derivesFrom CHILD ANC   rc 0 CHILD is ANC or descends from it · 1 not ·
#                              2 either argument not an identifier
# Both silent on every path and fork-free.
#   §A kk.isAbstract states      §B malformed names (no abort, nothing run)
#   §C kk.derivesFrom            §D set -eu, silence, fork-free, no leaks

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "IsAbstract" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"
source "$KKLASS_DIR/kklass_pascal.sh"

TMPD="${TMPDIR:-/tmp}/kk133_$$"
mkdir -p "$TMPD" && TMPD="$(cd "$TMPD" && pwd)"
trap 'cd /; rm -rf "$TMPD"' EXIT
OUTF="$TMPD/out.txt"
ERRF="$TMPD/err.txt"
# The hostile names below spell `$(touch pwn)` — relative, so run from TMPD.
cd "$TMPD" || exit 1

# Run a command in THIS shell; stdout/stderr/rc land in OUT/ERR/RC.
run() {
    "$@" >"$OUTF" 2>"$ERRF"; RC=$?
    OUT="$(<"$OUTF")"; ERR="$(<"$ERRF")"
}
# expect_rc LABEL WANT_RC — stdout and stderr must both be empty.
expect_rc() {
    if [[ "$RC" == "$2" && -z "$OUT" && -z "$ERR" ]]; then
        kt_test_pass "$1"
    else
        kt_test_fail "$1: rc=$RC out='$OUT' err='$ERR' (want rc=$2, silent)"
    fi
}

# --- fixtures ---------------------------------------------------------------
declareClass TIaShape ""
    abstract; func Area
    abstract; procedure Draw
    procedure Kind
endClass
implement TIaShape.Kind 'echo shape'
endImplementation TIaShape

declareClass TIaHalf TIaShape          # implements Area only
    override; func Area
endClass
implement TIaHalf.Area 'RESULT=1'
endImplementation TIaHalf

declareClass TIaFull TIaShape          # implements both
    override; func Area
    override; procedure Draw
endClass
implement TIaFull.Area 'RESULT=2'
implement TIaFull.Draw 'echo draw'
endImplementation TIaFull

declareClass TIaPlain ""
    procedure Go
endClass
implement TIaPlain.Go 'echo go'
endImplementation TIaPlain

defineClass TIaDef "" property x method m 'echo m'
defineClass TIaDefKid TIaDef property y

declareClass TIaPending ""             # declared + endClass, NOT finalized
    procedure Go
endClass

kk._build_class_runtime TIaRaw "" property x method m 'echo raw'   # raw: no flag

class TIaDsl
    public
        abstract func Area
end
build TIaDsl

# ===========================================================================
# §A  kk.isAbstract — the states (C10)
# ===========================================================================
kt_test_start "A1 a class with two unresolved abstract members → rc 0"
run kk.isAbstract TIaShape; expect_rc "abstract" 0

kt_test_start "A2 a subclass implementing only one of them is still abstract → rc 0"
run kk.isAbstract TIaHalf; expect_rc "half" 0

kt_test_start "A3 a subclass implementing both → rc 1"
run kk.isAbstract TIaFull; expect_rc "full" 1

kt_test_start "A4 a declared class with no abstract member → rc 1"
run kk.isAbstract TIaPlain; expect_rc "plain" 1

kt_test_start "A5 defineClass classes (base and child) → rc 1"
run kk.isAbstract TIaDef; a="$RC:$OUT:$ERR"
run kk.isAbstract TIaDefKid
if [[ "$a" == "1::" && "$RC:$OUT:$ERR" == "1::" ]]; then kt_test_pass "both rc 1"; else kt_test_fail "TIaDef '$a' TIaDefKid '$RC:$OUT:$ERR'"; fi

kt_test_start "A6 a Pascal-DSL abstract class (class … abstract func … end; build) → rc 0"
run kk.isAbstract TIaDsl; expect_rc "dsl abstract" 0

kt_test_start "A7 a never-declared name → rc 2 (the flag is unset, as for a raw-built class)"
run kk.isAbstract TIaNeverDeclared; expect_rc "never declared" 2

kt_test_start "A8 declared + endClass but not finalized (flag 0, no .new) → rc 2"
f="TIaPending_class_abstract"
run kk.isAbstract TIaPending
if [[ "${!f-UNSET}" == 0 ]] && ! declare -F TIaPending.new >/dev/null; then expect_rc "pending" 2
else kt_test_fail "fixture drift: flag='${!f-UNSET}' .new=$(declare -F TIaPending.new)"; fi

kt_test_start "A9 declareClass only (still open, in a subshell) → rc 2"
a="$( declareClass TIaOnlyDeclared "" >/dev/null 2>&1; kk.isAbstract TIaOnlyDeclared 2>&1; echo "rc=$?" )"
if [[ "$a" == "rc=2" ]]; then kt_test_pass "rc 2, silent"; else kt_test_fail "got '$a'"; fi

kt_test_start "A10 raw-built via kk._build_class_runtime (flag UNSET, .new works) → rc 1"
f="TIaRaw_class_abstract"
run kk.isAbstract TIaRaw
if [[ "${!f-UNSET}" == UNSET ]] && declare -F TIaRaw.new >/dev/null; then expect_rc "raw" 1
else kt_test_fail "fixture drift: flag='${!f-UNSET}'"; fi

kt_test_start "A11 rc agrees with .new on every built class: rc 0 ⇔ .new refused, rc 1 ⇔ .new works"
bad=""
for c in TIaShape TIaHalf TIaFull TIaPlain TIaDef TIaDefKid TIaDsl TIaRaw; do
    run kk.isAbstract "$c"; r="$RC"
    nrc=0; "$c.new" "ia_probe_$c" 2>/dev/null || nrc=$?
    if (( nrc == 0 )); then "ia_probe_$c.delete"; fi
    case "$r:$nrc" in
        0:0) bad+=" $c(abstract-but-new-ok)" ;;
        1:0) ;;
        0:*) ;;
        *)   bad+=" $c(rc=$r new=$nrc)" ;;
    esac
done
if [[ -z "$bad" ]]; then kt_test_pass "consistent"; else kt_test_fail "$bad"; fi

kt_test_start "A12 the decided rc for a never-declared name and an unfinalized one is the same (2); the flag reads differ"
run kk.isAbstract TIaNeverDeclared; a="$RC"
run kk.isAbstract TIaPending; b="$RC"
if [[ "$a" == 2 && "$b" == 2 && "${TIaNeverDeclared_class_abstract-UNSET}" == UNSET && "${TIaPending_class_abstract-UNSET}" == 0 ]]; then
    kt_test_pass "2 and 2"
else
    kt_test_fail "never=$a pending=$b"
fi

# ===========================================================================
# §B  malformed names: rc 2, silent, the caller's command NOT aborted, nothing run
# ===========================================================================
# An indirect expansion of a non-identifier is fatal for the caller's whole
# top-level command; MARK (set after the call on the SAME line) proves it ran on.
bad=""
for name in "" "a b" "1abc" "a-b" "a.b" "a[0]" 'a[$(touch pwn)]' '$(touch pwn)' 'x;touch pwn' '`touch pwn`' $'a\nb' "é"; do
    MARK=0; run kk.isAbstract "$name"; MARK=1
    [[ "$MARK:$RC:$OUT:$ERR" == "1:2::" ]] || bad+=" [$name]=mark$MARK:rc$RC:'$OUT':'$ERR'"
done
kt_test_start "B1 kk.isAbstract on 12 malformed names (empty, space, digit-first, '-', '.', subscript, \$( ), ';', backticks, newline, non-ASCII) → rc 2, silent, no abort"
if [[ -z "$bad" ]]; then kt_test_pass "all rc 2"; else kt_test_fail "$bad"; fi

kt_test_start "B2 kk.isAbstract with no argument → rc 2 (set -u safe)"
run kk.isAbstract; expect_rc "no arg" 2

bad=""
for name in "" "a b" 'a[$(touch pwn)]' '$(touch pwn)' 'x;touch pwn'; do
    MARK=0; run kk.derivesFrom "$name" TIaShape; MARK=1
    [[ "$MARK:$RC:$OUT:$ERR" == "1:2::" ]] || bad+=" child[$name]=mark$MARK:rc$RC:'$ERR'"
    MARK=0; run kk.derivesFrom TIaFull "$name"; MARK=1
    [[ "$MARK:$RC:$OUT:$ERR" == "1:2::" ]] || bad+=" anc[$name]=mark$MARK:rc$RC:'$ERR'"
    MARK=0; run kk.derivesFrom "$name" "$name"; MARK=1
    [[ "$MARK:$RC:$OUT:$ERR" == "1:2::" ]] || bad+=" both[$name]=mark$MARK:rc$RC:'$ERR'"
done
kt_test_start "B3 kk.derivesFrom with a malformed CHILD, ANCESTOR or both (incl. equal hostile strings, which the internal answered 0) → rc 2, silent, no abort"
if [[ -z "$bad" ]]; then kt_test_pass "all rc 2"; else kt_test_fail "$bad"; fi

kt_test_start "B4 kk.derivesFrom with missing arguments → rc 2"
run kk.derivesFrom; a="$RC:$OUT:$ERR"
run kk.derivesFrom TIaFull
if [[ "$a" == "2::" && "$RC:$OUT:$ERR" == "2::" ]]; then kt_test_pass "rc 2 both"; else kt_test_fail "none='$a' one='$RC:$OUT:$ERR'"; fi

kt_test_start "B5 no hostile name was ever executed (no pwn file)"
if [[ ! -e "$TMPD/pwn" && ! -e "$KKLASS_DIR/pwn" && ! -e "$KKLASS_DIR/tests/pwn" ]]; then kt_test_pass "no pwn"; else kt_test_fail "pwn created"; fi

# ===========================================================================
# §C  kk.derivesFrom — answers
# ===========================================================================
kt_test_start "C1 child → parent, grandchild → grandparent, reflexive → rc 0"
bad=""
for pair in "TIaFull TIaShape" "TIaHalf TIaShape" "TIaDefKid TIaDef" "TIaShape TIaShape" "TIaRaw TIaRaw"; do
    run kk.derivesFrom $pair; [[ "$RC:$OUT:$ERR" == "0::" ]] || bad+=" [$pair]=$RC:'$ERR'"
done
declareClass TIaGrand TIaHalf
endClass
endImplementation TIaGrand
run kk.derivesFrom TIaGrand TIaShape; [[ "$RC:$OUT:$ERR" == "0::" ]] || bad+=" [TIaGrand TIaShape]=$RC:'$ERR'"
if [[ -z "$bad" ]]; then kt_test_pass "all rc 0"; else kt_test_fail "$bad"; fi

kt_test_start "C2 parent → child, siblings, unrelated, never-declared → rc 1"
bad=""
for pair in "TIaShape TIaFull" "TIaHalf TIaFull" "TIaPlain TIaShape" "TIaNeverDeclared TIaShape" "TIaFull TIaNeverDeclared"; do
    run kk.derivesFrom $pair; [[ "$RC:$OUT:$ERR" == "1::" ]] || bad+=" [$pair]=$RC:'$ERR'"
done
if [[ -z "$bad" ]]; then kt_test_pass "all rc 1"; else kt_test_fail "$bad"; fi

kt_test_start "C3 on well-formed names kk.derivesFrom agrees with kk._class_derives_from"
bad=""
for c in TIaShape TIaHalf TIaFull TIaGrand TIaPlain TIaDef TIaDefKid TIaRaw TIaNeverDeclared; do
    for a in TIaShape TIaHalf TIaDef TIaPlain TIaNeverDeclared; do
        r1=0; kk._class_derives_from "$c" "$a" || r1=$?
        r2=0; kk.derivesFrom "$c" "$a" || r2=$?
        [[ "$r1" == "$r2" ]] || bad+=" $c/$a:$r1/$r2"
    done
done
if [[ -z "$bad" ]]; then kt_test_pass "45 pairs equal"; else kt_test_fail "$bad"; fi

# ===========================================================================
# §D  set -eu, silence under debug, fork-free, no leaks
# ===========================================================================
kt_test_start "D1 under set -eu: every answer usable via if / || / !, script runs to the end"
cat > "$TMPD/seteu.sh" <<EOF
set -eu
source '$KKLASS_DIR/kklass.sh'
declareClass TSa ""
    abstract; procedure P
endClass
endImplementation TSa
defineClass TSc "" property v
declareClass TSp ""
endClass
kk._build_class_runtime TSr "" property x
o=""
if kk.isAbstract TSa; then o+="a0 "; fi
if ! kk.isAbstract TSc; then o+="c1 "; fi
r=0; kk.isAbstract TSc || r=\$?; o+="c\$r "
r=0; kk.isAbstract TSp || r=\$?; o+="p\$r "
r=0; kk.isAbstract TSr || r=\$?; o+="r\$r "
r=0; kk.isAbstract TSnever || r=\$?; o+="n\$r "
r=0; kk.isAbstract 'a[\$(touch pwn)]' || r=\$?; o+="h\$r "
r=0; kk.isAbstract || r=\$?; o+="e\$r "
kk.derivesFrom TSc TSc && o+="d0 "
r=0; kk.derivesFrom TSc TSa || r=\$?; o+="d\$r "
r=0; kk.derivesFrom 'a b' TSa || r=\$?; o+="d\$r "
r=0; kk.derivesFrom || r=\$?; o+="d\$r "
printf '%s' "\$o"
EOF
out="$(cd "$TMPD" && "$BASH" "$TMPD/seteu.sh" 2>"$TMPD/seteu.err")"; rc=$?
err="$(<"$TMPD/seteu.err")"
if [[ $rc -eq 0 && "$out" == "a0 c1 c1 p2 r1 n2 h2 e2 d0 d1 d2 d2 " && -z "$err" && ! -e "$TMPD/pwn" ]]; then
    kt_test_pass "clean"
else
    kt_test_fail "rc=$rc out='$out' err='$err'"
fi

kt_test_start "D2 silent under VERBOSE_KKLASS=debug too (no diagnostic on any path)"
bad=""
for args in "TIaShape" "TIaFull" "TIaNeverDeclared" "TIaPending" "a b"; do
    VERBOSE_KKLASS=debug run kk.isAbstract $args
    [[ -z "$OUT$ERR" ]] || bad+=" isAbstract[$args]:'$OUT$ERR'"
done
VERBOSE_KKLASS=debug run kk.derivesFrom "a b" TIaShape; [[ -z "$OUT$ERR" ]] || bad+=" derivesFrom:'$OUT$ERR'"
if [[ -z "$bad" ]]; then kt_test_pass "silent"; else kt_test_fail "$bad"; fi

kt_test_start "D3 fork-free: no subshell/pipe/process substitution in either body; a DEBUG canary sees one BASHPID"
bad=""
for fn in kk.isAbstract kk.derivesFrom kk._class_derives_from; do
    body="$(declare -f "$fn")" || { bad+=" $fn-undefined"; continue; }
    body="${body//'||'/}"     # `||` is a list operator, not a pipe
    case "$body" in *'$('*|*'`'*|*'|'*|*'<('*|*'>('*) bad+=" $fn-forks" ;; esac
done
CANARY="$TMPD/canary.txt"; : > "$CANARY"; MAINPID="$BASHPID"
set -T
trap '[[ $BASHPID == "$MAINPID" ]] || echo "fork $BASHPID" >> "$CANARY"' DEBUG
kk.isAbstract TIaShape; kk.isAbstract TIaFull; kk.isAbstract TIaNeverDeclared; kk.isAbstract 'a b'
kk.derivesFrom TIaGrand TIaShape; kk.derivesFrom TIaPlain TIaShape; kk.derivesFrom 'a b' x
trap - DEBUG
set +T
[[ -s "$CANARY" ]] && bad+=" canary:$(<"$CANARY")"
if [[ -z "$bad" ]]; then kt_test_pass "no fork"; else kt_test_fail "$bad"; fi

kt_test_start "D4 no variable leaks into the caller (BASH_REMATCH aside — see the book)"
unset __kk_v __kk_ia
kk.isAbstract TIaShape; kk.isAbstract TIaFull; kk.derivesFrom TIaFull TIaShape
if [[ -z "${__kk_v+x}${__kk_ia+x}" ]] && ! declare -p __kk_v __kk_ia &>/dev/null; then kt_test_pass "none"; else kt_test_fail "leak"; fi

kt_test_start "D5 a stray variable named like the flag, with no built class behind it → rc 2"
TIaLook_class_abstract=1          # a stray variable, no such class
run kk.isAbstract TIaLook; a="$RC"
unset TIaLook_class_abstract
if [[ "$a" == 2 ]]; then kt_test_pass "stray flag without a built class → rc 2"; else kt_test_fail "rc=$a"; fi

cd / || :
kt_test_log "133_IsAbstract.sh completed"
