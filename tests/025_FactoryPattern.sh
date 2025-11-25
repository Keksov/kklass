#!/bin/bash
# FactoryPattern
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "FactoryPattern" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 25: Factory pattern with static counters
kk_test_start "Factory pattern with static counters"
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
    kk_test_pass "Factory pattern with static counters"
else
    kk_test_fail "Factory pattern with static counters (got: '$result1', '$result2', count: '$count')"
fi

prod1.delete
prod2.delete

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
