#!/bin/bash
# Example 02: Instance Creation
# Demonstrates creating instances of classes and verifying their existence

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Instance Creation Example ==="
echo

# Define a simple class first
defineClass "TestClass" "" \
    "property" "name" \
    "method" "greet" 'echo "Hello from $name"'

# Create an instance
TestClass.new myobj

echo "✓ Instance 'myobj' created"

# Verify the instance exists by checking if its functions are available
if declare -F | grep -q "myobj\."; then
    echo "✓ Instance functions are available in the shell"
else
    echo "✗ Instance functions not found"
    exit 1
fi

# List all instance methods
echo "Available instance methods:"
declare -F | grep "myobj\." | sed 's/declare -f //'

# Clean up
myobj.delete
echo "✓ Instance cleaned up"

echo
echo "=== Example completed successfully ==="