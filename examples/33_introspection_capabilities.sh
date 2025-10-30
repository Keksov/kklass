#!/bin/bash
# Example 33: Introspection Capabilities
# Demonstrates getting information about classes, instances, methods, and properties

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Introspection Capabilities Example ==="
echo

# Define a test class with various methods and properties
defineClass "Introspectable" "" \
    "property" "name" \
    "property" "value" \
    "property" "description" \
    "method" "getName" 'echo "$name"' \
    "method" "setName" 'name="$1"' \
    "method" "getValue" 'echo "$value"' \
    "method" "process" 'echo "Processing $name with value $value"' \
    "method" "getInfo" 'echo "Name: $name, Value: $value, Description: $description"'

# Create an instance
Introspectable.new obj

echo "✓ Introspectable class defined and instance created"

# Demonstrate introspection by examining available methods and properties
echo "=== Instance Introspection ==="

# List all available methods for the instance
echo "Available methods:"
declare -F | grep "obj\." | sed 's/declare -f //' | sort

# List all available properties (by trying to access them)
echo
echo "Available properties:"
obj.name = "test"
obj.value = "123"
obj.description = "Test object"

echo "  name: $(obj.name)"
echo "  value: $(obj.value)"
echo "  description: $(obj.description)"

# Test property existence checking
echo
echo "=== Property Existence Checking ==="
if obj.name 2>/dev/null; then
    echo "✓ Property 'name' exists"
else
    echo "✗ Property 'name' does not exist"
fi

if obj.nonexistent 2>/dev/null; then
    echo "✗ Property 'nonexistent' should not exist"
else
    echo "✓ Property 'nonexistent' correctly does not exist"
fi

# Demonstrate method introspection
echo
echo "=== Method Introspection ==="
echo "Testing method calls to discover available methods:"

# Test existing methods
if obj.getName 2>/dev/null; then
    echo "✓ Method 'getName' exists"
else
    echo "✗ Method 'getName' does not exist"
fi

if obj.nonexistentMethod 2>/dev/null; then
    echo "✗ Method 'nonexistentMethod' should not exist"
else
    echo "✓ Method 'nonexistentMethod' correctly does not exist"
fi

# Show method functionality
obj.setName "IntrospectedObject"
echo "Set name using setName method: $(obj.getName)"

# Clean up
obj.delete
echo "✓ Instance cleaned up"

echo
echo "=== Example completed successfully ==="