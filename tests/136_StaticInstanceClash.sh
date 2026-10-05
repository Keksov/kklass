#!/bin/bash
# StaticInstanceClash (round 4 / P12, finding V1, decision DR10).
#
# Inside a member body every property of the instance AND every static
# property of the class is a plain variable name (kk._run_frame_body binds the
# instance namerefs first, then the static ones). With an instance property
# and a static property of the SAME name the static one won: `x=fromBody`
# wrote the static, the instance's x was never touched — on every path (raw
# build, defineClass, declarative verbs, Pascal var + static var, .kkp field +
# class var), own or inherited, either declaration order; 22 combinations
# built rc 0 (critic probe v1/pairs.sh).
#
# DR10: an instance PROPERTY of any kind (property, field, lazy, computed /
# read-write) and a STATIC PROPERTY (static_property, classVar, Pascal
# `static var`, .kkp `class var`) of the same name are refused and poison the
# class (DR8). Two check sites: the declarative verbs (own decl tables + the
# BUILT parent's merged lists) and the merged-list check in
# kk._build_class_runtime (every path ends there). Pairs involving a METHOD do
# not collide and stay allowed, with their body semantics unchanged.
#   §A refused (raw / defineClass / verbs / Pascal / .kkp, own + inherited)
#   §B allowed pairs keep building, semantics unchanged
#   §C poison side effects (next class builds, refused redefinition keeps the old class)

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "StaticInstanceClash" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"
source "$KKLASS_DIR/kklass_pascal.sh"

TMPD="$(cd "$(kt_fixture_tmpdir)" && pwd)"
OUTF="$TMPD/out.txt"
ERRF="$TMPD/err.txt"

run() {
    "$@" >"$OUTF" 2>"$ERRF"; RC=$?
    OUT="$(<"$OUTF")"; ERR="$(<"$ERRF")"
}
built() { declare -p "${1}_class_methods" &>/dev/null; }
PB='x=fromBody'

# refused LABEL CLASS — after the definition ran (RC/ERR of its LAST step):
# not built, rc != 0, the error names 'x', no class left open. When the body
# probe class was built anyway (the pre-P12 behaviour), report where the write
# went, so the red run shows the bug itself.
BAD=""
refused() {
    local label="$1" c="$2" where=""
    if built "$c"; then
        if "$c.new" "o_$c" 2>/dev/null && "o_$c.probe" 2>/dev/null; then
            where=" (body x=fromBody -> instance '$("o_$c.x" 2>/dev/null)', static '$("$c.x" 2>/dev/null)')"
        fi
        BAD+=" [$label] BUILT rc=$RC$where;"
    else
        (( RC != 0 )) || BAD+=" [$label] rc 0;"
        [[ "$ERR" == *"'x'"* ]] || BAD+=" [$label] error does not name 'x': '${ERR//$'\n'/ | }';"
    fi
    [[ -z "$KK_DECL_CURRENT_CLASS" ]] || { BAD+=" [$label] class left open ($KK_DECL_CURRENT_CLASS);"; KK_DECL_CURRENT_CLASS=""; }
}
# The clash message itself (checked once per path below).
clash_msg() { [[ "$ERR" == *"'x'"* && "$ERR" == *"instance propert"* && "$ERR" == *"static propert"* ]]; }

# ===========================================================================
# §A  refused
# ===========================================================================
kt_test_start "A1 raw kk._build_class_runtime: property / lazy / computed × static_property x, either order → rc 1, not built"
BAD=""
run kk._build_class_runtime TRw1 "" property x static_property x method probe "$PB"; refused "property+static" TRw1
clash_msg || BAD+=" [message] '${ERR//$'\n'/ | }';"
run kk._build_class_runtime TRw2 "" static_property x property x method probe "$PB"; refused "static+property" TRw2
run kk._build_class_runtime TRw3 "" lazy_property x initX method initX 'echo L' static_property x method probe "$PB"; refused "lazy+static" TRw3
run kk._build_class_runtime TRw4 "" property x getX method getX 'kk._return G' static_property x method probe "$PB"; refused "computed+static" TRw4
run kk._build_class_runtime TRw5 "" static_property x property x getX setX method getX 'kk._return G' method setX ':' method probe "$PB"; refused "static+computed" TRw5
if [[ -z "$BAD" ]]; then kt_test_pass "5 refused"; else kt_test_fail "$BAD"; fi

kt_test_start "A2 raw build, INHERITED either way (parent property/lazy → child static; parent static → child property/lazy)"
BAD=""
kk._build_class_runtime TRwPp "" property x
kk._build_class_runtime TRwPl "" lazy_property x initX method initX 'echo L'
kk._build_class_runtime TRwPs "" static_property x
run kk._build_class_runtime TRwK1 TRwPp static_property x method probe "$PB"; refused "parent property / child static" TRwK1
run kk._build_class_runtime TRwK2 TRwPl static_property x method probe "$PB"; refused "parent lazy / child static" TRwK2
run kk._build_class_runtime TRwK3 TRwPs property x method probe "$PB"; refused "parent static / child property" TRwK3
run kk._build_class_runtime TRwK4 TRwPs lazy_property x initX method initX 'echo L' method probe "$PB"; refused "parent static / child lazy" TRwK4
if [[ -z "$BAD" ]]; then kt_test_pass "4 refused"; else kt_test_fail "$BAD"; fi

kt_test_start "A3 defineClass: property / lazy / computed × static_property x, either order → rc 1, not built"
BAD=""
run defineClass TDc1 "" property x static_property x method probe "$PB"; refused "property+static" TDc1
clash_msg || BAD+=" [message] '${ERR//$'\n'/ | }';"
run defineClass TDc2 "" static_property x property x method probe "$PB"; refused "static+property" TDc2
run defineClass TDc3 "" lazy_property x initX method initX 'echo L' static_property x method probe "$PB"; refused "lazy+static" TDc3
run defineClass TDc4 "" static_property x lazy_property x initX method initX 'echo L' method probe "$PB"; refused "static+lazy" TDc4
run defineClass TDc5 "" property x getX setX method getX 'kk._return G' method setX ':' static_property x method probe "$PB"; refused "computed+static" TDc5
run defineClass TDc6 "" static_property x property x getX method getX 'kk._return G' method probe "$PB"; refused "static+computed" TDc6
if [[ -z "$BAD" ]]; then kt_test_pass "6 refused"; else kt_test_fail "$BAD"; fi

kt_test_start "A4 defineClass, INHERITED either way (parent property/computed → child static; parent static → child property)"
BAD=""
defineClass TDcPp "" property x
defineClass TDcPc "" property x getX method getX 'kk._return G'
defineClass TDcPs "" static_property x
run defineClass TDcK1 TDcPp static_property x method probe "$PB"; refused "parent property / child static" TDcK1
run defineClass TDcK2 TDcPc static_property x method probe "$PB"; refused "parent computed / child static" TDcK2
run defineClass TDcK3 TDcPs property x method probe "$PB"; refused "parent static / child property" TDcK3
run defineClass TDcK4 TDcPs lazy_property x initX method initX 'echo L' method probe "$PB"; refused "parent static / child lazy" TDcK4
if [[ -z "$BAD" ]]; then kt_test_pass "4 refused"; else kt_test_fail "$BAD"; fi

# Declarative verbs: the refused verb returns 1 and poisons the class; endClass
# then fails it (rc 1, names class + member), endImplementation refuses it.
# decl_run LABEL CLASS PARENT STEP... — each STEP is one verb line (eval'd).
decl_run() {
    local label="$1" c="$2" parent="$3" st v=0 e i; shift 3
    declareClass "$c" "$parent"
    for st in "$@"; do eval "$st" 2>>"$ERRF.verbs" || v=1; done
    procedure probe 2>>"$ERRF.verbs"
    endClass 2>>"$ERRF.verbs"; e=$?
    implement "$c.probe" "$PB" 2>/dev/null
    run endImplementation "$c"; i=$RC
    ERR="$(<"$ERRF.verbs")"$'\n'"$ERR"; : > "$ERRF.verbs"
    [[ "$v:$e:$i" == 1:1:1 ]] || BAD+=" [$label] verb=$v endClass=$e endImplementation=$i (want 1:1:1);"
    refused "$label" "$c"
}
: > "$ERRF.verbs"

kt_test_start "A5 declarative verbs: field / property / read-write property × classVar x, either order → verb rc 1, endClass rc 1, endImplementation rc 1"
BAD=""
decl_run "field+classVar" TVb1 "" "field x" "classVar x"
clash_msg || BAD+=" [message] '${ERR//$'\n'/ | }';"
decl_run "classVar+field" TVb2 "" "classVar x" "field x"
decl_run "property+classVar" TVb3 "" "property x" "classVar x"
decl_run "classVar+property" TVb4 "" "classVar x" "property x"
decl_run "read-write property+classVar" TVb5 "" "func getX" "procedure setX" "property x read getX write setX" "classVar x"
decl_run "classVar+read-write property" TVb6 "" "func getX" "classVar x" "property x read getX write x"
if [[ -z "$BAD" ]]; then kt_test_pass "6 refused"; else kt_test_fail "$BAD"; fi

kt_test_start "A6 declarative verbs, INHERITED either way (built parent property/field → child classVar; parent static → child field/property)"
BAD=""
declareClass TVbPf ""; field x; endClass; endImplementation TVbPf
declareClass TVbPs ""; classVar x; endClass; endImplementation TVbPs
decl_run "parent field / child classVar" TVbK1 TVbPf "classVar x"
decl_run "parent property (defineClass) / child classVar" TVbK2 TDcPp "classVar x"
decl_run "parent classVar / child field" TVbK3 TVbPs "field x"
decl_run "parent static_property (defineClass) / child property" TVbK4 TDcPs "property x"
if [[ -z "$BAD" ]]; then kt_test_pass "4 refused"; else kt_test_fail "$BAD"; fi

kt_test_start "A7 Pascal DSL: var x + static var x (either order), property read/write + static var, inherited var → child static var → end rc 1, build rc 1"
BAD=""
pas() {   # LABEL CLASS PARENT STEP...
    local label="$1" c="$2" parent="$3" st e b; shift 3
    if [[ -n "$parent" ]]; then class "$c" : "$parent"; else class "$c"; fi
    for st in "$@"; do eval "$st" 2>>"$ERRF.verbs"; done
    proc probe 2>>"$ERRF.verbs"
    end 2>>"$ERRF.verbs"; e=$?
    eval "$c.probe() { x=fromBody; }"
    run build "$c"; b=$RC
    ERR="$(<"$ERRF.verbs")"$'\n'"$ERR"; : > "$ERRF.verbs"
    [[ "$e:$b" == 1:1 ]] || BAD+=" [$label] end=$e build=$b (want 1:1);"
    refused "$label" "$c"
}
pas "var+static var" TPs1 "" "var x" "static var x"
clash_msg || BAD+=" [message] '${ERR//$'\n'/ | }';"
pas "static var+var" TPs2 "" "static var x" "var x"
TPs3.getX() { RESULT=1; }; TPs3.setX() { :; }
pas "property read/write+static var" TPs3 "" "var Fx" "func getX" "proc setX" "property x read getX write setX" "static var x"
class TPsP; var x; end; build TPsP
pas "inherited var / child static var" TPs4 TPsP "static var x"
class TPsQ; static var x; end; build TPsQ
pas "inherited static var / child var" TPs5 TPsQ "var x"
if [[ -z "$BAD" ]]; then kt_test_pass "5 refused"; else kt_test_fail "$BAD"; fi

kt_test_start "A8 .kkp: a field and a class var of the same name → compile rc 1, nothing written; the translated unit's endImplementation rc 1"
BAD=""
cat > "$TMPD/u.kkp" <<'EOF'
unit U;
interface
type
  KP = class
  public
    x: Integer;
    class var x: Integer;
    procedure probe;
  end;
implementation
procedure KP.probe;
begin
x=fromBody
end;
end.
EOF
rm -f "$TMPD/u.ckk.sh"
bash "$KKLASS_DIR/kklass_compiler.sh" "$TMPD/u.kkp" "$TMPD/u.ckk.sh" >"$OUTF" 2>"$ERRF"; rc=$?
(( rc == 1 )) || BAD+=" compile rc=$rc;"
[[ ! -e "$TMPD/u.ckk.sh" ]] || BAD+=" output written;"
grep -q "'x'" "$ERRF" || BAD+=" compile error does not name 'x': '$(tr '\n' '|' < "$ERRF")';"
bash "$KKLASS_DIR/kklass_kkp.sh" "$TMPD/u.kkp" "$TMPD/u.sh" >/dev/null 2>&1 || BAD+=" translate failed;"
o="$(bash -c 'source "$1/kklass.sh"; source "$2" 2>/dev/null; r=$?; declare -p KP_class_methods &>/dev/null && echo "built:$r" || echo "refused:$r"' _ "$KKLASS_DIR" "$TMPD/u.sh")"
[[ "$o" == refused:1 ]] || BAD+=" translated unit '$o';"
if [[ -z "$BAD" ]]; then kt_test_pass "refused"; else kt_test_fail "$BAD"; fi

# ===========================================================================
# §B  pairs involving a METHOD do not collide: they build, semantics unchanged
# ===========================================================================
kt_test_start "B1 method x + static_property x builds on every path: \$this.x runs the method, a body write of x is the static (unchanged)"
BAD=""
chk_ms() {   # LABEL CLASS
    local label="$1" c="$2" o
    built "$2" || { BAD+=" [$label] not built rc=$RC err='${ERR//$'\n'/ | }';"; return; }
    "$c.new" "i_$c"; "$c.x" = st0
    "i_$c.probe" >"$OUTF"; o="$(<"$OUTF")|$("$c.x")"
    [[ "$o" == "M|fromBody" ]] || BAD+=" [$label] '$o' (want M|fromBody);"
}
MB='x=fromBody; $this.x'
run kk._build_class_runtime TMs1 "" method x 'echo M' static_property x method probe "$MB"; chk_ms raw TMs1
run defineClass TMs2 "" method x 'echo M' static_property x method probe "$MB"; chk_ms defineClass TMs2
run defineClass TMs3 "" static_property x method x 'echo M' method probe "$MB"; chk_ms "defineClass static first" TMs3
declareClass TMs4 ""; procedure x; classVar x; procedure probe; endClass
implement TMs4.x 'echo M'; implement TMs4.probe "$MB"; run endImplementation TMs4; chk_ms verbs TMs4
class TMs5; proc x; static var x; proc probe; end
TMs5.x() { echo M; }; TMs5.probe() { x=fromBody; $this.x; }; run build TMs5; chk_ms Pascal TMs5
defineClass TMsP "" method x 'echo M'
run defineClass TMs6 TMsP static_property x method probe "$MB"; chk_ms "inherited method / child static" TMs6
defineClass TMsQ "" static_property x
run defineClass TMs7 TMsQ method x 'echo M' method probe "$MB"; chk_ms "inherited static / child method" TMs7
if [[ -z "$BAD" ]]; then kt_test_pass "7 build"; else kt_test_fail "$BAD"; fi

kt_test_start "B2 property x + static_method x builds: a body write of x is the INSTANCE's, CLASS.x runs the static method"
BAD=""
chk_ps() {
    local label="$1" c="$2" o
    built "$2" || { BAD+=" [$label] not built rc=$RC err='${ERR//$'\n'/ | }';"; return; }
    "$c.new" "j_$c"; "j_$c.probe"
    o="$("j_$c.x")|$("$c.x")"
    [[ "$o" == "fromBody|SM" ]] || BAD+=" [$label] '$o' (want fromBody|SM);"
}
run kk._build_class_runtime TPm1 "" property x static_method x 'echo SM' method probe "$PB"; chk_ps raw TPm1
run defineClass TPm2 "" property x static_method x 'echo SM' method probe "$PB"; chk_ps defineClass TPm2
declareClass TPm3 ""; field x; classProcedure x; procedure probe; endClass
implement TPm3.x 'echo SM'; implement TPm3.probe "$PB"; run endImplementation TPm3; chk_ps verbs TPm3
if [[ -z "$BAD" ]]; then kt_test_pass "3 build"; else kt_test_fail "$BAD"; fi

kt_test_start "B3 method x + static_method x builds (raw, defineClass): \$this.x is the instance method, CLASS.x the static one"
BAD=""
run kk._build_class_runtime TMm1 "" method x 'echo IM' static_method x 'echo SM' method probe '$this.x; TMm1.x'
o="$(TMm1.new k1 && k1.probe)"; [[ $RC == 0 && "$o" == $'IM\nSM' ]] || BAD+=" raw rc=$RC '$o';"
run defineClass TMm2 "" method x 'echo IM' static_method x 'echo SM' method probe '$this.x; TMm2.x'
o="$(TMm2.new k2 && k2.probe)"; [[ $RC == 0 && "$o" == $'IM\nSM' ]] || BAD+=" defineClass rc=$RC '$o';"
if [[ -z "$BAD" ]]; then kt_test_pass "both build"; else kt_test_fail "$BAD"; fi

kt_test_start "B4 distinct names: a static next to instance properties of OTHER names builds and keeps both"
run defineClass TOk "" property x static_property xs method probe 'x=ix; xs=sx'
o=""
if [[ $RC == 0 ]]; then TOk.new ok1; ok1.probe; o="$(ok1.x)|$(TOk.xs)"; fi
if [[ "$o" == "ix|sx" ]]; then kt_test_pass "ok"; else kt_test_fail "rc=$RC '$o' err='$ERR'"; fi

# ===========================================================================
# §C  poison side effects
# ===========================================================================
kt_test_start "C1 after a refused class the next class builds; the refused one is not instantiable"
run defineClass TNx "" property y
o="$(TDc1.new zz 2>&1; echo "rc=$?")"
if [[ $RC == 0 ]] && built TNx && [[ -z "$KK_DECL_CURRENT_CLASS" && "$o" == *"rc=127"* ]]; then
    kt_test_pass "ok"
else
    kt_test_fail "rc=$RC open='$KK_DECL_CURRENT_CLASS' TDc1.new: '$o'"
fi

kt_test_start "C2 a refused REdefinition (property x + static_property x) keeps the old class working"
defineClass TRdf "" property x method get 'echo "x=$x"'
run defineClass TRdf "" property x static_property x method get 'echo "x=$x"'
rc=$RC
TRdf.new rd1; rd1.x = old
o="$(rd1.get)"
if [[ $rc == 1 && "$o" == "x=old" && -z "$KK_DECL_CURRENT_CLASS" ]] && ! declare -F TRdf.x >/dev/null; then
    kt_test_pass "old class intact"
else
    kt_test_fail "rc=$rc get='$o' open='$KK_DECL_CURRENT_CLASS' TRdf.x=$(declare -F TRdf.x)"
fi

kt_test_log "136_StaticInstanceClash.sh completed"
