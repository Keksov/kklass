#!/bin/bash
# StaticPropertiesMethods
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "StaticPropertiesMethods" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 24: Static properties and methods
kk_test_start "Static properties and methods"
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
    kk_test_pass "Static properties and methods"
else
    kk_test_fail "Static properties and methods (count: '$result_count', id1: '$result_id1', id2: '$result_id2', name: '$result_name')"
fi

sc1.delete
sc2.delete

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
