#!/bin/bash
# Example 04: Method Calls
# Demonstrates calling methods on class instances

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Method Calls Example ==="
echo

# Define a class with methods
defineClass "TestClass" "" \
    "property" "name" \
    "method" "greet" 'echo "Hello, I am $name"' \
    "method" "getValue" 'echo "$value"' \
    "method" "setName" 'name="$1"'

# Create an instance
TestClass.new myobj

# Set initial property
myobj.name = "TestObject"

# Call methods and capture results
echo "Calling greet() method:"
result=$(myobj.greet)
echo "Result: $result"

echo
echo "Calling getValue() method (value not set yet):"
myobj.getValue

# Set value using method
echo "Setting name using setName() method:"
myobj.setName "NewObjectName"

echo "Calling greet() again with new name:"
myobj.greet

# Verify expected vs actual results
expected="Hello, I am NewObjectName"
actual=$(myobj.greet)

if [[ "$actual" == "$expected" ]]; then
    echo "✓ Method calls working correctly"
else
    echo "✗ Method call failed (expected: '$expected', got: '$actual')"
    exit 1
fi

# Clean up
myobj.delete
echo "✓ Instance cleaned up"

echo
echo "=== Example completed successfully ==="