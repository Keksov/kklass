#!/bin/bash
# Example 14: Property Values with Spaces
# Demonstrates handling property values that contain spaces and special characters

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Property Values with Spaces Example ==="
echo

# Define a Person class
defineClass "Person" "" \
    "property" "fullName" \
    "property" "title" \
    "property" "description" \
    "method" "introduce" 'echo "My name is $fullName"' \
    "method" "fullIntroduction" 'echo "Hi, I am $title $fullName. $description"'

# Create person instance
Person.new person1

# Set properties with spaces and special characters
person1.fullName = "John Doe Smith"
person1.title = "Dr."
person1.description = "I am a software engineer with 10 years of experience in web development."

echo "✓ Properties with spaces set:"
echo "  fullName: $(person1.fullName)"
echo "  title: $(person1.title)"
echo "  description: $(person1.description)"

# Test method calls with spaced values
echo "Simple introduction:"
result=$(person1.introduce)
echo "Result: $result"

echo "Full introduction:"
result2=$(person1.fullIntroduction)
echo "Result: $result2"

# Verify expected vs actual results
expected="My name is John Doe Smith"
if [[ "$result" == "$expected" ]]; then
    echo "✓ Property values with spaces handled correctly"
else
    echo "✗ Property values with spaces failed (expected: '$expected', got: '$result')"
    exit 1
fi

# Test with quotes in property values
person1.description = 'He said "Hello, World!" and everyone cheered.'
echo "Introduction with quotes:"
person1.fullIntroduction

# Clean up
person1.delete
echo "✓ Instance cleaned up"

echo
echo "=== Example completed successfully ==="