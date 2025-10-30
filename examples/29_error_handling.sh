#!/bin/bash
# Example 29: Error Handling - Non-existent Method
# Demonstrates error handling when calling non-existent methods

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Error Handling - Non-existent Method Example ==="
echo

# Define a class with limited methods
defineClass "ErrorTest" "" \
    "property" "name" \
    "method" "existingMethod" 'echo "This method exists"' \
    "method" "anotherMethod" 'echo "This also exists"'

# Create instance
ErrorTest.new errortest
errortest.name = "TestObject"

echo "✓ ErrorTest instance created"

# Test existing methods work
echo "Testing existing method:"
errortest.existingMethod

# Test calling non-existent method (should fail gracefully)
echo "Testing non-existent method:"
if ! errortest.nonExistentMethod 2>/dev/null; then
    echo "✓ Non-existent method call handled correctly (failed as expected)"
else
    echo "✗ Non-existent method call should have failed but didn't"
    exit 1
fi

# Test another non-existent method
echo "Testing another non-existent method:"
if ! errortest.someOtherMissingMethod 2>/dev/null; then
    echo "✓ Error handling working correctly for all non-existent methods"
else
    echo "✗ Error handling failed for non-existent method"
    exit 1
fi

# Verify existing methods still work after error attempts
echo "Verifying existing methods still work:"
errortest.anotherMethod

# Clean up
errortest.delete
echo "✓ Instance cleaned up"

echo
echo "=== Example completed successfully ==="