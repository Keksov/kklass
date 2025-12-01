#!/bin/bash
# KKIntegration
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "KKIntegration" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

# Tests interactions between multiple functions and real-world scenarios


kt_test_section "klib Integration Tests"

# Test 1: kk._var and kk._return workflow
kt_test_start "Integration - kk._var with kk._return"
kk._return "my.property" "myValue"
if [[ "${MY_PROPERTY}" == "myValue" ]]; then
    kt_test_pass "Integration - kk._var with kk._return"
else
    kt_test_fail "Integration - kk._var with kk._return"
fi

# Test 2: kl.write used multiple times
kt_test_start "Integration - multiple kl.write calls"
OUTPUT=$(kl.write "Start" && kl.write ": " && kl.write "Middle" && kl.write " " && kl.write "End" 2>&1)
if [[ "$OUTPUT" == "Start"*": "*"Middle"*" "*"End" ]]; then
    kt_test_pass "Integration - multiple kl.write calls"
else
    kt_test_fail "Integration - multiple kl.write calls"
fi

# Test 3: Output functions combined
kt_test_start "Integration - kl.write and kl.writeln"
OUTPUT=$(
    {
        kl.write "Status: "
        kl.writeln "Success"
    } 2>&1
)
if [[ "$OUTPUT" == "Status: Success"* ]]; then
    kt_test_pass "Integration - kl.write and kl.writeln"
else
    kt_test_fail "Integration - kl.write and kl.writeln"
fi

# Test 4: Dynamic variable creation with loop
kt_test_start "Integration - dynamic variable creation"
SUCCESS=true
for i in {1..5}; do
    kk._return "var${i}" "value${i}"
    var_name="VAR${i}"
    if [[ "${!var_name}" != "value${i}" ]]; then
        SUCCESS=false
        break
    fi
done
if [[ "$SUCCESS" == true ]]; then
    kt_test_pass "Integration - dynamic variable creation"
else
    kt_test_fail "Integration - dynamic variable creation"
fi

# Test 5: Output with variable expansion
kt_test_start "Integration - output with variable expansion"
kk._return "username" "testuser"
OUTPUT=$(kl.writeln "User: ${USERNAME}" 2>&1)
if [[ "$OUTPUT" == "User: testuser"* ]]; then
    kt_test_pass "Integration - output with variable expansion"
else
    kt_test_fail "Integration - output with variable expansion"
fi

# Test 6: Chained variable normalization
kt_test_start "Integration - chained variable normalization"
kk._var "Complex.Property Name"
VAR_NAME="$KK_VAR"
kk._return "Complex.Property Name" "complexValue"
if [[ "${!VAR_NAME}" == "complexValue" ]]; then
    kt_test_pass "Integration - chained variable normalization"
else
    kt_test_fail "Integration - chained variable normalization"
fi

# Test 7: Output formatting workflow
kt_test_start "Integration - output formatting workflow"
OUTPUT=$(
    {
        kl.writeln "=== Report ==="
        kl.writeln ""
        kl.write "Status"
        kl.writeln ": OK"
    } 2>&1
)
LINE_COUNT=$(echo "$OUTPUT" | wc -l)
if [[ "$LINE_COUNT" -ge 3 ]]; then
    kt_test_pass "Integration - output formatting workflow"
else
    kt_test_fail "Integration - output formatting workflow"
fi

kt_test_section "klib Real-world Scenarios"

# Test 8: Configuration file simulation
kt_test_start "Integration - configuration storage"
kk._return "db.host" "localhost"
kk._return "db.port" "5432"
kk._return "db.name" "myapp"
if [[ "${DB_HOST}" == "localhost" && "${DB_PORT}" == "5432" && "${DB_NAME}" == "myapp" ]]; then
    kt_test_pass "Integration - configuration storage"
else
    kt_test_fail "Integration - configuration storage"
fi

# Test 9: Dynamic property assignment with validation
kt_test_start "Integration - property with validation output"
PROP_NAME="app.version"
PROP_VALUE="1.2.3"
kk._return "$PROP_NAME" "$PROP_VALUE"
if [[ "${APP_VERSION}" == "1.2.3" ]]; then
    kt_test_pass "Integration - property with validation output"
else
    kt_test_fail "Integration - property with validation output"
fi

# Test 10: Logging simulation
kt_test_start "Integration - logging simulation"
OUTPUT=$(
    {
        kl.write "[INFO] "
        kl.writeln "Application started"
        kl.write "[DEBUG] "
        kl.writeln "System initialization complete"
    } 2>&1
)
if [[ "$OUTPUT" == *"[INFO]"* && "$OUTPUT" == *"[DEBUG]"* ]]; then
    kt_test_pass "Integration - logging simulation"
else
    kt_test_fail "Integration - logging simulation"
fi

kt_test_section "klib Stress Tests"

# Test 11: Large batch variable assignment
kt_test_start "Integration - large batch assignment"
SUCCESS=true
for i in {1..100}; do
    kk._return "property_${i}" "value_${i}"
done
# Check a few random ones
if [[ "${PROPERTY_1}" == "value_1" && "${PROPERTY_50}" == "value_50" && "${PROPERTY_100}" == "value_100" ]]; then
    kt_test_pass "Integration - large batch assignment"
else
    kt_test_fail "Integration - large batch assignment"
fi

# Test 12: Complex naming with various separators
kt_test_start "Integration - complex separators"
kk._return "My.Complex Property.Name With.Multiple Dots" "testVal"
if [[ "${MY_COMPLEX_PROPERTY_NAME_WITH_MULTIPLE_DOTS}" == "testVal" ]]; then
    kt_test_pass "Integration - complex separators"
else
    kt_test_fail "Integration - complex separators"
fi

# Test 13: Large output generation
kt_test_start "Integration - large output generation"
OUTPUT=$(
    for i in {1..50}; do
        kl.writeln "Line $i content"
    done
)
LINE_COUNT=$(echo "$OUTPUT" | wc -l)
if [[ "$LINE_COUNT" -eq 50 ]]; then
    kt_test_pass "Integration - large output generation"
else
    kt_test_fail "Integration - large output generation (got $LINE_COUNT lines)"
fi

# Test 14: Mixed operations in sequence
kt_test_start "Integration - mixed operations"
OUTPUT=$(kl.write "Config:" 2>&1)
kk._return "setting.one" "value1"
kk._return "setting.two" "value2"
OUTPUT2=$(kl.writeln " Settings saved" 2>&1)
if [[ "${SETTING_ONE}" == "value1" && "${SETTING_TWO}" == "value2" ]]; then
    kt_test_pass "Integration - mixed operations"
else
    kt_test_fail "Integration - mixed operations"
fi

# Test 15: Variable name case insensitivity
kt_test_start "Integration - variable case handling"
kk._return "MyVar" "val1"
if [[ "${MYVAR}" == "val1" ]]; then
    kt_test_pass "Integration - variable case handling"
else
    kt_test_fail "Integration - variable case handling"
fi
