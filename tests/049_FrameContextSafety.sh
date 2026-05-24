#!/bin/bash
# FrameContextSafety
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "FrameContextSafety" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"
source "$KKLASS_DIR/kklass_serializable.sh"



# Test 49.1: Executor bookkeeping names must not collide with properties
kt_test_start "Executor bookkeeping names do not shadow properties"
defineClass "ExecFrameSafe" "" \
    "property" "method_name" \
    "property" "target_class" \
    "method" "ping" 'echo "ok"'

ExecFrameSafe.new exec_frame_safe
exec_frame_safe.method_name = "payload_method"
exec_frame_safe.target_class = "payload_target"

result=$(exec_frame_safe.ping)
stored_method_name=$(exec_frame_safe.method_name)
stored_target_class=$(exec_frame_safe.target_class)

if [[ "$result" == "ok" ]] && \
   [[ "$stored_method_name" == "payload_method" ]] && \
   [[ "$stored_target_class" == "payload_target" ]]; then
    kt_test_pass "Executor bookkeeping names do not shadow properties"
else
    kt_test_fail "Executor bookkeeping names do not shadow properties (result: '$result', method_name: '$stored_method_name', target_class: '$stored_target_class')"
fi

exec_frame_safe.delete

# Test 49.2: JSON serialization helper names must not collide with properties
kt_test_start "JSON serialization helper names do not shadow properties"
defineClass "JsonFrameSafe" "" \
    "property" "key" \
    "property" "value"

addSerializable "JsonFrameSafe" "" "json"

JsonFrameSafe.new json_frame_safe
json_frame_safe.fromJSON '{"__class__":"JsonFrameSafe","key":"left","value":"right"}' >/dev/null

json_key=$(json_frame_safe.key)
json_value=$(json_frame_safe.value)

if [[ "$json_key" == "left" ]] && [[ "$json_value" == "right" ]]; then
    kt_test_pass "JSON serialization helper names do not shadow properties"
else
    kt_test_fail "JSON serialization helper names do not shadow properties (key: '$json_key', value: '$json_value')"
fi

json_frame_safe.delete