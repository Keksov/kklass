#!/bin/bash
# MixedSerialization
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "MixedSerialization" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Load serialization module
source "$KKLASS_DIR/kklass_serializable.sh"

# Test 46: Mixed format serialization (string and JSON)
kt_test_start "Mixed format serialization (string and JSON)"
defineClass "Item" "" \
    "property" "code" \
    "property" "description" \
    "property" "quantity"

addSerializable "Item" ":" "string"
addSerializable "Item" "" "json"

Item.new item1
item1.code = "ITM001"
item1.description = "Test Item"
item1.quantity = "10"

# Test both toString and toJSON work
str_data=$(item1.toString)
json_data=$(item1.toJSON)

Item.new item_from_str
item_from_str.fromString "$str_data"

Item.new item_from_json
item_from_json.fromJSON "$json_data"

if [[ "$(item1.code)" == "$(item_from_str.code)" ]] && \
   [[ "$(item1.code)" == "$(item_from_json.code)" ]]; then
    kt_test_pass "Mixed format serialization (string and JSON)"
else
    kt_test_fail "Mixed format serialization (string and JSON)"
fi

item1.delete
item_from_str.delete
item_from_json.delete

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
