#!/bin/bash
# 048_KKEchoResult.sh - Test KK_ECHO_RESULT global variable and kk._result behavior

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

# Test 1: Default KK_ECHO_RESULT is false - should not echo
test_start "Default KK_ECHO_RESULT is false (no echo)"
calc.add 5

# Verify the variable was still set
if [[ "${CALCULATOR_ADD}" == "15" ]]; then
    test_pass "Variable was set despite no echo"
else
    test_fail "Variable should be set to 15 (got: '${CALCULATOR_ADD}')"
fi

# Test 2: Enable KK_ECHO_RESULT globally - should echo
test_start "KK_ECHO_RESULT=true produces echo output"
export KK_ECHO_RESULT=true
# Capture output by redirecting, not subshell
output_file="$TEST_TMP_DIR/output_2"
calc.add 3 >"$output_file" 2>&1
output=$(cat "$output_file")
rm "$output_file"

if [[ "$output" == "13" ]]; then
    test_pass "KK_ECHO_RESULT=true produces echo output"
else
    test_fail "Expected output '13' but got: '$output'"
fi

# Test 2b: Verify variable was also set
test_start "Variable was set while echoing"
if [[ "${CALCULATOR_ADD}" == "13" ]]; then
    test_pass "Variable was set while echoing"
else
    test_fail "Variable should be set to 13 (got: '${CALCULATOR_ADD}')"
fi

# Test 3: Override global KK_ECHO_RESULT with explicit parameter - false overrides true
test_start "Explicit false parameter suppresses echo"
export KK_ECHO_RESULT=true
# Call kk._result in main shell (not subshell) to preserve variables
output_file="$TEST_TMP_DIR/output_3"
kk._result "test_var" "test_value" "false" >"$output_file" 2>&1
output=$(cat "$output_file")
rm "$output_file"
if [[ -z "$output" ]]; then
    test_pass "Explicit false parameter suppresses echo"
else
    test_fail "Explicit false should suppress echo (got: '$output')"
fi

# Test 3b: Verify the variable was still set
test_start "Variable was set despite false parameter"
if [[ "${TEST_VAR}" == "test_value" ]]; then
    test_pass "Variable was set despite false parameter"
else
    test_fail "Variable should be set to test_value (got: '${TEST_VAR}')"
fi

# Test 4: Override global KK_ECHO_RESULT with explicit parameter - true when global is false
test_start "Explicit true parameter produces echo"
export KK_ECHO_RESULT=false
# Call kk._result in main shell to preserve variables
output_file="$TEST_TMP_DIR/output_4"
kk._result "another_var" "another_value" "true" >"$output_file" 2>&1
output=$(cat "$output_file")
rm "$output_file"
if [[ "$output" == "another_value" ]]; then
    test_pass "Explicit true parameter produces echo"
else
    test_fail "Expected 'another_value' but got: '$output'"
fi

# Test 4b: Verify variable was also set
test_start "Variable was set while echoing with true parameter"
if [[ "${ANOTHER_VAR}" == "another_value" ]]; then
    test_pass "Variable was set while echoing with true parameter"
else
    test_fail "Variable should be set to another_value (got: '${ANOTHER_VAR}')"
fi

# Test 5: Reset to false and verify
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

# Test 6: Complex value with spaces (should echo if enabled)
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

# Test 7: Empty value echo
test_start "Echo handles empty values"
export KK_ECHO_RESULT=true
# Call kk._result in main shell to preserve variables
output_file="$TEST_TMP_DIR/output_7"
kk._result "empty_var" "" "true" >"$output_file" 2>&1
output=$(cat "$output_file")
rm "$output_file"
if [[ -z "$output" ]] && [[ -v EMPTY_VAR ]]; then
    test_pass "Empty value is properly set"
else
    test_fail "Empty variable handling failed (var set: $(declare -p EMPTY_VAR 2>/dev/null || echo 'not set'))"
fi

# Cleanup
calc.delete

# Reset to default
export KK_ECHO_RESULT=false

# Show results
#show_results
