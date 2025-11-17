#!/bin/bash
# 048_KKEchoResult.sh - Test KK_ECHO_RESULT global variable and kk._return behavior

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Setup temp directory for tests
init_test_tmpdir "048"

# Setup: Create TestClass with function
defineClass "Calculator" "" \
    "property" "value" \
    "function" "add" 'RESULT=$((value + $1))'

Calculator.new calc
calc.value = "10"

# Test 1: Default KK_ECHO_RESULT is empty (auto-detect, no echo in main shell)
test_start "Default KK_ECHO_RESULT is empty (auto-detect in main shell)"
unset KK_ECHO_RESULT
output_file="$TEST_TMP_DIR/output_1"
calc.add 5 >"$output_file" 2>&1
output=$(cat "$output_file")
rm "$output_file"

# In main shell, should NOT echo (no subshell)
if [[ -z "$output" ]]; then
    test_pass "Default behavior: no echo in main shell"
else
    test_fail "Expected no output in main shell (got: '$output')"
fi

# Test 2: Enable KK_ECHO_RESULT globally - explicit true should echo in main shell
test_start "KK_ECHO_RESULT=true produces echo output"
export KK_ECHO_RESULT=true
output_file="$TEST_TMP_DIR/output_2"
calc.add 3 >"$output_file" 2>&1
output=$(cat "$output_file")
rm "$output_file"

if [[ "$output" == "13" ]]; then
    test_pass "KK_ECHO_RESULT=true produces echo output"
else
    test_fail "Expected output '13' but got: '$output'"
fi

# Test 3: Auto-detect in subshell (should echo)
test_start "Auto-detect in subshell produces echo"
unset KK_ECHO_RESULT
result=$(calc.add 2)
if [[ "$result" == "12" ]]; then
    test_pass "Auto-detect in subshell produces echo"
else
    test_fail "Expected '12' in subshell (got: '$result')"
fi

# Test 4: Override global KK_ECHO_RESULT with explicit parameter - false suppresses echo
test_start "Explicit false parameter suppresses echo"
export KK_ECHO_RESULT=true
output_file="$TEST_TMP_DIR/output_3"
kk._return "test_var" "test_value" "false" >"$output_file" 2>&1
output=$(cat "$output_file")
rm "$output_file"
if [[ -z "$output" ]]; then
    test_pass "Explicit false parameter suppresses echo"
else
    test_fail "Explicit false should suppress echo (got: '$output')"
fi

# Test 5: Override global KK_ECHO_RESULT with explicit parameter - true when global is false
test_start "Explicit true parameter produces echo"
export KK_ECHO_RESULT=false
output_file="$TEST_TMP_DIR/output_4"
kk._return "another_var" "another_value" "true" >"$output_file" 2>&1
output=$(cat "$output_file")
rm "$output_file"
if [[ "$output" == "another_value" ]]; then
    test_pass "Explicit true parameter produces echo"
else
    test_fail "Expected 'another_value' but got: '$output'"
fi

# Test 6: Reset to false and verify
test_start "Reset KK_ECHO_RESULT to false"
export KK_ECHO_RESULT=false
output_file="$TEST_TMP_DIR/output_5"
calc.add 7 >"$output_file" 2>&1
output=$(cat "$output_file")
rm "$output_file"
if [[ -z "$output" ]]; then
    test_pass "KK_ECHO_RESULT=false suppresses output"
else
    test_fail "Expected no output but got: '$output'"
fi

# Test 7: Complex value with spaces (should echo if enabled)
test_start "Echo works with values containing spaces"
export KK_ECHO_RESULT=true
defineClass "Concatenator" "" \
    "property" "prefix" \
    "function" "concat" 'RESULT="${prefix} $1"'

Concatenator.new concat_inst
concat_inst.prefix = "Hello"
output_file="$TEST_TMP_DIR/output_6"
concat_inst.concat "World" >"$output_file" 2>&1
output=$(cat "$output_file")
rm "$output_file"
if [[ "$output" == "Hello World" ]]; then
    test_pass "Echo preserves spaces in output"
else
    test_fail "Expected 'Hello World' but got: '$output'"
fi
concat_inst.delete

# Test 8: Empty value echo
test_start "Echo handles empty values"
export KK_ECHO_RESULT=true
output_file="$TEST_TMP_DIR/output_7"
kk._return "empty_var" "" "true" >"$output_file" 2>&1
output=$(cat "$output_file")
rm "$output_file"
if [[ -z "$output" ]]; then
    test_pass "Empty value echoes as empty"
else
    test_fail "Expected empty echo but got: '$output'"
fi

# Cleanup
calc.delete

# Reset to default
unset KK_ECHO_RESULT
