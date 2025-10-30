#!/bin/bash
# Example 06: Method Overriding
# Demonstrates how derived classes can override methods from their parent class

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Method Overriding Example ==="
echo

# Define base class
defineClass "Animal" "" \
    "property" "name" \
    "method" "speak" 'echo "Some generic animal sound"'

# Define derived class that overrides the speak method
defineClass "Dog" "Animal" \
    "property" "breed" \
    "method" "speak" 'echo "Woof! Woof!"'

# Define another derived class with different override
defineClass "Cat" "Animal" \
    "property" "color" \
    "method" "speak" 'echo "Meow!"'

# Create instances
Dog.new dog1
Cat.new cat1

# Set properties
dog1.name = "Buddy"
dog1.breed = "Golden Retriever"
cat1.name = "Whiskers"
cat1.color = "Gray"

echo "Dog speaking:"
dog1.speak

echo "Cat speaking:"
cat1.speak

# Verify method overriding works correctly
dog_sound=$(dog1.speak)
cat_sound=$(cat1.speak)

if [[ "$dog_sound" == "Woof! Woof!" ]] && [[ "$cat_sound" == "Meow!" ]]; then
    echo "✓ Method overriding working correctly"
else
    echo "✗ Method overriding failed"
    exit 1
fi

# Show that each instance has its own method implementation
echo "Both objects have different speak() implementations:"
echo "  $(dog1.name) ($(dog1.breed)): $dog_sound"
echo "  $(cat1.name) ($(cat1.color)): $cat_sound"

# Clean up
dog1.delete
cat1.delete
echo "✓ Instances cleaned up"

echo
echo "=== Example completed successfully ==="