#!/bin/bash
# kklass micro-benchmark (P0 baseline; re-run after every phase, see PLAN.md §3).
# Measures, on a class with 2 properties + 10 methods:
#   - .new per instance (first 50, then up to 1000 -> shows template eval cost)
#   - method call, property read, computed-property read (per op)
#   - .delete per instance at ~50 and ~1000 live instances (the F1 scaling proof)
#   - total shell functions after 1000 instances, template size in bytes
# Timing: EPOCHREALTIME (bash 5+), integer microseconds, no forks in the loops.
# Run: bash bench/kklass_bench.sh            (or with the 5.3 recipe from PLAN.md)

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/kklass.sh"
source "$DIR/kklass_serializable.sh"

now_us() { local t="${EPOCHREALTIME/./}"; NOW_US="${t#0}"; }
# Function count: measured ONCE while the shell is still small, then derived
# arithmetically. Enumerating the function table (`compgen -A function`,
# forked or not) once the shell holds ~24k functions makes EVERY later
# function call ~1.7x slower for the rest of the process on cygwin/msys
# (measured at P2/P3: 445 -> 693 us/call right after the enumeration, and it
# never recovers). So the bench never enumerates a big shell.
fn_count() { local -a __l; compgen -A function > "$FNS_TMP"; mapfile -t __l < "$FNS_TMP"; FN_COUNT=${#__l[@]}; }
FNS_TMP="${TMPDIR:-/tmp}/.kk_bench_fns_$$"
trap 'rm -f "$FNS_TMP"' EXIT
report() {  # label total_us iters unit
    local x10=$(( $2 * 10 / $3 ))
    printf '  %-44s %6d.%d us/%s  (total %d ms)\n' "$1" $(( x10/10 )) $(( x10%10 )) "$4" $(( $2/1000 ))
}

margs=()
for i in 1 2 3 4 5 6 7 8 9 10; do margs+=(method "m$i" "echo m$i"); done
defineClass TBench "" property a property b property area getArea \
    function getArea 'RESULT=$((a*b))' "${margs[@]}"
# Serialization rows (round 2 / P7): 5 plain properties, JSON format. Clean
# values exercise the escape helper's fast path; the hostile instance holds a
# quote, a backslash, a newline, a tab and a control byte in every property.
defineClass TBenchJ "" property id property name property email property city property note
addSerializable TBenchJ "" json
TBenchJ.new jc
jc.id = 42; jc.name = "John Doe"; jc.email = "john@example.com"; jc.city = "New York"; jc.note = "plain text value"
TBenchJ.new jh
for p in id name email city note; do jh.$p = $'say "hi" C:\\new\n\tx\x01y'; done
TBenchJ.new jr
# Internal dispatch row (round 2 / P8): one outer call runs N internal
# `$this.leaf` calls. Up to P8 kklass rewrote that body text into
# `$__inst__.call leaf` (kk._call through the method cache); since P8 the text is
# left alone and `$this.leaf` is the instance's own wrapper (kk._exec).
defineClass TBenchT "" method leaf 'echo x' \
    method loop 'local __b_i; for (( __b_i = 0; __b_i < $1; __b_i++ )); do $this.leaf; done'
TBenchT.new bt

echo "kklass micro-benchmark  (bash ${BASH_VERSION})"
echo "  template bytes: ${#TBench_instance_template}"
echo

# Round 3 / P11 (M3 + review R1): the .new instance-name check is an inline
# explicit-letter glob (kk._is_ident only under nocasematch) instead of an
# inline `[[ =~ ]]`. Measured on the still-small shell: a .new/.delete cycle of
# one name, and kk._is_ident (the rule's single definition, used by every other
# entry path) against the regex it replaced. Round 4 / P12 (L1 + L2, DR13):
# kk._is_ident moved to kkore/klib.sh without its `local LC_ALL=C` (≈4.5×
# slower under a UTF-8 caller locale); kk.derivesFrom (two kk._is_ident calls,
# thttprouter runs it per request) and kk._outName (kkore; every kcl
# output-array member) are timed here too — run the bench with LC_ALL unset
# AND with LC_ALL=en_US.UTF-8 to see the locale (in)dependence.
echo "identifier guards (round 3 / P11, round 4 / P12):"
now_us; t0=$NOW_US
for (( i=0; i<300; i++ )); do TBench.new cyc; cyc.delete; done
now_us; t1=$NOW_US
report ".new + .delete cycle (small shell)" $(( t1-t0 )) 300 "cycle"
__b_re() { [[ "${1:-}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; }
if declare -F kk._is_ident >/dev/null; then
    now_us; t0=$NOW_US
    for (( i=0; i<2000; i++ )); do kk._is_ident TBenchInstanceName; done
    now_us; t1=$NOW_US
    report "kk._is_ident (the guard)" $(( t1-t0 )) 2000 "call"
else
    echo "  kk._is_ident: not in this module (pre-P11)"
fi
now_us; t0=$NOW_US
for (( i=0; i<2000; i++ )); do __b_re TBenchInstanceName; done
now_us; t1=$NOW_US
report "the replaced =~ guard (reference)" $(( t1-t0 )) 2000 "call"
defineClass TBenchD0 "" property a
defineClass TBenchD1 TBenchD0 property b
now_us; t0=$NOW_US
for (( i=0; i<2000; i++ )); do kk.derivesFrom TBenchD1 TBenchD0; done
now_us; t1=$NOW_US
report "kk.derivesFrom (child, parent)" $(( t1-t0 )) 2000 "call"
if declare -F kk._outName >/dev/null; then
    now_us; t0=$NOW_US
    for (( i=0; i<2000; i++ )); do kk._outName out_arr __tqs_; done
    now_us; t1=$NOW_US
    report "kk._outName NAME PREFIX (kkore)" $(( t1-t0 )) 2000 "call"
fi
echo "  (locale: LC_ALL=${LC_ALL-unset} LANG=${LANG-unset})"
echo

echo "instance creation / .delete scaling (F1):"
fn_count; fn_base=$FN_COUNT                     # small shell: safe to enumerate
now_us; t0=$NOW_US
for (( i=1; i<=60; i++ )); do TBench.new "o$i"; done
now_us; t1=$NOW_US
report ".new (first 60)" $(( t1-t0 )) 60 "inst"
fn_count; fcount=$FN_COUNT
fn_per_inst=$(( (fcount - fn_base) / 60 ))
now_us; t0=$NOW_US
for (( i=51; i<=60; i++ )); do "o$i.delete"; done
now_us; t1=$NOW_US
report ".delete @50 live instances ($fcount fns)" $(( t1-t0 )) 10 "del"
o1.a = 3; o1.b = 4
now_us; t0=$NOW_US
for (( i=0; i<200; i++ )); do o1.area >/dev/null; done
now_us; t1=$NOW_US
report "computed read @50 live (F7: forks per read)" $(( t1-t0 )) 200 "read"
now_us; t0=$NOW_US
for (( i=61; i<=1010; i++ )); do TBench.new "o$i"; done
now_us; t1=$NOW_US
report ".new (61..1010)" $(( t1-t0 )) 950 "inst"
fcount=$(( fn_base + 1000 * fn_per_inst ))       # derived, see fn_count note
echo "  shell functions with 1000 live instances: ~$fcount ($fn_per_inst per instance)"
now_us; t0=$NOW_US
for (( i=1001; i<=1010; i++ )); do "o$i.delete"; done
now_us; t1=$NOW_US
report ".delete @1000 live instances ($fcount fns)" $(( t1-t0 )) 10 "del"
left=0; for (( i=1001; i<=1010; i++ )); do declare -F "o$i.m1" >/dev/null 2>&1 && (( left++ )); done
echo "  leftover o1001-1010 instances with functions: $left"
# NOTE: the remaining 1000 instances are deliberately NOT deleted here — with the
# pre-P1 .delete that would take ~15 minutes (1.4 s each). Add a full teardown
# timing once P1 lands.

echo
echo "per-op (instance o1):"
o1.a = 3; o1.b = 4
now_us; t0=$NOW_US
for (( i=0; i<1000; i++ )); do o1.m1 >/dev/null; done
now_us; t1=$NOW_US
report "method call (echo body)" $(( t1-t0 )) 1000 "call"
now_us; t0=$NOW_US
for (( i=0; i<1000; i++ )); do o1.call m1 >/dev/null; done
now_us; t1=$NOW_US
report "inst.call m1" $(( t1-t0 )) 1000 "call"
now_us; t0=$NOW_US
bt.loop 1000 >/dev/null; bt.loop 1000 >/dev/null
now_us; t1=$NOW_US
report "internal \$this.m call (R2_P8)" $(( t1-t0 )) 2000 "call"
now_us; t0=$NOW_US
for (( i=0; i<1000; i++ )); do o1.a >/dev/null; done
now_us; t1=$NOW_US
report "property read" $(( t1-t0 )) 1000 "read"
now_us; t0=$NOW_US
for (( i=0; i<1000; i++ )); do o1.a = "$i"; done
now_us; t1=$NOW_US
report "property write" $(( t1-t0 )) 1000 "write"
now_us; t0=$NOW_US
for (( i=0; i<200; i++ )); do o1.area >/dev/null; done
now_us; t1=$NOW_US
report "computed read @1000 live (F7: forks per read)" $(( t1-t0 )) 200 "read"

echo
echo "serialization (round 2 / P7, 5 properties, @1000 live):"
now_us; t0=$NOW_US
for (( i=0; i<500; i++ )); do jc.toJSON >/dev/null; done
now_us; t1=$NOW_US
report "toJSON, clean values" $(( t1-t0 )) 500 "call"
now_us; t0=$NOW_US
for (( i=0; i<500; i++ )); do jh.toJSON >/dev/null; done
now_us; t1=$NOW_US
report "toJSON, hostile values (escape slow path)" $(( t1-t0 )) 500 "call"
jc.toJSON > "$FNS_TMP"; IFS= read -r js < "$FNS_TMP"
now_us; t0=$NOW_US
for (( i=0; i<200; i++ )); do jr.fromJSON "$js" >/dev/null; done
now_us; t1=$NOW_US
report "fromJSON, clean values" $(( t1-t0 )) 200 "call"
