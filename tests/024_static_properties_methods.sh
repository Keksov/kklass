#!/bin/bash
# 024_static_properties_methods.sh - Test static properties and methods

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Test 24: Static properties and methods
test_start "Static properties and methods"
defineClass "StaticCounter" "" \
    "static_property" "instance_count" \
    "static_property" "class_name" \
    "property" "id" \
    "static_method" "getInstanceCount" 'echo "$instance_count"' \
    "static_method" "getClassName" 'echo "$class_name"' \
    "static_method" "incrementCount" 'instance_count=$((instance_count + 1))' \
    "method" "initialize" 'id=$((instance_count + 1)); StaticCounter.incrementCount'

StaticCounter.class_name = "StaticCounter"
StaticCounter.instance_count = "0"

StaticCounter.new sc1
StaticCounter.new sc2
sc1.initialize
sc2.initialize

result_count=$(StaticCounter.getInstanceCount)
result_id1=$(sc1.id)
result_id2=$(sc2.id)
result_name=$(StaticCounter.getClassName)

if [[ "$result_count" == "2" ]] && [[ "$result_id1" == "1" ]] && [[ "$result_id2" == "2" ]] && [[ "$result_name" == "StaticCounter" ]]; then
    test_pass "Static properties and methods"
else
    test_fail "Static properties and methods (count: '$result_count', id1: '$result_id1', id2: '$result_id2', name: '$result_name')"
fi

sc1.delete
sc2.delete