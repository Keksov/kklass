#!/bin/bash
# ComplexNestedObjectGraph

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "ComplexNestedObjectGraph" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

kt_test_section "Complex nested object graph with overlapping names"

defineClass "ComplexNodeCtx" "" \
    "property" "name" \
    "property" "value" \
    "property" "state" \
    "function" "snapshot" 'RESULT="$name|$value|$state"' \
    "function" "prepare" 'value="prepared:${name}:$1"; state="prepared-state:${name}:$1"; $this.snapshot'

defineClass "ComplexCollectorCtx" "ComplexNodeCtx" \
    "property" "last_subject" \
    "property" "last_peer" \
    "property" "last_self" \
    "function" "touch" 'value="touch:${name}:$1:$2"; state="touch-state:${name}:$3"; $this.snapshot' \
    "function" "capture" 'last_subject="$1"; last_peer="$2"; last_self="$3"; value="capture:${name}:$1"; state="captured:${name}:$1"; $this.snapshot'

defineClass "ComplexWorkerCtx" "ComplexNodeCtx" \
    "property" "peer" \
    "property" "collector" \
    "function" "assist" '${collector}.touch "$name" "$1" "$2"; local collector_touch="$RESULT"; value="assist:${name}:from:$1:$2"; state="assist-state:${name}:$2"; $this.snapshot; local self_snapshot="$RESULT"; RESULT="${self_snapshot}<${collector_touch}"' \
    "function" "process" '$this.parent prepare "$1"; local base_snapshot="$RESULT"; value="process:${name}:$1"; state="process-state:${name}:$1"; $this.snapshot; local self_snapshot="$RESULT"; ${peer}.assist "$name" "$1"; local peer_snapshot="$RESULT"; ${collector}.capture "$name" "$peer_snapshot" "$self_snapshot"; local collector_snapshot="$RESULT"; RESULT="${base_snapshot}|${self_snapshot}|${peer_snapshot}|${collector_snapshot}"'

kt_test_start "Complex nested graph preserves per-instance state across deep calls"
ComplexCollectorCtx.new collector_left
ComplexCollectorCtx.new collector_right
ComplexWorkerCtx.new worker_left_a
ComplexWorkerCtx.new worker_left_b
ComplexWorkerCtx.new worker_right_a
ComplexWorkerCtx.new worker_right_b

collector_left.name = "collector-left"
collector_left.value = "collector-left-initial"
collector_left.state = "collector-left-idle"
collector_right.name = "collector-right"
collector_right.value = "collector-right-initial"
collector_right.state = "collector-right-idle"

worker_left_a.name = "left-a"
worker_left_a.value = "left-a-initial"
worker_left_a.state = "left-a-idle"
worker_left_a.peer = "worker_left_b"
worker_left_a.collector = "collector_left"

worker_left_b.name = "left-b"
worker_left_b.value = "left-b-initial"
worker_left_b.state = "left-b-idle"
worker_left_b.peer = "worker_left_a"
worker_left_b.collector = "collector_left"

worker_right_a.name = "right-a"
worker_right_a.value = "right-a-initial"
worker_right_a.state = "right-a-idle"
worker_right_a.peer = "worker_right_b"
worker_right_a.collector = "collector_right"

worker_right_b.name = "right-b"
worker_right_b.value = "right-b-initial"
worker_right_b.state = "right-b-idle"
worker_right_b.peer = "worker_right_a"
worker_right_b.collector = "collector_right"

worker_left_a.process 7
left_result="$RESULT"
worker_right_a.process 3
right_result="$RESULT"

worker_left_a.snapshot
left_a_snapshot="$RESULT"
worker_left_b.snapshot
left_b_snapshot="$RESULT"
collector_left.snapshot
left_collector_snapshot="$RESULT"
worker_right_a.snapshot
right_a_snapshot="$RESULT"
worker_right_b.snapshot
right_b_snapshot="$RESULT"
collector_right.snapshot
right_collector_snapshot="$RESULT"

left_last_subject="$(collector_left.last_subject)"
left_last_peer="$(collector_left.last_peer)"
left_last_self="$(collector_left.last_self)"
right_last_subject="$(collector_right.last_subject)"
right_last_peer="$(collector_right.last_peer)"
right_last_self="$(collector_right.last_self)"

expected_left_a="left-a|process:left-a:7|process-state:left-a:7"
expected_left_b="left-b|assist:left-b:from:left-a:7|assist-state:left-b:7"
expected_left_collector="collector-left|capture:collector-left:left-a|captured:collector-left:left-a"
expected_left_touch="collector-left|touch:collector-left:left-b:left-a|touch-state:collector-left:7"
expected_left_peer="${expected_left_b}<${expected_left_touch}"
expected_left_result="left-a|prepared:left-a:7|prepared-state:left-a:7|${expected_left_a}|${expected_left_peer}|${expected_left_collector}"

expected_right_a="right-a|process:right-a:3|process-state:right-a:3"
expected_right_b="right-b|assist:right-b:from:right-a:3|assist-state:right-b:3"
expected_right_collector="collector-right|capture:collector-right:right-a|captured:collector-right:right-a"
expected_right_touch="collector-right|touch:collector-right:right-b:right-a|touch-state:collector-right:3"
expected_right_peer="${expected_right_b}<${expected_right_touch}"
expected_right_result="right-a|prepared:right-a:3|prepared-state:right-a:3|${expected_right_a}|${expected_right_peer}|${expected_right_collector}"

if [[ "$left_result" == "$expected_left_result" ]] && \
   [[ "$right_result" == "$expected_right_result" ]] && \
   [[ "$left_a_snapshot" == "$expected_left_a" ]] && \
   [[ "$left_b_snapshot" == "$expected_left_b" ]] && \
   [[ "$left_collector_snapshot" == "$expected_left_collector" ]] && \
   [[ "$right_a_snapshot" == "$expected_right_a" ]] && \
   [[ "$right_b_snapshot" == "$expected_right_b" ]] && \
   [[ "$right_collector_snapshot" == "$expected_right_collector" ]] && \
   [[ "$left_last_subject" == "left-a" ]] && \
   [[ "$left_last_peer" == "$expected_left_peer" ]] && \
   [[ "$left_last_self" == "$expected_left_a" ]] && \
   [[ "$right_last_subject" == "right-a" ]] && \
   [[ "$right_last_peer" == "$expected_right_peer" ]] && \
   [[ "$right_last_self" == "$expected_right_a" ]]; then
    kt_test_pass "Complex nested graph preserves per-instance state across deep calls"
else
    kt_test_fail "Complex nested graph preserves per-instance state across deep calls (left_result: '$left_result', right_result: '$right_result', left_a: '$left_a_snapshot', left_b: '$left_b_snapshot', left_collector: '$left_collector_snapshot', right_a: '$right_a_snapshot', right_b: '$right_b_snapshot', right_collector: '$right_collector_snapshot')"
fi

worker_left_a.delete
worker_left_b.delete
worker_right_a.delete
worker_right_b.delete
collector_left.delete
collector_right.delete