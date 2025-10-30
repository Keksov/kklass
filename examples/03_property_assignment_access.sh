#!/bin/bash
# Example 03: Property Assignment and Access
# Demonstrates setting and getting property values on class instances

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Property Assignment and Access Example ==="
echo

# Define a class with properties
defineClass "TestClass" "" \
    "property" "name" \
    "property" "value" \
    "property" "description"

# Create an instance
TestClass.new myobj

# Assign values to properties
myobj.name = "TestObject"
myobj.value = "42"
myobj.description = "A test object for demonstration"

echo "✓ Properties assigned:"
echo "  name: $(myobj.name)"
echo "  value: $(myobj.value)"
echo "  description: $(myobj.description)"

# Verify the values are correct
if [[ "$(myobj.name)" == "TestObject" ]] && [[ "$(myobj.value)" == "42" ]]; then
    echo "✓ Property values are accessible and correct"
else
    echo "✗ Property values don't match expected results"
    exit 1
fi

# Demonstrate property access in string context
echo "Object info: $(myobj.name) has value $(myobj.value) - $(myobj.description)"

# Clean up
myobj.delete
echo "✓ Instance cleaned up"

echo
echo "=== Example completed successfully ==="