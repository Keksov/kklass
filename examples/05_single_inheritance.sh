#!/bin/bash
# Example 05: Single Inheritance
# Demonstrates class inheritance where a derived class inherits from a base class

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Single Inheritance Example ==="
echo

# Define base class (Animal)
defineClass "Animal" "" \
    "property" "species" \
    "method" "speak" 'echo "Some generic sound"' \
    "method" "getSpecies" 'echo "$species"'

# Define derived class (Dog) that inherits from Animal
defineClass "Dog" "Animal" \
    "property" "breed" \
    "method" "speak" 'echo "Woof!"' \
    "method" "getBreed" 'echo "$breed"'

# Create an instance of the derived class
Dog.new dog1

# Set properties from both base and derived class
dog1.species = "Canine"
dog1.breed = "Golden Retriever"

echo "✓ Properties set:"
echo "  species: $(dog1.species)"
echo "  breed: $(dog1.breed)"

# Verify inheritance works
if [[ "$(dog1.species)" == "Canine" ]] && [[ "$(dog1.breed)" == "Golden Retriever" ]]; then
    echo "✓ Property inheritance working correctly"
else
    echo "✗ Property inheritance failed"
    exit 1
fi

# Show that derived class can access base class methods
echo "Dog speaks: $(dog1.speak)"
echo "Dog species: $(dog1.getSpecies)"
echo "Dog breed: $(dog1.getBreed)"

# Clean up
dog1.delete
echo "✓ Instance cleaned up"

echo
echo "=== Example completed successfully ==="