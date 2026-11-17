#!/usr/bin/env bash
# FuncAnswer (fv ledger K-2, kklass round 7) — what a `func` answers.
#
# The rule (owner decisions 2026-11-17, option A + S2): a func answers with
# what RESULT holds when its body ends, however it ends (falls off the end,
# `return`, `return 0`, a bare last `inherited …`); its rc is the body's own,
# exactly like a proc's. On rc 0 the answer is RESULT, printed ONCE inside
# `$( )`; on rc != 0 without `kk._return` the caller's RESULT stays and
# nothing is printed; `kk._return V; return N` still gives value + failure.
# `static func` follows the same rule (a static func also prints its answer
# on a direct call, as before).
#
# Before: kk._processMethodBody appended `kk._return "$RESULT"` (the func
# trailer) to every func body and that line ran as the body's last command,
# so an explicit `return 0` skipped it (answer lost), a failing last command
# was masked (rc 0), a body ending with `kk._return V` printed V twice inside
# `$( )`, and a bare last `inherited Valid` passed rc 0 for a refusal. Now
# the stored text keeps that line only as the func MARKER: kk._body_fn cuts it
# off and marks the dispatcher's frame (`__kk_return_set = 2`); the
# dispatcher answers (kk._fret). The cache format went 6 -> 7 (the static
# func dispatchers and their __static_ bodies, dumped verbatim, changed).

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "FuncAnswer" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KBOOL_ROOT="$(cd "$KKLASS_DIR/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"
source "$KKLASS_DIR/kklass_pascal.sh"

TMPD="$(mktemp -d "${TMPDIR:-/tmp}/kk152.XXXXXX")" && TMPD="$(cd "$TMPD" && pwd)"
mkdir -p "$TMPD/home" "$TMPD/etc"
kk152_cleanup() { rm -rf "$TMPD"; }
kt_fixture_cleanup_register kk152_cleanup

check() {   # NAME WANT GOT
    if [[ "$3" == "$2" ]]; then kt_test_pass "$1"; else kt_test_fail "$1: got '${3//$'\n'/|}' want '${2//$'\n'/|}'"; fi
}
# case_run NAME — run $TMPD/NAME.sh in a child bash (cwd $TMPD, no user
# config); OUT, ERR, RC.
case_run() {
    ( cd "$TMPD" && env -u KBOOL_CONFIG -u KBOOL_HOME -u USERPROFILE -u ProgramData -u KKLASS_CKK_DIR \
        HOME="$TMPD/home" __KK_CFG_ETC="$TMPD/etc" \
        KKLASS_DIR="$KKLASS_DIR" TMPD="$TMPD" KBOOL_ROOT="$KBOOL_ROOT" \
        "$BASH" "$TMPD/$1.sh" >"$TMPD/$1.out" 2>"$TMPD/$1.err" ); RC=$?
    OUT="$(<"$TMPD/$1.out")"; ERR="$(<"$TMPD/$1.err")"
}

# ---------------------------------------------------------------------------
class TFaBase
    public
        func Valid
        func Get
        func Fail5
        func L
end
TFaBase.Valid() { [[ ${1-} == ok ]] || return 1; RESULT=base-valid; }
TFaBase.Get()   { RESULT=base; }
TFaBase.Fail5() { kk._return pv; return 5; }
TFaBase.L()     { RESULT=L1; return 0; }
build TFaBase

class TFa : TFaBase
    public
        func  Ret0
        func  RetN
        func  LastFail
        func  Supported
        func  SelfRet
        func  SelfRetRc
        func  EarlyRet0
        func  CondLast
        func  ViaHelper
        func  RetThenSet
        func  LocalResult
        func  NoSet
        func  EnvSeen
        func  Fact
        func  FactSilent
        func  Inner
        func  Outer
        override func Valid
        override func Get
        override func Fail5
        override func L
        proc  PRet
        proc  PLastFail
        proc  UseThis
end
TFa.Ret0()        { RESULT=7; return 0; }
TFa.RetN()        { RESULT=8; return 3; }
TFa.LastFail()    { RESULT=9; false; }
TFa.Supported()   { RESULT=10; }
TFa.SelfRet()     { kk._return 11; }
TFa.SelfRetRc()   { kk._return 12; return 4; }
TFa.EarlyRet0()   { if [[ ${1-} == early ]]; then RESULT=13; return 0; fi; RESULT=late; }
TFa.CondLast()    { [[ -n ${1-} ]] && RESULT=$1; }
TFa.ViaHelper()   { tfa_helper 14; }
TFa.RetThenSet()  { kk._return a; RESULT=b; }
TFa.LocalResult() { local RESULT=inner; }
TFa.NoSet()       { [[ -n ${1-} ]] || return 0; RESULT=$1; }
TFa.EnvSeen()     { RESULT=$(command env | command grep -c '^__kk_'); return 0; }
TFa.Fact()        { if (( $1 <= 1 )); then RESULT=1; return 0; fi; $this.Fact $(( $1 - 1 )); RESULT=$(( $1 * RESULT )); return 0; }
TFa.FactSilent()  { if (( $1 <= 1 )); then RESULT=1; return 0; fi; kk.call_silent "$this" FactSilent $(( $1 - 1 )); RESULT=$(( $1 * RESULT )); return 0; }
TFa.Inner()       { RESULT=in; return 0; }
TFa.Outer()       { local x; x=$($this.Inner); RESULT="out($x)"; return 0; }
TFa.Valid()       { inherited Valid "$@"; }
TFa.Get()         { inherited Get; return 0; }
TFa.Fail5()       { inherited Fail5; }
TFa.L()           { inherited L; RESULT="$RESULT>L2"; return 0; }
TFa.PRet()        { RESULT=p; return 0; }
TFa.PLastFail()   { false; }
TFa.UseThis()     {
    RESULT=keep; $this.Ret0;              FA_A="$?:$RESULT"
    RESULT=keep; $this.LastFail;          FA_B="$?:$RESULT"
    RESULT=keep; $this.call EarlyRet0 early; FA_C="$?:$RESULT"
    RESULT=keep; $this.PRet;              FA_D="$?:$RESULT"
}
tfa_helper() { kk._return "$1"; }   # a plain helper answering for the func (kcl: TQueueStack._count)
build TFa

class TFa3 : TFa
    public
        override func L
end
TFa3.L() { inherited L; RESULT="$RESULT>L3"; }
build TFa3

class TFaOr : TFaBase
    public
        override func Valid
end
TFaOr.Valid() { inherited Valid "$@" || return; RESULT="or+$RESULT"; }
build TFaOr

TFa.new o
TFa3.new o3
TFaOr.new oo

# row METHOD ARGS... -> ROW="rc=.. R=.. cap=[..] crc=.." (direct call with
# RESULT=caller first; its stdout goes to a file: OUTD)
row() {
    local rc r cap crc
    RESULT=caller; "o.$1" "${@:2}" >"$TMPD/row.out"; rc=$?; r=$RESULT
    OUTD=$(<"$TMPD/row.out")
    cap=$("o.$1" "${@:2}"); crc=$?
    ROW="rc=$rc R=$r cap=[$cap] crc=$crc"
}

# ===========================================================================
# §1 the probe table (design §1)
# ===========================================================================
kt_test_start "F1.1 return 0 after RESULT=x answers x (Q2), also inside \$( )"
row Ret0; check "F1.1" "rc=0 R=7 cap=[7] crc=0" "$ROW"
kt_test_start "F1.2 RESULT=x; return N (N != 0): rc N, the caller's RESULT, nothing printed (S2)"
row RetN; check "F1.2" "rc=3 R=caller cap=[] crc=3" "$ROW"
kt_test_start "F1.3 a failing last command fails the func (rc kept), the caller's RESULT (S2)"
row LastFail; check "F1.3" "rc=1 R=caller cap=[] crc=1" "$ROW"
kt_test_start "F1.4 the fall-through form answers as before"
row Supported; check "F1.4" "rc=0 R=10 cap=[10] crc=0" "$ROW"
kt_test_start "F1.5 kk._return V as the last line prints V ONCE inside \$( ) (before: twice)"
row SelfRet; check "F1.5" "rc=0 R=11 cap=[11] crc=0" "$ROW"
kt_test_start "F1.6 kk._return V; return N: value + failure (the kcl idiom, unchanged)"
row SelfRetRc; check "F1.6" "rc=4 R=12 cap=[12] crc=4" "$ROW"
kt_test_start "F1.7 an early return 0 answers; the late path too"
row EarlyRet0 early; a=$ROW; row EarlyRet0; check "F1.7" "rc=0 R=13 cap=[13] crc=0|rc=0 R=late cap=[late] crc=0" "$a|$ROW"
kt_test_start "F1.8 a body ending in 'cond && action' fails when cond is false (Q6, the proc rule); answers when true"
row CondLast; a=$ROW; row CondLast x; check "F1.8" "rc=1 R=caller cap=[] crc=1|rc=0 R=x cap=[x] crc=0" "$a|$ROW"
kt_test_start "F1.9 a bare last 'inherited Valid' passes the parent's refusal and its answer (Q3)"
row Valid bad; a=$ROW; row Valid ok; check "F1.9" "rc=1 R=caller cap=[] crc=1|rc=0 R=base-valid cap=[base-valid] crc=0" "$a|$ROW"
kt_test_start "F1.10 'inherited Get; return 0' answers the parent's value"
row Get; check "F1.10" "rc=0 R=base cap=[base] crc=0" "$ROW"
kt_test_start "F1.11 procs never answer: the caller's RESULT, the body's rc"
row PRet; a=$ROW; row PLastFail; check "F1.11" "rc=0 R=caller cap=[] crc=0|rc=1 R=caller cap=[] crc=1" "$a|$ROW"
kt_test_start "F1.12 a func answering through a helper that calls kk._return prints once (kcl \$(q.Count) printed '33')"
row ViaHelper; check "F1.12" "rc=0 R=14 cap=[14] crc=0" "$ROW"
kt_test_start "F1.13 an explicit kk._return is final: 'kk._return a; RESULT=b' answers a, printed once"
row RetThenSet; check "F1.13" "rc=0 R=a cap=[a] crc=0" "$ROW"
kt_test_start "F1.14 a func that never sets RESULT answers whatever RESULT held (Q5); a body's own 'local RESULT' is not its answer"
row NoSet; a=$ROW; row NoSet v; b=$ROW; row LocalResult
check "F1.14" "rc=0 R=caller cap=[caller] crc=0|rc=0 R=v cap=[v] crc=0|rc=0 R=caller cap=[caller] crc=0" "$a|$b|$ROW"
kt_test_start "F1.15 a direct call at the top level prints nothing (only \$( ) prints)"
o.Ret0 >"$TMPD/d1"; o.SelfRet >"$TMPD/d2"; o.Supported >"$TMPD/d3"
check "F1.15" "||" "$(<"$TMPD/d1")|$(<"$TMPD/d2")|$(<"$TMPD/d3")"

# ===========================================================================
# §2 every dispatcher: .call, $this.M, inherited chains, recursion
# ===========================================================================
kt_test_start "F2.1 .call: the same rule as obj.M"
r=""
RESULT=caller; o.call Ret0; r+="$?:$RESULT "
RESULT=caller; o.call LastFail; r+="$?:$RESULT "
RESULT=caller; o.call Valid bad; r+="$?:$RESULT "
r+="[$(o.call Ret0)][$(o.call SelfRet)][$(o.call LastFail)]"
check "F2.1" "0:7 1:caller 1:caller [7][11][]" "$r"
kt_test_start "F2.2 \$this.M and \$this.call M from a proc body"
FA_A= FA_B= FA_C= FA_D=; RESULT=outer; o.UseThis; r=$RESULT
check "F2.2" "0:7 1:keep 0:13 0:keep outer=outer" "$FA_A $FA_B $FA_C $FA_D outer=$r"
kt_test_start "F2.3 a 3-level inherited chain whose middle level ends with 'return 0' (TFa3 > TFa > TFaBase)"
RESULT=c; o3.L; r="$?:$RESULT"
check "F2.3" "0:L1>L2>L3 [L1>L2>L3]" "$r [$(o3.L)]"
kt_test_start "F2.4 'inherited … || return' keeps working: refusal passed, success continues"
RESULT=caller; oo.Valid bad; r="$?:$RESULT "; RESULT=caller; oo.Valid ok; r+="$?:$RESULT [$(oo.Valid ok)][$(oo.Valid bad)]"
check "F2.4" "1:caller 0:or+base-valid [or+base-valid][]" "$r"
kt_test_start "F2.5 a bare last inherited of a parent answering 'kk._return V; return N': rc N, the caller's RESULT (S2 at the child level)"
RESULT=caller; o.Fail5; r="$?:$RESULT "; RESULT=caller; kk._parent o Fail5; r+="parent=$?:$RESULT"
check "F2.5" "5:caller parent=5:pv" "$r"
kt_test_start "F2.6 recursion: a recursive func answering through 'return 0'; each level answers its own frame"
RESULT=c; o.Fact 5; r="$?:$RESULT"
check "F2.6" "0:120" "$r"
kt_test_start "F2.7 recursion captured: the inner direct calls print too (the documented Silent Calls caveat), kk.call_silent prints once"
check "F2.7" "12624|24" "$(o.Fact 4)|$(o.FactSilent 4)"
kt_test_start "F2.8 a nested \$( ) inside a func body; the outer prints once"
RESULT=c; o.Outer; check "F2.8" "out(in)|[out(in)]" "$RESULT|[$(o.Outer)]"

# ===========================================================================
# §3 kk.call_silent, computed properties
# ===========================================================================
kt_test_start "F3.1 kk.call_silent: no print, the answer in RESULT, the rc kept"
RESULT=caller
r=$(kk.call_silent o Ret0; printf '|%s:%s' "$?" "$RESULT")
r+=$(RESULT=caller; kk.call_silent o LastFail; printf '|%s:%s' "$?" "$RESULT")
r+=$(kk.call_silent o SelfRet; printf '|%s:%s' "$?" "$RESULT")
check "F3.1" "|0:7|1:caller|0:11" "$r"

class TFaProp
    public
        var  V
        func GetV
        func IsBig
        property P read GetV
        property Big read IsBig
end
TFaProp.GetV()  { RESULT="v=$V"; return 0; }
TFaProp.IsBig() { RESULT=big; (( V > 3 )); }
build TFaProp
TFaProp.new op
op.V = 5
kt_test_start "F3.2 a computed property over a func getter ending with 'return 0' answers (direct read: RESULT; \$( ): printed once)"
RESULT=c; op.P; check "F3.2" "v=5|[v=5]" "$RESULT|[$(op.P)]"
kt_test_start "F3.3 a computed property over a predicate func (last command (( … ))) passes its rc"
r=""; op.Big >/dev/null; r+="$?:$RESULT "; op.V = 1; op.Big >/dev/null; r+="$?"
check "F3.3" "0:big 1" "$r"

# ===========================================================================
# §4 shell states: set -e, set -u, set -a, nocasematch, odd IFS
# ===========================================================================
kt_test_start "F4.1 set -e: a func whose last command fails stops the caller; 'cond && x' with cond false too (Q6); '|| return' handled by the caller does not"
r=$( set -e; o.CondLast >/dev/null; echo survived ); a="$?:$r"
r=$( set -e; o.LastFail >/dev/null; echo survived ); a+=" $?:$r"
r=$( set -e; o.Valid bad >/dev/null; echo survived ); a+=" $?:$r"
r=$( set -e; oo.Valid bad >/dev/null || :; o.Ret0 >/dev/null; echo "survived $RESULT" ); a+=" $?:$r"
check "F4.1" "1: 1: 1: 0:survived 7" "$a"
kt_test_start "F4.2 set -u: every shape runs (no unbound variable)"
r=$( set -u
     for m in Ret0 RetN LastFail Supported SelfRet SelfRetRc EarlyRet0 CondLast ViaHelper NoSet; do
         RESULT=c; "o.$m" >/dev/null; printf '%s:%s ' "$?" "$RESULT"
     done; RESULT=c; o.Valid bad >/dev/null; printf '%s:%s' "$?" "$RESULT" ) 2>&1
check "F4.2" "0:7 3:c 1:c 0:10 0:11 4:12 0:late 1:c 0:14 0:c 1:c" "$r"
kt_test_start "F4.3 set -a: a child of the body sees no kklass private variable (the func marker is not exported); the caller's allexport survives"
r=$( set -a; RESULT=c; o.EnvSeen >/dev/null; n=$RESULT; o.Ret0 >/dev/null; echo "$n ${-//[!a]/} $RESULT" )
check "F4.3" "0 a 7" "$r"
# fa_table: one line for the shapes (direct, in this shell state; `|| rc=$?`
# and the captures as printf arguments, so a failing func does not end a
# set -e caller here — F4.1 pins that it does)
fa_table() {
    local m out="" rc cap
    for m in Ret0 LastFail SelfRet CondLast EarlyRet0; do
        RESULT=c; rc=0; "o.$m" >/dev/null || rc=$?; out+="$rc:$RESULT "
    done
    RESULT=c; rc=0; o.Valid bad >/dev/null || rc=$?; out+="$rc:$RESULT "
    printf -v cap '[%s][%s][%s]' "$(o.Ret0)" "$(o.SelfRet)" "$(o.LastFail)"
    printf '%s' "$out$cap"
}
FA_WANT="0:7 1:c 0:11 1:c 0:late 1:c [7][11][]"
kt_test_start "F4.4 nocasematch on: the same answers"
check "F4.4" "$FA_WANT" "$( shopt -s nocasematch; fa_table )"
kt_test_start "F4.5 odd IFS values (after the build): the same answers"
r=""
for ifs in '0123456789 ' '' '-*?[]' '2_c'; do
    r+="$( IFS=$ifs; fa_table )|"
done
check "F4.5" "$FA_WANT|$FA_WANT|$FA_WANT|$FA_WANT|" "$r"
kt_test_start "F4.6 set -eu + nocasematch + odd IFS at once"
check "F4.6" "$FA_WANT" "$( set -eu; shopt -s nocasematch; IFS='0123456789x_'; fa_table )"

# ===========================================================================
# §5 the other ways a func is declared; the marker
# ===========================================================================
defineClass TFaDC "" property a \
    function f 'RESULT=dc; return 0' \
    function g 'RESULT=g; false' \
    method p 'RESULT=pt
kk._return "$RESULT"' \
    method pf 'false
kk._return "$RESULT"'
defineFunction TFaDC early 'if [[ ${1-} == x ]]; then RESULT=early; return 0; fi; RESULT=late'
TFaDC.new odc
kt_test_start "F5.1 defineClass 'function' and defineFunction follow the rule"
r=""
RESULT=c; odc.f; r+="$?:$RESULT "; RESULT=c; odc.g; r+="$?:$RESULT "
RESULT=c; odc.early x; r+="$?:$RESULT "; RESULT=c; odc.early; r+="$?:$RESULT "
r+="[$(odc.f)][$(odc.early x)]"
check "F5.1" "0:dc 1:c 0:early 0:late [dc][early]" "$r"
kt_test_start "F5.2 a body text ending with the literal line 'kk._return \"\$RESULT\"' is a func (the marker): answers on success, fails with the caller's RESULT when the line before fails"
r=""; RESULT=c; odc.p; r+="$?:$RESULT "; RESULT=c; odc.pf; r+="$?:$RESULT [$(odc.p)]"
check "F5.2" "0:pt 1:c [pt]" "$r"
kt_test_start "F5.3 the stored text keeps the marker line; the body function has the frame marker instead of the trailer; a proc has neither"
t=$TFa_method_body_Ret0
n1=$([[ $t == *$'\n''kk._return "$RESULT"' ]] && echo kept || echo gone)
n2=$(declare -f __kkm.TFa.Ret0 | grep -c 'kk._return "$RESULT"')
n3=$(declare -f __kkm.TFa.Ret0 | grep -c '__kk_return_set = 2')
n4=$(declare -f __kkm.TFa.PRet | grep -c '__kk_return_set')
check "F5.3" "kept 0 1 0" "$n1 $n2 $n3 $n4"
kt_test_start "F5.4 the eval fallback (a body that only parses with extglob, built with it off) gets the marker too"
fa_ext=$(shopt -p extglob)
shopt -u extglob
defineClass TFaX "" function m 'case $1 in @(a|b)) RESULT=match; return 0;; esac; RESULT=nomatch'
shopt -s extglob
TFaX.new ox
r=""; RESULT=c; ox.m a; r+="$?:$RESULT "; RESULT=c; ox.m z; r+="$?:$RESULT [$(ox.m b)] "
r+="$(declare -f __kkm.TFaX.m | grep -c '__kk_return_set = 2')$(declare -f __kkm.TFaX.m | grep -c 'eval ')"
eval "$fa_ext"
check "F5.4" "0:match 0:nomatch [match] 11" "$r"

# ===========================================================================
# §6 static func (Q4): thin (no static vars) and capturing (static vars)
# ===========================================================================
class TFaS
    public
        static func  Ret0
        static func  RetN
        static func  LastFail
        static func  Supported
        static func  SelfRet
        static func  SelfRetRc
        static func  CondLast
        static proc  PRet
        static proc  Echo
end
TFaS.Ret0()      { RESULT=7; return 0; }
TFaS.RetN()      { RESULT=8; return 3; }
TFaS.LastFail()  { RESULT=9; false; }
TFaS.Supported() { RESULT=10; }
TFaS.SelfRet()   { kk._return 11; }
TFaS.SelfRetRc() { kk._return 12; return 4; }
TFaS.CondLast()  { [[ -n ${1-} ]] && RESULT=$1; }
TFaS.PRet()      { RESULT=p; return 0; }
TFaS.Echo()      { echo "e:$1"; }
build TFaS

class TFaSV
    public
        static var   N
        static func  Ret0
        static func  RetN
        static func  LastFail
        static func  Supported
        static func  SelfRet
        static func  SelfRetRc
        static func  CondLast
        static func  Talk
        static proc  PRet
end
TFaSV.Ret0()      { N=1; RESULT=7; return 0; }
TFaSV.RetN()      { RESULT=8; return 3; }
TFaSV.LastFail()  { RESULT=9; false; }
TFaSV.Supported() { RESULT=10; }
TFaSV.SelfRet()   { kk._return 11; }
TFaSV.SelfRetRc() { kk._return 12; return 4; }
TFaSV.CondLast()  { [[ -n ${1-} ]] && RESULT=$1; }
TFaSV.Talk()      { printf 'said:'; RESULT=t; return 0; }
TFaSV.PRet()      { RESULT=p; return 0; }
build TFaSV

class TFaSK : TFaS
    public
        static func Own
end
TFaSK.Own() { RESULT=own; return 0; }
build TFaSK

# srow CLASS METHOD ARGS... -> ROW="rc=.. R=.. out=[..] cap=[..] crc=.."
# (a static func prints its answer on a direct call too)
srow() {
    local rc r out cap crc
    RESULT=caller; "$1.$2" "${@:3}" >"$TMPD/srow.out"; rc=$?; r=$RESULT
    out=$(<"$TMPD/srow.out")
    cap=$("$1.$2" "${@:3}"); crc=$?
    ROW="rc=$rc R=$r out=[$out] cap=[$cap] crc=$crc"
}
for fa_sc in TFaS TFaSV; do
    kt_test_start "F6.1 $fa_sc static func: return 0 answers, return N / a failing last command / a false 'cond &&' fail with the caller's RESULT and print nothing"
    srow $fa_sc Ret0; a=$ROW; srow $fa_sc RetN; b=$ROW; srow $fa_sc LastFail; c=$ROW; srow $fa_sc CondLast
    check "F6.1 $fa_sc" "rc=0 R=7 out=[7] cap=[7] crc=0|rc=3 R=caller out=[] cap=[] crc=3|rc=1 R=caller out=[] cap=[] crc=1|rc=1 R=caller out=[] cap=[] crc=1" "$a|$b|$c|$ROW"
    kt_test_start "F6.2 $fa_sc static func: the fall-through form, kk._return last (printed once), kk._return V; return N"
    srow $fa_sc Supported; a=$ROW; srow $fa_sc SelfRet; b=$ROW; srow $fa_sc SelfRetRc
    check "F6.2 $fa_sc" "rc=0 R=10 out=[10] cap=[10] crc=0|rc=0 R=11 out=[11] cap=[11] crc=0|rc=4 R=12 out=[12] cap=[12] crc=4" "$a|$b|$ROW"
    kt_test_start "F6.3 $fa_sc static proc: unchanged (prints nothing, RESULT as the body left it)"
    srow $fa_sc PRet; check "F6.3 $fa_sc" "rc=0 R=p out=[] cap=[] crc=0" "$ROW"
done
kt_test_start "F6.4 a capturing static func: its own output first, then the answer; the static var mutation persists"
TFaSV.N = 0; srow TFaSV Talk; a=$ROW; TFaSV.Ret0 >/dev/null
check "F6.4" "rc=0 R=t out=[said:t] cap=[said:t] crc=0|N=1" "$a|N=$(TFaSV.N)"
kt_test_start "F6.5 an inherited static func (the child's own dispatcher) and the child's own; a static proc still passes stdout"
srow TFaSK Ret0; a=$ROW; srow TFaSK LastFail; b=$ROW; srow TFaSK Own
check "F6.5" "rc=0 R=7 out=[7] cap=[7] crc=0|rc=1 R=caller out=[] cap=[] crc=1|rc=0 R=own out=[own] cap=[own] crc=0|e:x" "$a|$b|$ROW|$(TFaSK.Echo x)"
kt_test_start "F6.6 the __static_ body of a static func has no trailer; a static func's stored text keeps the marker"
n1=$(declare -f TFaS.__static_Ret0 | grep -c 'kk._return "$RESULT"')
n2=$([[ $TFaS_static_method_body_Ret0 == *$'\n''kk._return "$RESULT"' ]] && echo kept || echo gone)
check "F6.6" "0 kept" "$n1 $n2"
kt_test_start "F6.7 a static func called from an instance body; set -u"
defineClass TFaSU "" method go 'RESULT=k; TFaS.Ret0 >/dev/null; FA_S="$?:$RESULT"; RESULT=k; TFaS.LastFail; FA_S+=" $?:$RESULT"'
TFaSU.new osu
r=$( set -u; FA_S=; osu.go; echo "$FA_S" )
check "F6.7" "0:7 1:k" "$r"

# ===========================================================================
# §7 compiled caches: format 7; a format-6 cache is rebuilt, not misread
# ===========================================================================
cat > "$TMPD/fa.kk" <<'EOF'
kk.uses kklass_pascal
class TFaC
    public
        func Ret0
        func Last
        static func SRet0
        static func SLast
end
TFaC.Ret0()  { RESULT=7; return 0; }
TFaC.Last()  { RESULT=9; false; }
TFaC.SRet0() { RESULT=s7; return 0; }
TFaC.SLast() { RESULT=s9; false; }
build TFaC
EOF
cat > "$TMPD/fa_scn.inc" <<'EOF'
fa_scn() {
    local r="" rc
    TFaC.new c
    RESULT=x; c.Ret0; r+="$?:$RESULT "
    RESULT=x; c.Last; r+="$?:$RESULT "
    RESULT=x; TFaC.SRet0 >/dev/null; r+="$?:$RESULT "
    RESULT=x; TFaC.SLast; r+="$?:$RESULT "
    r+="[$(c.Ret0)][$(TFaC.SRet0)][$(TFaC.SLast)]"
    echo "$r"
}
EOF
FA_SCN="0:7 1:x 0:s7 1:x [7][s7][]"
cat > "$TMPD/C1.sh" <<'EOF'
export KKLASS_CKK_DIR=$TMPD/ckk
source "$KKLASS_DIR/kklass_autoload.sh"
source "$TMPD/fa_scn.inc"
autoloadClasses "$TMPD/fa.kk"; echo "first=$?"
c=$KKLASS_CKK_DIR/fa.ckk.sh
grep '^kk._ckk_format ' "$c"
# the dumped __static_ bodies (declare -f text, the same on every bash) carry
# no kk._return; the loaded stored texts (declare -p, quoted per bash
# version) still end with the marker
sed -n '/^TFaC\.__static_S[A-Za-z0-9]* ()/,/^}/p' "$c" | grep -c 'kk._return' | sed 's/^/static-trailers=/'
m=0; for v in TFaC_method_body_Ret0 TFaC_method_body_Last TFaC_static_method_body_SRet0 TFaC_static_method_body_SLast; do
    [[ ${!v} == *"$__KK_FUNC_MARK" ]] && (( ++m )); done; echo "markers=$m"
fa_scn
EOF
kt_test_start "C1 a compiled cache is format 7; the static func bodies are dumped without the trailer (the stored texts keep the marker); the cached classes answer by the new rule"
case_run C1
check "C1" "first=0|kk._ckk_format 7|static-trailers=0|markers=4|$FA_SCN|rc=0" "${OUT//$'\n'/|}|rc=$RC"

cat > "$TMPD/C2.sh" <<'EOF'
export KKLASS_CKK_DIR=$TMPD/ckk
source "$KKLASS_DIR/kklass_autoload.sh"
source "$TMPD/fa_scn.inc"
c=$KKLASS_CKK_DIR/fa.ckk.sh
sed -e 's/^kk._ckk_format 7$/kk._ckk_format 6/' "$c" > "$c.old"; mv "$c.old" "$c"; touch "$c"
autoloadClasses "$TMPD/fa.kk" 2>"$TMPD/C2.e"; echo "rc=$?"
grep -c 'cache format 6 is not' "$TMPD/C2.e"
grep '^kk._ckk_format ' "$c"
fa_scn
EOF
kt_test_start "C2 a format-6 cache (newer than its source and kklass) is REBUILT by autoloadClasses (one message); the rebuilt one is format 7 and answers by the new rule"
case_run C2
check "C2" "rc=0|1|kk._ckk_format 7|$FA_SCN|rc=0" "${OUT//$'\n'/|}|rc=$RC"

cat > "$TMPD/C3.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh"; kk.uses kklass
c=$TMPD/ckk/fa.ckk.sh
sed -e 's/^kk._ckk_format 7$/kk._ckk_format 6/' "$c" > "$TMPD/old6.ckk.sh"
source "$TMPD/old6.ckk.sh"; echo "rc=$?"
declare -F TFaC.new >/dev/null && echo loaded || echo "not loaded"
EOF
kt_test_start "C3 a format-6 cache sourced DIRECTLY loads no class and says why (format 6 -> 7: the func answer, K-2)"
case_run C3
if [[ "$OUT" == $'rc=1\nnot loaded' && "$ERR" == *"has cache format 6, this kklass reads format 7"*"format 7: "*"recompile"* ]]; then
    kt_test_pass "C3"
else
    kt_test_fail "C3: out='${OUT//$'\n'/|}' err='${ERR//$'\n'/|}'"
fi

o.delete; o3.delete; oo.delete; op.delete; odc.delete; ox.delete; osu.delete
kt_test_log "152_FuncAnswer.sh completed"
