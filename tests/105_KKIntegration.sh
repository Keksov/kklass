#!/bin/bash
# KKIntegration
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "KKIntegration" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

# Tests interactions between multiple functions and real-world scenarios


kk_test_section "kklib Integration Tests"

# Test 1: kk._var and kk._return workflow
kk_test_start "Integration - kk._var with kk._return"
kk._return "my.property" "myValue"
if [[ "${MY_PROPERTY}" == "myValue" ]]; then
    kk_test_pass "Integration - kk._var with kk._return"
else
    kk_test_fail "Integration - kk._var with kk._return"
fi

# Test 2: kk.write used multiple times
kk_test_start "Integration - multiple kk.write calls"
OUTPUT=$(kk.write "Start" && kk.write ": " && kk.write "Middle" && kk.write " " && kk.write "End" 2>&1)
if [[ "$OUTPUT" == "Start"*": "*"Middle"*" "*"End" ]]; then
    kk_test_pass "Integration - multiple kk.write calls"
else
    kk_test_fail "Integration - multiple kk.write calls"
fi

# Test 3: Output functions combined
kk_test_start "Integration - kk.write and kk.writeln"
OUTPUT=$(
    {
        kk.write "Status: "
        kk.writeln "Success"
    } 2>&1
)
if [[ "$OUTPUT" == "Status: Success"* ]]; then
    kk_test_pass "Integration - kk.write and kk.writeln"
else
    kk_test_fail "Integration - kk.write and kk.writeln"
fi

# Test 4: Dynamic variable creation with loop
kk_test_start "Integration - dynamic variable creation"
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
    kk_test_pass "Integration - dynamic variable creation"
else
    kk_test_fail "Integration - dynamic variable creation"
fi

# Test 5: Output with variable expansion
kk_test_start "Integration - output with variable expansion"
kk._return "username" "testuser"
OUTPUT=$(kk.writeln "User: ${USERNAME}" 2>&1)
if [[ "$OUTPUT" == "User: testuser"* ]]; then
    kk_test_pass "Integration - output with variable expansion"
else
    kk_test_fail "Integration - output with variable expansion"
fi

# Test 6: Chained variable normalization
kk_test_start "Integration - chained variable normalization"
kk._var "Complex.Property Name"
VAR_NAME="$KK_VAR"
kk._return "Complex.Property Name" "complexValue"
if [[ "${!VAR_NAME}" == "complexValue" ]]; then
    kk_test_pass "Integration - chained variable normalization"
else
    kk_test_fail "Integration - chained variable normalization"
fi

# Test 7: Output formatting workflow
kk_test_start "Integration - output formatting workflow"
OUTPUT=$(
    {
        kk.writeln "=== Report ==="
        kk.writeln ""
        kk.write "Status"
        kk.writeln ": OK"
    } 2>&1
)
LINE_COUNT=$(echo "$OUTPUT" | wc -l)
if [[ "$LINE_COUNT" -ge 3 ]]; then
    kk_test_pass "Integration - output formatting workflow"
else
    kk_test_fail "Integration - output formatting workflow"
fi

kk_test_section "kklib Real-world Scenarios"

# Test 8: Configuration file simulation
kk_test_start "Integration - configuration storage"
kk._return "db.host" "localhost"
kk._return "db.port" "5432"
kk._return "db.name" "myapp"
if [[ "${DB_HOST}" == "localhost" && "${DB_PORT}" == "5432" && "${DB_NAME}" == "myapp" ]]; then
    kk_test_pass "Integration - configuration storage"
else
    kk_test_fail "Integration - configuration storage"
fi

# Test 9: Dynamic property assignment with validation
kk_test_start "Integration - property with validation output"
PROP_NAME="app.version"
PROP_VALUE="1.2.3"
kk._return "$PROP_NAME" "$PROP_VALUE"
if [[ "${APP_VERSION}" == "1.2.3" ]]; then
    kk_test_pass "Integration - property with validation output"
else
    kk_test_fail "Integration - property with validation output"
fi

# Test 10: Logging simulation
kk_test_start "Integration - logging simulation"
OUTPUT=$(
    {
        kk.write "[INFO] "
        kk.writeln "Application started"
        kk.write "[DEBUG] "
        kk.writeln "System initialization complete"
    } 2>&1
)
if [[ "$OUTPUT" == *"[INFO]"* && "$OUTPUT" == *"[DEBUG]"* ]]; then
    kk_test_pass "Integration - logging simulation"
else
    kk_test_fail "Integration - logging simulation"
fi

kk_test_section "kklib Stress Tests"

# Test 11: Large batch variable assignment
kk_test_start "Integration - large batch assignment"
SUCCESS=true
for i in {1..100}; do
    kk._return "property_${i}" "value_${i}"
done
# Check a few random ones
if [[ "${PROPERTY_1}" == "value_1" && "${PROPERTY_50}" == "value_50" && "${PROPERTY_100}" == "value_100" ]]; then
    kk_test_pass "Integration - large batch assignment"
else
    kk_test_fail "Integration - large batch assignment"
fi

# Test 12: Complex naming with various separators
kk_test_start "Integration - complex separators"
kk._return "My.Complex Property.Name With.Multiple Dots" "testVal"
if [[ "${MY_COMPLEX_PROPERTY_NAME_WITH_MULTIPLE_DOTS}" == "testVal" ]]; then
    kk_test_pass "Integration - complex separators"
else
    kk_test_fail "Integration - complex separators"
fi

# Test 13: Large output generation
kk_test_start "Integration - large output generation"
OUTPUT=$(
    for i in {1..50}; do
        kk.writeln "Line $i content"
    done
)
LINE_COUNT=$(echo "$OUTPUT" | wc -l)
if [[ "$LINE_COUNT" -eq 50 ]]; then
    kk_test_pass "Integration - large output generation"
else
    kk_test_fail "Integration - large output generation (got $LINE_COUNT lines)"
fi

# Test 14: Mixed operations in sequence
kk_test_start "Integration - mixed operations"
OUTPUT=$(kk.write "Config:" 2>&1)
kk._return "setting.one" "value1"
kk._return "setting.two" "value2"
OUTPUT2=$(kk.writeln " Settings saved" 2>&1)
if [[ "${SETTING_ONE}" == "value1" && "${SETTING_TWO}" == "value2" ]]; then
    kk_test_pass "Integration - mixed operations"
else
    kk_test_fail "Integration - mixed operations"
fi

# Test 15: Variable name case insensitivity
kk_test_start "Integration - variable case handling"
kk._return "MyVar" "val1"
if [[ "${MYVAR}" == "val1" ]]; then
    kk_test_pass "Integration - variable case handling"
else
    kk_test_fail "Integration - variable case handling"
fi
