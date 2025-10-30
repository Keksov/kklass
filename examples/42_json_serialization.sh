#!/bin/bash
# Example 42: JSON Serialization
# Demonstrates JSON serialization using kklass_serializable.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"
source "$SCRIPT_DIR/../kklass_serializable.sh"

echo "=== JSON Serialization Example ==="
echo

# Define a simple User class
defineClass "User" "" \
    "property" "id" \
    "property" "username" \
    "property" "email" \
    "property" "first_name" \
    "property" "last_name" \
    "method" "getFullName" 'echo "$first_name $last_name"' \
    "method" "getInfo" 'echo "User $username ($first_name $last_name) - $email"'

echo "✓ User class defined"

# Add JSON serialization capability BEFORE creating instances
addSerializable "User" "" "json"

# Create and populate user instances
User.new user1
user1.id = "1"
user1.username = "john_doe"
user1.email = "john@example.com"
user1.first_name = "John"
user1.last_name = "Doe"

User.new user2
user2.id = "2"
user2.username = "jane_smith"
user2.email = "jane@example.com"
user2.first_name = "Jane"
user2.last_name = "Smith"

echo "✓ User instances created and populated"
echo

# Test JSON serialization
echo "=== JSON Serialization ==="
json1=$(user1.toJSON)
json2=$(user2.toJSON)

echo "User 1 JSON:"
echo "$json1"
echo
echo "User 2 JSON:"
echo "$json2"
echo

# Test deserialization
echo "=== JSON Deserialization ==="
User.new restored1
restored1.fromJSON "$json1"

echo "Restored user 1: $(restored1.getInfo)"
echo "Full name: $(restored1.getFullName)"
echo

# Verify integrity
if [[ "$(user1.username)" == "$(restored1.username)" ]] && \
   [[ "$(user1.email)" == "$(restored1.email)" ]]; then
    echo "✓ JSON serialization integrity verified"
else
    echo "✗ JSON serialization integrity check failed"
    exit 1
fi

# Test file persistence with JSON
echo
echo "=== JSON File Persistence ==="
temp_file=$(mktemp)
echo "Saving to: $temp_file"

saveObjects "$temp_file" user1 user2

echo "File contents (JSON):"
cat "$temp_file"
echo

# Load objects back
echo "=== Loading JSON Objects ==="
declare -a loaded_users
loadObjects "$temp_file" "User" loaded_users

echo "Loaded ${#loaded_users[@]} users:"
for user in "${loaded_users[@]}"; do
    echo "  - $($user.getInfo)"
done

# Clean up
rm -f "$temp_file"
user1.delete
user2.delete
restored1.delete
for user in "${loaded_users[@]}"; do
    ${user}.delete
done

echo
echo "=== Example completed successfully ==="

