#!/bin/bash
# Example 41: Serialization using String
# Demonstrates using defineSerializableClass for automatic serialization

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"
source "$SCRIPT_DIR/../kklass_serializable.sh"

echo "=== Serialization using String Example ==="
echo

# Define a serializable User class
defineSerializableClass "User" "" ":" "string" \
    "property" "id" \
    "property" "username" \
    "property" "email" \
    "property" "first_name" \
    "property" "last_name" \
    "method" "getFullName" 'echo "$first_name $last_name"' \
    "method" "getInfo" 'echo "User $username ($first_name $last_name) - $email"'

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

echo "✓ User instances created"
echo

# Test serialization
echo "=== Serialization ==="
serialized1=$(user1.toString)
serialized2=$(user2.toString)

echo "User 1: $serialized1"
echo "User 2: $serialized2"
echo

# Test deserialization
echo "=== Deserialization ==="
User.new restored1
restored1.fromString "$serialized1" >/dev/null

echo "Restored: $(restored1.getInfo)"
echo "Full name: $(restored1.getFullName)"
echo

# Verify integrity
if [[ "$(user1.username)" == "$(restored1.username)" ]] && \
   [[ "$(user1.email)" == "$(restored1.email)" ]]; then
    echo "✓ Serialization integrity verified"
else
    echo "✗ Serialization failed"
    exit 1
fi

# Test file persistence
temp_file=$(mktemp)
saveObjects "$temp_file" user1 user2
echo "✓ Saved to $temp_file"

# Load back
declare -a loaded_users
loadObjects "$temp_file" "User" loaded_users

echo "✓ Loaded ${#loaded_users[@]} users:"
for user in "${loaded_users[@]}"; do
    echo "  - $(${user}.getInfo)"
done

# Cleanup
rm -f "$temp_file"
user1.delete
user2.delete
restored1.delete
for user in "${loaded_users[@]}"; do
    ${user}.delete
done

echo
echo "=== Example completed successfully ==="
