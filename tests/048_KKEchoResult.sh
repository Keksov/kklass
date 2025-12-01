#!/bin/bash
# KKEchoResult
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "KKEchoResult" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

# (Previously tested explicit KK_ECHO_RESULT control, now only auto-detect via BASH_SUBSHELL)

# Setup: Create TestClass with function
defineClass "Calculator" "" \
    "property" "value" \
    "function" "add" 'RESULT=$((value + $1))'

Calculator.new calc
calc.value = "10"

# Test 1: Main shell - no echo (BASH_SUBSHELL == 0)
kt_test_start "Main shell context: no echo output"
output_file="$_KT_TMPDIR/output_1"
calc.add 5 >"$output_file" 2>&1
output=$(cat "$output_file")
rm "$output_file"

if [[ -z "$output" ]]; then
    kt_test_pass "Main shell: no echo output"
else
    kt_test_fail "Expected no output in main shell (got: '$output')"
fi

# Test 2: Subshell - auto echo (BASH_SUBSHELL > 0)
kt_test_start "Subshell context: automatic echo output"
result=$(calc.add 3)
if [[ "$result" == "13" ]]; then
    kt_test_pass "Subshell: automatic echo output"
else
    kt_test_fail "Expected output '13' but got: '$result'"
fi

# Test 3: Nested subshell
kt_test_start "Nested subshell context"
result=$(
    calc.add 2
)
if [[ "$result" == "12" ]]; then
    kt_test_pass "Nested subshell: correct echo output"
else
    kt_test_fail "Expected '12' in nested subshell (got: '$result')"
fi

# Test 4: Complex value with spaces in subshell
kt_test_start "Subshell with values containing spaces"
defineClass "Concatenator" "" \
    "property" "prefix" \
    "function" "concat" 'RESULT="${prefix} $1"'

Concatenator.new concat_inst
concat_inst.prefix = "Hello"
result=$(concat_inst.concat "World")
if [[ "$result" == "Hello World" ]]; then
    kt_test_pass "Subshell: spaces preserved in output"
else
    kt_test_fail "Expected 'Hello World' but got: '$result'"
fi
concat_inst.delete

# Test 5: Empty value in subshell
kt_test_start "Subshell with empty value"
defineClass "Empty" "" \
    "function" "getEmpty" 'RESULT=""'

Empty.new empty_inst
result=$(empty_inst.getEmpty)
if [[ -z "$result" ]]; then
    kt_test_pass "Subshell: empty value echoes as empty"
else
    kt_test_fail "Expected empty echo but got: '$result'"
fi
empty_inst.delete

# Cleanup
calc.delete
