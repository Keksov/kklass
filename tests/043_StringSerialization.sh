#!/bin/bash
# StringSerialization
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "StringSerialization" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Load serialization module
source "$KKLASS_DIR/kklass_serializable.sh"

# Test 43: String serialization with defineSerializableClass
kk_test_start "String serialization with defineSerializableClass"
defineSerializableClass "UserStr" "" ":" "string" \
    "property" "id" \
    "property" "username" \
    "property" "email" \
    "method" "getInfo" 'echo "User: $username ($email)"'

UserStr.new user_str1
user_str1.id = "1"
user_str1.username = "john_doe"
user_str1.email = "john@example.com"

serialized=$(user_str1.toString)
UserStr.new user_str_restored
user_str_restored.fromString "$serialized" >/dev/null

if [[ "$(user_str1.username)" == "$(user_str_restored.username)" ]] && \
   [[ "$(user_str1.email)" == "$(user_str_restored.email)" ]]; then
    kk_test_pass "String serialization with defineSerializableClass"
else
    kk_test_fail "String serialization with defineSerializableClass"
fi

user_str1.delete
user_str_restored.delete

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
