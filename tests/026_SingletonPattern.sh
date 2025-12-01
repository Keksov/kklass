#!/bin/bash
# SingletonPattern
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "SingletonPattern" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 26: Singleton pattern with static properties
kt_test_start "Singleton pattern with static properties"
defineClass "Configuration" "" \
    "static_property" "instance" \
    "static_property" "initialized" \
    "property" "database_url" \
    "property" "api_key" \
    "property" "debug_mode" \
    "static_method" "getInstance" 'if [[ "$instance" == "" ]]; then Configuration.new config_instance; instance="config_instance"; initialized="true"; else true; fi; echo "$instance"' \
    "method" "setDatabaseUrl" 'database_url="$1"' \
    "method" "setApiKey" 'api_key="$1"' \
    "method" "setDebugMode" 'debug_mode="$1"' \
    "method" "getConfig" 'echo "DB: $database_url, API: $api_key, Debug: $debug_mode"'

# Get singleton instance three times
Configuration.getInstance >/dev/null; instance1_ref="$REPLY"
Configuration.getInstance >/dev/null; instance2_ref="$REPLY"
Configuration.getInstance >/dev/null; instance3_ref="$REPLY"

# Verify all references point to same instance
if [[ "$instance1_ref" == "$instance2_ref" ]] && [[ "$instance2_ref" == "$instance3_ref" ]] && [[ -n "$instance1_ref" ]]; then
    # Configure via first reference
    $instance1_ref.setDatabaseUrl "postgresql://localhost:5432/myapp"
    $instance1_ref.setApiKey "secret-api-key"
    $instance1_ref.setDebugMode "true"
    
    # Verify state is shared across all references
    config1=$($instance1_ref.getConfig)
    config2=$($instance2_ref.getConfig)
    config3=$($instance3_ref.getConfig)
    
    if [[ "$config1" == "$config2" ]] && [[ "$config2" == "$config3" ]] && [[ "$config1" == *"postgresql"* ]]; then
        # Test state mutation sharing
        $instance2_ref.setDebugMode "false"
        debug1=$($instance1_ref.debug_mode)
        debug2=$($instance2_ref.debug_mode)
        debug3=$($instance3_ref.debug_mode)
        
        if [[ "$debug1" == "false" ]] && [[ "$debug2" == "false" ]] && [[ "$debug3" == "false" ]]; then
            kt_test_pass "Singleton pattern with static properties"
        else
            kt_test_fail "Singleton pattern - state changes not shared (debug: '$debug1', '$debug2', '$debug3')"
        fi
    else
        kt_test_fail "Singleton pattern - configuration not shared properly"
    fi
else
    kt_test_fail "Singleton pattern - instances not identical ($instance1_ref, $instance2_ref, $instance3_ref)"
fi

$instance1_ref.delete 2>/dev/null || true

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
