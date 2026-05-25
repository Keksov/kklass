#!/bin/bash
# StaticRegistrationHelper

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "StaticRegistrationHelper" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"

sample.echoValue() {
    echo "$1"
}

sample.failIfEmpty() {
    if [[ -z "$1" ]]; then
        return 1
    fi
    echo "$1"
}

kt_test_start "kk.register_static_methods registers public functions as static methods"
kk.register_static_methods "sample" "sample" "Sample" echoValue failIfEmpty
missing_methods=()
for expected_method in echoValue failIfEmpty; do
    found=false
    for registered_method in "${sample_class_static_methods[@]}"; do
        if [[ "$registered_method" == "$expected_method" ]]; then
            found=true
            break
        fi
    done
    [[ "$found" == "true" ]] || missing_methods+=("$expected_method")
done

if (( ${#sample_class_static_methods[@]} == 2 && ${#missing_methods[@]} == 0 )); then
    kt_test_pass "kk.register_static_methods registers public functions as static methods"
else
    kt_test_fail "kk.register_static_methods metadata mismatch: missing ${missing_methods[*]:-(none)}, count ${#sample_class_static_methods[@]}"
fi

kt_test_start "kk.register_static_methods preserves public function status"
if sample.failIfEmpty "" >/dev/null 2>&1; then
    kt_test_fail "kk.register_static_methods preserves public function status"
else
    kt_test_pass "kk.register_static_methods preserves public function status"
fi

kt_test_start "kk.register_static_methods preserves public function output"
result=$(sample.echoValue "value")
if [[ "$result" == "value" ]]; then
    kt_test_pass "kk.register_static_methods preserves public function output"
else
    kt_test_fail "kk.register_static_methods preserves public function output (expected: value, got: $result)"
fi