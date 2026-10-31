#!/usr/bin/env bash
# Round6 (kklass round 6 / P16; PLAN.md "# Round 6", findings E1, E2, E3;
# owner decisions DR20, DR21, DR22; research scratchpad/research_r6).
#   §A DR20 (a) export-safe binding: a property / static-property nameref is
#      bound `local -n +x` (kk._run_frame_body, the capturing static
#      dispatcher), so a child of a method sees the GLOBAL value of an exported
#      variable of the same name (before: the nameref inherited the export flag
#      and exported its TARGET NAME, `MYENV=e_data[MYENV]`); .ckk format 3
#   §B DR20 (b) variable-like members (property, static property, lazy
#      property, field) named like bash's own variables, TZ, TERM, USER,
#      LOGNAME or with the prefixes BASH_ LC_ COMP_ READLINE_ HIST are refused
#      at declaration on every path (defineClass, declarative, Pascal,
#      serializable, .kkp, .ckk compile); class and method names are not checked
#   §C DR21 kk.frameReset: the EXIT handler after a `set -e` exit inside a
#      method body clears the stale frame and restores localvar_unset
#   §D DR22 set -u: the accessor of a declared, never-assigned property reads
#      "" (rc 0); the examples run under `bash -u`

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "Round6" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KBOOL_ROOT="$(cd "$KKLASS_DIR/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"
source "$KKLASS_DIR/kklass_pascal.sh"
source "$KKLASS_DIR/kklass_serializable.sh"

TMPD="$(mktemp -d "${TMPDIR:-/tmp}/kk147.XXXXXX")" && TMPD="$(cd "$TMPD" && pwd)"
mkdir -p "$TMPD/home" "$TMPD/etc"
OUTF="$TMPD/out" ERRF="$TMPD/err"
kk147_cleanup() { rm -rf "$TMPD"; }
kt_fixture_cleanup_register kk147_cleanup

# run CMD... — in THIS shell; stdout/stderr/rc land in OUT/ERR/RC.
run() {
    "$@" >"$OUTF" 2>"$ERRF"; RC=$?
    OUT="$(<"$OUTF")"; ERR="$(<"$ERRF")"
}
# check LABEL WANT GOT
check() {
    if [[ "$3" == "$2" ]]; then kt_test_pass "$1"; else kt_test_fail "$1: got '${3//$'\n'/|}' want '${2//$'\n'/|}'"; fi
}
# case_run NAME — run $TMPD/NAME.sh in a child bash (cwd $TMPD); OUT, ERR, RC.
case_run() {
    ( cd "$TMPD" && env -u KBOOL_CONFIG -u KBOOL_HOME -u USERPROFILE -u ProgramData -u KKLASS_CKK_DIR \
        -u MYENV -u MYSTAT HOME="$TMPD/home" __KK_CFG_ETC="$TMPD/etc" \
        KKLASS_DIR="$KKLASS_DIR" TMPD="$TMPD" KBOOL_ROOT="$KBOOL_ROOT" \
        "$BASH" "$TMPD/$1.sh" >"$TMPD/$1.out" 2>"$TMPD/$1.err" ); RC=$?
    OUT="$(<"$TMPD/$1.out")"; ERR="$(<"$TMPD/$1.err")"
}

# ===========================================================================
# §A export-safe binding (DR20 a)
# ===========================================================================
# ce NAMES — the NAMES=VALUE lines a child process gets (env is a child).
cat > "$TMPD/cls.inc" <<'EOF'
ce() { command env | command grep -E "^($1)=" | command sort | command tr '\n' ' '; }
defineClass Tool "" property x \
  method run 'echo "cross: MYENV=${MYENV-UNSET} child=[$(ce MYENV)]"' \
  method runs 'echo "cross: MYSTAT=${MYSTAT-UNSET} child=[$(ce MYSTAT)]"'
defineClass Env "" property MYENV static_property MYSTAT \
  method own 'echo "own: MYENV=${MYENV-UNSET} child=[$(ce MYENV)]"' \
  method w 'MYENV=written; echo "w: child=[$(ce MYENV)]"' \
  method cross 't.run' method crosss 't.runs' \
  method st 'echo "st: MYSTAT=${MYSTAT-UNSET} child=[$(ce MYSTAT)]"' \
  method callfat 'Env.fat' \
  static_method fat 'echo "fat: MYSTAT=${MYSTAT-UNSET} child=[$(ce MYSTAT)]"'
defineClass Sib "" property MYSTAT method callfat 'Env.fat'
EOF
cat > "$TMPD/A1.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh"; kk.uses kklass
export MYENV=globalval MYSTAT=gstat
source "$TMPD/cls.inc"
Tool.new t; Env.new e; Env.new e2; Sib.new sb
e.MYENV = propval; Env.MYSTAT = sval; sb.MYSTAT = sibval
e.own; e2.own; e.cross; e.st; Env.fat; echo; e.callfat; echo; e.crosss; sb.callfat; echo
e.w; echo "e.MYENV=$(e.MYENV)"
echo "top: MYENV=$MYENV MYSTAT=$MYSTAT child=[$(ce 'MYENV|MYSTAT')]"
EOF
kt_test_start "A1 a child of a method sees the GLOBAL value of an exported variable a property / static property of the same name hides (own body, never-set property, another class's callee, static from a method, fat static, a static called from a class binding the name); the body still reads/writes the member"
case_run A1
want='own: MYENV=propval child=[MYENV=globalval ]
own: MYENV=UNSET child=[MYENV=globalval ]
cross: MYENV=UNSET child=[MYENV=globalval ]
st: MYSTAT=sval child=[MYSTAT=gstat ]
fat: MYSTAT=sval child=[MYSTAT=gstat ]
fat: MYSTAT=sval child=[MYSTAT=gstat ]
cross: MYSTAT=UNSET child=[MYSTAT=gstat ]
fat: MYSTAT=sval child=[MYSTAT=gstat ]
w: child=[MYENV=globalval ]
e.MYENV=written
top: MYENV=globalval MYSTAT=gstat child=[MYENV=globalval MYSTAT=gstat ]'
check "A1" "$want|rc=0 err=" "$OUT|rc=$RC err=$ERR"

# TZ / LANG: refused as member names by every declaration path (§B), so the
# binding itself is pinned through the raw builder kk._build_class_runtime
# (identifier validation only — what the .ckk dump of an older class holds).
cat > "$TMPD/A2.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh"; kk.uses kklass
export TZ=Asia/Tokyo LANG=C.UTF-8
ce() { command env | command grep -E "^($1)=" | command sort | command tr '\n' ' '; }
kk._build_class_runtime RawEnv "" property TZ property LANG static_property TERM \
  method own 'echo "own: TZ=${TZ-UNSET} child=[$(ce "TZ|LANG")]"' \
  static_method fat 'echo "fat: TERM=${TERM-UNSET} child=[$(ce TERM)]"'
RawEnv.new r; r.TZ = UTC; r.LANG = POSIX; RawEnv.TERM = vt-prop
export TERM=xterm-global
r.own; RawEnv.fat
EOF
kt_test_start "A2 TZ / LANG / TERM (raw builder): children get the global TZ=Asia/Tokyo LANG=C.UTF-8 TERM=xterm-global, not the nameref target"
case_run A2
check "A2" "own: TZ=UTC child=[LANG=C.UTF-8 TZ=Asia/Tokyo ]|fat: TERM=vt-prop child=[TERM=xterm-global ]|rc=0 err=" "${OUT//$'\n'/|}|rc=$RC err=$ERR"

kt_test_start "A3 the three binding sites carry +x (kk._run_frame_body properties + static properties, the fat static dispatcher)"
defineClass A3F "" static_property sp static_method m ':'
n1=$(declare -f kk._run_frame_body | grep -c 'local -n +x "\${__kk_p}=')
n2=$(declare -f A3F.m | grep -c 'local -n +x sp=A3F_static_sp')
check "A3" "2 1" "$n1 $n2"

# .ckk cache format 3 (the fat dispatchers are dumped verbatim)
cat > "$TMPD/fmt3.kk" <<'EOF'
defineClass F3S "" static_property MYSTAT static_method fat 'echo "fat child=[$(command env | command grep -E "^MYSTAT=" | command tr "\n" " ")]"'
EOF
cat > "$TMPD/A4.sh" <<'EOF'
export KKLASS_CKK_DIR=$TMPD/ckk
source "$KKLASS_DIR/kklass_autoload.sh"
export MYSTAT=gstat
autoloadClasses "$TMPD/fmt3.kk" 2>/dev/null; echo "first=$?"
c=$KKLASS_CKK_DIR/fmt3.ckk.sh
grep '^kk._ckk_format ' "$c"
grep -c 'local -n +x MYSTAT=F3S_static_MYSTAT' "$c"
F3S.MYSTAT = sval; F3S.fat
EOF
kt_test_start "A4 a compiled cache is format 4 and holds the +x fat-static binding; its static's child sees the global value"
case_run A4
check "A4" "first=0|kk._ckk_format 4|1|fat child=[MYSTAT=gstat ]|rc=0" "${OUT//$'\n'/|}|rc=$RC"

# a FORMAT-2 cache (P15's: fat bindings without +x), newer than source + kklass
cat > "$TMPD/A5.sh" <<'EOF'
export KKLASS_CKK_DIR=$TMPD/ckk
source "$KKLASS_DIR/kklass_autoload.sh"
export MYSTAT=gstat
c=$KKLASS_CKK_DIR/fmt3.ckk.sh
sed -e 's/^kk._ckk_format 4$/kk._ckk_format 2/' -e 's/local -n +x /local -n /' "$c" > "$c.old"; mv "$c.old" "$c"; touch "$c"
autoloadClasses "$TMPD/fmt3.kk" 2>"$TMPD/A5.e"; echo "rc=$?"
grep -c 'cache format 2 is not' "$TMPD/A5.e"
grep '^kk._ckk_format ' "$c"
F3S.MYSTAT = sval; F3S.fat
EOF
kt_test_start "A5 a format-2 cache is REBUILT by autoloadClasses (one message); the rebuilt one is format 4 and export-safe"
case_run A5
check "A5" "rc=0|1|kk._ckk_format 4|fat child=[MYSTAT=gstat ]|rc=0" "${OUT//$'\n'/|}|rc=$RC"

cat > "$TMPD/A6.sh" <<'EOF'
export KKLASS_CKK_DIR=$TMPD/ckk
source "$KKLASS_DIR/kklass_autoload.sh"
export MYSTAT=gstat
c=$KKLASS_CKK_DIR/fmt3.ckk.sh
sed -e 's/^kk._ckk_format 4$/kk._ckk_format 2/' -e 's/local -n +x /local -n /' "$c" > "$c.old"; mv "$c.old" "$c"; touch "$c"
autoloadClasses "$TMPD/fmt3.kk" --no-compile 2>"$TMPD/A6.e"; echo "rc=$?"
grep -c 'runtime mode' "$TMPD/A6.e"
grep '^kk._ckk_format ' "$c"
F3S.MYSTAT = sval; F3S.fat
EOF
kt_test_start "A6 --no-compile with a format-2 cache runs the source (runtime mode): export-safe; the cache is left as it is"
case_run A6
check "A6" "rc=0|1|kk._ckk_format 2|fat child=[MYSTAT=gstat ]|rc=0" "${OUT//$'\n'/|}|rc=$RC"

cat > "$TMPD/A7.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh"; kk.uses kklass
source "$TMPD/ckk/fmt3.ckk.sh"; echo "rc=$?"
declare -F F3S.fat >/dev/null && echo loaded || echo "not loaded"
EOF
kt_test_start "A7 a format-2 cache sourced DIRECTLY loads no class, says why once, rc 1"
case_run A7
e1="${ERR//$'\n'/|}"
if [[ "$OUT" == $'rc=1\nnot loaded' && "$ERR" == *"cache format 2"*"format 3"*"recompile"* && "$e1" != *"|"* ]]; then
    kt_test_pass "A7"
else
    kt_test_fail "A7: out='${OUT//$'\n'/|}' err='$e1'"
fi

# review F1: set -a (allexport) in the caller exported every bind with its
# TARGET NAME (`local -n +x` loses to allexport) and the runtime's own locals
cat > "$TMPD/A8.sh" <<'EOF2'
source "$KBOOL_ROOT/kbool.sh"; kk.uses kklass
export MYENV=globalval
ce() { command env | command grep -E "^($1)=" | command sort | command tr '\n' ' '; }
defineClass Tool "" property x method run 'echo "cross: child=[$(ce "MYENV|MYSTAT|this|state|__kk_[a-z_]*")]"'
defineClass SA "" property MYENV static_property MYSTAT \
  method own 'echo "own: a=${-//[!a]/} child=[$(ce "MYENV|MYSTAT|this|__inst__|__class__|state|__kk_[a-z_]*")]"; z=fromBody; echo "user var: [$(ce z)]"' \
  method w 'MYENV=written; MYSTAT=swritten' method cross 't.run' \
  method off 'set +a; t.run; echo "after inner: a=[${-//[!a]/}]"; set -a' \
  method fatin 'SA.fat' \
  static_method fat 'echo "fat: a=${-//[!a]/} child=[$(ce "MYENV|MYSTAT|state|__kk_[a-z_]*")]"; zs=fromFat; echo "fat user var: [$(ce zs)]"'
Tool.new t; SA.new k; k.MYENV = prop; SA.MYSTAT = sval
set -a
k.own; k.w; echo "storage: $(k.MYENV) $(SA.MYSTAT)"; k.cross; k.off; echo "after off: a=[${-//[!a]/}]"
SA.fat; echo; k.fatin; echo
k.call nosuch 2>/dev/null; echo "after missing .call: a=[${-//[!a]/}]"; k.parent nosuch 2>/dev/null; echo "after missing .parent: a=[${-//[!a]/}]"; Tool.new t2; echo "after .new without constructor: a=[${-//[!a]/}]"
set +a
unset MYENV; set -a; k.own; set +a
EOF2
kt_test_start "A8 (review F1, critic r6b) set -a in the caller: no bind (property, static, state, this, __inst__, __class__) and no private __kk_* local reaches a child; error paths and .new keep allexport on (own body, cross-class callee, fat static from the top and from a method); writes reach storage; the body keeps allexport (its own assignments are exported); a body that turns it off stays off for its callees; also when the global is unset"
case_run A8
want='own: a=a child=[MYENV=globalval ]
user var: [z=fromBody ]
storage: written swritten
cross: child=[MYENV=globalval ]
cross: child=[MYENV=globalval ]
after inner: a=[]
after off: a=[a]
fat: a=a child=[MYENV=globalval ]
fat user var: [zs=fromFat ]
fat: a=a child=[MYENV=globalval ]
fat user var: [zs=fromFat ]
after missing .call: a=[a]
after missing .parent: a=[a]
after .new without constructor: a=[a]
own: a=a child=[]
user var: [z=fromBody ]'
check "A8" "$want|rc=0 err=" "$OUT|rc=$RC err=$ERR"

# review F2: state / this / __inst__ / __class__ were plain (or -n) locals:
# an exported global of that name made them exported with the frame's value
cat > "$TMPD/A9.sh" <<'EOF2'
source "$KBOOL_ROOT/kbool.sh"; kk.uses kklass
export state=gstate this=gthis __inst__=ginst __class__=gclass
ce() { command env | command grep -E "^($1)=" | command sort | command tr '\n' ' '; }
defineClass SB "" property y method m 'echo "body: this=$this state=${!state} child=[$(ce "state|this|__inst__|__class__")]"' method c 't2.m'
SB.new k; SB.new t2; k.m; k.c
EOF2
kt_test_start "A9 (review F2) exported globals state / this / __inst__ / __class__: the body sees the frame's values, its children the global ones"
case_run A9
check "A9" "body: this=k state=k_data child=[__class__=gclass __inst__=ginst state=gstate this=gthis ]|body: this=t2 state=t2_data child=[__class__=gclass __inst__=ginst state=gstate this=gthis ]|rc=0 err=" "${OUT//$'\n'/|}|rc=$RC err=$ERR"

# ===========================================================================
# §B refused variable-like member names (DR20 b)
# ===========================================================================
# The refused list (owner 2026-10-18, after review: the names whose binding
# breaks or changes bash or kklass itself), spelled out independently of
# kklass, plus one name per refused family.
refused="_ BASH BASHOPTS BASHPID COMPREPLY COPROC DIRSTACK EPOCHREALTIME EPOCHSECONDS EUID FUNCNAME GROUPS HISTCMD
LINENO MAPFILE OPTARG OPTERR OPTIND PIPESTATUS PPID RANDOM SECONDS SHELLOPTS SRANDOM UID
BASH_ALIASES BASH_ARGC BASH_ARGV BASH_ARGV0 BASH_CMDS BASH_COMMAND BASH_COMPAT BASH_ENV BASH_EXECUTION_STRING BASH_LINENO
BASH_LOADABLES_PATH BASH_MONOSECONDS BASH_REMATCH BASH_SOURCE BASH_SUBSHELL BASH_TRAPSIG BASH_VERSINFO BASH_VERSION
BASH_XTRACEFD BASH_FOO COMP_CWORD COMP_KEY COMP_LINE COMP_POINT COMP_TYPE COMP_WORDBREAKS COMP_WORDS COMP_X
READLINE_ARGUMENT READLINE_LINE READLINE_MARK READLINE_POINT READLINE_X
PATH EXECIGNORE HOME PWD OLDPWD CDPATH GLOBIGNORE GLOBSORT FIGNORE LANG LC_ALL LC_COLLATE LC_CTYPE LC_MESSAGES
LC_NUMERIC LC_TIME LC_FOO TZ PS0 PS1 PS2 PS3 PS4 PROMPT_COMMAND POSIXLY_CORRECT FUNCNEST TIMEFORMAT TMOUT TMPDIR TEMP TMP
HISTCONTROL HISTFILE HISTFILESIZE HISTIGNORE HISTSIZE HISTTIMEFORMAT"
# Allowed on purpose: plain environment / informational names (the children
# of a method see their real value through the +x binding, §A).
allowed="USER LOGNAME TERM HOSTNAME HOSTTYPE MACHTYPE OSTYPE SHELL SHLVL COLUMNS LINES MAIL MAILCHECK MAILPATH ENV
EMACS INSIDE_EMACS CHILD_MAX FCEDIT HOSTFILE IGNOREEOF INPUTRC TEXTDOMAIN TEXTDOMAINDIR auto_resume histchars
MSYSTEM SYSTEMROOT WINDIR HISTORY HISTOGRAM USERPROFILE MYENV"
kt_test_start "B1 every refused name (bash's special variables and BASH_/COMP_/READLINE_ families, the variables bash's behaviour depends on, the seven history variables) is refused as a defineClass property, rc 1, the message naming the name and the class"
bad=""
i=0
for n in $refused; do
    i=$((i + 1))
    run defineClass "B1C$i" "" property "$n"
    [[ $RC == 1 && $ERR == *"Reserved property name: '$n' (class 'B1C$i': "* ]] || bad+=" $n(rc=$RC)"
done
check "B1 refused" "" "$bad"

kt_test_start "B1b every variable of a clean bash of this runtime (env -i bash --norc --noprofile -c 'compgen -v') is either refused or on the allowed list — a new bash variable is a decision, not an accident"
declare -A known=()
for n in $refused $allowed IFS; do known[$n]=1; done
undecided=""
while IFS= read -r n; do [[ -n $n && -z ${known[$n]+x} ]] && undecided+=" $n"; done < <(env -i "$BASH" --norc --noprofile -c 'compgen -v')
check "B1b" "" "$undecided"

kt_test_start "B2 the message names a TRUE reason: special variable / what bash uses it for / the family / read by code"
run defineClass B2a "" property PATH; e1=$ERR
run defineClass B2b "" property PPID; e2=$ERR
run defineClass B2c "" property LC_PAPER; e3=$ERR
run defineClass B2d "" property COMP_X; e4=$ERR
run defineClass B2e "" property TMPDIR; e5=$ERR
if [[ $e1 == *"bash uses PATH for command lookup"* && $e2 == *"PPID is one of bash's special variables"* \
   && $e3 == *"bash uses LC_PAPER for the locale"*"C locale"* && $e4 == *"names starting with BASH_, COMP_ or READLINE_"* \
   && $e5 == *"TMPDIR is read by the code of the class's bodies"* ]]; then
    kt_test_pass "B2"
else
    kt_test_fail "B2: '$e1' / '$e2' / '$e3' / '$e4' / '$e5'"
fi

kt_test_start "B3 every variable-like member kind and every declaration path refuses (defineClass property / static_property / lazy_property, declarative field / property / classVar, Pascal var / static var / property, defineSerializableClass)"
bad=""
run defineClass B3a "" static_property TZ; [[ $RC != 0 && $ERR == *"Reserved static property name: 'TZ' (class 'B3a': "* ]] || bad+=" static_property($RC:$ERR)"
run defineClass B3b "" lazy_property TZ initTz method initTz 'echo x'; [[ $RC != 0 && $ERR == *"Reserved lazy property name: 'TZ' (class 'B3b': "* ]] || bad+=" lazy_property($RC:$ERR)"
b3_decl() { declareClass "$1" ""; "$2" "$3"; local r=$?; endClass >/dev/null 2>&1; return $r; }
run b3_decl B3c field TZ; [[ $RC != 0 && $ERR == *"Reserved field name: 'TZ' (class 'B3c': "* ]] || bad+=" field($RC:$ERR)"
run b3_decl B3d property HOME; [[ $RC != 0 && $ERR == *"Reserved property name: 'HOME' (class 'B3d': "* ]] || bad+=" decl-property($RC:$ERR)"
run b3_decl B3e classVar PWD; [[ $RC != 0 && $ERR == *"Reserved static property name: 'PWD' (class 'B3e': "* ]] || bad+=" classVar($RC:$ERR)"
b3_pas() { class "$1"; public; "${@:2}"; local r=$?; end >/dev/null 2>&1; return $r; }
run b3_pas B3f var SECONDS; [[ $RC != 0 && $ERR == *"Reserved field name: 'SECONDS' (class 'B3f': "* ]] || bad+=" pascal-var($RC:$ERR)"
run b3_pas B3g static var TMPDIR; [[ $RC != 0 && $ERR == *"Reserved static property name: 'TMPDIR' (class 'B3g': "* ]] || bad+=" pascal-static-var($RC:$ERR)"
run b3_pas B3h property HISTFILE read x write x; [[ $RC != 0 && $ERR == *"Reserved property name: 'HISTFILE' (class 'B3h': "* ]] || bad+=" pascal-property($RC:$ERR)"
run defineSerializableClass B3i "" ":" string property BASH_ENV; [[ $RC != 0 && $ERR == *"Reserved property name: 'BASH_ENV' (class 'B3i': "* ]] || bad+=" serializable($RC:$ERR)"
check "B3" "" "$bad"

kt_test_start "B4 nothing of a refused class is built (no B3a.new / B1C1.new)"
check "B4" "no no" "$(declare -F B3a.new >/dev/null && echo yes || echo no) $(declare -F B1C1.new >/dev/null && echo yes || echo no)"

kt_test_start "B5 allowed: the allowed list (USER LOGNAME TERM HOSTNAME COLUMNS LINES MAIL ENV HISTORY HISTOGRAM ...) and other spellings (case-sensitive: path Path tz home Lang lc_all LCX BASHFUL Hist comp_x); class and METHOD names are not checked; under nocasematch too"
bad=""
i=0
for n in $allowed path Path tz Tz home Lang lc_all LCX BASHFUL Hist comp_x term Logname; do
    i=$((i + 1))
    run defineClass "B5C$i" "" property "$n" static_property "s$n"; [[ $RC == 0 && -z $ERR ]] || bad+=" $n($RC:$ERR)"
done
run defineClass B5M "" property x method PATH 'echo m-ok' method TZ 'echo tz-ok'; [[ $RC == 0 ]] || bad+=" methods($RC:$ERR)"
B5M.new b5m; [[ "$(b5m.PATH) $(b5m.TZ)" == "m-ok tz-ok" ]] || bad+=" method-call"
shopt -s nocasematch
run defineClass B5N "" property path; [[ $RC == 0 ]] || bad+=" ncm-path($RC:$ERR)"
run defineClass B5O "" property PATH; [[ $RC == 1 && $ERR == *"Reserved property name: 'PATH' (class 'B5O': "* ]] || bad+=" ncm-PATH($RC:$ERR)"
shopt -u nocasematch
check "B5" "" "$bad"

# .ckk path: the compiler runs the source, so a refused name never reaches a cache
cat > "$TMPD/bad.kk" <<'EOF'
defineClass BadCk "" property TMPDIR method m 'echo m'
EOF
cat > "$TMPD/B6.sh" <<'EOF'
export KKLASS_CKK_DIR=$TMPD/ckk
source "$KKLASS_DIR/kklass_autoload.sh"
autoloadClasses "$TMPD/bad.kk"; echo "rc=$?"
declare -F BadCk.new >/dev/null && echo built || echo "not built"
[[ -e $KKLASS_CKK_DIR/bad.ckk.sh ]] && echo "cache written" || echo "no cache"
EOF
kt_test_start "B6 autoloadClasses (.ckk compile) of a source declaring a property TMPDIR: refused with the message (nothing compiled, rc 1), no class, no cache"
case_run B6
if [[ "$OUT" == $'rc=1\nnot built\nno cache' &&"$ERR" == *"Reserved property name: 'TMPDIR' ("*"nothing compiled"* ]]; then
    kt_test_pass "B6"
else
    kt_test_fail "B6: out='${OUT//$'\n'/|}' err='${ERR//$'\n'/|}'"
fi

# .kkp path: the translator emits the declarative verbs, which refuse
printf 'unit badkkp;\n\ninterface\n\ntype\n  TBadK = class\n  public\n    TZ: Integer;\n    procedure M;\n  end;\n\nimplementation\n\nprocedure TBadK.M;\nbegin\n  echo m\nend;\n\nend.\n' > "$TMPD/badkkp.kkp"
cat > "$TMPD/B7.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh"; kk.uses kklass
bash "$KKLASS_DIR/kklass_kkp.sh" "$TMPD/badkkp.kkp" "$TMPD/badkkp.sh" >/dev/null 2>&1; echo "translate=$?"
source "$TMPD/badkkp.sh"; echo "source=$?"
declare -F TBadK.new >/dev/null && echo built || echo "not built"
EOF
kt_test_start "B7 a .kkp unit with a field TZ: translated, its source refuses the field (rc 1), no class"
case_run B7
if [[ "$OUT" == $'translate=0\nsource=1\nnot built' && "$ERR" == *"Reserved field name: 'TZ' ("* ]]; then
    kt_test_pass "B7"
else
    kt_test_fail "B7: out='${OUT//$'\n'/|}' err='${ERR//$'\n'/|}'"
fi

# owner 2026-10-18: plain environment names are allowed — the +x binding
# gives the children of a method the real value
cat > "$TMPD/B8.sh" <<'EOF2'
source "$KBOOL_ROOT/kbool.sh"; kk.uses kklass
export USER=globaluser TERM=globalterm
ce() { command env | command grep -E "^($1)=" | command sort | command tr '\n' ' '; }
defineClass Acct "" property USER property TERM method m 'USER=propuser; echo "body USER=$USER child=[$(ce "USER|TERM")] whoami-style=$(printenv USER)"'
Acct.new a; a.m; echo "a.USER=$(a.USER) top USER=$USER"
EOF2
kt_test_start "B8 an allowed environment name as a property (USER, TERM): set in a body, the body reads the property, its children the global value"
case_run B8
check "B8" "body USER=propuser child=[TERM=globalterm USER=globaluser ] whoami-style=globaluser|a.USER=propuser top USER=globaluser|rc=0 err=" "${OUT//$'\n'/|}|rc=$RC err=$ERR"

# ===========================================================================
# §C kk.frameReset (DR21)
# ===========================================================================
# bash 5.1 runs the EXIT trap of a `set -e` exit inside a function in that
# function's scope (5.2+ unwinds it first; launch L4.3): there the body's frame
# is live and kk.frameReset is the documented no-op, as for an explicit exit (C3)
sete_scope=$("$BASH" -c 'f() { local v=in; false; }; trap '\''echo "${v-out}"'\'' EXIT; set -e; f')
cat > "$TMPD/C1.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh"; kk.uses kklass
declareClass A ""
privateSection
  procedure secret
publicSection
  field y
  procedure boom
endClass
implement A.secret 'echo "secret ran"'
implement A.boom 'y=set_by_boom; false; echo "NOT REACHED"'
endImplementation A
A.new a
lvu() { shopt -q localvar_unset && echo on || echo off; }
onexit() {
  local rc=$?
  echo "trap rc=$rc frames=${#__KLIB_FRAME_STACK[@]} lvu=$(lvu)"
  kk.frameReset; echo "reset rc=$?"
  echo "after frames=${#__KLIB_FRAME_STACK[@]}/${#__KLIB_FRAME_INSTANCE[@]}/${#__KLIB_FRAME_CLASS[@]} lvu=$(lvu)"
  a.secret 2>&1
  x=1; f() { local x=2; g; }; g() { unset x; echo "unset reveals x=[${x-UNSET}]"; }; f
  kk.frameReset; echo "again rc=$? frames=${#__KLIB_FRAME_STACK[@]} lvu=$(lvu)"
}
trap onexit EXIT
set -e
a.boom
echo "NOT REACHED top"
EOF
kt_test_start "C1 set -e exit inside a body -> EXIT trap: kk.frameReset clears the stale frame (0 frames), turns localvar_unset back off, a private call warns as from the top level, unset reveals; a second reset is a no-op"
case_run C1
want="trap rc=1 frames=1 lvu=on
reset rc=0
after frames=0/0/0 lvu=off
[kk] warning: private method 'A.secret' accessed from 'external'
secret ran
unset reveals x=[1]
again rc=0 frames=0 lvu=off"
[[ $sete_scope == in ]] && want="trap rc=1 frames=1 lvu=on
reset rc=0
after frames=1/1/1 lvu=on
secret ran
unset reveals x=[UNSET]
again rc=0 frames=1 lvu=on"
check "C1" "$want|rc=1" "$OUT|rc=$RC"

cat > "$TMPD/C2.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh"; kk.uses kklass
defineClass A "" property y method boom 'false; echo "NOT REACHED"' method show 'echo "show frames=${#__KLIB_FRAME_STACK[@]}"'
A.new a
lvu() { shopt -q localvar_unset && echo on || echo off; }
onexit() { kk.frameReset; echo "after frames=${#__KLIB_FRAME_STACK[@]} lvu=$(lvu)"; a.show; echo "end frames=${#__KLIB_FRAME_STACK[@]} lvu=$(lvu)"; }
trap onexit EXIT
shopt -s localvar_unset
set -e
a.boom
EOF
kt_test_start "C2 the caller had localvar_unset ON before the call (kklass did not turn it on): kk.frameReset clears the frame but leaves the option on; a method call in the handler works"
case_run C2
want="after frames=0 lvu=on|show frames=1|end frames=0 lvu=on"
[[ $sete_scope == in ]] && want="after frames=1 lvu=on|show frames=2|end frames=1 lvu=on"
check "C2" "$want|rc=1" "${OUT//$'\n'/|}|rc=$RC"

cat > "$TMPD/C3.sh" <<'EOF'
source "$KBOOL_ROOT/kbool.sh"; kk.uses kklass
defineClass A "" property y method m 'kk.frameReset; echo "in body: rc=$? frames=${#__KLIB_FRAME_STACK[@]} lvu=$(shopt -q localvar_unset && echo on || echo off) this=$this y=$y"' \
  method bye 'y=byeval; exit 3'
A.new a; a.y = v
kk.frameReset; echo "top: rc=$? frames=${#__KLIB_FRAME_STACK[@]} lvu=$(shopt -q localvar_unset && echo on || echo off)"
a.m
echo "after: frames=${#__KLIB_FRAME_STACK[@]} lvu=$(shopt -q localvar_unset && echo on || echo off)"
onexit() { kk.frameReset; echo "exit trap (inside the body scope): frames=${#__KLIB_FRAME_STACK[@]} y=$y"; }
trap onexit EXIT
a.bye
EOF
kt_test_start "C3 no-op when nothing is stale: at the top level, inside a running body (the live frame is kept), in an EXIT trap that runs inside the body scope (explicit exit)"
case_run C3
check "C3" "top: rc=0 frames=0 lvu=off|in body: rc=0 frames=1 lvu=on this=a y=v|after: frames=0 lvu=off|exit trap (inside the body scope): frames=1 y=byeval|rc=3" "${OUT//$'\n'/|}|rc=$RC"

cat > "$TMPD/C4.sh" <<'EOF'
export __KK_LVU_OWN=1
source "$KBOOL_ROOT/kbool.sh"; kk.uses kklass
shopt -s localvar_unset
__KLIB_FRAME_STACK=(0) __KLIB_FRAME_INSTANCE=(x) __KLIB_FRAME_CLASS=(X)
kk.frameReset; echo "frames=${#__KLIB_FRAME_STACK[@]} lvu=$(shopt -q localvar_unset && echo on || echo off)"
EOF
kt_test_start "C4 ownership (R14): an owner flag that came from the environment does not make kk.frameReset turn the caller's localvar_unset off"
case_run C4
check "C4" "frames=0 lvu=on|rc=0" "${OUT//$'\n'/|}|rc=$RC"

# ===========================================================================
# §D set -u (DR22)
# ===========================================================================
defineClass D1U "" property y property n method get 'echo "y=[${y-}]"'
D1U.new d1u
kt_test_start "D1 set -u: the accessor of a declared, never-assigned property reads '' with rc 0 (a.y, a.property y)"
o1=$( { set -u; d1u.y; echo "rc=$?"; } 2>&1 )
o2=$( { set -u; d1u.property y; echo "rc=$?"; } 2>&1 )
o3=$( { set -u; d1u.get; echo "rc=$?"; } 2>&1 )
check "D1" "|rc=0||rc=0|y=[]|rc=0" "${o1//$'\n'/|}|${o2//$'\n'/|}|${o3//$'\n'/|}"

defineClass D4S "" static_property sp static_property sq
kt_test_start "D4 (review F3) set -u: a static property accessor reads '' rc 0 (never assigned), and its value after S.sp = v"
o1=$( { set -u; D4S.sp; echo "rc=$?"; D4S.sp = v; D4S.sp; echo "rc=$?"; D4S.sq =; D4S.sq; echo "rc=$?"; } 2>&1 )
check "D4" "|rc=0|v|rc=0||rc=0" "${o1//$'\n'/|}"

kt_test_start "D2 the examples that read never-assigned properties (04, 34, 38, 40) run under bash -u with rc 0"
bad=""
for ex in 04_method_calls 34_composition_patterns 38_observer_pattern 40_builder_pattern; do
    mkdir -p "$TMPD/ex/$ex"
    ( cd "$TMPD/ex/$ex" && env -u KBOOL_CONFIG -u KBOOL_HOME -u KKLASS_CKK_DIR HOME="$TMPD/home" TMPDIR="$TMPD/ex/$ex" \
        __KK_CFG_ETC="$TMPD/etc" "$BASH" -u "$KKLASS_DIR/examples/$ex.sh" </dev/null >"$TMPD/ex/$ex.out" 2>"$TMPD/ex/$ex.err" ); r=$?
    [[ $r == 0 && ! -s "$TMPD/ex/$ex.err" ]] || bad+=" $ex(rc=$r: $(head -c 200 "$TMPD/ex/$ex.err"))"
done
check "D2" "" "$bad"

kt_test_start "D3 example 38 notifies its observers (the never-set \$emailNotifier passed nothing before)"
check "D3" "3 4" "$(grep -c "Sending email notification" "$TMPD/ex/38_observer_pattern.out") $(grep -c "Logging:" "$TMPD/ex/38_observer_pattern.out")"

cd / || :
kt_test_log "147_Round6.sh completed"
