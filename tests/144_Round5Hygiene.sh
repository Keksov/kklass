#!/usr/bin/env bash
# Round5Hygiene (kklass round 5 / P13; PLAN.md "# Round 5", findings K3, K3b,
# K4, K5, K6; decisions DR17, DR14, DR15, DR19).
#   K3/DR17  under the caller's `shopt -s nocasematch` every `[[ == ]]`, `case`
#            and `${x//pat/}` of kklass folded case — quoted right-hand sides
#            too: kk.derivesFrom Foo foo answered 0, class foo passed Foo's
#            private check silently, the token parsers took PROPERTY / METHOD,
#            a property A or a method M next to a / m was dropped, a Pascal body
#            `echo Inherited;` was rewritten. Every public verb and the runtime
#            visibility check now start with an ENTRY GUARD (nocasematch off
#            around the core, the caller's setting restored).
#   K3b      an unknown declaration token was dropped silently (`*) shift ;;`),
#            and a token missing its arguments (`method m` without a body,
#            `static_method s`) looped forever: both are refused, rc 2, naming
#            the token (defineClass and kk._build_class_runtime).
#   K4/DR14  a CLASS may not take the name of a live INSTANCE (Duplicate
#            identifier) on every declaration path; a live instance = X_class
#            names a registered class AND X_data is an associative array, so a
#            user's plain X_class variable is not one (also kk._name_in_use:
#            `css_class=btn; kk.namespace css` was refused).
#   K5/DR15  KKLASS_EXPORT_FUNCTIONS is gone (ONE warning when still set); a
#            child shell bootstraps kbool itself (`source kbool.sh; kk.uses ...`).
#   K6/DR19  the examples load kklass the canonical way and keep their files
#            in a temp dir of their own (static checks here; the output gate is
#            run by hand, PLAN.md P13).
# The K4/K5 cases run in a child bash (fresh registries), files in $TMPD; kbool
# loads with an empty, private config (HOME, __KK_CFG_ETC, no KBOOL_CONFIG).

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "Round5Hygiene" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KBOOL_ROOT="$(cd "$KKLASS_DIR/.." && pwd)"
source "$KKLASS_DIR/kklass_pascal.sh"
source "$KKLASS_DIR/kklass_serializable.sh"
source "$KKLASS_DIR/kklass_autoload.sh"

TMPD="$(mktemp -d "${TMPDIR:-/tmp}/kk144.XXXXXX")" && TMPD="$(cd "$TMPD" && pwd)"
mkdir -p "$TMPD/home" "$TMPD/etc"
kk144_cleanup() { rm -rf "$TMPD"; }
kt_fixture_cleanup_register kk144_cleanup
ERRF="$TMPD/err"
# nlines TEXT -> N (number of lines; 0 for empty)
nlines() { N=0; [[ -z "$1" ]] && return 0; local -a a; mapfile -t a <<<"$1"; N=${#a[@]}; }

# case_run NAME — run $TMPD/NAME.sh in a child bash (cwd $TMPD); OUT, ERR, RC.
case_run() {
    ( cd "$TMPD" && env -u KBOOL_CONFIG -u KBOOL_HOME -u USERPROFILE -u ProgramData -u KKLASS_CKK_DIR \
        -u KKLASS_EXPORT_FUNCTIONS HOME="$TMPD/home" __KK_CFG_ETC="$TMPD/etc" \
        KKLASS_DIR="$KKLASS_DIR" TMPD="$TMPD" KBOOL_ROOT="$KBOOL_ROOT" \
        "$BASH" "$TMPD/$1.sh" >"$TMPD/$1.out" 2>"$TMPD/$1.err" ); RC=$?
    OUT="$(<"$TMPD/$1.out")"; ERR="$(<"$TMPD/$1.err")"
}

# ===========================================================================
# K3 — nocasematch (every case sets it itself and checks it is kept)
# ===========================================================================
kt_test_start "H1 K3 nocasematch: kk.derivesFrom compares class names exactly (Foo/foo 1, Kid/base 1, Kid/Base 0); nocasematch kept"
defineClass H1Base ""; defineClass H1Kid H1Base
shopt -s nocasematch
kk.derivesFrom H1Foo h1foo; r1=$?
kk.derivesFrom H1Kid h1base; r2=$?
kk.derivesFrom H1Kid H1Base; r3=$?
kk.derivesFrom H1Kid H1Kid; r4=$?
shopt -q nocasematch && k=kept || k=lost
shopt -u nocasematch
if [[ "$r1$r2$r3$r4 $k" == "1100 kept" ]]; then kt_test_pass "exact"; else kt_test_fail "rc=$r1$r2$r3$r4 nocasematch $k"; fi

kt_test_start "H2 K3 nocasematch: class h2foo touching a private member of class H2Foo is WARNED (the runtime visibility check is exact); nocasematch kept"
declareClass H2Foo ""; privateSection; procedure secret; publicSection; procedure open; endClass
implement H2Foo.secret 'echo s'; implement H2Foo.open 'echo o'; endImplementation H2Foo
defineClass h2foo "" method poke 'local o=$1; $o.secret'
H2Foo.new h2a; h2foo.new h2b
shopt -s nocasematch
o="$(h2b.poke h2a 2>"$ERRF")"; e="$(<"$ERRF")"
shopt -q nocasematch && k=kept || k=lost
shopt -u nocasematch
if [[ "$o" == s && "$e" == *"private method 'H2Foo.secret' accessed from 'h2foo'"* && $k == kept ]]; then
    kt_test_pass "$e"
else
    kt_test_fail "o='$o' e='$e' nocasematch $k"
fi

kt_test_start "H3 K3 nocasematch: the declarative DSL keeps members that differ in case only (property a / A, procedure m / M); nocasematch kept"
shopt -s nocasematch
{
    declareClass H3P ""; property a; property A; procedure m; procedure M; endClass
    implement H3P.m 'echo lower'; implement H3P.M 'echo upper'; endImplementation H3P
} 2>"$ERRF"; rc=$?
shopt -q nocasematch && k=kept || k=lost
shopt -u nocasematch
o=""
if declare -F H3P.new >/dev/null; then
    H3P.new h3; h3.a = 1 2>>"$ERRF"; h3.A = 2 2>>"$ERRF"
    o="$(h3.a 2>>"$ERRF")/$(h3.A 2>>"$ERRF")/$(h3.m 2>>"$ERRF")/$(h3.M 2>>"$ERRF")"
fi
if [[ $rc == 0 && "$o" == "1/2/lower/upper" && $k == kept ]]; then kt_test_pass "$o"; else kt_test_fail "rc=$rc o='$o' err='$(<"$ERRF")' nocasematch $k"; fi

kt_test_start "H4 K3 nocasematch: Pascal and declarative bodies are not rewritten by a case-folded 'inherited' match (echo Inherited; stays); nocasematch kept"
shopt -s nocasematch
{
    class H4Pas; proc Speak; end
    H4Pas.Speak() { echo Inherited; }
    build H4Pas
    declareClass H4Dec ""; procedure n; endClass; implement H4Dec.n 'echo Inherited;'; endImplementation H4Dec
} 2>"$ERRF"
shopt -q nocasematch && k=kept || k=lost
shopt -u nocasematch
H4Pas.new h4p; H4Dec.new h4d
o="$(h4p.Speak 2>&1)|$(h4d.n 2>&1)"
if [[ "$o" == "Inherited|Inherited" && $k == kept ]]; then kt_test_pass "$o"; else kt_test_fail "o='$o' err='$(<"$ERRF")' nocasematch $k"; fi

kt_test_start "H5 K3+K3b nocasematch: defineClass tokens are exact — PROPERTY / METHOD are unknown tokens: rc 2, the token named, nothing built; nocasematch kept"
shopt -s nocasematch
defineClass H5X "" PROPERTY q METHOD hello 'echo hi' 2>"$ERRF"; rc=$?
shopt -q nocasematch && k=kept || k=lost
shopt -u nocasematch
e="$(<"$ERRF")"
if [[ $rc == 2 && "$e" == *"unknown token 'PROPERTY'"*"H5X"* ]] && ! declare -F H5X.new >/dev/null && [[ $k == kept ]]; then
    kt_test_pass "$e"
else
    kt_test_fail "rc=$rc e='$e' new=$(declare -F H5X.new) nocasematch $k"
fi

kt_test_start "H6 K3 every public verb starts with the nocasematch entry guard (declare -f: the first statement tests nocasematch)"
bad=""
for f in kk.derivesFrom kk.isAbstract kk.class kk._warn_visibility kk._ckk_class defineClass defineMethod defineProcedure defineFunction \
         declareClass privateSection protectedSection publicSection classVar field property constructor virtual override abstract \
         procedure declareProcedure func declareFunction classProcedure classFunction endClass finalizeClass implement \
         implementConstructor endImplementation finalizeImplementation \
         class end public private protected static var proc destructor build \
         defineSerializableClass addSerializable saveObjects loadObjects autoloadClasses kkload kkrecompile \
         kk._build_class_runtime kk.register_static_methods; do
    body="$(declare -f "$f")" || { bad+=" $f:missing"; continue; }
    mapfile -t bl <<<"$body"
    # line 0 `NAME ()`, line 1 `{`, line 2 the first statement: the probe
    if [[ $f == kk._warn_visibility ]]; then
        # past its public fast path (a public access pays nothing)
        [[ "$body" == *"case a in"*"kk.decl._ncm_off kk._warn_visibility"* ]] || bad+=" $f"
        continue
    fi
    [[ "${bl[2]}" == *"a == A"*nocasematch* || "${bl[2]}" == *"case a in"* ]] || bad+=" $f"
done
if [[ -z "$bad" ]]; then kt_test_pass "all guarded"; else kt_test_fail "no guard:$bad"; fi

kt_test_start "H6b K3 nocasematch (review F1): the low-level builders are exact too — kk._build_class_runtime refuses PROPERTY (rc 2), kk.register_static_methods takes a static named __IMPL_x (only __impl_* is its own); nocasematch kept"
P6B.__IMPL_x() { RESULT=ix; }
shopt -s nocasematch
kk._build_class_runtime H6bLow "" PROPERTY q METHOD hi 'echo hi' 2>"$ERRF"; r1=$?
kk.register_static_methods P6B P6B P6B __IMPL_x 2>>"$ERRF"; r2=$?
shopt -q nocasematch && k=kept || k=lost
shopt -u nocasematch
e="$(<"$ERRF")"
if [[ $r1 == 2 && $r2 == 0 && $k == kept && "$e" == *"unknown token 'PROPERTY'"* && "$e" != *Reserved* ]] && ! declare -F H6bLow.new >/dev/null; then
    kt_test_pass "exact"
else
    kt_test_fail "r1=$r1 r2=$r2 nocasematch $k e='$e'"
fi

# ===========================================================================
# K3b — unknown / incomplete tokens
# ===========================================================================
kt_test_start "H7 K3b defineClass: an unknown token (PROPERTY, nocasematch off) is refused — rc 2, named, the class not built; the next class builds"
defineClass H7X "" PROPERTY q 2>"$ERRF"; rc=$?
e="$(<"$ERRF")"
defineClass H7Ok "" property q 2>/dev/null; rc2=$?
if [[ $rc == 2 && "$e" == *"unknown token 'PROPERTY'"* && $rc2 == 0 ]] && ! declare -F H7X.new >/dev/null; then
    kt_test_pass "$e"
else
    kt_test_fail "rc=$rc rc2=$rc2 e='$e'"
fi

kt_test_start "H8 K3b defineClass: a token missing its arguments (method m / static_method s / static_property / constructor at the end) is refused (rc 2, named) instead of looping forever"
if ! kt_need_timeout; then kt_test_pass "SKIP: $KT_TIMEOUT_WHY"
else
o=""
for args in "method m" "static_method s" "static_property" "constructor" "lazy_property p"; do
    # shellcheck disable=SC2086
    "$KT_TIMEOUT" 20 "$BASH" -c 'source "$1/kklass.sh" >/dev/null 2>&1; shift; defineClass H8X "" "$@"; echo "rc=$?"' _ "$KKLASS_DIR" $args >"$TMPD/h8.out" 2>"$TMPD/h8.err"
    t=$?
    o+="[$args] t=$t $(<"$TMPD/h8.out") $(grep -c "token '${args%% *}'" "$TMPD/h8.err");"
done
want="[method m] t=0 rc=2 1;[static_method s] t=0 rc=2 1;[static_property] t=0 rc=2 1;[constructor] t=0 rc=2 1;[lazy_property p] t=0 rc=2 1;"
if [[ "$o" == "$want" ]]; then kt_test_pass "refused"; else kt_test_fail "'$o'"; fi
fi   # kt_need_timeout

kt_test_start "H8b K3b (review F7): an EMPTY word between tokens keeps HEAD's behaviour (skipped, rc 0, class built) in defineClass and kk._build_class_runtime; a non-empty unknown word next to it is still refused"
defineClass H8bA "" property a "" method m 'echo m' "" 2>"$ERRF"; r1=$?
kk._build_class_runtime H8bB "" "" property b "" 2>>"$ERRF"; r2=$?
defineClass H8bC "" property c "" bogus 2>>"$ERRF"; r3=$?
e="$(<"$ERRF")"
o=""; if declare -F H8bA.new >/dev/null; then H8bA.new h8a; h8a.a = 1; o="$(h8a.a)$(h8a.m)"; fi
if [[ $r1 == 0 && $r2 == 0 && $r3 == 2 && "$o" == 1m && "$e" == *"unknown token 'bogus'"* && "$e" != *"token ''"* ]] && declare -F H8bB.new >/dev/null && ! declare -F H8bC.new >/dev/null; then
    kt_test_pass "empty skipped, bogus refused"
else
    kt_test_fail "r=$r1$r2$r3 o='$o' e='$e'"
fi

kt_test_start "H9 K3b kk._build_class_runtime: an unknown token is refused (rc 2, named), nothing built"
kk._build_class_runtime H9X "" property a bogus_token 2>"$ERRF"; rc=$?
e="$(<"$ERRF")"
if [[ $rc == 2 && "$e" == *"unknown token 'bogus_token'"* ]] && ! declare -F H9X.new >/dev/null; then kt_test_pass "$e"; else kt_test_fail "rc=$rc e='$e'"; fi

# ===========================================================================
# K4 — a class named like a live instance
# ===========================================================================
cat > "$TMPD/foo.kk" <<'EOF'
defineClass foo "" property b
EOF
cat > "$TMPD/K4.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh"; kk.uses kklass_pascal kklass_autoload || exit 9
export KKLASS_CKK_DIR=$TMPD/ckk4
defineClass TA "" property a method hi 'echo hi'
TA.new foo; foo.a = 7
before="$(declare -f foo.hi foo.a foo.property foo.call foo.delete)"
defineClass foo "" property b 2>>"$TMPD/K4.e"; echo "defineClass=$?"
declareClass foo ""; echo "declareClass=$?"; field x; endClass; endImplementation foo 2>>"$TMPD/K4.e"
class foo; proc hi; end; foo.hi() { echo IMPOSTER; }; build foo 2>>"$TMPD/K4.e"; echo "pascal=$?"
autoloadClasses "$TMPD/foo.kk" >/dev/null 2>>"$TMPD/K4.e"; echo "ckk=$?"
[[ "$(declare -f foo.hi foo.a foo.property foo.call foo.delete)" == "$before" ]] && echo "instance kept"
declare -F foo.new >/dev/null && echo "foo.new made" || echo "no foo.new"
echo "a=$(foo.a) hi=$(foo.hi) built=${_KKLASS_CLASS_SITE[foo]+yes}"
foo.delete
defineClass foo "" property b; echo "after delete=$?"
foo.new bar; bar.b = 3; echo "b=$(bar.b)"
EOF
kt_test_start "H10 K4 a class named like a live instance is refused (Duplicate identifier) on every path — defineClass, declareClass, Pascal, a .ckk cache; the instance kept; allowed after .delete"
case_run K4; e="$(<"$TMPD/K4.e")"
want=$'defineClass=1\ndeclareClass=1\npascal=1\nckk=0\ninstance kept\nno foo.new\na=7 hi=hi built=\nafter delete=0\nb=3'
n="$(cat "$TMPD/K4.e" "$TMPD/K4.err" | grep -c "Duplicate identifier: 'foo' is a live instance of class TA")"
sites="$(cat "$TMPD/K4.e" "$TMPD/K4.err" | grep -oE '(K4\.sh:[0-9]+|foo\.kk:1)$' | sort | tr '\n' ' ')"
if [[ "$OUT" == "$want" && $n == 4 && "$sites" == "K4.sh:6 K4.sh:7 K4.sh:8 foo.kk:1 " ]]; then
    kt_test_pass "$n refusals: $sites"
else
    kt_test_fail "out='${OUT//$'\n'/|}' refusals=$n e='${e//$'\n'/ | }' err='$ERR'"
fi

cat > "$TMPD/K4b.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh"; kk.uses kklass || exit 9
defineClass btn "" property a
css_class=btn; defineClass css "" property c; echo "class over X_class=$?"
nav_class=btn; kk.namespace nav; echo "namespace over X_class=$?"
declare -A menu_data=(); menu_class=nope; defineClass menu "" property m; echo "unregistered class=$?"
btn.new live; kk.namespace live 2>/dev/null; echo "namespace over instance=$?"
EOF
kt_test_start "H11 K4 a user's plain X_class variable is not a live instance (no false positive): defineClass css, kk.namespace nav build/declare; a real instance is still refused by kk.namespace"
case_run K4b
if [[ "$OUT" == $'class over X_class=0\nnamespace over X_class=0\nunregistered class=0\nnamespace over instance=2' && -z "$ERR" ]]; then
    kt_test_pass "ok"
else
    kt_test_fail "out='${OUT//$'\n'/|}' err='$ERR'"
fi

cat > "$TMPD/K4c.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh"; kk.uses kklass || exit 9
defineClass TC "" property a
declare -a arr=()
qux_class=TC; declare -n qux_data='arr[$(echo PWN-data >&2; echo 0)]'
defineClass qux "" property z; echo "data-nameref=$? built=${_KKLASS_CLASS_SITE[qux]+yes}"
declare -A zz_data=(); declare -n zz_class='arr[$(echo PWN-class >&2; echo 0)]'
defineClass zz "" property z; echo "class-nameref=$? built=${_KKLASS_CLASS_SITE[zz]+yes}"
declare -A nn_data=(); declare -n nn_class='arr[$(echo PWN-ns >&2; echo 0)]'
kk.namespace nn; echo "namespace=$?"
EOF
kt_test_start "H11b K4 (review F2, R14): kk._live_instance follows no nameref — an X_class / X_data that is a nameref to 'arr[\$(cmd)]' runs nothing (no PWN) and is not an instance (defineClass, kk.namespace)"
case_run K4c
if [[ "$OUT" == $'data-nameref=0 built=yes\nclass-nameref=0 built=yes\nnamespace=0' && "$ERR" != *PWN* && -z "$ERR" ]]; then
    kt_test_pass "no evaluation"
else
    kt_test_fail "out='${OUT//$'\n'/|}' err='$ERR'"
fi

cat > "$TMPD/K4d.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh"; kk.uses kklass || exit 9
defineClass TF "" property a; defineClass TG "" property a
TF.new f1; TF.new f2; TG.new g1
kk.class --forget TG 2>"$TMPD/K4d.e1"; echo "forget-TG=$?"
g1.delete; kk.class --forget TG 2>"$TMPD/K4d.e2"; echo "forget-TG-again=$?"
defineClass TH "" property a
kk.class --forget TH 2>"$TMPD/K4d.e3"; echo "forget-TH=$?"
kk.class --forget TF 2>"$TMPD/K4d.e4"; echo "forget-TF=$?"
defineClass f1 "" property b 2>/dev/null; echo "class-over-orphan=$?"
EOF
kt_test_start "H11c K4 (review F3): kk.class --forget CLASS prints ONE WARNING naming CLASS's live instances (their names are no longer protected); none when it has none"
case_run K4d
e1="$(<"$TMPD/K4d.e1")" e2="$(<"$TMPD/K4d.e2")" e3="$(<"$TMPD/K4d.e3")" e4="$(<"$TMPD/K4d.e4")"
nlines "$e4"
if [[ "$OUT" == $'forget-TG=0\nforget-TG-again=1\nforget-TH=0\nforget-TF=0\nclass-over-orphan=0' \
      && "$e1" == *"WARNING"*"TG"*"g1"* && -z "$e2" && -z "$e3" && $N == 1 && "$e4" == *"WARNING"*"f1"*"f2"* ]]; then
    kt_test_pass "$e4"
else
    kt_test_fail "out='${OUT//$'\n'/|}' e1='$e1' e2='$e2' e3='$e3' e4='$e4' err='$ERR'"
fi

# ===========================================================================
# K5 — KKLASS_EXPORT_FUNCTIONS removed
# ===========================================================================
kt_test_start "H12 K5 no kklass file exports functions (no 'export -f', no KKLASS_EXPORT_FUNCTIONS switch)"
hits="$(grep -nE 'export -f|KKLASS_EXPORT_FUNCTIONS:-' "$KKLASS_DIR"/kklass*.sh | grep -vE '^[^:]*:[0-9]+: *#')"
if [[ -z "$hits" ]]; then kt_test_pass "none"; else kt_test_fail "$hits"; fi

cat > "$TMPD/K5.sh" <<'EOF'
export KKLASS_EXPORT_FUNCTIONS=1
source "$KBOOL_ROOT/kbool.sh"; kk.uses kklass_pascal kklass_serializable kklass_autoload || exit 9
"$BASH" -c 'declare -F kk._is_ident >/dev/null && echo leaked || echo "child bare"'
EOF
kt_test_start "H13 K5 a still-set KKLASS_EXPORT_FUNCTIONS=1 gives ONE warning naming it and exports nothing"
case_run K5; nlines "$ERR"
if [[ "$OUT" == "child bare" && $N == 1 && "$ERR" == *KKLASS_EXPORT_FUNCTIONS* ]]; then kt_test_pass "$ERR"; else kt_test_fail "out='$OUT' err='$ERR'"; fi

cat > "$TMPD/K5b.sh" <<'EOF'
"$BASH" -c '
    source "$1/kbool.sh" && kk.uses kklass_pascal kklass_serializable || exit 9
    declareClass TChild ""; property v; procedure hi; endClass
    implement TChild.hi "echo child-\$v"; endImplementation TChild
    TChild.new c; c.v = ok; c.hi
    kk._is_ident ok_1 && ! kk._is_ident "a b" && echo ident-ok' _ "$KBOOL_ROOT"
EOF
kt_test_start "H14 K5 a child shell bootstraps kbool itself (source kbool.sh; kk.uses kklass_pascal kklass_serializable): declareClass, CLASS.new and kk._is_ident work there"
case_run K5b
if [[ "$OUT" == $'child-ok\nident-ok' && -z "$ERR" ]]; then kt_test_pass "ok"; else kt_test_fail "out='${OUT//$'\n'/|}' err='$ERR'"; fi

# ===========================================================================
# K6 — the examples (static checks; the output gate is PLAN.md P13's)
# ===========================================================================
kt_test_start "H15 K6 every example loads kklass the canonical way (source …/kbool.sh + kk.uses), no direct source of a kklass*.sh, also in child shells"
bad=""
for f in "$KKLASS_DIR"/examples/*.sh; do
    grep -q 'kklass[a-z_]*\.sh' <(grep -v '^\s*#' "$f" | grep 'source') && bad+=" ${f##*/}:direct"
    # demo.sh loads nothing itself: it runs every example in a bash of its own
    [[ ${f##*/} == demo.sh ]] || grep -q 'kbool\.sh' "$f" || bad+=" ${f##*/}:no-kbool"
    # a child shell is the bash running the example (review F5), not PATH's bash
    grep -v '^\s*#' "$f" | grep -qE '(^|[$( ])bash -c' && bad+=" ${f##*/}:PATH-bash-child"
done
grep -q 'source "\$SCRIPT_DIR/\.\./kklass' "$KKLASS_DIR/examples/README.md" && bad+=" README:direct"
if [[ -z "$bad" ]]; then kt_test_pass "canonical"; else kt_test_fail "$bad"; fi

kt_test_start "H16 K6 no example writes into the caller's cwd: no 'rm -rf .ckk' / 'mkdir -p .ckk' / bare mktemp; temp dirs come from a named template with a cleanup trap (EXIT + TERM INT HUP)"
bad=""
for f in "$KKLASS_DIR"/examples/*.sh; do
    b=${f##*/}
    grep -v '^\s*#' "$f" | grep -qE '(rm -rf|mkdir -p) \.ckk' && bad+=" $b:cwd-ckk"
    grep -v '^\s*#' "$f" | grep -qE 'mktemp( -d)?( *[)|;]|$)' && bad+=" $b:bare-mktemp"
    if grep -q 'mktemp' "$f"; then
        grep -q 'trap .* EXIT' "$f" && grep -qE 'trap .*(TERM|INT|HUP)' "$f" || bad+=" $b:no-trap"
    fi
done
if [[ -z "$bad" ]]; then kt_test_pass "clean"; else kt_test_fail "$bad"; fi

cd / || :
kt_test_log "144_Round5Hygiene.sh completed"
