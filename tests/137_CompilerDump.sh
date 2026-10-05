#!/bin/bash
# CompilerDump (round 4 / P12, finding C15, decision DR12).
#   C6  The header heredoc of kklass_compiler.sh is UNQUOTED (it expands
#       $KKLASS_COMPILER_DIR), and a comment line in it carried a backquoted
#       `source`: a command substitution — every compile ran `source` with no
#       argument ("line 98: source: filename argument required" on stderr) and
#       every generated header read "load with .".
#   C7  kk.compiler._collect_classes took every function named *.new, so
#       kkore's kv.new was dumped as a class "kv" (its 10 kv.* functions went
#       into every compiled file and were redefined when it was sourced).
#       Now: X.new is a function AND ${X}_class_methods exists — exactly the
#       classes the runtime built (abstract, empty raw, and the parents the
#       source loaded, which a compiled child needs for its inherited methods).
#   C8  autoload recompiled only when the SOURCE was newer than the cache: a
#       cache from an older compiler/runtime (e.g. one with "Class: kv") was
#       sourced forever. Now it also recompiles when kklass_compiler.sh or
#       kklass.sh is newer than the cache.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "CompilerDump" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
W="$(cd "$(kt_fixture_tmpdir)" && pwd)"

cat > "$W/parent.kk" <<'EOF'
defineClass PBase "" property a method hello 'echo hi'
EOF
cat > "$W/child.kk" <<EOF
source "$W/parent.kk"
defineClass PChild PBase property b
# abstract class (declarative)
declareClass AbsK
  abstract; procedure run
endClass
endImplementation AbsK
# empty raw class (no members)
kk._build_class_runtime EmptyK ""
# a non-class factory function
Factory.new() { echo factory; }
# declared but never implemented
declareClass HalfK
  field x
endClass
EOF

( cd "$W" && bash "$KKLASS_DIR/kklass_compiler.sh" child.kk child.ckk.sh >"$W/c.out" 2>"$W/c.err" ); crc=$?
F="$W/child.ckk.sh"

kt_test_start "C6 compile is silent on stderr and the header says 'load with \`source\`'"
bad=""
(( crc == 0 )) || bad+=" rc=$crc;"
[[ ! -s "$W/c.err" ]] || bad+=" stderr='$(tr '\n' '|' < "$W/c.err")';"
grep -qxF '# from the source file; load with `source`.' "$F" 2>/dev/null || bad+=" header='$(grep -m1 'load with' "$F" 2>/dev/null)';"
if [[ -z "$bad" ]]; then kt_test_pass "clean"; else kt_test_fail "$bad"; fi

kt_test_start "C7 Classes = the built classes only: the source's own + the parent it sourced + abstract + empty raw; not Factory.new, not kv, not a never-built class"
line="$(grep '^  Classes:' "$W/c.out")"
got="$(printf '%s\n' ${line#  Classes:} | sort | tr '\n' ' ')"
sections="$(grep -o '^# ===== Class: [A-Za-z_0-9]* =====' "$F" | sed 's/^# ===== Class: //; s/ =====$//' | sort | tr '\n' ' ')"
bad=""
[[ "$got" == "AbsK EmptyK PBase PChild " ]] || bad+=" Classes='$line';"
[[ "$sections" == "AbsK EmptyK PBase PChild " ]] || bad+=" sections='$sections';"
! grep -qE '^kv\.[A-Za-z_]+ \(\)' "$F" || bad+=" kv.* functions dumped;"
! grep -q '^Factory\.new ()' "$F" || bad+=" Factory.new dumped;"
if [[ -z "$bad" ]]; then kt_test_pass "4 classes"; else kt_test_fail "$bad"; fi

kt_test_start "C7 the compiled child loaded ALONE: inherited method works, AbsK stays abstract, EmptyK instantiates, kkore's kv.new is not replaced"
o="$(bash -c '
source "$2/kklass.sh"; kvref="$(declare -f kv.new)"
source "$1"
PChild.new o && o.hello
kk.isAbstract AbsK; echo "abs=$?"
EmptyK.new e && echo empty-ok
declare -F Factory.new >/dev/null && echo factory-defined
[[ "$(declare -f kv.new)" == "$kvref" ]] && echo kv-same
' _ "$F" "$KKLASS_DIR" 2>&1)"
if [[ "$o" == $'hi\nabs=0\nempty-ok\nkv-same' ]]; then kt_test_pass "ok"; else kt_test_fail "'${o//$'\n'/|}'"; fi

# ---------------------------------------------------------------------------
# C8 — autoload staleness: a cache older than kklass_compiler.sh / kklass.sh is
# recompiled even when the source is older than the cache.
# ---------------------------------------------------------------------------
mkdir -p "$W/ckk"
cat > "$W/stale.kk" <<'EOF'
defineClass StaleK "" method hi 'echo fresh'
EOF
stale_cache="$W/ckk/stale.ckk.sh"
cat > "$stale_cache" <<'EOF'
#!/bin/bash
echo STALE-CACHE-LOADED
EOF
touch -d '2001-01-01 00:00:00' "$W/stale.kk"
touch -d '2002-01-01 00:00:00' "$stale_cache"
o="$(cd "$W" && KKLASS_CKK_DIR="$W/ckk" bash -c 'source "$1/kklass_autoload.sh"; kkload "$2" 2>/dev/null; StaleK.new s && s.hi' _ "$KKLASS_DIR" "$W/stale.kk" 2>&1)"
kt_test_start "C8 a cache older than kklass_compiler.sh is recompiled (source older than the cache)"
if [[ "$o" == fresh ]] && ! grep -q STALE-CACHE-LOADED "$stale_cache"; then
    kt_test_pass "recompiled"
else
    kt_test_fail "out='${o//$'\n'/|}' cache: $(head -c 200 "$stale_cache" | tr '\n' '|')"
fi

# A cache NEWER than the source and the framework is still used as is.
cat > "$stale_cache" <<'EOF'
#!/bin/bash
echo CACHE-USED
EOF
touch -d '2099-01-01 00:00:00' "$stale_cache"
o="$(cd "$W" && KKLASS_CKK_DIR="$W/ckk" bash -c 'source "$1/kklass_autoload.sh"; kkload "$2" 2>&1' _ "$KKLASS_DIR" "$W/stale.kk" 2>&1)"
kt_test_start "C8 a cache newer than the source AND the framework is reused (no recompile)"
if [[ "$o" == *"Using cached compiled file"* && "$o" == *CACHE-USED* && "$o" != *Compiling* ]]; then
    kt_test_pass "reused"
else
    kt_test_fail "'${o//$'\n'/|}'"
fi

kt_test_log "137_CompilerDump.sh completed"
