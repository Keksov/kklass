#!/bin/bash
# Example 09: Resource Cleanup
# Demonstrates proper cleanup of class instances and their associated functions

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Resource Cleanup Example ==="
echo

# Define a class
defineClass "TestClass" "" \
    "property" "name" \
    "method" "greet" 'echo "Hello, I am $name"'

# Create an instance
TestClass.new myobj
myobj.name = "TestObject"

echo "✓ Instance created and configured"

# Verify instance exists
if declare -F | grep -q "myobj\."; then
    echo "✓ Instance functions are available before cleanup"
else
    echo "✗ Instance functions not found before cleanup"
    exit 1
fi

# List instance methods before cleanup
echo "Instance methods before cleanup:"
declare -F | grep "myobj\." | sed 's/declare -f //' | head -5

# Clean up the instance
myobj.delete
echo "✓ Instance deleted"

# Verify instance no longer exists
if ! declare -F | grep -q "myobj\."; then
    echo "✓ Instance functions properly removed after cleanup"
else
    echo "✗ Instance functions still exist after cleanup"
    exit 1
fi

echo "✓ Resource cleanup working correctly"

echo
echo "=== Example completed successfully ==="