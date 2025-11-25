#!/bin/bash
# ObserverPattern
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "ObserverPattern" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 40: Observer pattern
kk_test_start "Observer pattern"
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
        kk_test_pass "Observer pattern"
    else
        kk_test_fail "Observer pattern - selective update failed (email: '$result3', logger: '$result4')"
    fi
else
    kk_test_fail "Observer pattern - update failed (email: '$result1', logger: '$result2')"
fi

emailNotifier.delete
loggerObs.delete

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
