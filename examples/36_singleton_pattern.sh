#!/bin/bash
# Example 36: Singleton Pattern
# Demonstrates ensuring only one instance of a class exists

# Source the kklass system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass.sh"

echo "=== Singleton Pattern Example ==="
echo

# Define a Singleton class
defineClass "Configuration" "" \
    "static_property" "instance" \
    "static_property" "initialized" \
    "property" "database_url" \
    "property" "api_key" \
    "property" "debug_mode" \
    "static_method" "getInstance" 'if [[ "$instance" == "" ]]; then Configuration.new config_instance; instance="config_instance"; initialized="true"; echo "Created new Configuration instance" >&2; else echo "Returning existing Configuration instance" >&2; fi; echo "$instance"' \
    "method" "setDatabaseUrl" 'database_url="$1"' \
    "method" "setApiKey" 'api_key="$1"' \
    "method" "setDebugMode" 'debug_mode="$1"' \
    "method" "getConfig" 'echo "DB: $database_url, API: $api_key, Debug: $debug_mode"'

echo "✓ Configuration singleton class defined"

# Get singleton instance
echo "=== Getting Singleton Instance ==="
Configuration.getInstance >/dev/null; instance1_ref="$REPLY"
Configuration.getInstance >/dev/null; instance2_ref="$REPLY"
Configuration.getInstance >/dev/null; instance3_ref="$REPLY"

echo "✓ Got three references to singleton"

# Check if they are the same instance
if [[ "$instance1_ref" == "$instance2_ref" ]] && [[ "$instance2_ref" == "$instance3_ref" ]]; then
    echo "✓ All references point to the same singleton instance"
else
    echo "✗ Singleton pattern failed - different instances created"
    exit 1
fi

# Configure the singleton
echo
echo "=== Configuring Singleton ==="
$instance1_ref.setDatabaseUrl "postgresql://localhost:5432/myapp"
$instance1_ref.setApiKey "secret-api-key-12345"
$instance1_ref.setDebugMode "true"

echo "Configuration set via first reference"

# Access configuration from different references
echo
echo "=== Accessing Configuration from Different References ==="
echo "Config from instance1: $($instance1_ref.getConfig)"
echo "Config from instance2: $($instance2_ref.getConfig)"
echo "Config from instance3: $($instance3_ref.getConfig)"

# Verify all references see the same configuration
config1=$($instance1_ref.getConfig)
config2=$($instance2_ref.getConfig)

if [[ "$config1" == "$config2" ]]; then
    echo "✓ Singleton pattern working correctly - all references share state"
else
    echo "✗ Singleton pattern failed - different state in references"
    exit 1
fi

# Demonstrate that changes are reflected across all references
echo
echo "=== Testing State Sharing ==="
$instance2_ref.setDebugMode "false"
echo "Changed debug mode via instance2"

echo "Debug mode from all references:"
echo "  instance1: $($instance1_ref.debug_mode)"
echo "  instance2: $($instance2_ref.debug_mode)"
echo "  instance3: $($instance3_ref.debug_mode)"

# Verify state is shared
if [[ "$($instance1_ref.debug_mode)" == "false" ]] && [[ "$($instance2_ref.debug_mode)" == "false" ]] && [[ "$($instance3_ref.debug_mode)" == "false" ]]; then
    echo "✓ State changes are shared across all references"
else
    echo "✗ State sharing failed"
    exit 1
fi

# Clean up
$instance1_ref.delete
echo "✓ Singleton instance cleaned up"

echo
echo "=== Example completed successfully ==="