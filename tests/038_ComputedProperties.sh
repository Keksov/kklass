#!/bin/bash
# ComputedProperties
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "ComputedProperties" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 38.1: Computed property with both getter and setter (new unified syntax)
test_start "Computed properties - both getter and setter"
defineClass "UserWithComputed" "" \
    "property" "first_name" \
    "property" "last_name" \
    "property" "full_name" "get_full_name" "set_full_name" \
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
        test_pass "Computed properties - both getter and setter"
    else
        test_fail "Computed properties - setter failed (first: '$result2', last: '$result3')"
    fi
else
    test_fail "Computed properties - getter failed (expected: 'John Doe', got: '$result1')"
fi

user_comp.delete

# Test 38.2: Computed property with only getter
test_start "Computed properties - only getter"
defineClass "UserWithGetter" "" \
    "property" "first_name" \
    "property" "last_name" \
    "property" "display_name" "get_display_name" \
    "method" "get_display_name" 'echo "${last_name}, ${first_name}"'

UserWithGetter.new user_getter

user_getter.first_name = "John"
user_getter.last_name = "Doe"
result=$(user_getter.display_name)

if [[ "$result" == "Doe, John" ]]; then
    test_pass "Computed properties - only getter"
else
    test_fail "Computed properties - getter only failed (expected: 'Doe, John', got: '$result')"
fi

user_getter.delete

# Test 38.3: Computed property with only setter
test_start "Computed properties - only setter"
defineClass "UserWithSetter" "" \
    "property" "name" \
    "property" "username" \
    "property" "display_mode" "set_display_mode" \
    "method" "set_display_mode" 'local mode="$1"; username="user_${mode}"'

UserWithSetter.new user_setter

user_setter.name = "John Doe"
user_setter.display_mode = "admin"
result=$(user_setter.username)

if [[ "$result" == "user_admin" ]]; then
    test_pass "Computed properties - only setter"
else
    test_fail "Computed properties - setter only failed (expected: 'user_admin', got: '$result')"
fi

user_setter.delete

# Test 38.4: Property detection order (get/set by first 3 chars)
test_start "Computed properties - detection by prefix"
defineClass "PropertyDetection" "" \
    "property" "raw_value" \
    "property" "value" "getValue" "setValue" \
    "property" "cached" "getCachedValue" \
    "method" "getValue" 'echo "val_${raw_value}"' \
    "method" "setValue" 'raw_value="set_$1"' \
    "method" "getCachedValue" 'echo "cached_data"'

PropertyDetection.new prop_test

prop_test.value = "original"
result1=$(prop_test.value)

if [[ "$result1" == "val_set_original" ]]; then
    prop_test.value = "modified"
    result2=$(prop_test.value)
    result3=$(prop_test.cached)
    
    if [[ "$result2" == "val_set_modified" ]] && [[ "$result3" == "cached_data" ]]; then
        test_pass "Computed properties - detection by prefix"
    else
        test_fail "Computed properties - setter/getter detection failed (val2: '$result2', val3: '$result3')"
    fi
else
    test_fail "Computed properties - getter detection failed (expected: 'val_set_original', got: '$result1')"
fi

prop_test.delete

# TODO: Migrate this test completely:
# - Replace test_start() with kk_test_start()
# - Replace test_pass() with kk_test_pass()
# - Replace test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
