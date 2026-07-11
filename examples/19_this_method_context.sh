#!/bin/bash
# Example 19: Dispatch semantics — virtual $this vs static $this.parent
# All kklass dispatch is dynamic (the Delphi virtual+override model):
#   - $this.method resolves from the INSTANCE's actual class, so subclass
#     overrides win even when the call happens inside an inherited body;
#   - $this.parent (and the DSL's `inherited`) resolves STATICALLY, one level
#     up from the class where the currently executing body is defined.

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Dispatch: virtual \$this vs static \$this.parent ==="
echo

# Define base class
defineClass "Base" "" \
    "property" "name" \
    "method" "greet" 'echo "BaseGreeting"' \
    "method" "sayHello" 'echo -n "From Base: "; $this.greet'

# Define derived class that overrides greet
defineClass "Derived" "Base" \
    "property" "type" \
    "method" "greet" 'echo "DerivedGreeting"' \
    "method" "test" '$this.parent sayHello'

# Create derived instance
Derived.new derived1
derived1.name = "TestDerived"
derived1.type = "Special"

echo "✓ Derived instance created"

# test() explicitly asks for the PARENT's sayHello ($this.parent — static).
# Inside Base.sayHello, $this.greet dispatches VIRTUALLY: the instance is a
# Derived, so Derived's override of greet wins (template-method pattern).
echo "Calling test() method (which calls parent sayHello):"
result=$(derived1.test)
echo "Result: $result"

expected="From Base: DerivedGreeting"
if [[ "$result" == "$expected" ]]; then
    echo "✓ \$this.method dispatches virtually (override wins inside a parent body)"
else
    echo "✗ virtual dispatch failed (expected: '$expected', got: '$result')"
    exit 1
fi

# The static counterpart: $this.parent explicitly targets the parent's version.
echo "Direct call to derived greet(): $(derived1.greet)"
echo "Direct call to base greet() via parent: $(derived1.parent greet)"

expected_parent="BaseGreeting"
actual_parent="$(derived1.parent greet)"
if [[ "$actual_parent" == "$expected_parent" ]]; then
    echo "✓ \$this.parent resolves statically to the parent implementation"
else
    echo "✗ parent dispatch failed (expected: '$expected_parent', got: '$actual_parent')"
    exit 1
fi

# Clean up
derived1.delete
echo "✓ Instance cleaned up"

echo
echo "=== Example completed successfully ==="
