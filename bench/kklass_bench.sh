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

echo "kklass micro-benchmark  (bash ${BASH_VERSION})"
echo "  template bytes: ${#TBench_instance_template}"
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
