#!/bin/bash
# ObserverPattern
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "ObserverPattern" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 40: Observer pattern
kt_test_start "Observer pattern"
defineClass "ObserverTest" "" \
    "property" "name" \
    "property" "last_message" \
    "method" "update" 'last_message="$1"'

defineClass "EmailNotifierTest" "ObserverTest"
defineClass "LoggerObserverTest" "ObserverTest"

EmailNotifierTest.new emailNotifier
emailNotifier.name = "Email"
LoggerObserverTest.new loggerObs
loggerObs.name = "Logger"

# Test 1: Both observers receive notification
emailNotifier.update "Test news"
loggerObs.update "Test news"
result1=$(emailNotifier.last_message)
result2=$(loggerObs.last_message)

if [[ "$result1" == "Test news" ]] && [[ "$result2" == "Test news" ]]; then
    # Test 2: Only one observer receives update
    loggerObs.update "Second news"
    result3=$(emailNotifier.last_message)
    result4=$(loggerObs.last_message)
    
    if [[ "$result3" == "Test news" ]] && [[ "$result4" == "Second news" ]]; then
        kt_test_pass "Observer pattern"
    else
        kt_test_fail "Observer pattern - selective update failed (email: '$result3', logger: '$result4')"
    fi
else
    kt_test_fail "Observer pattern - update failed (email: '$result1', logger: '$result2')"
fi

emailNotifier.delete
loggerObs.delete

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
