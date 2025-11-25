#!/bin/bash
# 043_string_serialization.sh - Test string serialization with defineSerializableClass

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Load serialization module
source "$KKLASS_DIR/kklass_serializable.sh"

# Test 43: String serialization with defineSerializableClass
test_start "String serialization with defineSerializableClass"
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
    test_pass "String serialization with defineSerializableClass"
else
    test_fail "String serialization with defineSerializableClass"
fi

user_str1.delete
user_str_restored.delete