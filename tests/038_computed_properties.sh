#!/bin/bash
# 038_computed_properties.sh - Test computed properties (getter and setter)

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Test 38: Computed properties (getter and setter)
test_start "Computed properties (getter and setter)"
defineClass "UserWithComputed" "" \
    "property" "first_name" \
    "property" "last_name" \
    "computed_property" "full_name" "get_full_name" "set_full_name" \
    "method" "get_full_name" 'echo "$first_name $last_name"' \
    "method" "set_full_name" 'local full="$1"; local f l; IFS=" " read -r f l <<< "$full"; first_name="$f"; last_name="$l"'

UserWithComputed.new user_comp

user_comp.first_name = "John"
user_comp.last_name = "Doe"
result1=$(user_comp.full_name)

if [[ "$result1" == "John Doe" ]]; then
    # Test computed setter
    user_comp.full_name = "Jane Smith"
    result2=$(user_comp.first_name)
    result3=$(user_comp.last_name)
    
    if [[ "$result2" == "Jane" ]] && [[ "$result3" == "Smith" ]]; then
        test_pass "Computed properties (getter and setter)"
    else
        test_fail "Computed properties - setter failed (first: '$result2', last: '$result3')"
    fi
else
    test_fail "Computed properties - getter failed (expected: 'John Doe', got: '$result1')"
fi

user_comp.delete