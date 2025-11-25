#!/bin/bash
# ThisMethodContext
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "ThisMethodContext" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 19: $this.method ensures current class context
test_start "\$this.method calls method in current class context"
defineClass "Base" "" \
    "method" "greet" 'echo "BaseGreeting"' \
    "method" "sayHello" 'echo -n "From Base: "; $this.greet'

defineClass "Derived" "Base" \
    "method" "greet" 'echo "DerivedGreeting"' \
    "method" "test" '$this.parent sayHello'

Derived.new derived1
result=$(derived1.test)
expected="From Base: BaseGreeting"
if [[ "$result" == "$expected" ]]; then
    test_pass "\$this.method calls method in current class context"
else
    test_fail "\$this.method calls method in current class context (expected: '$expected', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace test_start() with kk_test_start()
# - Replace test_pass() with kk_test_pass()
# - Replace test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
