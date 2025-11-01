#!/bin/bash
# 044_json_serialization.sh - Test JSON serialization with addSerializable

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Load serialization module
source "$KKLASS_DIR/kklass_serializable.sh"

# Test 44: JSON serialization with addSerializable
test_start "JSON serialization with addSerializable"
defineClass "UserJSON" "" \
    "property" "id" \
    "property" "username" \
    "property" "email" \
    "method" "getInfo" 'echo "User: $username ($email)"'

addSerializable "UserJSON" "" "json"

UserJSON.new user_json1
user_json1.id = "2"
user_json1.username = "jane_smith"
user_json1.email = "jane@example.com"

json_data=$(user_json1.toJSON)
UserJSON.new user_json_restored
user_json_restored.fromJSON "$json_data"

if [[ "$(user_json1.username)" == "$(user_json_restored.username)" ]] && \
   [[ "$(user_json1.email)" == "$(user_json_restored.email)" ]]; then
    test_pass "JSON serialization with addSerializable"
else
    test_fail "JSON serialization with addSerializable"
fi

user_json1.delete
user_json_restored.delete