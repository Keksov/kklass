#!/bin/bash
# Example 19: $this.method Ensures Current Class Context
# Demonstrates that $this.method calls methods in the current class context

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== \$this.method Current Class Context Example ==="
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

# Test that $this in base class calls base method, not derived
echo "Calling test() method (which calls parent sayHello):"
result=$(derived1.test)
echo "Result: $result"

# Verify expected vs actual results
expected="From Base: BaseGreeting"
if [[ "$result" == "$expected" ]]; then
    echo "✓ \$this.method calls method in current class context"
else
    echo "✗ \$this.method context failed (expected: '$expected', got: '$result')"
    exit 1
fi

# Demonstrate the difference between $this and direct calls
echo "Direct call to derived greet(): $(derived1.greet)"
echo "Direct call to base greet() via parent: $(derived1.parent greet)"

# Clean up
derived1.delete
echo "✓ Instance cleaned up"

echo
echo "=== Example completed successfully ==="