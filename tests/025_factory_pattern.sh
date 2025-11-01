#!/bin/bash
# 025_factory_pattern.sh - Test factory pattern with static counters

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Test 25: Factory pattern with static counters
test_start "Factory pattern with static counters"
defineClass "Product" "" \
    "property" "id" \
    "property" "name" \
    "method" "getInfo" 'echo "Product #$id: $name"'

defineClass "Registry" "" \
    "static_property" "total_count" \
    "static_method" "register" '((total_count++)) || true' \
    "static_method" "getTotal" 'echo "$total_count"'

Registry.total_count = "0"

Product.new prod1
prod1.id = "1"
prod1.name = "Widget"
Registry.register

Product.new prod2
prod2.id = "2"
prod2.name = "Gadget"
Registry.register

result1=$(prod1.getInfo)
result2=$(prod2.getInfo)
count=$(Registry.getTotal)

if [[ "$result1" == "Product #1: Widget" ]] && [[ "$result2" == "Product #2: Gadget" ]] && [[ "$count" == "2" ]]; then
    test_pass "Factory pattern with static counters"
else
    test_fail "Factory pattern with static counters (got: '$result1', '$result2', count: '$count')"
fi

prod1.delete
prod2.delete