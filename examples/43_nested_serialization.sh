
#!/bin/bash
# Example 41: Complex Object Serialization
# Demonstrates serialization of nested objects using both string and JSON formats

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"
source "$SCRIPT_DIR/../kklass_serializable.sh"

echo "=== Complex Object Serialization Example ==="
echo

# Define Address class
defineClass "Address" "" \
    "property" "street" \
    "property" "city" \
    "property" "zipcode" \
    "method" "getFullAddress" 'echo "$street, $city $zipcode"'

echo "✓ Address class defined"

# Define Contact class
defineClass "Contact" "" \
    "property" "phone" \
    "property" "email" \
    "property" "website" \
    "method" "getContactInfo" 'echo "Phone: $phone, Email: $email"'

echo "✓ Contact class defined"

# Define Person class containing nested objects
defineClass "Person" "" \
    "property" "name" \
    "property" "age" \
    "property" "address_data" \
    "property" "contact_data" \
    "method" "getInfo" 'echo "$name, age $age"'

echo "✓ Person class defined"
echo

# Add string serialization to all classes
echo "=== Adding String Serialization ==="
addSerializable "Address" ":" "string"
addSerializable "Contact" ":" "string"
addSerializable "Person" "|" "string"

# Create nested objects for string serialization
echo
echo "=== Creating Objects (String Format) ==="
Address.new addr1
addr1.street = "123 Main St"
addr1.city = "New York"
addr1.zipcode = "10001"

Contact.new contact1
contact1.phone = "+1-555-0100"
contact1.email = "john@example.com"
contact1.website = "https://john.example.com"

Person.new person1
person1.name = "John Doe"
person1.age = "30"
# Serialize nested objects as part of person data
person1.address_data = "$(addr1.toString)"
person1.contact_data = "$(contact1.toString)"

echo "✓ Objects created with nested data"
echo "Person: $(person1.getInfo)"
echo "Address: $(addr1.getFullAddress)"
echo "Contact: $(contact1.getContactInfo)"

# Test string serialization
echo
echo "=== String Serialization Test ==="
person_str=$(person1.toString)
echo "Serialized Person: $person_str"
echo

# Deserialize and restore nested objects
Person.new person1_restored
person1_restored.fromString "$person_str"

Address.new addr1_restored
addr1_restored.fromString "$(person1_restored.address_data)"

Contact.new contact1_restored
contact1_restored.fromString "$(person1_restored.contact_data)"

echo "✓ Deserialized from string"
echo "Restored Person: $(person1_restored.getInfo)"
echo "Restored Address: $(addr1_restored.getFullAddress)"
echo "Restored Contact: $(contact1_restored.getContactInfo)"

# Verify string serialization integrity
if [[ "$(person1.name)" == "$(person1_restored.name)" ]] && \
   [[ "$(addr1.city)" == "$(addr1_restored.city)" ]] && \
   [[ "$(contact1.email)" == "$(contact1_restored.email)" ]]; then
    echo "✓ String serialization integrity verified"
else
    echo "✗ String serialization integrity check failed"
    exit 1
fi

# Clean up string format objects
addr1.delete
contact1.delete
person1.delete
addr1_restored.delete
contact1_restored.delete
person1_restored.delete

echo
echo "=== JSON Serialization Test ==="

# Add JSON serialization to existing classes
addSerializable "Address" "" "json"
addSerializable "Contact" "" "json"
addSerializable "Person" "" "json"

# Create new objects using same classes
echo
echo "Creating new objects for JSON test..."
Address.new addr2
addr2.street = "789 Elm St"
addr2.city = "Chicago"
addr2.zipcode = "60601"

Contact.new contact2
contact2.phone = "+1-555-0300"
contact2.email = "alice@example.com"
contact2.website = "https://alice.dev"

Person.new person2
person2.name = "Alice Johnson"
person2.age = "35"
person2.address_data = "$(addr2.toJSON)"
person2.contact_data = "$(contact2.toJSON)"

echo "✓ Objects created for JSON test"
echo "Address: $(addr2.getFullAddress)"
echo "Contact: $(contact2.getContactInfo)"
echo "Person: $(person2.getInfo)"
echo

# Test JSON serialization
echo "Serialized JSONs:"
addr_json=$(addr2.toJSON)
echo "Address: $addr_json"

contact_json=$(contact2.toJSON)
echo "Contact: $contact_json"

person_json=$(person2.toJSON)
echo "Person: $person_json"
echo

# Deserialize from JSON
Address.new addr3
addr3.fromJSON "$addr_json"

Contact.new contact3
contact3.fromJSON "$contact_json"

Person.new person3
person3.fromJSON "$person_json"

echo "✓ Deserialized from JSON"
echo "Restored Address: $(addr3.getFullAddress)"
echo "Restored Contact: $(contact3.getContactInfo)"
echo "Restored Person: $(person3.getInfo)"

# Verify JSON serialization integrity
if [[ "$(addr2.city)" == "$(addr3.city)" ]] && \
   [[ "$(contact2.email)" == "$(contact3.email)" ]] && \
   [[ "$(person2.name)" == "$(person3.name)" ]]; then
    echo "✓ JSON serialization integrity verified"
else
    echo "✗ JSON serialization integrity check failed"
    exit 1
fi

# File persistence test (mixed formats)
echo
echo "=== Mixed Format File Persistence ==="
temp_file=$(mktemp)
echo "Saving mixed string/JSON objects to: $temp_file"

# Save objects - some will use toString, others toJSON
saveObjects "$temp_file" person1 addr2 contact2 person2

echo "File contents (mixed formats):"
cat "$temp_file"
echo

# Load back from file
echo "Loading Person objects:"
declare -a loaded_persons
loadObjects "$temp_file" "Person" loaded_persons
for obj in "${loaded_persons[@]}"; do
    echo "  - $($obj.getInfo)"
    ${obj}.delete
done

# Clean up
rm -f "$temp_file"
addr2.delete
contact2.delete
person2.delete
addr3.delete
contact3.delete
person3.delete

echo
echo "=== Example completed successfully ==="
