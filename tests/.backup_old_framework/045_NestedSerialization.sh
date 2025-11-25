#!/bin/bash
# 045_nested_serialization.sh - Test nested object serialization (string format)

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Load serialization module
source "$KKLASS_DIR/kklass_serializable.sh"

# Test 45: Nested object serialization (string format)
test_start "Nested object serialization (string format)"
defineClass "Address" "" \
    "property" "street" \
    "property" "city" \
    "property" "zipcode"

defineClass "PersonNested" "" \
    "property" "name" \
    "property" "age" \
    "property" "address_data"

addSerializable "Address" ":" "string"
addSerializable "PersonNested" "|" "string"

Address.new addr_test
addr_test.street = "123 Main St"
addr_test.city = "New York"
addr_test.zipcode = "10001"

PersonNested.new person_test
person_test.name = "Test User"
person_test.age = "30"
person_test.address_data = "$(addr_test.toString)"

person_str=$(person_test.toString)
PersonNested.new person_test_restored
person_test_restored.fromString "$person_str"

Address.new addr_test_restored
addr_test_restored.fromString "$(person_test_restored.address_data)"

if [[ "$(person_test.name)" == "$(person_test_restored.name)" ]] && \
   [[ "$(addr_test.city)" == "$(addr_test_restored.city)" ]]; then
    test_pass "Nested object serialization (string format)"
else
    test_fail "Nested object serialization (string format)"
fi

addr_test.delete
person_test.delete
person_test_restored.delete
addr_test_restored.delete