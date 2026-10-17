#!/bin/bash
# ScopeIsolation (kklass round 5 / P15; PLAN.md "# Round 5", findings K2, K2+;
# decision DR16a = the owner's choice "A5 full isolation"; critic r5b p1/p2).
# A member body binds its instance's properties as LOCAL namerefs and bash
# scopes locals dynamically, so up to P15 a body called from a body — a static
# method, another class's method, a constructor, a computed getter, an
# inherited body of another class — READ and WROTE every caller name it did not
# bind itself (`SThin.bump 'y=x'` called from a method set the caller's y), and
# a static method saw the caller's this / __inst__ / __class__ / state.
# DR16a: kk._invoke shadows the CALLER's property + static-property names (one
# scope above the callee's own binds); every static dispatcher shadows them
# plus this/__inst__/__class__/state, and a capturing ("fat") one hands its
# own statics to its callees as the names to shadow.
#   §A writes and reads of the caller's properties (every r5b path)
#   §B caller static properties, both ways; a static never sees the caller's
#      this / __inst__ / __class__ / state
#   §C property named `state` (test 066), set -u, RESULT / REPLY channels
#   §D unchanged by design: declare -g, plain shell functions, the caller's
#      own plain locals, same-instance / parent / subclass callees
#   §E .ckk cache format (static dispatchers are dumped): an old-format cache
#      is rebuilt by autoloadClasses, refused when sourced directly
#   §F `unset` in a callee: localvar_unset in the outermost kk._invoke (F3)

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "ScopeIsolation" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KBOOL_ROOT="$(cd "$KKLASS_DIR/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"
source "$KKLASS_DIR/kklass_pascal.sh"

TMPD="$(mktemp -d "${TMPDIR:-/tmp}/kk146.XXXXXX")" && TMPD="$(cd "$TMPD" && pwd)"
mkdir -p "$TMPD/home" "$TMPD/etc"
OUTF="$TMPD/out" ERRF="$TMPD/err"
kk146_cleanup() { rm -rf "$TMPD"; }
kt_fixture_cleanup_register kk146_cleanup

# run CMD... — in THIS shell; stdout/stderr/rc land in OUT/ERR/RC.
run() {
    "$@" >"$OUTF" 2>"$ERRF"; RC=$?
    OUT="$(<"$OUTF")"; ERR="$(<"$ERRF")"
}
# check LABEL WANT GOT
check() {
    if [[ "$3" == "$2" ]]; then kt_test_pass "$1"; else kt_test_fail "$1: got '${3//$'\n'/|}' want '${2//$'\n'/|}'"; fi
}

# ===========================================================================
# §A the caller's properties: WRITE (a.y stays orig) and READ (UNSET)
# ===========================================================================
defineClass I1Thin "" static_method bump 'y=fromStatic' static_method peek 'echo "peek y=${y-UNSET}"'
defineClass I1Fat "" static_property cnt static_method bump 'y=fromFat' static_method peek 'echo "fatpeek y=${y-UNSET}"'
defineClass I1B "" property z method m 'y=fromB' method r 'echo "B y=${y-UNSET}"' method nest 'i1c.m2' method nestr 'i1c.r2'
defineClass I1C "" method m2 'y=fromC' method r2 'echo "C y=${y-UNSET}"'
defineClass I1A "" property y \
    method w1 'I1Thin.bump' method r1 'I1Thin.peek' \
    method w2 'I1Fat.bump' method r2 'I1Fat.peek' \
    method w3 'i1b.m' method r3 'i1b.r' \
    method w4 'i1b.nest' method r4 'i1b.nestr' \
    method w5 'i1b.call m' method r5 'i1b.call r' \
    method w6 'local t=i1b; $t.m' method r6 'local t=i1b; $t.r'
I1A.new i1a; I1B.new i1b; I1C.new i1c

i=0
for path in "thin static" "fat static" "another class's method" "2-level chain b.nest -> c.m2" "b.call m" "\$t.m (t=b)"; do
    i=$((i + 1))
    kt_test_start "A$i WRITE: $path called from a method: a bare y= does not write the caller's property y"
    i1a.y = orig; i1a.w$i >/dev/null 2>&1
    check "A$i write" orig "$(i1a.y)"
done
i=0
for want in "peek y=UNSET" "fatpeek y=UNSET" "B y=UNSET" "C y=UNSET" "B y=UNSET" "B y=UNSET"; do
    i=$((i + 1))
    kt_test_start "A$((i + 6)) READ: ${want%% *} called from a method does not see the caller's property y"
    i1a.y = orig; run i1a.r$i
    check "A$((i + 6)) read" "$want rc=0 err=" "$OUT rc=$RC err=$ERR"
done
kt_test_start "A13 none of A1-A12 created a global y"
check "A13 no global y was created" "unset" "${y-unset}"

# inherited / $this.parent of ANOTHER class's instance, the parent lacking y
defineClass I2P "" method pm 'y=fromParent' method pr 'echo "P y=${y-UNSET}"'
defineClass I2Q I2P method qm 'inherited pm' method qm2 '$this.parent pm' method qr 'inherited pr' method qr2 '$this.parent pr'
defineClass I2A "" property y method g 'i2q.qm' method g2 'i2q.qm2' method h 'i2q.qr' method h2 'i2q.qr2'
I2A.new i2a; I2Q.new i2q
kt_test_start "A14 WRITE: inherited / \$this.parent (parent without y) of another class's instance"
i2a.y = orig; i2a.g; r1="$(i2a.y)"; i2a.y = orig; i2a.g2; r2="$(i2a.y)"
check "A14" "orig orig" "$r1 $r2"
kt_test_start "A15 READ: inherited / \$this.parent (parent without y) of another class's instance"
i2a.y = orig; run i2a.h; o1="$OUT"; run i2a.h2
check "A15" "P y=UNSET|P y=UNSET" "$o1|$OUT"

# a computed getter read DIRECTLY (sets RESULT), under $( ), a lazy init
defineClass I3CP "" property v getV property u getU function getV 'y=fromGetter; RESULT=1' \
    function getU 'RESULT="getter y=${y-UNSET}"' lazy_property lz initLz method initLz 'echo "lazy y=${y-UNSET}"'
defineClass I3A "" property y method g 'i3cp.v >/dev/null' method h 'i3cp.u; echo "$RESULT"' \
    method hc 'local r; r=$(i3cp.u); echo "$r"' method hl 'i3cp.lz'
I3A.new i3a; I3CP.new i3cp
kt_test_start "A16 WRITE: a computed getter read directly from a method"
i3a.y = orig; i3a.g
check "A16" orig "$(i3a.y)"
kt_test_start "A17 READ: a computed getter read directly, under \$( ), a lazy init"
i3a.y = orig; run i3a.h; o1="$OUT"; run i3a.hc; o2="$OUT"; run i3a.hl
check "A17" "getter y=UNSET|getter y=UNSET|lazy y=UNSET" "$o1|$o2|$OUT"

# a CONSTRUCTOR body (B.new inside A's method)
defineClass I4BC "" property z constructor 'y=fromCtor'
defineClass I4BR "" property z constructor 'echo "ctor y=${y-UNSET}"'
defineClass I4A "" property y method g 'I4BC.new i4bc' method h 'I4BR.new i4br'
I4A.new i4a
kt_test_start "A18 WRITE: a constructor body run by B.new inside A's method"
i4a.y = orig; i4a.g
check "A18" orig "$(i4a.y)"
kt_test_start "A19 READ: a constructor body run by B.new inside A's method"
i4a.y = orig; run i4a.h
check "A19" "ctor y=UNSET" "$OUT"

# an instance method called from a static; A -> thin static -> another class
defineClass I5B "" method w 'y=fromB4' method r 'echo "b4 y=${y-UNSET}"'
defineClass I5S "" static_method s 'local y=staticLocal; i5b.w; echo "static y=$y"' static_method t 'local y=staticLocal; i5b.r'
defineClass I5ST "" static_method s 'i5d.m' static_method r 'i5d.r'
defineClass I5D "" property w method m 'y=fromDviaStatic' method r 'echo "d y=${y-UNSET}"'
defineClass I5A "" property y method g 'I5ST.s' method h 'I5ST.r'
I5B.new i5b; I5D.new i5d; I5A.new i5a
kt_test_start "A20 (by design, plain bash) a static's OWN plain local y is seen and written by the instance method it calls — like any caller's plain local (D2)"
run I5S.s; o1="$OUT"; run I5S.t
check "A20" "static y=fromB4|b4 y=staticLocal" "$o1|$OUT"
kt_test_start "A21 A's method -> thin static -> another class's method: y neither written nor read"
i5a.y = orig; i5a.g; r1="$(i5a.y)"; run i5a.h
check "A21" "orig|d y=UNSET" "$r1|$OUT"

# kk.register_static_methods: its public PREFIX.m skips the dispatcher
I6R.bump() { y=fromRegistered; }
I6R.peek() { echo "reg y=${y-UNSET}"; }
kk.register_static_methods I6RC I6R I6R bump peek
defineClass I6A "" property y method g 'I6R.bump' method h 'I6R.peek'
I6A.new i6a
kt_test_start "A22 kk.register_static_methods' public functions called from a method: y neither written nor read"
i6a.y = orig; i6a.g; r1="$(i6a.y)"; run i6a.h
check "A22" "orig|reg y=UNSET" "$r1|$OUT"

# the declarative and the Pascal DSL build their statics through the same
# generator (kk._class_static_api)
declareClass I18DS ""
classVar "Cnt"
classProcedure "Bump"
endClass
implement I18DS.Bump 'y=fromDecl; echo "decl y=${y-UNSET} this=${this-UNSET}"'
endImplementation I18DS
class TI18Ps
    public
        static proc PBump
end
TI18Ps.PBump() { y=fromPascal; echo "pascal y=${y-UNSET} this=${this-UNSET}"; }
build TI18Ps
defineClass I18A "" property y method g 'I18DS.Bump; echo; TI18Ps.PBump'
I18A.new i18a
kt_test_start "A23 declarative (classProcedure, fat) and Pascal (static proc) statics called from a method: y neither written nor read, no this"
i18a.y = orig; run i18a.g
check "A23" "decl y=fromDecl this=UNSET|pascal y=fromPascal this=UNSET|orig" "${OUT//$'\n'/|}|$(i18a.y)"

# case-twin classes (legal since K3) under the CALLER's nocasematch: the skip
# rule of kk._invoke compares table names and must compare them EXACTLY
# (review F1: `[[ != ]]` folds case — I19Up's body skipped the shadow of i19up's)
defineClass I19Up "" property b method w 'echo "Up sees a=${a-UNSET}"; a=UpWroteA'
defineClass i19up "" property a method go 'a=orig; i19U.w; echo "after a=$a"'
I19Up.new i19U; i19up.new i19l
kt_test_start "A24 case-twin classes I19Up / i19up under nocasematch: the I19Up body neither reads nor writes i19up's property a; nocasematch kept"
shopt -s nocasematch
run i19l.go
shopt -q nocasematch && k=kept || k=lost
shopt -u nocasematch
check "A24" "Up sees a=UNSET|after a=orig|orig|kept" "${OUT//$'\n'/|}|$(i19l.a)|$k"

# review round 2 N1 (critic p15 b1.sh): the own-instance skip must not trust the
# user-visible `this` — a plain helper's own `local this=$1`, a loop's
# `local this=$o`, a body's `for this in …` made a call on ANOTHER instance
# look like a call on the own instance (no shadow: B wrote the caller's y).
# kk._invoke compares a frame-private marker (__kk_self) instead.
defineClass I21B "" property z method m 'y=fromB'
i21helper() { local this=$1; $this.m; }
i21loop() { local o; for o in "$@"; do local this=$o; $this.m; done; }
defineClass I21Sx "" static_property k static_method run 'local this=i21b; i21b.m' static_method run2 'local __kk_x; i21a.own'
defineClass I21A "" property y \
    method g1 'i21helper i21b' method g2 'i21loop i21b' method g3 'local -n t=this; i21b.m' \
    method g5 'for this in i21b; do i21b.m; done' method g6 'I21Sx.run' method own 'echo "own sees k=${k-UNSET}"' method g7 'I21Sx.run2'
I21A.new i21a; I21B.new i21b
i=0
for g in g1 g2 g3 g5 g6; do
    i=$((i + 1))
    kt_test_start "G$i N1 '$g' (helper / loop / nameref / for-loop / static with a local this): another instance's method does not write the caller's property"
    i21a.y = orig; i21a.$g >/dev/null 2>&1
    check "G$i" orig "$(i21a.y)"
done
kt_test_start "G6 a fat static calling a method on the instance that called it: the method does not see the static's own static property"
I21Sx.k = statk; run i21a.g7
check "G6" "own sees k=UNSET" "$OUT"

# ===========================================================================
# §B caller STATIC properties; the caller's this / __inst__ / __class__ / state
# ===========================================================================
defineClass I7B "" method w 'echo "B sees sv=${sv-UNSET}"; sv=fromB'
defineClass I7SP "" static_property sv property y method g 'sv=callerStatic; i7b.w'
I7SP.new i7sp; I7B.new i7b
kt_test_start "B1 a callee neither sees nor writes the CALLER's static property"
run i7sp.g
check "B1" "B sees sv=UNSET|callerStatic" "$OUT|$(I7SP.sv)"

defineClass I8D "" property w method m 'echo "D sees cnt=${cnt-UNSET}"; cnt=fromD'
defineClass I8SF "" static_property cnt static_method s 'cnt=5; i8d.m; echo "after cnt=$cnt"'
I8D.new i8d
kt_test_start "B2 an instance method called from a fat static neither sees nor writes the static's own static property"
run I8SF.s
check "B2" "D sees cnt=UNSET|after cnt=5|5" "${OUT//$'\n'/|}|$(I8SF.cnt)"

defineClass I9T "" static_method s 'echo "this=${this-UNSET} inst=${__inst__-UNSET} class=${__class__-UNSET} state=${state[y]-UNSET}"' \
    static_method w 'state[y]=hacked'
defineClass I9F "" static_property k static_method s 'echo "this=${this-UNSET} inst=${__inst__-UNSET} class=${__class__-UNSET} state=${state[y]-UNSET}"'
defineClass I9A "" property y method g 'I9T.s' method gf 'I9F.s' method gw 'I9T.w'
I9A.new i9a
kt_test_start "B3 a thin static called from a method does not see the caller's this / __inst__ / __class__ / state"
i9a.y = vv; run i9a.g
check "B3" "this=UNSET inst=UNSET class=UNSET state=UNSET" "$OUT"
kt_test_start "B4 a fat static called from a method does not see the caller's this / __inst__ / __class__ / state"
i9a.y = vv; run i9a.gf
check "B4" "this=UNSET inst=UNSET class=UNSET state=UNSET" "$OUT"
kt_test_start "B5 state[y]= in a static called from a method does not write the caller's instance"
i9a.y = vv; i9a.gw
check "B5" vv "$(i9a.y)"

# a fat static calling a static of ANOTHER class: its statics are shadowed too
defineClass I10P "" static_method peek 'echo "peek cnt=${cnt-UNSET}"'
defineClass I10F "" static_property cnt static_method s 'cnt=7; I10P.peek'
kt_test_start "B6 a static called from a fat static does not see the fat static's static property"
run I10F.s
check "B6" "peek cnt=UNSET" "$OUT"

# ===========================================================================
# §C property named `state`, set -u, the RESULT / REPLY channels
# ===========================================================================
defineClass I11W "" property state method r 'echo "callee state=${state-UNSET}"'
defineClass I11N "" method r 'echo "plain callee state=${state-UNSET}"'
defineClass I11S "" property state property y \
    method g 'state=mine; y=yy; i11w.r; i11n.r; I9T.s; I1Thin.bump; echo "after state=$state y=$y"'
I11W.new i11w; I11N.new i11n; I11S.new i11s
i11w.state = theirs
kt_test_start "C1 a property named state (test 066): own binding intact, a callee with a property state sees its own, others see nothing"
run i11s.g
check "C1" "callee state=theirs|plain callee state=UNSET|this=UNSET inst=UNSET class=UNSET state=UNSET|after state=mine y=yy|rc=0 err=" "${OUT//$'\n'/|}|rc=$RC err=$ERR"

kt_test_start "C2 set -u: top-level method / thin / fat static, method -> other class / thin / fat static / ctor, fat static -> method: no error, no write"
cat > "$TMPD/c2.sh" <<'EOF'
set -u
i1a.y = orig
i1a.w1; i1a.w2; i1a.w3; i1a.w4; i1a.w5; i1a.w6
i4a.g; i5a.g
I1Thin.bump; I1Fat.bump; i1b.m
I8SF.s >/dev/null; I10F.s >/dev/null
echo "a=$(i1a.y) i4a=$(i4a.y) i5a=$(i5a.y)"
EOF
i4a.y = orig; i5a.y = orig
o="$( (source "$TMPD/c2.sh") 2>"$ERRF" )"; ERR="$(<"$ERRF")"
check "C2" "a=orig i4a=orig i5a=orig|err=" "$o|err=$ERR"

defineClass I12SR "" static_method r 'kk._return "rv"' static_method e 'echo out'
defineClass I12SF "" static_property c static_method r 'echo "o"; kk._return "rv"'
defineClass I12B "" method r 'kk._return "brv"'
defineClass I12A "" property y method g '
    RESULT=x; REPLY=x; I12SR.r >/dev/null; echo "thin RESULT=$RESULT REPLY=$REPLY"
    local v; v=$(I12SR.r); echo "thin cap=$v"
    v=$(I12SR.e); echo "thin out=$v"
    RESULT=x; REPLY=x; I12SF.r >/dev/null; echo "fat RESULT=$RESULT REPLY=$REPLY"
    v=$(I12SF.r); echo "fat cap=$v"
    RESULT=x; i12b.r; echo "method RESULT=$RESULT"
    v=$(i12b.r); echo "method cap=$v"'
I12A.new i12a; I12B.new i12b
kt_test_start "C3 RESULT / REPLY / capture channels of statics and methods called from a method are unchanged"
run i12a.g
check "C3" "thin RESULT=rv REPLY=x|thin cap=rv|thin out=out|fat RESULT=rv REPLY=orv|fat cap=orv|method RESULT=brv|method cap=brv" "${OUT//$'\n'/|}"
kt_test_start "C4 the same channels from the top level are unchanged"
RESULT=x; REPLY=x; I12SR.r >/dev/null; t1="$RESULT $REPLY"
RESULT=x; REPLY=x; I12SF.r >/dev/null; t2="$RESULT $REPLY"
check "C4" "rv x|rv orv|rv" "$t1|$t2|$(I12SR.r)"

# ===========================================================================
# §D unchanged by design (plain bash) — pinned so a change is noticed
# ===========================================================================
defineClass I13B "" method g 'declare -g ig=fromGlobal' method bare 'ig=bare; echo "callee ig=$ig"'
defineClass I13A "" property ig method g 'i13b.g' method bare 'i13b.bare'
I13A.new i13a; I13B.new i13b
kt_test_start "D1 declare -g in a callee writes the GLOBAL (the documented escape); a bare assignment stays callee-local"
unset ig; i13a.ig = orig; i13a.g; g1="${ig-unset}"; g2="$(i13a.ig)"; unset ig
run i13a.bare
check "D1" "fromGlobal|orig|callee ig=bare|unset|orig" "$g1|$g2|$OUT|${ig-unset}|$(i13a.ig)"

i14plain() { y=fromPlainFn; }
defineClass I14B "" method w 'tmp=fromCallee'
defineClass I14A "" property y method g 'i14plain' method l 'local tmp=callerLocal; i14b.w; echo "tmp=$tmp"'
I14A.new i14a; I14B.new i14b
kt_test_start "D2 a PLAIN shell function called from a body still sees/writes the property; a callee still writes the caller's own plain local (bash dynamic scope, documented)"
i14a.y = orig; i14a.g; run i14a.l
check "D2" "fromPlainFn|tmp=fromCallee" "$(i14a.y)|$OUT"

defineClass I15P "" property y method pm 'y=fromP'
defineClass I15Ch I15P property extra method cm 'extra=e; i15p.pm; echo "ch y=$y"' method self '$this.own; echo "self y=$y"' method own 'y=fromSelf'
defineClass I15Ch2 I15P property extra method cm 'echo "ch2 y=$y extra=$extra"'
defineClass I15P3 "" property y method pm 'i15ch2.cm'
I15P.new i15p; I15Ch.new i15ch; I15Ch2.new i15ch2; I15P3.new i15p3
kt_test_start "D3 same instance (\$this.m), parent-class and subclass callees work on their OWN instance"
i15ch.y = orig; i15p.y = porig; run i15ch.cm; o1="$OUT|$(i15p.y)"
i15ch2.y = c2y; i15ch2.extra = ex; i15p3.y = p3y; run i15p3.pm; o2="$OUT"
i15ch.y = orig; run i15ch.self
check "D3" "ch y=orig|fromP|ch2 y=c2y extra=ex|self y=fromSelf" "$o1|$o2|$OUT"

defineClass I16S "" static_property n static_method inc 'n=$((n + 1))' static_method get 'echo "n=$n"'
defineClass I16A "" property y method g 'I16S.inc; I16S.inc; I16S.get'
I16A.new i16a
kt_test_start "D4 a fat static called from a method still reads/writes its OWN static property"
I16S.n = 0; run i16a.g
check "D4" "n=2|2" "$OUT|$(I16S.n)"

defineClass I17P "" property y static_property sp method pm 'y=fromPm; sp=fromPm; echo "pm extra=${extra-UNSET}"' method go 'i17ch.pm'
defineClass I17Ch I17P property extra
I17P.new i17p; I17Ch.new i17ch
kt_test_start "D5 the skip path: a caller of class P calling a P-owned body on an instance of a SUBCLASS writes that instance (its frame rebinds every P name) and sees the subclass's own names"
i17p.y = porig; i17ch.y = chorig; i17ch.extra = ex; run i17p.go
check "D5" "pm extra=ex|porig|fromPm|fromPm" "$OUT|$(i17p.y)|$(i17ch.y)|$(I17P.sp)"

# ===========================================================================
# §E the .ckk cache format (static dispatchers are dumped verbatim)
# ===========================================================================
# case_run NAME — run $TMPD/NAME.sh in a child bash (cwd $TMPD); OUT, ERR, RC.
case_run() {
    ( cd "$TMPD" && env -u KBOOL_CONFIG -u KBOOL_HOME -u USERPROFILE -u ProgramData -u KKLASS_CKK_DIR \
        HOME="$TMPD/home" __KK_CFG_ETC="$TMPD/etc" \
        KKLASS_DIR="$KKLASS_DIR" TMPD="$TMPD" KBOOL_ROOT="$KBOOL_ROOT" \
        "$BASH" "$TMPD/$1.sh" >"$TMPD/$1.out" 2>"$TMPD/$1.err" ); RC=$?
    OUT="$(<"$TMPD/$1.out")"; ERR="$(<"$TMPD/$1.err")"
}

# review F5 (critic p15 a1.sh): the second skip (caller table = the callee
# INSTANCE's class table: an inherited body on the own instance) and every
# other skip / shadow combination — parent body on a subclass instance from a
# parent caller, subclass and grandchild callers of a parent body, re-entrancy,
# recursion through another class, override + inherited from a third class.
# Pinned (child bash): no caller name is written or read; names no frame binds
# go global (plain bash).
cat > "$TMPD/D6.sh" <<'EOF2'
source "$KBOOL_ROOT/kbool.sh"; kk.uses kklass
r() { printf '%s: %s\n' "$1" "$2"; }
defineClass P "" property y static_property sp \
  method pm 'y=pm_y; z=pm_z; ss=pm_ss; extra=pm_extra' \
  method pr 'echo "pr sees y=${y-UNSET} z=${z-UNSET} ss=${ss-UNSET} q=${q-UNSET}"' \
  method callS 'y=caller; s.pm' method callSr 's.pr' \
  method callBack 's.cb' method cbP 'y=fromCbP'
defineClass S P property z static_property ss \
  method callP 'z=callerZ; p.pm' method callPr 'z=callerZ; p.pr' \
  method callS2 'z=callerZ; s2.pm' \
  method cb 'p.cbP; echo "cb after: y=$y z=$z"' \
  method selfInh '$this.pr' method selfInh2 'inherited pr' method pr2 'z=selfZ; $this.selfInh; $this.selfInh2'
defineClass Q S property q method callP 'q=callerQ; p.pm' method callPr 'q=callerQ; p.pr' method callSr 'q=callerQ; s.pr'
P.new p; S.new s; S.new s2; Q.new qq
p.y = py; s.y = sy; s.z = sz; s2.y = s2y; s2.z = s2z; qq.q = qq0
p.callS; r "1 p.callS p.y/s.y/s.z" "$(p.y)/$(s.y)/$(s.z)"
p.callSr
s.z = sz; s.callP; r "2 s.callP s.z/s.y" "$(s.z)/$(s.y)"
s.callPr
s.z = sz; s.callS2; r "3 s.callS2 s.z/s2.z" "$(s.z)/$(s2.z)"
qq.callP; r "4 qq.callP qq.q" "$(qq.q)"
qq.callPr; qq.callSr
p.y = py; s.y = sy; s.z = sz; p.callBack; r "5 reentrant p.y/s.y/s.z" "$(p.y)/$(s.y)/$(s.z)"
s.pr2
defineClass R1 "" property n method down 'local k=$1; n=$k; (( k > 0 )) && r2.down $((k-1)); echo "R1 k=$k n=$n"'
defineClass R2 "" property m method down 'local k=$1; n=bad$k; m=$k; (( k > 0 )) && r1.down $((k-1)); :'
R1.new r1; R2.new r2; r1.down 4
defineClass T P property t method pm 'y=T_pm; t=T_t; inherited pm'
T.new tt; defineClass U "" property y property t method go 'y=U0; t=U0; tt.pm; echo "U after tt.pm: y=$y t=$t"'
U.new u; u.go; r "7 tt y/t" "$(tt.y)/$(tt.t)"
echo "globals: y=${y-unset} z=${z-unset} ss=${ss-unset} extra=${extra-unset} n=${n-unset} t=${t-unset}"
EOF2
kt_test_start "D6 skip and shadow combinations (review F5, critic a1): own-instance inherited bodies see the own instance, no caller name written or read"
case_run D6
want='1 p.callS p.y/s.y/s.z: caller/pm_y/pm_z
pr sees y=pm_y z=pm_z ss=pm_ss q=UNSET
2 s.callP s.z/s.y: callerZ/pm_y
pr sees y=pm_y z=UNSET ss=UNSET q=UNSET
3 s.callS2 s.z/s2.z: callerZ/pm_z
4 qq.callP qq.q: callerQ
pr sees y=pm_y z=UNSET ss=UNSET q=UNSET
pr sees y=pm_y z=callerZ ss=pm_ss q=UNSET
cb after: y=sy z=sz
5 reentrant p.y/s.y/s.z: fromCbP/sy/sz
pr sees y=sy z=selfZ ss=pm_ss q=UNSET
pr sees y=sy z=selfZ ss=pm_ss q=UNSET
R1 k=0 n=0
R1 k=2 n=0
R1 k=4 n=0
U after tt.pm: y=U0 t=U0
7 tt y/t: pm_y/T_t
globals: y=unset z=pm_z ss=pm_ss extra=pm_extra n=unset t=unset'
check "D6" "$want|rc=0 err=" "$OUT|rc=$RC err=$ERR"
cat > "$TMPD/fmt.kk" <<'EOF'
defineClass E1S "" static_method bump 'y=fromCachedStatic'
defineClass E1A "" property y method g 'E1S.bump'
EOF
cat > "$TMPD/E1.sh" <<'EOF'
export KKLASS_CKK_DIR=$TMPD/ckk
source "$KKLASS_DIR/kklass_autoload.sh"
autoloadClasses "$TMPD/fmt.kk" 2>/dev/null; echo "first=$?"
c=$KKLASS_CKK_DIR/fmt.ckk.sh
grep -c '^kk._ckk_format ' "$c"
# an OLD-format cache: no format line (what every cache before P15 is), newer
# than its source and than kklass
grep -v '^kk._ckk_format ' "$c" > "$c.old"; mv "$c.old" "$c"; touch "$c"
autoloadClasses "$TMPD/fmt.kk" 2>"$TMPD/E1.e2"; echo "second=$?"
grep -c 'cache format' "$TMPD/E1.e2"
grep -c '^kk._ckk_format ' "$c"
E1A.new a; a.y = orig; a.g; echo "a.y=$(a.y)"
EOF
kt_test_start "E1 an old-format .ckk cache (newer than source and kklass) is REBUILT by autoloadClasses; the rebuilt one isolates"
case_run E1
check "E1" "first=0|1|second=0|1|1|a.y=orig|rc=0" "${OUT//$'\n'/|}|rc=$RC"

cat > "$TMPD/E2.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh"; kk.uses kklass
c=$TMPD/ckk/fmt.ckk.sh
grep -v '^kk._ckk_format ' "$c" > "$TMPD/old.ckk.sh"
source "$TMPD/old.ckk.sh"; echo "rc=$?"
declare -F E1S.bump >/dev/null && echo loaded || echo "not loaded"
source "$c"; echo "rc=$?"
declare -F E1S.bump >/dev/null && echo loaded || echo "not loaded"
EOF
kt_test_start "E2 an old-format cache sourced DIRECTLY loads no class, says why (one message) and its source returns 1 (review F6); the current format loads"
case_run E2
e1="${ERR//$'\n'/|}"
if [[ "$OUT" == $'rc=1\nnot loaded\nrc=0\nloaded' && "$ERR" == *"old.ckk.sh"*"format"*"recompile"* && "$e1" != *"|"* ]]; then
    kt_test_pass "E2"
else
    kt_test_fail "E2: out='${OUT//$'\n'/|}' err='$e1'"
fi

cat > "$TMPD/E3.sh" <<'EOF'
export KKLASS_CKK_DIR=$TMPD/ckk
source "$KKLASS_DIR/kklass_autoload.sh"
c=$KKLASS_CKK_DIR/fmt.ckk.sh
grep -v '^kk._ckk_format ' "$c" > "$c.old"; mv "$c.old" "$c"; touch "$c"
autoloadClasses "$TMPD/fmt.kk" --no-compile 2>"$TMPD/E3.e"; echo "rc=$?"
grep -c 'runtime mode' "$TMPD/E3.e"
grep -c 'kklass: the compiled cache' "$TMPD/E3.e"
grep -c '^kk._ckk_format ' "$c"
E1A.new a; a.y = orig; a.g; echo "a.y=$(a.y)"
EOF
kt_test_start "E3 autoloadClasses --no-compile with an old-format cache falls back to the runtime mode (review F6): the classes load from the source and isolate; the cache is neither loaded nor rebuilt"
case_run E3
check "E3" "rc=0|1|0|0|a.y=orig|rc=0" "${OUT//$'\n'/|}|rc=$RC"

# ===========================================================================
# §F `unset` in a callee (review F3, owner 2026-10-17: localvar_unset in the
#    outermost kk._invoke). Without it bash's `unset` of a local of a PREVIOUS
#    scope removes the shadow, and the next lookup finds the caller's nameref:
#    unset+assign wrote the caller's property, a double unset destroyed it,
#    unset+read read it, a static's `unset this` revealed the caller instance.
# ===========================================================================
defineClass I20B "" property z \
    method m1 'unset y; y=fromB_afterUnset' \
    method m2 'unset y; unset y; :' \
    method m3 'unset parts; IFS=, read -r parts <<< "x,from_read"' \
    method r 'unset y; echo "B reads y=${y-UNSET} after unset"'
defineClass I20S "" static_method s1 'unset y; y=fromStatic_afterUnset' \
    static_method s2 'unset this; echo "static this=${this-UNSET}"; unset state; echo "static state[y]=${state[y]-UNSET}"; unset __inst__ __class__; echo "inst=${__inst__-UNSET} class=${__class__-UNSET}"'
i20plain() { shopt -q localvar_unset && echo "plain fn: localvar_unset on" || echo "plain fn: off"; }
defineClass I20A "" property y property parts \
    method g1 'i20b.m1' method g2 'i20b.m2' method g3 'i20b.m3' method g4 'i20b.r' method g5 'I20S.s1' method g6 'I20S.s2' \
    method nest 'i20b.r >/dev/null; shopt -q localvar_unset && echo "after a nested call: on" || echo "after a nested call: off"; i20plain' \
    method ret 'return 7' method fail 'false' method mid 'false; echo "after false"'
I20A.new i20a; I20B.new i20b

kt_test_start "F1 unset y; y=… in another class's method called from a method does not write the caller's property"
i20a.y = orig; i20a.g1
check "F1" orig "$(i20a.y)"
kt_test_start "F2 a double unset y in another class's method does not destroy the caller's property"
i20a.y = orig; i20a.g2
check "F2" "orig|set" "$(i20a.y)|$([[ -v i20a_data[y] ]] && echo set || echo gone)"
kt_test_start "F3 unset parts; IFS=, read -r parts (the 'unset then fill' idiom) in another class's method"
i20a.parts = p0; i20a.g3
check "F3" p0 "$(i20a.parts)"
kt_test_start "F4 unset y then a read in another class's method sees nothing"
i20a.y = orig; run i20a.g4
check "F4" "B reads y=UNSET after unset" "$OUT"
kt_test_start "F5 unset y; y=… in a static called from a method does not write the caller's property"
i20a.y = orig; i20a.g5
check "F5" orig "$(i20a.y)"
kt_test_start "F6 unset this / state / __inst__ / __class__ in a static called from a method reveals nothing of the caller"
i20a.y = vv; run i20a.g6
check "F6" "static this=UNSET|static state[y]=UNSET|inst=UNSET class=UNSET" "${OUT//$'\n'/|}"

kt_test_start "F7 localvar_unset is OFF at the top level before and after a method call; ON inside a body after a nested call and in a plain function it calls"
b1=$(shopt -q localvar_unset && echo on || echo off); run i20a.nest
check "F7" "off|after a nested call: on|plain fn: localvar_unset on|off" "$b1|${OUT//$'\n'/|}|$(shopt -q localvar_unset && echo on || echo off)"
kt_test_start "F8 after a body's 'return N': the option is restored, the status is N"
i20a.ret; r=$?
check "F8" "7|off" "$r|$(shopt -q localvar_unset && echo on || echo off)"
kt_test_start "F9 set -e: a failing body called under || is restored with its status; a body stopped by errexit (in a subshell) leaves the caller off"
o="$( set -e; r=0; i20a.fail || r=$?; echo "r=$r $(shopt -q localvar_unset && echo on || echo off)" )"
( set -e; i20a.mid >/dev/null ); r2=$?
check "F9" "r=1 off|1|off" "$o|$r2|$(shopt -q localvar_unset && echo on || echo off)"
kt_test_start "F10 a caller that had localvar_unset ON keeps it on (not restored to off)"
shopt -s localvar_unset; i20a.y = orig; i20a.g1; i20a.ret; s=$(shopt -q localvar_unset && echo on || echo off); shopt -u localvar_unset
check "F10" "orig|on" "$(i20a.y)|$s"
kt_test_start "F11 a static called from the TOP level runs as before (option untouched, off); a method it calls is isolated and restores it"
defineClass I20T "" static_method s 'echo "top static: $(shopt -q localvar_unset && echo on || echo off)"; i20b.r'
run I20T.s
check "F11" "top static: off|B reads y=UNSET after unset|off" "${OUT//$'\n'/|}|$(shopt -q localvar_unset && echo on || echo off)"


cd / || :
kt_test_log "146_ScopeIsolation.sh completed"
