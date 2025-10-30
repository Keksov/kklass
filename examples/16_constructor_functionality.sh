#!/bin/bash
# Example 16: Constructor Functionality
# Demonstrates class constructors and initialization

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Constructor Functionality Example ==="
echo

# Define a class with a constructor
defineClass "ConstructedClass" "" \
    "property" "initialized" \
    "property" "created_at" \
    "property" "name" \
    "constructor" 'echo "Constructor called for $1"; initialized="true"; created_at=$(date +%s); name="$1"' \
    "method" "isInitialized" 'echo "$initialized"' \
    "method" "getName" 'echo "$name"' \
    "method" "getAge" 'echo "$(( $(date +%s) - created_at )) seconds old"'

# Create instance with constructor parameter
ConstructedClass.new constructed "MyObject"

echo "✓ Instance created with constructor"

# Check initialization status
echo "Is initialized: $(constructed.isInitialized)"
echo "Object name: $(constructed.getName)"
echo "Object age: $(constructed.getAge)"

# Verify constructor worked correctly
if [[ "$(constructed.isInitialized)" == "true" ]]; then
    echo "✓ Constructor functionality working correctly"
else
    echo "✗ Constructor functionality failed"
    exit 1
fi

# Create another instance to show different constructor calls
ConstructedClass.new another "DifferentObject"
echo "Second object name: $(another.getName)"
echo "Second object initialized: $(another.isInitialized)"

# Clean up
constructed.delete
another.delete
echo "✓ Instances cleaned up"

echo
echo "=== Example completed successfully ==="