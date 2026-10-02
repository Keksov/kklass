#!/bin/bash
# ThisDispatch (round 2 / R2_P8, finding K1, decision DR1 as amended 2026-10-01).
# Up to P8 kklass rewrote the TEXT `$this.NAME` / `${this}.NAME` of every member
# body (and of the constructor) into `$__inst__.call NAME`, for every method NAME
# of the class. A blind prefix substitution: it hit quoted data
# (`local s="$this.Home"` became `q.call Home`) and longer names (with a method
# `count`, `$this.counter` became `.call counter`; `inherited go` -> `$this.parent
# go` became `.call parent go` once a method `pa` existed). P8 removes it: the
# text stays as written and `$this.NAME` is the instance's own wrapper (kk._exec,
# the defining class baked in at .new) — VIRTUAL AS OF .new.
#   §A quoted text is data            §B no prefix mangling (C8)
#   §C the decided divergences (a)-(d) between the wrapper and `.call`
#   §D regression guards: identical before and after P8

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "ThisDispatch" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"

OUTF="${TMPDIR:-/tmp}/kk132_out_$$.txt"
ERRF="${TMPDIR:-/tmp}/kk132_err_$$.txt"
# Cleanup via the framework (never `trap … EXIT`: it would replace kt_test_init's
# trap, so the fixture teardown would not run).
kk132_cleanup() { rm -f "$OUTF" "$ERRF"; }
kt_fixture_cleanup_register kk132_cleanup

# Run a command in THIS shell; stdout/stderr/rc land in OUT/ERR/RC.
run() {
    "$@" >"$OUTF" 2>"$ERRF"; RC=$?
    OUT="$(<"$OUTF")"; ERR="$(<"$ERRF")"
}
# expect LABEL WANT_OUT WANT_RC [WANT_ERR]  (WANT_ERR omitted = stderr must be empty)
expect() {
    local want_err="${4-}"
    if [[ "$OUT" == "$2" && "$RC" == "$3" && "$ERR" == "$want_err" ]]; then
        kt_test_pass "$1"
    else
        kt_test_fail "$1: out='$OUT' rc=$RC err='$ERR' (want out='$2' rc=$3 err='$want_err')"
    fi
}

# ===========================================================================
# §A  quoted text is data
# ===========================================================================
body_single='printf "%s\n" '\''$this.Home'\'''
defineClass TThQ "" \
    property note \
    method Home 'echo home' \
    method quoted 'local s="$this.Home"; printf "%s\n" "$s"' \
    method braced 'local s="${this}.Home"; printf "%s\n" "$s"' \
    method single "$body_single" \
    method url 'echo "url=$this.Home/x"' \
    method store 'note="$this.Home"'
TThQ.new q

kt_test_start "A1 'local s=\"\$this.Home\"' keeps the text (K1)"
run q.quoted; expect "quoted" "q.Home" 0

kt_test_start "A2 'local s=\"\${this}.Home\"' keeps the text"
run q.braced; expect "braced" "q.Home" 0

kt_test_start "A3 single-quoted '\$this.Home' stays literal"
run q.single; expect "single" '$this.Home' 0

kt_test_start "A4 \$this.Home inside an echo argument"
run q.url; expect "url" "url=q.Home/x" 0

kt_test_start "A5 a handler registered as \"\$this.Home\" is the instance's wrapper and runs"
run q.store
handler="$(q.note)"
if [[ "$handler" == "q.Home" ]]; then
    run "$handler"; expect "handler $handler" "home" 0
else
    kt_test_fail "stored handler is '$handler' (want 'q.Home')"
fi

kt_test_start "A6 the stored method body keeps the \$this.NAME text"
if [[ "$TThQ_method_body_quoted" == *'"$this.Home"'* && "$TThQ_method_body_braced" == *'"${this}.Home"'* \
      && "$TThQ_method_body_quoted" != *'.call'* ]]; then
    kt_test_pass "bodies verbatim"
else
    kt_test_fail "quoted body='$TThQ_method_body_quoted' braced body='$TThQ_method_body_braced'"
fi

kt_test_start "A7 constructor: quoted \$this.Home is data, body stored verbatim"
defineClass TThQC "" property note method Home 'echo home' constructor 'note="$this.Home"'
TThQC.new qc
run qc.note
if [[ "$TThQC_constructor_body" == *'$this.Home'* ]]; then
    expect "constructor note" "qc.Home" 0
else
    kt_test_fail "constructor body rewritten: '$TThQC_constructor_body' (note='$OUT')"
fi
qc.delete
q.delete

# ===========================================================================
# §B  no prefix mangling (C8)
# ===========================================================================
defineClass TThP "" \
    property HomeDir \
    property counter getCounter \
    method Home 'echo home' \
    method count 'echo C' \
    function getCounter 'RESULT=42' \
    method readCounter 'echo "[$($this.counter)]"' \
    method readCounterB 'echo "[$(${this}.counter)]"' \
    method readCounterR '$this.counter; echo "r=$RESULT"' \
    method readHomeDir 'echo "[$($this.HomeDir)]"' \
    method callCount '$this.count; $this.Home'
TThP.new pp
pp.HomeDir = /x

kt_test_start "B1 \$(\$this.counter) with a method 'count' reads the computed property"
run pp.readCounter; expect "readCounter" "[42]" 0

kt_test_start "B2 \$(\${this}.counter) with a method 'count'"
run pp.readCounterB; expect "readCounterB" "[42]" 0

kt_test_start "B3 direct \$this.counter sets RESULT (D1) with a method 'count'"
run pp.readCounterR; expect "readCounterR" "r=42" 0

kt_test_start "B4 \$(\$this.HomeDir) with a method 'Home' reads the property"
run pp.readHomeDir; expect "readHomeDir" "[/x]" 0

kt_test_start "B5 the shorter names themselves still dispatch"
run pp.callCount; expect "callCount" $'C\nhome' 0
pp.delete

kt_test_start "B6 'inherited go' still reaches the parent when the class has a method 'pa'"
defineClass TThIB "" method go 'echo base-go'
defineClass TThIC TThIB method pa 'echo pa' method go 'inherited go; echo child-go'
TThIC.new ic
run ic.go; expect "ic.go" $'base-go\nchild-go' 0
ic.delete

# ===========================================================================
# §C  the decided divergences (DR1 amended): wrapper vs .call
# ===========================================================================
# (a) defineMethod overriding an INHERITED method after .new: the pre-existing
#     instance's wrapper keeps the owner it was built with; .call sees the new
#     body. `$this.greet` is the wrapper -> virtual as of .new.
defineClass TThA "" method greet 'echo A-greet' method run '$this.greet'
defineClass TThAC TThA
TThAC.new a1
defineMethod TThAC greet 'echo AC-greet' 2>"$ERRF"

kt_test_start "C(a)1 pre-existing instance: a1.greet keeps the body of .new time (limitation)"
run a1.greet; expect "a1.greet" "A-greet" 0

kt_test_start "C(a)2 pre-existing instance: a1.call greet sees the override"
run a1.call greet; expect "a1.call greet" "AC-greet" 0

kt_test_start "C(a)3 pre-existing instance: \$this.greet in a body = the wrapper (as of .new)"
run a1.run; expect "a1.run" "A-greet" 0

kt_test_start "C(a)4 pre-existing instance: a1.call run -> its \$this.greet is still the wrapper"
run a1.call run; expect "a1.call run" "A-greet" 0

kt_test_start "C(a)5 an instance made after defineMethod sees the override everywhere"
TThAC.new a2
run a2.greet; o1="$OUT"; run a2.run; o2="$OUT"; run a2.call greet; o3="$OUT"
[[ "$o1|$o2|$o3" == "AC-greet|AC-greet|AC-greet" ]] && kt_test_pass "AC-greet x3" \
    || kt_test_fail "got '$o1|$o2|$o3'"
a1.delete; a2.delete

kt_test_start "C(a)6 replacing the class's OWN method: the pre-existing wrapper sees the new body"
defineClass TThA2 "" method greet 'echo v1' method run '$this.greet'
TThA2.new ab
defineMethod TThA2 greet 'echo v2'
run ab.greet; o1="$OUT"; run ab.run; o2="$OUT"
[[ "$o1|$o2" == "v2|v2" ]] && kt_test_pass "v2 x2" || kt_test_fail "got '$o1|$o2'"
ab.delete

# (b) a method ADDED after .new: no wrapper on the pre-existing instance.
defineClass TThB "" method base 'echo base'
TThB.new b1
defineMethod TThB late 'echo late'
defineMethod TThB useLate '$this.late'

kt_test_start "C(b)1 pre-existing instance has no wrapper for a later method (rc 127)"
run b1.late
if [[ $RC -eq 127 ]] && ! declare -F b1.late >/dev/null; then
    kt_test_pass "b1.late rc 127"
else
    kt_test_fail "b1.late rc=$RC out='$OUT'"
fi

kt_test_start "C(b)2 b1.call late reaches the later method"
run b1.call late; expect "b1.call late" "late" 0

kt_test_start "C(b)3 b1.call useLate: its \$this.late is the (missing) wrapper -> rc 127"
run b1.call useLate
[[ $RC -eq 127 && -z "$OUT" ]] && kt_test_pass "rc 127" || kt_test_fail "rc=$RC out='$OUT'"

kt_test_start "C(b)4 an instance made after defineMethod has both wrappers"
TThB.new b2
run b2.useLate; expect "b2.useLate" "late" 0
b1.delete; b2.delete

# (c) an EMPTY method body: silent rc 0 through every path.
defineClass TThE "" method Empty '' method callEmpty '$this.Empty; echo "rc=$?"'
defineClass TThEC TThE
TThE.new e
TThEC.new ec

kt_test_start "C(c)1 e.Empty (wrapper) is silent rc 0"
run e.Empty; expect "e.Empty" "" 0

kt_test_start "C(c)2 \$this.Empty in a body is silent rc 0"
run e.callEmpty; expect "e.callEmpty" "rc=0" 0

kt_test_start "C(c)3 e.call Empty is silent rc 0"
run e.call Empty; expect "e.call Empty" "" 0

kt_test_start "C(c)4 an inherited empty body via the child's wrapper is silent rc 0"
run ec.Empty; expect "ec.Empty" "" 0

kt_test_start "C(c)5 RESULT survives an empty-body call"
RESULT=keep; e.Empty 2>/dev/null
[[ "$RESULT" == "keep" ]] && kt_test_pass "RESULT kept" || kt_test_fail "RESULT='$RESULT'"
e.delete; ec.delete

kt_test_start "C(c)6 a wrapper whose body variable is UNSET still reports 'not found' (rc 1)"
defineClass TThG "" method Gone 'echo g'
TThG.new g
unset TThG_method_body_Gone
run g.Gone; expect "g.Gone" "" 1 "Error: Method 'Gone' not found in class 'TThG'"
g.delete

# (d) member names that collide with the per-instance built-ins are refused.
for nm in call delete property parent new; do
    kt_test_start "C(d) defineClass method '$nm' is refused"
    run defineClass "TThRM_$nm" "" method "$nm" 'echo user'
    KK_DECL_CURRENT_CLASS=""
    if [[ $RC -ne 0 && "$ERR" == *"'$nm'"* ]] && ! declare -F "TThRM_$nm.new" >/dev/null; then
        kt_test_pass "refused: $ERR"
    else
        kt_test_fail "accepted (rc=$RC err='$ERR')"
    fi

    kt_test_start "C(d) defineClass property '$nm' is refused"
    run defineClass "TThRP_$nm" "" property "$nm"
    KK_DECL_CURRENT_CLASS=""
    if [[ $RC -ne 0 && "$ERR" == *"'$nm'"* ]] && ! declare -F "TThRP_$nm.new" >/dev/null; then
        kt_test_pass "refused: $ERR"
    else
        kt_test_fail "accepted (rc=$RC err='$ERR')"
    fi
done

kt_test_start "C(d) every other entry path refuses a reserved member name"
bad=""
run eval 'declareClass TThRD1 ""; procedure delete'; KK_DECL_CURRENT_CLASS=""
[[ $RC -ne 0 ]] || bad+=" procedure"
run eval 'declareClass TThRD2 ""; func call'; KK_DECL_CURRENT_CLASS=""
[[ $RC -ne 0 ]] || bad+=" func"
run eval 'declareClass TThRD3 ""; field parent'; KK_DECL_CURRENT_CLASS=""
[[ $RC -ne 0 ]] || bad+=" field"
run eval 'declareClass TThRD4 ""; property property'; KK_DECL_CURRENT_CLASS=""
[[ $RC -ne 0 ]] || bad+=" property-verb"
run defineClass TThRD5 "" lazy_property new initNew method initNew 'echo x'; KK_DECL_CURRENT_CLASS=""
[[ $RC -ne 0 ]] || bad+=" lazy_property"
run defineClass TThRD6 "" function call 'RESULT=x'; KK_DECL_CURRENT_CLASS=""
[[ $RC -ne 0 ]] || bad+=" defineClass-function"
run kk._build_class_runtime TThRD7 "" method delete 'echo x'
[[ $RC -ne 0 ]] || bad+=" build-method"
run kk._build_class_runtime TThRD8 "" property parent
[[ $RC -ne 0 ]] || bad+=" build-property"
run kk._build_class_runtime TThRD9 "" lazy_property call initX
[[ $RC -ne 0 ]] || bad+=" build-lazy"
[[ -z "$bad" ]] && kt_test_pass "all refused" || kt_test_fail "accepted by:$bad"

kt_test_start "C(d) defineMethod/defineFunction/defineProcedure refuse a reserved name and leave the class untouched"
defineClass TThRDm "" method keep 'echo keep'
bad=""
run defineMethod TThRDm delete 'echo x';    [[ $RC -ne 0 && "$ERR" == *"'delete'"* ]] || bad+=" defineMethod"
run defineFunction TThRDm call 'RESULT=x';  [[ $RC -ne 0 && "$ERR" == *"'call'"* ]] || bad+=" defineFunction"
run defineProcedure TThRDm parent 'echo x'; [[ $RC -ne 0 && "$ERR" == *"'parent'"* ]] || bad+=" defineProcedure"
run defineMethod TThRDm 'x;y' 'echo x';     [[ $RC -ne 0 ]] || bad+=" defineMethod-nonident"
[[ "${TThRDm_class_methods[*]}" == "keep" ]] || bad+=" methods=(${TThRDm_class_methods[*]})"
[[ -z "$bad" ]] && kt_test_pass "refused, class untouched" || kt_test_fail "$bad"

kt_test_start "C(d) no over-matching: names that merely START with a reserved word work"
run defineClass TThOk "" property callback property parentId property deleted property newest \
    method recall 'echo recall' method delete2 'echo d2' method properties 'echo props' \
    method newer 'echo newer' method parental 'echo par' \
    method go '$this.recall; $this.delete2; $this.properties; $this.newer; $this.parental'
if [[ $RC -ne 0 ]]; then
    kt_test_fail "class refused (rc=$RC err='$ERR')"
else
    TThOk.new ok
    ok.callback = cb; ok.parentId = 7
    run ok.go
    if [[ "$OUT" == $'recall\nd2\nprops\nnewer\npar' && $RC -eq 0 && -z "$ERR" \
          && "$(ok.callback)|$(ok.parentId)" == "cb|7" ]]; then
        kt_test_pass "all five dispatch, properties work"
    else
        kt_test_fail "out='$OUT' rc=$RC err='$ERR'"
    fi
    ok.delete
fi

# ===========================================================================
# §D  regression guards (identical before and after P8)
# ===========================================================================
defineClass TThV "" method Step 'echo base-step' \
    method Run 'echo run:; $this.Step' method RunB 'echo runB:; ${this}.Step'
defineClass TThVC TThV method Step 'echo child-step'
defineClass TThVL TThVC
TThVC.new vc; TThVL.new vl; TThV.new vb

kt_test_start "D1 virtual dispatch from a base body: \$this.Step -> the child's override"
run vc.Run; expect "vc.Run" $'run:\nchild-step' 0

kt_test_start "D2 the same with the \${this}.Step spelling"
run vc.RunB; expect "vc.RunB" $'runB:\nchild-step' 0

kt_test_start "D3 a leaf without its own override gets the nearest one"
run vl.Run; expect "vl.Run" $'run:\nchild-step' 0

kt_test_start "D4 the base instance keeps the base body"
run vb.Run; expect "vb.Run" $'run:\nbase-step' 0
vc.delete; vl.delete; vb.delete

kt_test_start "D5 inherited chain: a leaf without override runs mid's body once, mid's inherited goes to base"
defineClass TThI1 "" method Describe 'echo base' method callDescribe '$this.Describe'
defineClass TThI2 TThI1 method Describe 'echo mid; inherited Describe'
defineClass TThI3 TThI2
TThI3.new i3
run i3.Describe; o1="$OUT"; run i3.callDescribe; o2="$OUT"
[[ "$o1" == $'mid\nbase' && "$o2" == $'mid\nbase' ]] && kt_test_pass "mid, base" \
    || kt_test_fail "Describe='$o1' callDescribe='$o2'"
i3.delete

kt_test_start "D6 frame class: \$this.who from a child body runs in the DEFINING class's frame"
defineClass TThF "" method who 'echo "$__class__"'
defineClass TThFC TThF method ask '$this.who; echo "$__class__"'
TThFC.new fc
run fc.ask; expect "fc.ask" $'TThF\nTThFC' 0
fc.delete

declareClass TThVis ""
    privateSection
        procedure Priv
    protectedSection
        procedure Prot
    publicSection
        procedure UsePriv
        procedure UseProt
endClass
implement TThVis.Priv 'echo priv'
implement TThVis.Prot 'echo prot'
implement TThVis.UsePriv '$this.Priv'
implement TThVis.UseProt '$this.Prot'
endImplementation TThVis
declareClass TThVisC TThVis
    publicSection
        procedure ChildPriv
        procedure ChildProt
endClass
implement TThVisC.ChildPriv '$this.Priv'
implement TThVisC.ChildProt '$this.Prot'
endImplementation TThVisC
TThVisC.new vis

kt_test_start "D7 visibility: \$this.Priv from the own class is silent"
unset __KK_VIS_WARNED
run vis.UsePriv; expect "vis.UsePriv" "priv" 0

kt_test_start "D8 visibility: \$this.Priv from a child body warns (from the child class)"
unset __KK_VIS_WARNED
run vis.ChildPriv; expect "vis.ChildPriv" "priv" 0 "[kk] warning: private method 'TThVis.Priv' accessed from 'TThVisC'"

kt_test_start "D9 visibility: \$this.Prot from a child body is silent"
unset __KK_VIS_WARNED
run vis.ChildProt; expect "vis.ChildProt" "prot" 0

kt_test_start "D10 visibility: an external vis.Priv warns (external)"
unset __KK_VIS_WARNED
run vis.Priv; expect "vis.Priv" "priv" 0 "[kk] warning: private method 'TThVis.Priv' accessed from 'external'"
vis.delete

kt_test_start "D11 constructor: \$this.setup \"\$1\" dispatches"
defineClass TThK "" property v method setup 'v="set:$1"' constructor '$this.setup "$1"'
TThK.new k arg1
run k.v; expect "k.v" "set:arg1" 0
k.delete

defineClass TThR "" function val 'RESULT="v-$1"' method failer 'return 3' \
    method show '$this.val x; echo "$RESULT"' \
    method probe '$this.failer; echo "rc=$?"' \
    method outer '$this.val x; echo "/"' \
    method outerSilent 'kk.call_silent "$__inst__" val x; echo "/"' \
    method viaCall '$this.call val y; echo "$RESULT"'
TThR.new r

kt_test_start "D12 \$this.fn sets RESULT for the caller"
run r.show; expect "r.show" "v-x" 0

kt_test_start "D13 \$this.m propagates the callee's status"
run r.probe; expect "r.probe" "rc=3" 0

kt_test_start "D14 under \$( ) a \$this.func callee prints its value (the tutil trap, unchanged)"
out="$(r.outer)"
[[ "$out" == "v-x/" ]] && kt_test_pass "'$out'" || kt_test_fail "got '$out'"

kt_test_start "D15 kk.call_silent keeps the callee silent under \$( )"
out="$(r.outerSilent)"
[[ "$out" == "/" ]] && kt_test_pass "'$out'" || kt_test_fail "got '$out'"

kt_test_start "D16 the explicit \$this.call NAME form still works"
run r.viaCall; expect "r.viaCall" "v-y" 0
r.delete

kt_test_log "132_ThisDispatch.sh completed"
