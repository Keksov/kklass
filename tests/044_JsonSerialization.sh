#!/bin/bash
# JsonSerialization
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "JsonSerialization" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Load serialization module
source "$KKLASS_DIR/kklass_serializable.sh"

# Test 44: JSON serialization with addSerializable
kk_test_start "JSON serialization with addSerializable"
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
    kk_test_pass "JSON serialization with addSerializable"
else
    kk_test_fail "JSON serialization with addSerializable"
fi

user_json1.delete
user_json_restored.delete

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
