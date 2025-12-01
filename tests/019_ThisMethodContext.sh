#!/bin/bash
# ThisMethodContext
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "ThisMethodContext" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 19: $this.method ensures current class context
kt_test_start "\$this.method calls method in current class context"
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
    kt_test_pass "\$this.method calls method in current class context"
else
    kt_test_fail "\$this.method calls method in current class context (expected: '$expected', got: '$result')"
fi

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
