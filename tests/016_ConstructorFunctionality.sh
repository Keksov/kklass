#!/bin/bash
# 016_constructor_functionality.sh - Test constructor functionality with initialization

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
parse_args "$@"

# Test 16: Constructor functionality with initialization
test_start "Constructor functionality with initialization"
defineClass "ConstructedClass" "" \
    "property" "initialized" \
    "property" "created_at" \
    "property" "name" \
    "constructor" 'initialized="true"; created_at=$(date +%s); name="$1"' \
    "method" "isInitialized" 'echo "$initialized"' \
    "method" "getName" 'echo "$name"' \
    "method" "getAge" 'echo "$(( $(date +%s) - created_at )) seconds old"'

ConstructedClass.new constructed "TestObject"
result_init=$(constructed.isInitialized)
result_name=$(constructed.getName)

if [[ "$result_init" == "true" ]] && [[ "$result_name" == "TestObject" ]]; then
    test_pass "Constructor functionality with initialization"
else
    test_fail "Constructor functionality with initialization (init: '$result_init', name: '$result_name')"
fi

# Test 16.1: Child class constructor invokes parent constructor
test_start "Child class constructor invokes parent constructor"
defineClass "TChild" "ConstructedClass" \
    "property" "child_initialized" \
    "constructor" 'child_initialized="true"; ConstructedClass.constructor "$@"' \
    "method" "isChildInitialized" 'echo "$child_initialized"'

TChild.new child "ChildObject"
result_parent_init=$(child.isInitialized)
result_parent_name=$(child.getName)
result_child_init=$(child.isChildInitialized)

if [[ "$result_parent_init" == "true" ]] && [[ "$result_parent_name" == "ChildObject" ]] && [[ "$result_child_init" == "true" ]]; then
    test_pass "Child class constructor invokes parent constructor"
else
    test_fail "Child class constructor invokes parent constructor (parent_init: '$result_parent_init', parent_name: '$result_parent_name', child_init: '$result_child_init')"
fi