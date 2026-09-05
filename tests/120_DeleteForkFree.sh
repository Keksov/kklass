#!/bin/bash
# DeleteForkFree (P0 regression for F1 + F8, see PLAN.md).
# .delete must (a) remove every per-instance function and the data/class vars,
# (b) remove the lazy-property globals `inst_lazy_<p>` (F8), and (c) cost the
# same no matter how many OTHER functions exist in the shell (F1: the original
# `unset -f $(compgen -A function inst.)` forked and scanned ALL functions, so
# one delete grew from 15 ms at 585 functions to 1.4 s at 20k functions).

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "DeleteForkFree" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"

now_us() { local t="${EPOCHREALTIME/./}"; printf -v NOW_US '%d' "${t#0}"; }

margs=()
for i in 1 2 3 4 5 6 7 8 9 10; do margs+=(method "m$i" "echo m$i"); done
defineClass TDel "" property a property b lazy_property lz initLz "${margs[@]}" \
    method initLz 'echo 42'

# ---------------------------------------------------------------------------
kt_test_start ".delete leaves no inst.* function and no inst_* variable"
TDel.new d1
d1.a = x; d1.lz >/dev/null                    # touch the lazy prop -> global created
d1.delete
left="$(compgen -A function d1. 2>/dev/null | wc -l | tr -d ' ')"
vars=""
declare -p d1_data  &>/dev/null && vars+=" d1_data"
declare -p d1_class &>/dev/null && vars+=" d1_class"
if [[ "$left" == "0" && -z "$vars" ]]; then
    kt_test_pass "no functions, no data/class vars left"
else
    kt_test_fail "left functions=$left vars='$vars'"
fi

# ---------------------------------------------------------------------------
kt_test_start ".delete removes the lazy-property global (F8)"
TDel.new d2; d2.lz >/dev/null
[[ -v d2_lazy_lz ]] || kt_test_log "note: lazy global not named d2_lazy_lz (naming changed?)"
d2.delete
if [[ ! -v d2_lazy_lz ]]; then
    kt_test_pass "d2_lazy_lz gone after delete"
else
    kt_test_fail "d2_lazy_lz survived delete (value='$d2_lazy_lz')"
fi

# ---------------------------------------------------------------------------
kt_test_start ".delete cost does not scale with the number of shell functions (F1)"
# 20 instances -> ~300 functions; time 10 deletes. Then 600 more instances
# (~9k functions) and time 10 deletes again. A fork-free delete is flat; the
# compgen scan grew ~10x in the review measurements. Allow 3x for noise.
for i in $(seq 1 30); do TDel.new "s$i"; done
now_us; t0=$NOW_US
for i in $(seq 1 10); do "s$i.delete"; done
now_us; t1=$NOW_US
small=$(( t1 - t0 ))
for i in $(seq 1 600); do TDel.new "b$i"; done
fcount="$(compgen -A function | wc -l | tr -d ' ')"
now_us; t0=$NOW_US
for i in $(seq 11 20); do "s$i.delete"; done
now_us; t1=$NOW_US
big=$(( t1 - t0 ))
kt_test_log "10 deletes: ${small} us @~300 functions, ${big} us @${fcount} functions"
if (( small > 0 && big <= small * 3 )); then
    kt_test_pass "delete cost flat (${big} us vs ${small} us)"
else
    kt_test_fail "delete cost grew with function count: ${small} us -> ${big} us @${fcount} functions"
fi

kt_test_log "120_DeleteForkFree.sh completed"
