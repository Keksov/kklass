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

# Test 16.2: Inherited properties and methods from parent class
test_start "Inherited properties and methods from parent class work in child"
TChild.new child2 "ChildObject2"
result_age=$(child2.getAge)
result_name=$(child2.getName)
if [[ "$result_age" =~ ^[0-9]+\ seconds\ old$ ]] && [[ "$result_name" == "ChildObject2" ]]; then
    test_pass "Inherited properties and methods from parent class work in child"
else
    test_fail "Inherited properties and methods from parent class work in child (age: '$result_age', name: '$result_name')"
fi

# Test 16.3: Constructor with optional parameters
test_start "Constructor with optional parameters"
defineClass "OptionalClass" "" \
    "property" "title" \
    "property" "description" \
    "constructor" 'title="${1:-DefaultTitle}"; description="${2:-DefaultDescription}"' \
    "method" "getTitle" 'echo "$title"' \
    "method" "getDescription" 'echo "$description"'

OptionalClass.new opt1 "CustomTitle"
result_title=$(opt1.getTitle)
result_desc=$(opt1.getDescription)

if [[ "$result_title" == "CustomTitle" ]] && [[ "$result_desc" == "DefaultDescription" ]]; then
    test_pass "Constructor with optional parameters"
else
    test_fail "Constructor with optional parameters (title: '$result_title', desc: '$result_desc')"
fi

# Test 16.4: Multiple level inheritance (Grandfather, Father, Grandson)
test_start "Multiple level inheritance with constructors"
defineClass "GrandFather" "" \
    "property" "gf_name" \
    "property" "gf_status" \
    "constructor" 'gf_name="$1"; gf_status="active"' \
    "method" "getGFName" 'echo "$gf_name"' \
    "method" "getGFStatus" 'echo "$gf_status"'

defineClass "Father" "GrandFather" \
    "property" "father_role" \
    "property" "father_status" \
    "constructor" 'GrandFather.constructor "$@"; father_role="father"; father_status="working"' \
    "method" "getFatherRole" 'echo "$father_role"' \
    "method" "getFatherStatus" 'echo "$father_status"'

defineClass "GrandSon" "Father" \
    "property" "gs_age" \
    "property" "gs_status" \
    "constructor" 'Father.constructor "$@"; gs_age=25; gs_status="student"' \
    "method" "getGSAge" 'echo "$gs_age"' \
    "method" "getGSStatus" 'echo "$gs_status"'

GrandSon.new grandson "Smith"
result_gf_name=$(grandson.getGFName)
result_gf_status=$(grandson.getGFStatus)
result_role=$(grandson.getFatherRole)
result_father_status=$(grandson.getFatherStatus)
result_age=$(grandson.getGSAge)
result_gs_status=$(grandson.getGSStatus)

if [[ "$result_gf_name" == "Smith" ]] && [[ "$result_gf_status" == "active" ]] && [[ "$result_role" == "father" ]] && [[ "$result_father_status" == "working" ]] && [[ "$result_age" == "25" ]] && [[ "$result_gs_status" == "student" ]]; then
    test_pass "Multiple level inheritance with constructors"
else
    test_fail "Multiple level inheritance with constructors (gf_name: '$result_gf_name', gf_status: '$result_gf_status', role: '$result_role', father_status: '$result_father_status', age: '$result_age', gs_status: '$result_gs_status')"
fi

# Test 16.5: Constructor with complex initialization
test_start "Constructor with complex initialization"
defineClass "ComplexInit" "" \
    "property" "data_count" \
    "property" "timestamp" \
    "property" "status" \
    "constructor" 'data_count=0; timestamp=$(date +%Y%m%d%H%M%S); status="initialized"' \
    "method" "getStatus" 'echo "$status"' \
    "method" "getDataCount" 'echo "$data_count"'

ComplexInit.new complex
result_status=$(complex.getStatus)
result_count=$(complex.getDataCount)

if [[ "$result_status" == "initialized" ]] && [[ "$result_count" == "0" ]]; then
    test_pass "Constructor with complex initialization"
else
    test_fail "Constructor with complex initialization (status: '$result_status', count: '$result_count')"
fi

# Test 16.6: Constructor with property modification after creation
test_start "Constructor with property modification after creation"
defineClass "MutableClass" "" \
    "property" "value" \
    "property" "modified_count" \
    "constructor" 'value="$1"; modified_count=0' \
    "method" "getValue" 'echo "$value"' \
    "method" "setValue" 'value="$1"; modified_count=$((modified_count + 1))' \
    "method" "getModifiedCount" 'echo "$modified_count"'

MutableClass.new mutable "InitialValue"
mutable.setValue "NewValue"
result_value=$(mutable.getValue)
result_mod_count=$(mutable.getModifiedCount)

if [[ "$result_value" == "NewValue" ]] && [[ "$result_mod_count" == "1" ]]; then
    test_pass "Constructor with property modification after creation"
else
    test_fail "Constructor with property modification after creation (value: '$result_value', count: '$result_mod_count')"
fi

# Test 16.7: Child class constructor with parent.constructor syntax
test_start "Child class constructor invokes parent via parent.constructor syntax"
defineClass "TParent" "" \
    "property" "parent_init" \
    "property" "parent_name" \
    "constructor" 'parent_init="true"; parent_name="$1"' \
    "method" "getParentInit" 'echo "$parent_init"' \
    "method" "getParentName" 'echo "$parent_name"'

defineClass "TChildWithParent" "TParent" \
    "property" "child_init" \
    "constructor" 'parent.constructor "$@"; child_init="true"' \
    "method" "getChildInit" 'echo "$child_init"'

TChildWithParent.new child_obj "ParentObjectName"
result_parent_init=$(child_obj.getParentInit)
result_parent_name=$(child_obj.getParentName)
result_child_init=$(child_obj.getChildInit)

if [[ "$result_parent_init" == "true" ]] && [[ "$result_parent_name" == "ParentObjectName" ]] && [[ "$result_child_init" == "true" ]]; then
    test_pass "Child class constructor invokes parent via parent.constructor syntax"
else
    test_fail "Child class constructor invokes parent via parent.constructor syntax (parent_init: '$result_parent_init', parent_name: '$result_parent_name', child_init: '$result_child_init')"
fi

# Test 16.8: Multi-level inheritance with parent.constructor syntax
test_start "Multi-level inheritance with parent.constructor syntax"
defineClass "GrandParent2" "" \
    "property" "gp_value" \
    "constructor" 'gp_value="$1"' \
    "method" "getGPValue" 'echo "$gp_value"'

defineClass "Parent2" "GrandParent2" \
    "property" "p_value" \
    "constructor" 'parent.constructor "$@"; p_value="$2"' \
    "method" "getPValue" 'echo "$p_value"'

defineClass "Child2" "Parent2" \
    "property" "c_value" \
    "constructor" 'parent.constructor "$@"; c_value="$3"' \
    "method" "getCValue" 'echo "$c_value"'

Child2.new multilevel "GrandValue" "ParentValue" "ChildValue"
result_gp=$(multilevel.getGPValue)
result_p=$(multilevel.getPValue)
result_c=$(multilevel.getCValue)

if [[ "$result_gp" == "GrandValue" ]] && [[ "$result_p" == "ParentValue" ]] && [[ "$result_c" == "ChildValue" ]]; then
    test_pass "Multi-level inheritance with parent.constructor syntax"
else
    test_fail "Multi-level inheritance with parent.constructor syntax (gp: '$result_gp', p: '$result_p', c: '$result_c')"
fi