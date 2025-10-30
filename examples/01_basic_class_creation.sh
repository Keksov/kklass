#!/bin/bash
# Example 01: Basic Class Creation
# Demonstrates how to define a simple class with properties and methods

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Basic Class Creation Example ==="
echo

# Define a simple TestClass with properties and methods
defineClass "TestClass" "" \
    "property" "name" \
    "property" "value" \
    "method" "greet" 'echo "Hello, I am $name"' \
    "method" "getValue" 'echo "$value"'

echo "✓ TestClass defined successfully"

# Create an instance of the class
TestClass.new myobj

echo "✓ Instance 'myobj' created"

# Set property values
myobj.name = "TestObject"
myobj.value = "42"

echo "✓ Properties set: name=TestObject, value=42"

# Call methods
echo "Calling greet() method:"
myobj.greet

echo "Calling getValue() method:"
myobj.getValue

# Clean up
myobj.delete
echo "✓ Instance cleaned up"

echo
echo "=== Example completed successfully ==="