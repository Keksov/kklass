#!/bin/bash
# Example 07: Parent Method Calls
# Demonstrates how to call parent class methods from derived classes using $this.parent

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Parent Method Calls Example ==="
echo

# Define base class
defineClass "Animal" "" \
    "property" "species" \
    "method" "speak" 'echo "Some generic sound"'

# Define derived class that calls parent method
defineClass "Cat" "Animal" \
    "property" "name" \
    "method" "speak" 'echo "Meow!"' \
    "method" "speakAsAnimal" 'echo -n "Cat sound: "; $this.speak; echo -n " - Animal sound: "; $this.parent speak'

# Create instance
Cat.new cat1
cat1.species = "Feline"
cat1.name = "Whiskers"

echo "Calling speakAsAnimal() method:"
result=$(cat1.speakAsAnimal)
echo "Result: $result"

# Verify the result contains both cat and animal sounds
expected="Cat sound: Meow! - Animal sound: Some generic sound"
if [[ "$result" == "$expected" ]]; then
    echo "✓ Parent method calls working correctly"
else
    echo "✗ Parent method call failed (expected: '$expected', got: '$result')"
    exit 1
fi

# Demonstrate that we can call parent methods directly
echo "Direct parent method call:"
cat1.parent speak

# Clean up
cat1.delete
echo "✓ Instance cleaned up"

echo
echo "=== Example completed successfully ==="