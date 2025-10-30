#!/bin/bash
# Example 30: Complex Property Names
# Demonstrates using property names with underscores and numbers

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Complex Property Names Example ==="
echo

# Define a class with complex property names
defineClass "ComplexTest" "" \
    "property" "file_name" \
    "property" "file_size" \
    "property" "created_date" \
    "property" "modified_time" \
    "property" "owner_name" \
    "method" "getFileInfo" 'echo "File: $file_name, Size: $file_size bytes"' \
    "method" "getTimestamps" 'echo "Created: $created_date, Modified: $modified_time"' \
    "method" "getOwner" 'echo "Owner: $owner_name"'

# Create instance
ComplexTest.new complextest

# Set complex property names
complextest.file_name = "test.txt"
complextest.file_size = "1024"
complextest.created_date = "2024-01-15"
complextest.modified_time = "2024-01-20"
complextest.owner_name = "john_doe"

echo "✓ Complex properties set:"
echo "  file_name: $(complextest.file_name)"
echo "  file_size: $(complextest.file_size)"
echo "  created_date: $(complextest.created_date)"
echo "  modified_time: $(complextest.modified_time)"
echo "  owner_name: $(complextest.owner_name)"

# Test that complex property names work correctly
if [[ "$(complextest.file_name)" == "test.txt" ]] && [[ "$(complextest.file_size)" == "1024" ]]; then
    echo "✓ Complex property names working correctly"
else
    echo "✗ Complex property names failed"
    exit 1
fi

# Test methods that use complex property names
echo "File info:"
complextest.getFileInfo

echo "Timestamps:"
complextest.getTimestamps

echo "Owner:"
complextest.getOwner

# Test with numbers in property names
defineClass "NumberProps" "" \
    "property" "prop1" \
    "property" "prop2" \
    "property" "data_123" \
    "method" "showAll" 'echo "prop1=$prop1, prop2=$prop2, data_123=$data_123"'

NumberProps.new numtest
numtest.prop1 = "value1"
numtest.prop2 = "value2"
numtest.data_123 = "number_value"

echo "Numbered properties:"
numtest.showAll

# Clean up
complextest.delete
numtest.delete
echo "✓ Instances cleaned up"

echo
echo "=== Example completed successfully ==="