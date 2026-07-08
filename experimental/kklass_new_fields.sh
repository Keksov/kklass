#!/bin/bash

declare -gA __vars_main_TMyClass_obj1=(
    ["name"]="John Doe"
    ["age"]="30"
    ["id"]="1001"
)

TMyClass.getField() {
    local context_name="main"
    local class_name="TMyClass"
    local obj_name="obj1"
    local field_name="$1"
    
    local vars_name="__vars_${context_name}_${class_name}_${obj_name}"

    if ! declare -p "$vars_name" &>/dev/null; then
        echo "ERROR: array '$vars_name' not found" >&2
        return 1
    elif [[ $(declare -p "$vars_name" 2>/dev/null) != 'declare -A'* ]]; then
        echo "ERROR: '$vars_name' is not an associative array" >&2
        return 2
    fi

    local -n vars_ref="$vars_name"

    if [[ -z "${vars_ref[$field_name]+exists}" ]]; then
        echo "Error: the field '$field_name' doesn't exist" >&2
        return 3
    fi

    if [[ -z "$2" ]]; then
        echo -n "${vars_ref[$field_name]}"
        return 0
    fi

    local -n result_ref="$2" 
    result_ref="${vars_ref[$field_name]}"
}

# ============ TESTS ============

# Test 1: Get field with direct output
echo "Test 1: Get 'name' field (direct output)"
TMyClass.getField name
echo " (expected: John Doe)"
echo

# Test 2: Get field with variable output
echo "Test 2: Get 'age' field into variable"
TMyClass.getField age result
if [[ "$result" != "30" ]]; then
    echo "✗ FAIL Test 2: expected '30', got '$result'"
fi
echo

# Test 3: Get non-existent field
echo "Test 3: Get non-existent field 'email'"
TMyClass.getField email 2>&1 | grep -q "doesn't exist"
if [[ $? -ne 0 ]]; then
    echo "✗ FAIL Test 3: should return error about non-existent field"
fi
echo

# Test 4: Get 'id' field
echo "Test 4: Get 'id' field into variable"
TMyClass.getField id result
if [[ "$result" != "1001" ]]; then
    echo "✗ FAIL Test 4: expected '1001', got '$result'"
fi
echo

# Test 5: Check return code on success
echo "Test 5: Check return code on success"
TMyClass.getField name result
if [[ $? -ne 0 ]]; then
    echo "✗ FAIL Test 5: return code should be 0 on success, got $?"
fi
echo

# Test 6: Check return code on non-existent field
echo "Test 6: Check return code on non-existent field"
TMyClass.getField nonexistent result 2>/dev/null
if [[ $? -eq 0 ]]; then
    echo "✗ FAIL Test 6: return code should be non-zero on error, got $?"
fi
echo

# Test 7: Empty field name
echo "Test 7: Get field with empty name"
TMyClass.getField "" result 2>&1 | grep -q "doesn't exist"
if [[ $? -ne 0 ]]; then
    echo "✗ FAIL Test 7: should return error for empty field name"
fi
echo

# Test 8: All fields in separate variables
echo "Test 8: Get all fields"
TMyClass.getField name name_var
TMyClass.getField age age_var
TMyClass.getField id id_var
if [[ "$name_var" != "John Doe" || "$age_var" != "30" || "$id_var" != "1001" ]]; then
    echo "✗ FAIL Test 8: got name='$name_var', age='$age_var', id='$id_var'"
fi
echo

# ============ SECURITY TESTS ============

# Test 9: Code injection with command substitution
echo "Test 9: Security - command substitution injection"
injection='$(touch /tmp/pwned)'
TMyClass.getField "$injection" result 2>&1 | grep -q "doesn't exist"
if [[ $? -ne 0 ]]; then
    echo "✗ FAIL Test 9: should reject injection"
fi
if [[ -f /tmp/pwned ]]; then
    rm /tmp/pwned
    echo "✗ FAIL Test 9: command was executed!"
fi
echo

# Test 10: Code injection with backticks
echo "Test 10: Security - backtick injection"
injection='`touch /tmp/pwned2`'
TMyClass.getField "$injection" result 2>&1 | grep -q "doesn't exist"
if [[ $? -ne 0 ]]; then
    echo "✗ FAIL Test 10: should reject injection"
fi
if [[ -f /tmp/pwned2 ]]; then
    rm /tmp/pwned2
    echo "✗ FAIL Test 10: command was executed!"
fi
echo

# Test 11: Code injection with eval
echo "Test 11: Security - eval injection"
injection='name; touch /tmp/pwned3'
TMyClass.getField "$injection" result 2>&1 | grep -q "doesn't exist"
if [[ $? -ne 0 ]]; then
    echo "✗ FAIL Test 11: should reject injection"
fi
if [[ -f /tmp/pwned3 ]]; then
    rm /tmp/pwned3
    echo "✗ FAIL Test 11: command was executed!"
fi
echo

# Test 12: Field name with special characters
echo "Test 12: Field name with special characters"
injection='name*'
TMyClass.getField "$injection" result 2>&1 | grep -q "doesn't exist"
if [[ $? -ne 0 ]]; then
    echo "✗ FAIL Test 12: should reject field with wildcards"
fi
echo

# Test 13: Attempt variable expansion in field name
echo "Test 13: Prevent variable expansion in field name"
injected_var="name"
TMyClass.getField '$injected_var' result 2>&1 | grep -q "doesn't exist"
if [[ $? -ne 0 ]]; then
    echo "✗ FAIL Test 13: should not expand variables in field name"
fi
echo

# Test 14: Field name with path traversal attempt
echo "Test 14: Security - path traversal in field name"
TMyClass.getField "../../../etc/passwd" result 2>&1 | grep -q "doesn't exist"
if [[ $? -ne 0 ]]; then
    echo "✗ FAIL Test 14: should reject path traversal"
fi
echo

# Test 15: Field name with whitespace
echo "Test 15: Field name with whitespace"
TMyClass.getField "name " result 2>&1 | grep -q "doesn't exist"
if [[ $? -ne 0 ]]; then
    echo "✗ FAIL Test 15: should reject field with trailing space"
fi
echo

# Test 16: Field name with newline
echo "Test 16: Security - newline in field name"
injection=$'name\ntouch /tmp/pwned16'
TMyClass.getField "$injection" result 2>&1 | grep -q "doesn't exist"
if [[ $? -ne 0 ]]; then
    echo "✗ FAIL Test 16: should reject field with newline"
fi
if [[ -f /tmp/pwned16 ]]; then
    rm /tmp/pwned16
    echo "✗ FAIL Test 16: command was executed!"
fi
echo

# ============ EDGE CASES ============

# Test 17: Field with numeric name
echo "Test 17: Get field with numeric name"
declare -gA __vars_main_TMyClass_obj2=(
    ["123"]="numeric"
)
context_name="main"
class_name="TMyClass"
obj_name="obj2"
field_name="123"
vars_name="__vars_${context_name}_${class_name}_${obj_name}"
declare -n vars_ref="$vars_name"
if [[ "${vars_ref["123"]}" != "numeric" ]]; then
    echo "✗ FAIL Test 17: numeric field name not working"
fi
echo

