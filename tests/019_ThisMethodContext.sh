#!/bin/bash
# 019_this_method_context.sh - Test $this.method calls method in current class context

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

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