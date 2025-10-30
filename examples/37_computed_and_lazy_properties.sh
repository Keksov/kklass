#!/bin/bash
# Example 37: Computed and Lazy Properties
# Demonstrates computed properties (with getters/setters) and lazy-loaded properties

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Computed and Lazy Properties Example ==="
echo

# Define a User class with computed and lazy properties
defineClass "User" "" \
    "property" "first_name" \
    "property" "last_name" \
    "property" "email" \
    "computed_property" "full_name" "get_full_name" "set_full_name" \
    "lazy_property" "gravatar" "compute_gravatar" \
    "method" "get_full_name" 'echo "$first_name $last_name"' \
    "method" "set_full_name" 'local full="$1"; local f l; IFS=" " read -r f l <<< "$full"; first_name="$f"; last_name="$l"' \
    "method" "compute_gravatar" '
        local em
        em="$(printf "%s" "$email" | tr "[:upper:]" "[:lower:]" | xargs)"
        local hash
        if command -v md5sum >/dev/null 2>&1; then
            hash="$(printf "%s" "$em" | md5sum | cut -d" " -f1)"
        elif command -v md5 >/dev/null 2>&1; then
            hash="$(printf "%s" "$em" | md5 -q)"
        else
            hash="00000000000000000000000000000000"
        fi
        echo "https://www.gravatar.com/avatar/$hash?s=80&d=identicon"
    ' \
    "method" "invalidateGravatar" 'unset __INST___data["gravatar"]' \
    "method" "getInfo" 'echo "User: $($this.full_name) <$email>"'

echo "✓ User class defined with computed and lazy properties"

# Demonstrate computed property (full_name)
echo
echo "=== Computed Property: full_name ==="
User.new user1

user1.first_name = "Ada"
user1.last_name = "Lovelace"
user1.email = "ada@example.com"

echo "First name: $(user1.first_name)"
echo "Last name: $(user1.last_name)"
echo "Full name (computed): $(user1.full_name)"

# Demonstrate computed setter - splits full name into first/last
echo
echo "=== Computed Setter: full_name ==="
user1.full_name = "Augusta Ada"
echo "After setting full_name to 'Augusta Ada':"
echo "  First name: $(user1.first_name)"
echo "  Last name: $(user1.last_name)"
echo "  Full name: $(user1.full_name)"

# Demonstrate lazy property (gravatar)
echo
echo "=== Lazy Property: gravatar ==="
user1.full_name = "Grace Hopper"
user1.email = "grace@example.com"

echo "Email: $(user1.email)"
echo "Gravatar URL (lazy, computed once): $(user1.gravatar)"
echo "Gravatar URL (cached, no recomputation): $(user1.gravatar)"

# Demonstrate lazy property invalidation
echo
echo "=== Lazy Property Invalidation ==="
user1.email = "grace@newmail.com"
echo "Email changed to: $(user1.email)"
echo "Gravatar (still cached): $(user1.gravatar)"

user1.invalidateGravatar
echo "After invalidation, Gravatar (recomputed): $(user1.gravatar)"

# Another example with a different user
echo
echo "=== Another User Example ==="
User.new user2

user2.first_name = "Alan"
user2.last_name = "Turing"
user2.email = "alan@turing.com"

echo "Info: $(user2.getInfo)"
echo "Gravatar: $(user2.gravatar)"

# Demonstrate computed property with more complex data
echo
echo "=== Product with Computed Price ==="
defineClass "Product" "" \
    "property" "base_price" \
    "property" "tax_rate" \
    "property" "discount" \
    "computed_property" "final_price" "calculate_price" "-" \
    "method" "calculate_price" '
        local price=$(echo "scale=2; $base_price * (1 + $tax_rate / 100) * (1 - $discount / 100)" | bc 2>/dev/null || echo "$base_price")
        echo "$price"
    ' \
    "method" "getInfo" 'echo "Product: base=$base_price, tax=$tax_rate%, discount=$discount%, final=$($this.final_price)"'

Product.new product1

product1.base_price = "100"
product1.tax_rate = "20"
product1.discount = "10"

echo "$(product1.getInfo)"
echo "Final price (computed): \$$(product1.final_price)"

# Change values and see computed property update
product1.discount = "25"
echo "After discount change to 25%:"
echo "Final price (recomputed): \$$(product1.final_price)"

# Demonstrate lazy loading with expensive computation
echo
echo "=== Lazy Loading: File Hash ==="
defineClass "FileInfo" "" \
    "property" "filename" \
    "lazy_property" "checksum" "compute_checksum" \
    "method" "compute_checksum" '
        if [[ -f "$filename" ]]; then
            local hash
            if command -v sha256sum >/dev/null 2>&1; then
                hash="$(sha256sum "$filename" 2>/dev/null | cut -d" " -f1)"
            elif command -v shasum >/dev/null 2>&1; then
                hash="$(shasum -a 256 "$filename" 2>/dev/null | cut -d" " -f1)"
            else
                hash="[no sha256 tool available]"
            fi
            echo "$hash"
        else
            echo "[file not found]"
        fi
    ' \
    "method" "invalidateChecksum" 'unset __INST___data["checksum"]'

FileInfo.new fileinfo

# Create a test file
echo "test content" > /tmp/test_kklass_file.txt
fileinfo.filename = "/tmp/test_kklass_file.txt"

echo "Filename: $(fileinfo.filename)"
echo "Checksum (lazy, computed once): $(fileinfo.checksum)"
echo "Checksum (cached): $(fileinfo.checksum)"

# Modify file and invalidate cache
echo "modified content" > /tmp/test_kklass_file.txt
fileinfo.invalidateChecksum
echo "After file modification and cache invalidation:"
echo "Checksum (recomputed): $(fileinfo.checksum)"

# Clean up
rm -f /tmp/test_kklass_file.txt

# Benefits summary
echo
echo "=== Computed and Lazy Properties Benefits ==="
echo "✓ Computed properties:"
echo "  - Automatically calculate values based on other properties"
echo "  - Support custom getters and setters"
echo "  - No need to manually sync dependent values"
echo ""
echo "✓ Lazy properties:"
echo "  - Compute expensive values only when first accessed"
echo "  - Cache results for subsequent accesses"
echo "  - Can be invalidated and recomputed when needed"

# Clean up
user1.delete
user2.delete
product1.delete
fileinfo.delete
echo "✓ All instances cleaned up"

echo
echo "=== Example completed successfully ==="
