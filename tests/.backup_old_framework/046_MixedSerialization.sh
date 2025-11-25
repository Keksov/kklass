#!/bin/bash
# 046_mixed_serialization.sh - Test mixed format serialization (string and JSON)

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Load serialization module
source "$KKLASS_DIR/kklass_serializable.sh"

# Test 46: Mixed format serialization (string and JSON)
test_start "Mixed format serialization (string and JSON)"
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
    test_pass "Mixed format serialization (string and JSON)"
else
    test_fail "Mixed format serialization (string and JSON)"
fi

item1.delete
item_from_str.delete
item_from_json.delete