#!/bin/bash
# TakenNames (uses phase U2b; kklass/USES_PLAN.md U22 as amended by U40, U35,
# U32, U36, U33, C13, P9, U11).
#   U22/U40 a class or an instance may not take the name of a DECLARED function
#         namespace (kkore's kk kl ke kv kc, kklass's kkp, a unit's own name, a
#         `kk.namespace X`): one assoc lookup in declareClass and .new, no listing
#         of the function table; the rest of a refused block is swallowed and the
#         namespace's functions survive an imposter (sink mode n). kk.unit and
#         kk.namespace refuse a name that is already a class or a live instance.
#         The gap: a plain library without a unit header or kk.namespace.
#   U35   the DSL verbs (kklass_decl, kklass_pascal, kklass.sh, serializable,
#         uses) are refused as class and instance names; the list is
#         recomputed here from the live function table.
#   C13/P9 a class loaded from a compiled cache (.ckk) is registered like a
#         built one; the cache loads kklass through the unit loader when kbool
#         is loaded, names a unit source by its unit name and its source file
#         relative to the cache folder (a moved project); U11 the cache folder
#         comes from the config's ckkdir unless KKLASS_CKK_DIR is set.
#   U36/U33 the .kkp translator: `unit X;` -> the two §7.4 user header lines (X
#         must be the file stem), `uses A, B;` -> kk.uses A B; no comment after
#         a statement.
#   U32   `uses` in the Pascal DSL = kk.uses (rc 2 without kbool).
#   R14   a set -a child with hostile names evaluates nothing, helpers first.
# Every case runs in a child bash (fresh registries), files in $TMPD; kbool
# loads with an empty, private config (HOME, __KK_CFG_ETC, no KBOOL_CONFIG).

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "TakenNames" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KBOOL_ROOT="$(cd "$KKLASS_DIR/.." && pwd)"

TMPD="${TMPDIR:-/tmp}/kk140_$$"
mkdir -p "$TMPD/home" "$TMPD/etc" && TMPD="$(cd "$TMPD" && pwd)"
kk140_cleanup() { rm -rf "$TMPD"; }
kt_fixture_cleanup_register kk140_cleanup

# case_run NAME — run $TMPD/NAME.sh in a child bash (cwd $TMPD); OUT, ERR, RC.
case_run() {
    ( cd "$TMPD" && env -u KBOOL_CONFIG -u KBOOL_HOME -u USERPROFILE -u ProgramData -u KKLASS_CKK_DIR \
        HOME="$TMPD/home" __KK_CFG_ETC="$TMPD/etc" \
        KKLASS_DIR="$KKLASS_DIR" TMPD="$TMPD" KBOOL_ROOT="$KBOOL_ROOT" \
        "$BASH" "$TMPD/$1.sh" >"$TMPD/$1.out" 2>"$TMPD/$1.err" ); RC=$?
    OUT="$(<"$TMPD/$1.out")"; ERR="$(<"$TMPD/$1.err")"
}
# nlines TEXT -> N (number of lines; 0 for empty)
nlines() { N=0; [[ -z "$1" ]] && return 0; local -a a; mapfile -t a <<<"$1"; N=${#a[@]}; }
fl() { local f; for f in "$@"; do printf '%s' "$(<"$TMPD/$f")"; done; }

# ---------------------------------------------------------------------------
cat > "$TMPD/T1.sh" <<'EOF'
source "$KKLASS_DIR/kklass.sh"
before="$(declare -f kv.new)"
defineClass kv "" property a; echo "rc=$?"
[[ "$(declare -f kv.new)" == "$before" ]] && echo "kv.new kept"
declareClass kk ""; echo "decl=$?"
field x; echo "field=$?"
endClass; echo "end=$?"
endImplementation kk; echo "endimpl=$?"
echo "sink=[$__KK_SINK] open=[$KK_DECL_CURRENT_CLASS] built=[${kv_class_methods+kv}${kk_class_methods+kk}]"
defineClass TOkN "" property a; echo "next=$?"
EOF
kt_test_start "N1 a class named like a kkore namespace (kv, kk): Duplicate identifier naming it, rc 1, the rest of the block swallowed (rc 1), kkore's functions untouched, the next class builds"
case_run T1; nlines "$ERR"
if [[ "$OUT" == $'rc=1\nkv.new kept\ndecl=1\nfield=1\nend=1\nendimpl=1\nsink=[] open=[] built=[]\nnext=0' && $N -eq 2 \
      && "$ERR" == *"Duplicate identifier: 'kv' is a function namespace (kv."*"kkore/kvar.sh)"* \
      && "$ERR" == *"Duplicate identifier: 'kk' is a function namespace"* && "$ERR" == *"T1.sh:3"* ]]; then
    kt_test_pass "${ERR//$'\n'/ | }"
else
    kt_test_fail "out='${OUT//$'\n'/|}' lines=$N err='$ERR'"
fi

# ---------------------------------------------------------------------------
cat > "$TMPD/impke.sh" <<'EOF'
class ke
    public
        proc enableErrorReport
        func Extra
end
ke.enableErrorReport() { echo IMPOSTER; }
ke.Extra() { RESULT=x; }
build ke
echo "build=$?"
EOF
cat > "$TMPD/T2.sh" <<'EOF'
source "$KKLASS_DIR/kklass_pascal.sh"
before="$(declare -f ke.enableErrorReport)"
source "$TMPD/impke.sh" 2>"$TMPD/T2.e"
[[ "$(declare -f ke.enableErrorReport)" == "$before" ]] && echo restored
declare -F ke.Extra >/dev/null && echo "extra left"
echo "sink=[$__KK_SINK] snap=${#_KKLASS_SINK_NS[@]} built=${ke_class_methods+yes}"
EOF
kt_test_start "N2 a Pascal imposter 'class ke' (critic n1b): refused, build rc 1, kkore's ke.enableErrorReport restored (not deleted, not replaced), the imposter's extra body gone"
case_run T2; e="$(fl T2.e)"; nlines "$e"
if [[ "$OUT" == $'build=1\nrestored\nsink=[] snap=0 built=' && $N -eq 1 && "$e" == *"'ke' is a function namespace"*"kerr.sh"* && -z "$ERR" ]]; then
    kt_test_pass "$e"
else
    kt_test_fail "out='${OUT//$'\n'/|}' lines=$N e='$e' err='$ERR'"
fi

# ---------------------------------------------------------------------------
cat > "$TMPD/T3.sh" <<'EOF'
source "$KKLASS_DIR/kklass_pascal.sh"
defineClass TNw "" property a
defineClass TNx "" property b
for n in kv ke kl kk class end uses var TNw TNx; do
    TNw.new "$n" 2>>"$TMPD/T3.e"; r=$?
    declare -F "$n.call" >/dev/null && c=made || c=none
    printf '%s=%s:%s ' "$n" "$r" "$c"
done
echo
TNw.new okname; echo "ok=$?"; okname.a = 1; TNw.new okname; echo "renew=$? a=[$(okname.a)]"
EOF
kt_test_start "N3 .new refuses a namespace (kv ke kl kk), a verb (class end uses var) and a class name (TNw TNx): rc 1, one 'Invalid instance name' line each, nothing created; other names and re-creation work"
case_run T3; e="$(fl T3.e)"; nlines "$e"
want='kv=1:none ke=1:none kl=1:none kk=1:none class=1:none end=1:none uses=1:none var=1:none TNw=1:none TNx=1:none '
if [[ "$OUT" == "$want"$'\nok=0\nrenew=0 a=[1]' && $N -eq 10 && "$e" == *"Invalid instance name: kv (a function namespace: kv."*"kvar.sh)"* \
      && "$e" == *"Invalid instance name: end (a kklass DSL verb)"* && "$e" == *"Invalid instance name: TNx (the name of a class)"* && -z "$ERR" ]]; then
    kt_test_pass "10 refused"
else
    kt_test_fail "out='${OUT//$'\n'/|}' lines=$N e='${e//$'\n'/ | }' err='$ERR'"
fi

# ---------------------------------------------------------------------------
cat > "$TMPD/T4.sh" <<'EOF'
source "$KKLASS_DIR/kklass_pascal.sh"
defineClass TCo "" property a method m 'echo m'
TCo.new x0
bad=""
for f in declareClass endClass endImplementation defineClass class build kk._build_class_runtime \
         kk._class_verdict kk._class_site kk._class_site_same kk._class_register kk._taken_check \
         kk._taken_init kk._namespace_add kk._name_in_use kk._ns_txt kk._new_refused \
         kk.decl._sink_enter kk.decl._sunk kk.decl._ns_snap kk.decl._sink_close \
         kk._ckk_begin kk._ckk_class kk._ckk_built TCo.new TCo.__decl_new_impl; do
    body="$(declare -f "$f")" || { bad+=" $f:missing"; continue; }
    [[ $body != *compgen* && $body != *extdebug* ]] || bad+=" $f:compgen"
    if grep -qE 'declare -[Ff]( *[>|;&)]| *$| +2>)' <<<"$body"; then bad+=" $f:listing"; fi
done
echo "listing=[$bad]"
now() { REPLY=${EPOCHREALTIME//[!0-9]/}; }
measure() {   # -> T_NEW (us per .new, best of 3 x 300), T_DECL (us per defineClass, best of 3 x 3)
    local r s e i b=0 d=0
    for r in 1 2 3; do
        now; s=$REPLY; for ((i = 0; i < 300; i++)); do TCo.new "m$1$r$i"; done; now; e=$REPLY
        (( b == 0 || e - s < b )) && b=$((e - s))
        now; s=$REPLY; for ((i = 0; i < 3; i++)); do defineClass "TCm$1$r$i" "" property a method m 'echo'; done; now; e=$REPLY
        (( d == 0 || e - s < d )) && d=$((e - s))
    done
    T_NEW=$((b / 300)) T_DECL=$((d / 3))
}
measure a; n0=$T_NEW d0=$T_DECL
for ((i = 0; i < 5000; i++)); do eval "zx$i.f() { :; }"; done
measure b; n1=$T_NEW d1=$T_DECL
echo "new: $n0 -> $n1 us, declare: $d0 -> $d1 us" >&2
(( n1 * 10 <= n0 * 15 + 200 )) && echo "new not slower" || echo "new SLOWER $n0 -> $n1"
(( d1 * 10 <= d0 * 15 + 200000 )) && echo "declare not slower" || echo "declare SLOWER $d0 -> $d1"
EOF
kt_test_start "N4 U40: no listing of the function table on the declaration or .new paths (no compgen / extdebug / name-less declare -F|-f in their functions); a class declaration and .new with 5000 extra functions defined are not slower than with none"
case_run T4
if [[ "$OUT" == $'listing=[]\nnew not slower\ndeclare not slower' ]]; then kt_test_pass "$ERR"; else kt_test_fail "out='${OUT//$'\n'/|}' err='$ERR'"; fi

# ---------------------------------------------------------------------------
unit() {   # FILE NAME BODY... — a unit file with the user header
    { printf '%s\n' '[[ ${__KK_UNITS[@]@a} == A* ]] || source "${KBOOL_HOME-}/kbool.sh" || return 2' \
                    "kk.unit $2 || return \$__kk_unit_rc"; shift 2; printf '%s\n' "$@"; } > "$TMPD/${1}"
}
unit uns.sh uns 'uns.hello() { echo hi; }'
unit hlp.sh hlp 'kk.namespace hns; echo "ns=$?"' 'hns.f() { :; }'
unit c4i.sh c4i
unit c4c.sh c4c
unit own.sh own 'defineClass own "" property a; echo "own class=$?"'
cat > "$TMPD/T5.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh" || { echo "no kbool"; exit 1; }
source "$KKLASS_DIR/kklass.sh"
defineClass TUa "" property a; TUa.new o1
kk.uses "$TMPD/uns.sh"; echo "uses=$?"
TUa.new uns 2>"$TMPD/T5.e1"; echo "new uns=$?"
defineClass uns "" property a 2>"$TMPD/T5.e2"; echo "class uns=$?"
TUa.new kc 2>/dev/null; echo "new kc=$?"
kk.uses "$TMPD/hlp.sh"; echo "hlp=$?"
TUa.new hns 2>/dev/null; echo "new hns=$?"
defineClass hns "" property a 2>/dev/null; echo "class hns=$?"
kk.uses "$TMPD/own.sh"; echo "own unit=$?"
TUa.new c4i
kk.uses "$TMPD/c4i.sh" 2>"$TMPD/T5.e3"; echo "unit named like an instance=$? reg=${__KK_UNITS[c4i]+yes}"
defineClass c4c "" property a
kk.uses "$TMPD/c4c.sh" 2>"$TMPD/T5.e4"; echo "unit named like a class=$? reg=${__KK_UNITS[c4c]+yes}"
kk.namespace o1 2>"$TMPD/T5.e5"; echo "kk.namespace an instance=$?"
kk.namespace 'b@d' 2>/dev/null; echo "kk.namespace bad=$?"
kk.namespace 2>/dev/null; echo "kk.namespace none=$?"
kk.namespace myns; echo "kk.namespace myns=$?"
TUa.new myns 2>/dev/null; echo "new myns=$?"
EOF
kt_test_start "N5 U22/U40 with kbool: a unit's name and its kk.namespace prefixes are taken (class and .new refused, messages name the unit); a unit may declare a class of its own name; kk.unit / kk.namespace refuse a name that is a live instance or a built class (rc 2, the unit not registered); kk.namespace usage errors rc 2"
case_run T5; e1="$(fl T5.e1)"; e2="$(fl T5.e2)"; e3="$(fl T5.e3)"; e4="$(fl T5.e4)"; e5="$(fl T5.e5)"
want=$'uses=0\nnew uns=1\nclass uns=1\nnew kc=1\nns=0\nhlp=0\nnew hns=1\nclass hns=1\nown class=0\nown unit=0'
want+=$'\nunit named like an instance=2 reg=\nunit named like a class=2 reg=\nkk.namespace an instance=2\nkk.namespace bad=2\nkk.namespace none=2\nkk.namespace myns=0\nnew myns=1'
if [[ "$OUT" == "$want" && "$e1" == *"Invalid instance name: uns (a function namespace: uns.* of unit uns ("*"/uns.sh))"* \
      && "$e2" == *"'uns' is a function namespace (uns.* of unit uns ("*"/uns.sh))"* \
      && "$e3" == *"'c4i' is already an instance of TUa"* && "$e4" == *"'c4c' is already a class declared at "*"T5.sh"* \
      && "$e5" == *"'o1' is already an instance of TUa"* ]]; then
    kt_test_pass "ok"
else
    kt_test_fail "out='${OUT//$'\n'/|}' e1='$e1' e2='$e2' e3='$e3' e4='$e4' e5='$e5' err='$ERR'"
fi

# ---------------------------------------------------------------------------
cat > "$TMPD/bodies.sh" <<'EOF'
TFo.Hi() { RESULT=foreign; }
EOF
cat > "$TMPD/bodies2.sh" <<'EOF'
kk.namespace TFq
TFq.Hi() { RESULT=lib; }
EOF
cat > "$TMPD/T6.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh" || { echo "no kbool"; exit 1; }
source "$KKLASS_DIR/kklass_pascal.sh"
TOw.Hi() { RESULT=own; }
class TOw
    public
        func Hi
end
build TOw; echo "own=$?"
source "$TMPD/bodies.sh"
class TFo
    public
        func Hi
end
build TFo; echo "undeclared=$?"
source "$TMPD/bodies2.sh"
class TFq
    public
        func Hi
end
TFq.Hi() { RESULT=imposter; }
build TFq 2>/dev/null; echo "declared=$?"
TFq.Hi; echo "kept=$RESULT"
TOw.new w; w.Hi; echo "w=$RESULT"
EOF
kt_test_start "N6 Pascal bodies before 'class X' are the class's own (built); an UNdeclared prefix of another file is not protected (the U40 gap); a kk.namespace-declared one is refused and its function survives the imposter's body"
case_run T6; nlines "$ERR"
if [[ "$OUT" == $'own=0\nundeclared=0\ndeclared=1\nkept=lib\nw=own' && $N -eq 1 && "$ERR" == *"'TFq' is a function namespace (TFq.* ("*"/bodies2.sh))"* ]]; then
    kt_test_pass "$ERR"
else
    kt_test_fail "out='${OUT//$'\n'/|}' lines=$N err='$ERR'"
fi

# ---------------------------------------------------------------------------
printf 'libns.get() { echo orig; }\n' > "$TMPD/libns.sh"
printf 'kk.namespace libns2\nlibns2.get() { echo orig; }\n' > "$TMPD/libns2.sh"
cat > "$TMPD/T7.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh" || { echo "no kbool"; exit 1; }
source "$KKLASS_DIR/kklass.sh"
sample.echoValue() { echo "v=$1"; }
kk.register_static_methods sample sample Sample echoValue; echo "adopt=$? out=$(sample.echoValue 3)"
before="$(declare -f kv.get)"
kk.register_static_methods kv kv Kv get 2>/dev/null; echo "adopt kv=$?"
[[ "$(declare -f kv.get)" == "$before" ]] && echo "kv.get kept"
defineClass TB "" property a method get 'echo instance'
source "$TMPD/libns.sh"
TB.new libns; echo "plain library (U40 gap)=$? get=$(libns.get)"
source "$TMPD/libns2.sh"
TB.new libns2 2>/dev/null; echo "declared library=$? get=$(libns2.get)"
EOF
kt_test_start "N7 kk.register_static_methods X X turns an undeclared prefix into a class, never a declared namespace (kv kept); U40 gap pinned: a plain library without kk.namespace is not protected, with kk.namespace it is"
case_run T7
if [[ "$OUT" == $'adopt=0 out=v=3\nadopt kv=1\nkv.get kept\nplain library (U40 gap)=0 get=instance\ndeclared library=1 get=orig' ]]; then kt_test_pass "ok"; else kt_test_fail "out='${OUT//$'\n'/|}' err='$ERR'"; fi

# ---------------------------------------------------------------------------
cat > "$TMPD/T8.sh" <<'EOF'
source "$KKLASS_DIR/kklass_pascal.sh"
source "$KKLASS_DIR/kklass_serializable.sh"
missing="" verbs=()
shopt -s extdebug
while IFS= read -r fn; do
    [[ $fn == *.* || $fn == _* ]] && continue
    line="$(declare -F "$fn")"; file="${line#* * }"
    case "${file##*/}" in
        kklass.sh|kklass_decl.sh|kklass_pascal.sh|kklass_serializable.sh) ;;
        *) continue ;;
    esac
    verbs+=("$fn")
    [[ ${_KKLASS_TAKEN[$fn]-} == verb ]] || missing+=" $fn"
done < <(compgen -A function)
shopt -u extdebug
[[ ${_KKLASS_TAKEN[uses]-} == verb ]] || missing+=" uses"
echo "missing=[$missing] enough=$(( ${#verbs[@]} >= 40 ))"
defineClass TVb "" property a
bad=""
for v in "${verbs[@]}" uses; do
    defineClass "$v" "" property a 2>/dev/null && bad+=" class:$v"
    TVb.new "$v" 2>/dev/null && bad+=" new:$v"
done
echo "bad=[$bad] sink=[$__KK_SINK]"
EOF
kt_test_start "N8 U35: every public dotless function of the kklass DSL files (recomputed from the live table, extdebug) plus 'uses' is a refused verb — as a class name and as an instance name"
case_run T8
if [[ "$OUT" == $'missing=[] enough=1\nbad=[] sink=[]' ]]; then kt_test_pass "ok"; else kt_test_fail "out='${OUT//$'\n'/|}' err='${ERR:0:400}'"; fi

# ---------------------------------------------------------------------------
mkdir -p "$TMPD/inj"
cat > "$TMPD/T9.sh" <<'EOF'
cd "$TMPD/inj"
set -a
source "$KBOOL_ROOT/kbool.sh"
source "$KKLASS_DIR/kklass_pascal.sh"
defineClass TRs "" property a
set +a
export hz='z[$(touch PWN_hz)]' kk='k[$(touch PWN_kk)]' TRs_x='t[$(touch PWN_t)]' x='x[$(touch PWN_x)]'
# every helper FIRST, in a fresh child (no tables yet), by a name whose variable is hostile
for fn in kk._taken_check kk._new_refused kk._namespace_add kk._name_in_use kk._ns_txt kk.decl._ns_snap \
          kk._ckk_class kk._ckk_built kk._class_register kk.decl._sink_end kk.decl._sink_close kk.namespace; do
    "$BASH" -c "$fn hz x >/dev/null 2>&1; echo \"$fn=\$?\"" | tr '\n' ' '
done; echo
"$BASH" -c 'kk._taken_check hz; echo "tc=$?"; TRs.new hz; echo "new=$?"; TRs.new kk 2>/dev/null; echo "kk=$?"; TRs.new hz; echo "renew=$?"'
"$BASH" -c 'kk.decl._ns_snap "q[\$(touch PWN_q)]" x; kk._namespace_add "r[\$(touch PWN_r)]"; kk._name_in_use "s[\$(touch PWN_s)]"; kk.namespace "u[\$(touch PWN_u)]" 2>/dev/null; echo "hostile args done"'
ls PWN* 2>/dev/null | tr '\n' ' '; echo "end"
EOF
kt_test_start "N9 R14 (review R3): in a fresh set -a child every U2b helper called FIRST (before any table exists) with a name whose variable is hostile, and with hostile arguments: nothing evaluated; .new and the checks answer correctly"
case_run T9
want='kk._taken_check=0 kk._new_refused=1 kk._namespace_add=0 kk._name_in_use=1 kk._ns_txt=0 kk.decl._ns_snap=0 kk._ckk_class=0 kk._ckk_built=0 kk._class_register=0 kk.decl._sink_end=0 kk.decl._sink_close=0 kk.namespace=2 '
want+=$'\ntc=0\nnew=0\nkk=1\nrenew=0\nhostile args done\nend'
if [[ "$OUT" == "$want" ]]; then kt_test_pass "no PWN"; else kt_test_fail "out='${OUT//$'\n'/|}' err='${ERR:0:400}'"; fi

# ---------------------------------------------------------------------------
cat > "$TMPD/cc.kk" <<'EOF'
defineClass TCkk "" property v method who 'echo ORIGINAL'
EOF
cat > "$TMPD/impcc.sh" <<'EOF'
defineClass TCkk "" property v method who 'echo IMPOSTER'
EOF
cat > "$TMPD/T10.sh" <<'EOF'
export KKLASS_CKK_DIR=$TMPD/ckk10
source "$KKLASS_DIR/kklass_autoload.sh"
autoloadClasses "$TMPD/cc.kk" >/dev/null 2>&1; echo "load=$? reg=${_KKLASS_CLASS_SOURCE[TCkk]+yes}"
source "$TMPD/impcc.sh" 2>"$TMPD/T10.e1"; echo "imp=$?"
TCkk.new o; o.who
autoloadClasses "$TMPD/cc.kk" 2>"$TMPD/T10.e2" >/dev/null; echo "cached=$? warn=$(grep -c 'WARNING: class .TCkk' "$TMPD/T10.e2")"
source "$TMPD/cc.kk" 2>"$TMPD/T10.e3"; echo "direct=$? warn=$(grep -c 'WARNING: class .TCkk' "$TMPD/T10.e3")"
TCkk.new p; p.who
EOF
kt_test_start "N10 C13 (critic u22_ckk): a class loaded from a .ckk cache is registered — another file's declaration is a Duplicate identifier (the class kept); the cache again or its source sourced directly = the same place (one WARNING each, not rebuilt)"
case_run T10; e1="$(fl T10.e1)"
if [[ "$OUT" == $'load=0 reg=yes\nimp=1\nORIGINAL\ncached=0 warn=1\ndirect=0 warn=1\nORIGINAL' && "$e1" == *"Duplicate identifier: class 'TCkk'"*"cc.kk:1"*"impcc.sh:1"* ]]; then
    kt_test_pass "$e1"
else
    kt_test_fail "out='${OUT//$'\n'/|}' e1='$e1' err='$ERR'"
fi

ckf="$TMPD/ckk10/cc.ckk.sh"
cat > "$TMPD/T10b.sh" <<'EOF'
ckf="$TMPD/ckk10/cc.ckk.sh"
# a bare shell: the cache loads kklass itself (no kbool, no KBOOL_HOME: the compile-time copy)
"$BASH" -c 'source "$1"; TCkk.new o; o.who; echo "reg=${_KKLASS_CLASS_SOURCE[TCkk]+yes}"' _ "$ckf"
# KBOOL_HOME set, kbool not loaded: KBOOL_HOME's kklass
KBOOL_HOME="$KBOOL_ROOT" "$BASH" -c 'source "$1"; TCkk.new o; o.who' _ "$ckf"
# kbool loaded, kklass not: through the unit loader (kk.uses), recorded once
"$BASH" -c 'source "$2/kbool.sh"; source "$1"; TCkk.new o; o.who
            for k in "${!__KK_UNIT_FILES[@]}"; do [[ $k == */kklass/kklass.sh ]] && echo "via kk.uses"; done' _ "$ckf" "$KBOOL_ROOT"
EOF
kt_test_start "N11 C13: the cache's own kklass loading — already loaded: nothing; kbool loaded: kk.uses (recorded by the loader); else KBOOL_HOME's kklass; else the compiler's; the registration line and the unit loader line are in the cache"
case_run T10b
if [[ "$OUT" == $'ORIGINAL\nreg=yes\nORIGINAL\nORIGINAL\nvia kk.uses' && -z "$ERR" ]] \
   && grep -q '^        kk.uses "\$KBOOL_HOME/kklass/kklass.sh" || return$' "$ckf" \
   && grep -q '^if kk._ckk_class TCkk ' "$ckf" && grep -q '^kk._ckk_built TCkk$' "$ckf" && grep -q '^kk._ckk_begin ' "$ckf"; then
    kt_test_pass "ok"
else
    kt_test_fail "out='${OUT//$'\n'/|}' err='$ERR' cache-lines='$(grep -n 'kk\.\|^source\|^ *source' "$ckf" | head -8 | tr '\n' '|')'"
fi

# ---------------------------------------------------------------------------
mkdir -p "$TMPD/proj11"
printf 'ckkdir = cache\n' > "$TMPD/proj11/kb.conf"
cat > "$TMPD/T11.sh" <<'EOF'
export KBOOL_CONFIG="$TMPD/proj11/kb.conf"
source "$KBOOL_ROOT/kbool.sh" || { echo "no kbool"; exit 1; }
source "$KKLASS_DIR/kklass_autoload.sh"
cd "$TMPD/proj11"
printf 'defineClass TCd "" property a\n' > cd.kk
printf 'defineClass TCe "" property a\n' > ce.kk
autoloadClasses cd.kk >/dev/null 2>&1; echo "load=$?"
[[ -f "$TMPD/proj11/cache/cd.ckk.sh" ]] && echo "cache in ckkdir"
[[ -e "$TMPD/proj11/.ckk" ]] || echo "no ./.ckk"
KKLASS_CKK_DIR=rel autoloadClasses ce.kk >/dev/null 2>&1; echo "load=$?"
[[ -f "$TMPD/proj11/rel/ce.ckk.sh" && ! -e "$TMPD/proj11/cache/ce.ckk.sh" ]] && echo "KKLASS_CKK_DIR (relative) wins over ckkdir"
EOF
kt_test_start "N12 U11 (+ review R6): with kbool loaded and no KKLASS_CKK_DIR the cache goes into the config's ckkdir; a KKLASS_CKK_DIR — also a relative one, taken from \$PWD — wins over it"
case_run T11
if [[ "$OUT" == $'load=0\ncache in ckkdir\nno ./.ckk\nload=0\nKKLASS_CKK_DIR (relative) wins over ckkdir' ]]; then kt_test_pass "ok"; else kt_test_fail "out='${OUT//$'\n'/|}' err='$ERR'"; fi

# ---------------------------------------------------------------------------
cat > "$TMPD/pu.kkp" <<'EOF'
// a unit
unit pu;

interface

type
  TPu = class
  public
    function Hi;
  end;

implementation

function TPu.Hi;
begin
RESULT=hi
end;

end.
EOF
cat > "$TMPD/T12.sh" <<'EOF'
export KKLASS_CKK_DIR=$TMPD/ckk12
source "$KKLASS_DIR/kklass_autoload.sh"
autoloadClasses "$TMPD/pu.kkp" >/dev/null 2>&1; echo "compiled=$?"
TPu.new a; a.Hi; echo "a=$RESULT"
cp "$KKLASS_CKK_DIR/pu.ckk.sh" "$TMPD/pu.ckk.keep"; rm -f "$KKLASS_CKK_DIR/pu.ckk.sh"    # force the runtime translation
autoloadClasses "$TMPD/pu.kkp" --no-compile 2>"$TMPD/T12.e" >/dev/null; echo "runtime=$? warn=$(grep -c "WARNING: class 'TPu'" "$TMPD/T12.e") unit=${__KK_UNITS[pu]+registered}"
grep -c '^# Source unit: pu$' "$TMPD/pu.ckk.keep"
grep -c "^kk._ckk_begin pu pu.sh ''$" "$TMPD/pu.ckk.keep"
[[ -f "$KKLASS_CKK_DIR/pu.sh" && ! -e "$KKLASS_CKK_DIR/pu.runtime.sh" ]] && echo "runtime file pu.sh"
EOF
kt_test_start "N13 P9 + U36: a .kkp unit's cache names it by unit name and its site by the runtime translation <cache>/pu.sh; a compiled then a runtime load of it (in a bare shell: autoload supplies KBOOL_HOME) is the same place (one WARNING, not rebuilt)"
case_run T12
if [[ "$OUT" == $'compiled=0\na=hi\nruntime=0 warn=1 unit=registered\n2\n1\nruntime file pu.sh' ]]; then kt_test_pass "ok"; else kt_test_fail "out='${OUT//$'\n'/|}' err='$ERR'"; fi

# ---------------------------------------------------------------------------
mkdir -p "$TMPD/kp"
cat > "$TMPD/kp/dep.sh" <<'EOF'
[[ ${__KK_UNITS[@]@a} == A* ]] || source "${KBOOL_HOME-}/kbool.sh" || return 2
kk.unit dep || return $__kk_unit_rc
dep_loaded=$(( ${dep_loaded:-0} + 1 ))
EOF
cat > "$TMPD/kp/good.kkp" <<'EOF'
// comment first
unit good;

uses dep,
     dep;

interface

type
  TGood = class
  public
    function Hi;
  end;

implementation

function TGood.Hi;
begin
RESULT=good
end;

end.
EOF
sed 's/^unit good;/unit Good;/' "$TMPD/kp/good.kkp" > "$TMPD/kp/bad.kkp"
printf 'interface\nunit late;\nend.\n' > "$TMPD/kp/late.kkp"
printf 'unit 9x;\nend.\n' > "$TMPD/kp/malf.kkp"
printf 'uses a, b c;\nend.\n' > "$TMPD/kp/badu.kkp"
printf '// c\nunit ucom; // trailing\nend.\n' > "$TMPD/kp/ucom.kkp"
printf 'unit scom;\nuses a, b; // two units\ninterface\nend.\n' > "$TMPD/kp/scom.kkp"
printf 'uses dep;\nend.\n' > "$TMPD/kp/nounit.kkp"
cat > "$TMPD/T13.sh" <<'EOF'
K="$KKLASS_DIR/kklass_kkp.sh"; cd "$TMPD/kp"
for f in bad late malf badu ucom scom; do
    "$BASH" "$K" "$f.kkp" "$f.sh" 2>"$TMPD/T13.$f"; printf '%s=%s:%s ' "$f" "$?" "$([[ -s $f.sh ]] && echo written || echo none)"
done; echo
"$BASH" "$K" good.kkp good.sh; echo "good=$?"
sed -n 2,3p good.sh
grep -c '^kk.uses dep dep || return$' good.sh
"$BASH" "$K" nounit.kkp nounit.sh; grep -A1 -F kbool.sh nounit.sh
grep -c 'KBOOL_HOME:-' good.sh nounit.sh | tr '\n' ' '; echo
"$BASH" -c 'source "$1/kklass.sh"; source ./good.sh; echo "no KBOOL_HOME: rc=$?"' _ "$KKLASS_DIR" 2>/dev/null
export KBOOL_HOME="$KBOOL_ROOT"
source "$KKLASS_DIR/kklass.sh"
source ./good.sh; echo "src=$? dep=$dep_loaded"
TGood.new g; g.Hi; echo "g=$RESULT"
source ./good.sh; echo "again=$? dep=$dep_loaded"
kk._unit_has_header good.sh good && echo "indexable header"
EOF
kt_test_start "N14 U36/U33 + review R4/R5: unit name != file stem, a late unit, a malformed unit, a bad uses list and a comment after a unit/uses statement are translation errors with FILE:LINE (rc 1, nothing written); unit/uses translate to the §7.4 user header (no baked path) and kk.uses; the translated unit needs KBOOL_HOME (or kbool), then loads once"
case_run T13
want=$'bad=1:none late=1:none malf=1:none badu=1:none ucom=1:none scom=1:none \ngood=0'
want+=$'\n[[ ${__KK_UNITS[@]@a} == A* ]] || source "${KBOOL_HOME-}/kbool.sh" || return 2\nkk.unit good || return $__kk_unit_rc\n1'
want+=$'\n[[ ${__KK_UNITS[@]@a} == A* ]] || source "${KBOOL_HOME-}/kbool.sh" || return 2\nkk.uses dep || return'
want+=$'\ngood.sh:0 nounit.sh:0 \nno KBOOL_HOME: rc=2\nsrc=0 dep=1\ng=good\nagain=0 dep=1\nindexable header'
e="$(fl T13.bad)"
if [[ "$OUT" == "$want" && "$e" == *"unit name 'Good' does not match the file name 'bad.kkp'"* && "$(fl T13.late)" == *"late.kkp:2:"*"must be the first statement"* \
      && "$(fl T13.malf)" == *"malf.kkp:1: malformed unit statement"* && "$(fl T13.badu)" == *"badu.kkp:1:"*"not a unit name: 'b c'"* \
      && "$(fl T13.ucom)" == *"ucom.kkp:2:"*"comments after a statement are not supported"* \
      && "$(fl T13.scom)" == *"scom.kkp:2:"*"comments after a statement are not supported"* ]]; then
    kt_test_pass "ok"
else
    kt_test_fail "out='${OUT//$'\n'/|}' want='${want//$'\n'/|}' err='$ERR' errs='$(fl T13.bad T13.late T13.malf T13.badu T13.ucom T13.scom)'"
fi

# ---------------------------------------------------------------------------
mkdir -p "$TMPD/us"
cat > "$TMPD/us/myu.sh" <<'EOF'
[[ ${__KK_UNITS[@]@a} == A* ]] || source "${KBOOL_HOME-}/kbool.sh" || return 2
kk.unit myu || return $__kk_unit_rc
myu_n=$(( ${myu_n:-0} + 1 ))
EOF
cat > "$TMPD/us/caller.sh" <<'EOF'
uses myu; echo "uses=$? n=$myu_n"
uses myu; echo "again=$? n=$myu_n"
uses nosuchunit 2>/dev/null; echo "missing=$?"
EOF
cat > "$TMPD/T14.sh" <<'EOF'
source "$KKLASS_DIR/kklass_pascal.sh"
uses myu 2>"$TMPD/T14.e"; echo "nokbool=$?"
source "$KBOOL_ROOT/kbool.sh"
source "$TMPD/us/caller.sh"
EOF
kt_test_start "N15 U32: 'uses' in the Pascal DSL = kk.uses from the CALLING file's folder, once; without kbool rc 2 with a message"
case_run T14
if [[ "$OUT" == $'nokbool=2\nuses=0 n=1\nagain=0 n=1\nmissing=2' && "$(fl T14.e)" == *"uses: kbool.sh is not loaded"* ]]; then
    kt_test_pass "ok"
else
    kt_test_fail "out='${OUT//$'\n'/|}' e='$(fl T14.e)' err='$ERR'"
fi

# ---------------------------------------------------------------------------
mkdir -p "$TMPD/mv/P1/.ckk"
cat > "$TMPD/mv/P1/myu.sh" <<'EOF'
[[ ${__KK_UNITS[@]@a} == A* ]] || source "${KBOOL_HOME-}/kbool.sh" || return 2
kk.unit myu || return $__kk_unit_rc
source "$KBOOL_HOME/kklass/kklass.sh"
defineClass TMu "" property a method who 'echo myu'
EOF
cat > "$TMPD/T15.sh" <<'EOF'
KBOOL_HOME="$KBOOL_ROOT" "$BASH" "$KKLASS_DIR/kklass_compiler.sh" "$TMPD/mv/P1/myu.sh" "$TMPD/mv/P1/.ckk/myu.ckk.sh" >/dev/null 2>&1; echo "compile=$?"
grep -c "^kk._ckk_begin myu ../myu.sh " "$TMPD/mv/P1/.ckk/myu.ckk.sh"
mv "$TMPD/mv/P1" "$TMPD/mv/P2"
"$BASH" -c 'source "$1/kbool.sh"; source "$2/.ckk/myu.ckk.sh"; echo "ckk=$?"
            source "$2/myu.sh" 2>"$3"; echo "unit=$? dup=$(grep -c "Duplicate identifier" "$3") warn=$(grep -c WARNING "$3")"
            kk.uses "$2/myu.sh"; echo "uses=$?"; TMu.new o; o.who' _ "$KBOOL_ROOT" "$TMPD/mv/P2" "$TMPD/T15.e"
EOF
kt_test_start "N16 P9 (review R2, critic k1): a unit's cache records its source relative to the cache folder: after the project moved, the cache and then its unit sourced directly are the same place (one WARNING, no Duplicate identifier), and kk.uses of it succeeds"
case_run T15
if [[ "$OUT" == $'compile=0\n1\nckk=0\nunit=0 dup=0 warn=1\nuses=0\nmyu' ]]; then kt_test_pass "ok"; else kt_test_fail "out='${OUT//$'\n'/|}' err='$ERR' e='$(fl T15.e)'"; fi

# ---------------------------------------------------------------------------
mkdir -p "$TMPD/tree/kkore" "$TMPD/tree/kklass" "$TMPD/mt"
cp "$KBOOL_ROOT/kbool.sh" "$TMPD/tree/"
cp "$KBOOL_ROOT"/kkore/*.sh "$TMPD/tree/kkore/"
cp "$KKLASS_DIR"/kklass*.sh "$TMPD/tree/kklass/"
cat > "$TMPD/mt/m.kkp" <<'EOF'
unit m;
interface
type
  TMt = class
  public
    procedure P;
  end;
implementation
procedure TMt.P;
begin
echo p
end;
end.
EOF
printf 'defineClass TMk "" property a\n' > "$TMPD/mt/k.kk"
cat > "$TMPD/T16.sh" <<'EOF'
T="$TMPD/tree"; C="$TMPD/mt/ckk"
load() { KKLASS_CKK_DIR="$C" "$BASH" -c 'source "$1/kklass/kklass_autoload.sh"; autoloadClasses "$2"' _ "$T" "$1" 2>&1 | grep -c "$2"; }
load "$TMPD/mt/m.kkp" "Compilation successful"
load "$TMPD/mt/k.kk" "Compilation successful"
touch -d '2001-01-01 00:00:00' "$T"/kklass/*.sh "$TMPD/mt/m.kkp" "$TMPD/mt/k.kk"
touch -d '2002-01-01 00:00:00' "$C/m.ckk.sh" "$C/k.ckk.sh"
load "$TMPD/mt/m.kkp" "Using cached compiled file"
touch -d '2003-01-01 00:00:00' "$T/kklass/kklass_kkp.sh"
load "$TMPD/mt/m.kkp" "compiler/runtime is newer than the cache"
load "$TMPD/mt/k.kk" "Using cached compiled file"
EOF
kt_test_start "N17 review R6: a .kkp cache older than kklass_kkp.sh is recompiled; a .kk cache is not (a copy of the tree, mtimes set by touch)"
case_run T16
if [[ "$OUT" == $'1\n1\n1\n1\n1' ]]; then kt_test_pass "ok"; else kt_test_fail "out='${OUT//$'\n'/|}' err='$ERR'"; fi

# ---------------------------------------------------------------------------
cat > "$TMPD/T17.sh" <<'EOF'
source "$KKLASS_DIR/kklass.sh"
declare -F kkp.compile >/dev/null && echo "kkp loaded" || echo "kkp not loaded"
defineClass kkp "" property a 2>"$TMPD/T17.e"; echo "class kkp=$?"
defineClass TK "" property a; TK.new kkp 2>/dev/null; echo "new kkp=$?"
EOF
kt_test_start "N18 review R7: kklass declares kk and kkp when it loads — 'defineClass kkp' is refused even when kklass_kkp.sh is not loaded"
case_run T17
if [[ "$OUT" == $'kkp not loaded\nclass kkp=1\nnew kkp=1' && "$(fl T17.e)" == *"'kkp' is a function namespace (kkp.* of unit kklass ("*"kklass_kkp.sh))"* ]]; then
    kt_test_pass "ok"
else
    kt_test_fail "out='${OUT//$'\n'/|}' e='$(fl T17.e)'"
fi

kt_test_log "140_TakenNames.sh completed"
