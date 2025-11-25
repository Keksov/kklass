#!/bin/bash
# 040_observer_pattern.sh - Test observer pattern

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Test 40: Observer pattern
test_start "Observer pattern"
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
        test_pass "Observer pattern"
    else
        test_fail "Observer pattern - selective update failed (email: '$result3', logger: '$result4')"
    fi
else
    test_fail "Observer pattern - update failed (email: '$result1', logger: '$result2')"
fi

emailNotifier.delete
loggerObs.delete