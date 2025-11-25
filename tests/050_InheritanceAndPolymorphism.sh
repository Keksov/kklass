#!/bin/bash
# InheritanceAndPolymorphism
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "InheritanceAndPolymorphism" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

# Tests full OOP functionality: class hierarchy, method overriding, and polymorphic behavior


kk_test_section "Inheritance and Polymorphism Test Suite"

# Define base parent class with constructor
defineClass "TParent" "" \
    "property" "count" \
    "property" "baseValue" \
    "constructor" 'count=0; baseValue=0' \
    "method" "IncCount" 'count=$((count + $1))' \
    "method" "getCount" 'echo "$count"'

# Define child class that overrides IncCount
defineClass "TChild" "TParent" \
    "property" "childValue" \
    "constructor" 'TParent.constructor "$@"; childValue=0' \
    "method" "IncCount" 'count=$((count + $1 * 2))' \
    "method" "getChildValue" 'echo "$childValue"'

# Test 1: Parent Class Definition
kk_test_start "TParent class definition"
if declare -F TParent.new >/dev/null 2>&1; then
    kk_test_pass "TParent class definition"
else
    kk_test_fail "TParent class definition"
fi

# Test 2: Child Class Definition
kk_test_start "TChild class definition (inherits from TParent)"
if declare -F TChild.new >/dev/null 2>&1; then
    kk_test_pass "TChild class definition (inherits from TParent)"
else
    kk_test_fail "TChild class definition (inherits from TParent)"
fi

# Test 2.6: Parent baseValue property exists
kk_test_start "TParent has baseValue property"
TParent.new parent_with_base
parent_with_base.baseValue = 10
result=$(parent_with_base.baseValue)
expected="10"
if [[ "$result" == "$expected" ]]; then
    kk_test_pass "TParent has baseValue property"
else
    kk_test_fail "TParent has baseValue property (expected: $expected, got: $result)"
fi

# Test 2.7: Child Inherits baseValue from Parent
kk_test_start "TChild inherits baseValue property from TParent"
TChild.new child_basevalue
child_basevalue.baseValue = 10
result=$(child_basevalue.baseValue)
expected="10"
if [[ "$result" == "$expected" ]]; then
    kk_test_pass "TChild inherits baseValue property from TParent"
else
    kk_test_fail "TChild inherits baseValue property from TParent (expected: $expected, got: $result)"
fi

# Test 3: Parent Instance Creation
kk_test_start "TParent instance creation"
TParent.new parent1
if declare -F parent1.IncCount >/dev/null 2>&1; then
    kk_test_pass "TParent instance creation"
else
    kk_test_fail "TParent instance creation"
fi

# Test 4: Child Instance Creation
kk_test_start "TChild instance creation with inherited properties"
TChild.new child1
if declare -F child1.IncCount >/dev/null 2>&1; then
    kk_test_pass "TChild instance creation with inherited properties"
else
    kk_test_fail "TChild instance creation with inherited properties"
fi

# Test 5: Parent Method Works
kk_test_start "Parent IncCount method increments by 5"
parent1.IncCount 5
result=$(parent1.count)
expected="5"
if [[ "$result" == "$expected" ]]; then
    kk_test_pass "Parent IncCount method increments by 5"
else
    kk_test_fail "Parent IncCount method increments by 5 (expected: $expected, got: $result)"
fi

# Test 6: Child Method Doubles Increment
kk_test_start "Child IncCount method doubles increment (5*2=10)"
child1.IncCount 5
result=$(child1.count)
expected="10"
if [[ "$result" == "$expected" ]]; then
    kk_test_pass "Child IncCount method doubles increment (5*2=10)"
else
    kk_test_fail "Child IncCount method doubles increment (5*2=10) (expected: $expected, got: $result)"
fi

# Test 7: Parent Multiple Operations
kk_test_start "Parent accumulates values across multiple calls"
parent1.IncCount 3
result=$(parent1.count)
expected="8"
# 5 + 3 = 8
if [[ "$result" == "$expected" ]]; then
    kk_test_pass "Parent accumulates values across multiple calls"
else
    kk_test_fail "Parent accumulates values across multiple calls (expected: $expected, got: $result)"
fi

# Test 8: Child Multiple Operations
kk_test_start "Child accumulates doubled values across multiple calls"
child1.IncCount 3
result=$(child1.count)
expected="16"
# 10 + (3*2) = 16
if [[ "$result" == "$expected" ]]; then
    kk_test_pass "Child accumulates doubled values across multiple calls"
else
    kk_test_fail "Child accumulates doubled values across multiple calls (expected: $expected, got: $result)"
fi

# Test 9: Polymorphism - Different Behaviors
kk_test_start "Polymorphism verification: parent and child have different behaviors"
TParent.new parent2
TChild.new child2
parent2.IncCount 10
child2.IncCount 10
parent_result=$(parent2.count)
child_result=$(child2.count)
# Parent: 0 + 10 = 10, Child: 0 + (10 * 2) = 20
if [[ "$parent_result" == "10" && "$child_result" == "20" ]]; then
    kk_test_pass "Polymorphism verification: parent and child have different behaviors"
else
    kk_test_fail "Polymorphism verification: parent and child have different behaviors (expected: parent=10, child=20; got: parent=$parent_result, child=$child_result)"
fi

# Test 10: Multiple Independent Instances
kk_test_start "Multiple instances maintain independent state"
TChild.new child3
TChild.new child4
child3.IncCount 5
child4.IncCount 7
result3=$(child3.count)
result4=$(child4.count)
# 0 + (5*2) = 10, 0 + (7*2) = 14
if [[ "$result3" == "10" && "$result4" == "14" ]]; then
    kk_test_pass "Multiple instances maintain independent state"
else
    kk_test_fail "Multiple instances maintain independent state (expected: child3=10, child4=14; got: child3=$result3, child4=$result4)"
fi

# Test 11: Interleaved Operations
kk_test_start "Interleaved operations on different instances"
child3.IncCount 2
result3_after=$(child3.count)
child4.IncCount 3
result4_after=$(child4.count)
# child3: 10 + (2*2) = 14, child4: 14 + (3*2) = 20
if [[ "$result3_after" == "14" && "$result4_after" == "20" ]]; then
    kk_test_pass "Interleaved operations on different instances"
else
    kk_test_fail "Interleaved operations on different instances (expected: child3=14, child4=20; got: child3=$result3_after, child4=$result4_after)"
fi

# Test 12: Large Value Increment
kk_test_start "Large value increment handling"
TChild.new child5
child5.IncCount 1000
result=$(child5.count)
expected="2000"
if [[ "$result" == "$expected" ]]; then
    kk_test_pass "Large value increment handling"
else
    kk_test_fail "Large value increment handling (expected: $expected, got: $result)"
fi

# Test 13: Zero Increment
kk_test_start "Zero increment handling"
TChild.new child6
child6.IncCount 0
result=$(child6.count)
expected="0"
if [[ "$result" == "$expected" ]]; then
    kk_test_pass "Zero increment handling"
else
    kk_test_fail "Zero increment handling (expected: $expected, got: $result)"
fi

# Test 14: Negative Increment
kk_test_start "Negative increment (decrement) handling"
TParent.new parent3
parent3.IncCount 10
parent3.IncCount -3
result=$(parent3.count)
expected="7"
# 10 + (-3) = 7
if [[ "$result" == "$expected" ]]; then
    kk_test_pass "Negative increment (decrement) handling"
else
    kk_test_fail "Negative increment (decrement) handling (expected: $expected, got: $result)"
fi

# Test 15: Sequential Accumulation
kk_test_start "Sequential operations accumulation"
TChild.new child7
child7.IncCount 2
child7.IncCount 3
child7.IncCount 5
result=$(child7.count)
expected="20"
# 0 + (2*2) + (3*2) + (5*2) = 0 + 4 + 6 + 10 = 20
if [[ "$result" == "$expected" ]]; then
    kk_test_pass "Sequential operations accumulation"
else
    kk_test_fail "Sequential operations accumulation (expected: $expected, got: $result)"
fi

# Test 16: Three-Level Inheritance
kk_test_start "Grandchild class definition and instantiation"
defineClass "TGrandchild" "TChild" \
    "property" "grandchildValue" \
    "constructor" 'TChild.constructor "$@"; grandchildValue=0' \
    "method" "IncCount" 'count=$((count + $1 * 3))'

TGrandchild.new grandchild1
grandchild1.IncCount 5
result=$(grandchild1.count)
expected="15"
# 0 + (5*3) = 15
if [[ "$result" == "$expected" ]]; then
    kk_test_pass "Grandchild class definition and instantiation"
else
    kk_test_fail "Grandchild class definition and instantiation (expected: $expected, got: $result)"
fi

# Test 17: Grandchild Multiple Operations
kk_test_start "Grandchild polymorphic behavior"
grandchild1.IncCount 2
result=$(grandchild1.count)
expected="21"
# 15 + (2*3) = 21
if [[ "$result" == "$expected" ]]; then
    kk_test_pass "Grandchild polymorphic behavior"
else
    kk_test_fail "Grandchild polymorphic behavior (expected: $expected, got: $result)"
fi

# Test 18: Polymorphism with Three Levels
kk_test_start "Three-level polymorphism verification"
TParent.new p_test
TChild.new c_test
TGrandchild.new g_test
p_test.IncCount 10
c_test.IncCount 10
g_test.IncCount 10
p_result=$(p_test.count)
c_result=$(c_test.count)
g_result=$(g_test.count)
# Parent: 10, Child: 20, Grandchild: 30
if [[ "$p_result" == "10" && "$c_result" == "20" && "$g_result" == "30" ]]; then
    kk_test_pass "Three-level polymorphism verification"
else
    kk_test_fail "Three-level polymorphism verification (expected: parent=10, child=20, grandchild=30; got: parent=$p_result, child=$c_result, grandchild=$g_result)"
fi

# Test 19: Property Access Works
kk_test_start "Direct property access on instances"
TParent.new p_prop
p_prop.count = 42
result=$(p_prop.count)
if [[ "$result" == "42" ]]; then
    kk_test_pass "Direct property access on instances"
else
    kk_test_fail "Direct property access on instances (expected: 42, got: $result)"
fi

# Test 20: Instance Cleanup
kk_test_start "Instance deletion cleanup"
parent1.delete
if ! declare -F parent1.IncCount >/dev/null 2>&1; then
    kk_test_pass "Instance deletion cleanup"
else
    kk_test_fail "Instance deletion cleanup"
fi

# Test 21: Parent Method Called from Child
kk_test_start "Access to parent method from child instance"
TParent.new parent_access
parent_access.IncCount 7
result=$(parent_access.count)
expected="7"
if [[ "$result" == "$expected" ]]; then
    kk_test_pass "Access to parent method from child instance"
else
    kk_test_fail "Access to parent method from child instance (expected: $expected, got: $result)"
fi

# Test 22: Mixed Parent and Child Operations
kk_test_start "Mixed operations with parent and child instances"
TParent.new mixed_parent
TChild.new mixed_child
mixed_parent.IncCount 4
mixed_child.IncCount 4
mixed_parent.IncCount 2
result_p=$(mixed_parent.count)
result_c=$(mixed_child.count)
# parent: 4 + 2 = 6, child: 0 + (4*2) = 8
if [[ "$result_p" == "6" && "$result_c" == "8" ]]; then
    kk_test_pass "Mixed operations with parent and child instances"
else
    kk_test_fail "Mixed operations with parent and child instances (expected: parent=6, child=8; got: parent=$result_p, child=$result_c)"
fi

# Test 23: Count Property Mutation Tracking
kk_test_start "Count property mutation persists across calls"
TChild.new mutation_test
mutation_test.IncCount 1
val1=$(mutation_test.count)
mutation_test.IncCount 1
val2=$(mutation_test.count)
mutation_test.IncCount 1
val3=$(mutation_test.count)
# (1*2) + (1*2) + (1*2) = 2 + 2 + 2 = 6
if [[ "$val1" == "2" && "$val2" == "4" && "$val3" == "6" ]]; then
    kk_test_pass "Count property mutation persists across calls"
else
    kk_test_fail "Count property mutation persists across calls (expected: 2,4,6; got: $val1,$val2,$val3)"
fi

# Test 24: Inheritance Chain Depth
kk_test_start "Inheritance chain with four levels"
defineClass "TGreatGrandchild" "TGrandchild" \
    "property" "greatGrandchildValue" \
    "constructor" 'TGrandchild.constructor "$@"; greatGrandchildValue=0' \
    "method" "IncCount" 'count=$((count + $1 * 4))'

TGreatGrandchild.new ggc
ggc.IncCount 5
result=$(ggc.count)
expected="20"
# 0 + (5*4) = 20
if [[ "$result" == "$expected" ]]; then
    kk_test_pass "Inheritance chain with four levels"
else
    kk_test_fail "Inheritance chain with four levels (expected: $expected, got: $result)"
fi

# Test 25: Method Override Verification
kk_test_start "Method override changes behavior between parent and child"
TParent.new override_test_parent
TChild.new override_test_child
override_test_parent.count = 100
override_test_child.count = 100
override_test_parent.IncCount 5
override_test_child.IncCount 5
result_p=$(override_test_parent.count)
result_c=$(override_test_child.count)
# parent: 100 + 5 = 105, child: 100 + (5*2) = 110
if [[ "$result_p" == "105" && "$result_c" == "110" ]]; then
    kk_test_pass "Method override changes behavior between parent and child"
else
    kk_test_fail "Method override changes behavior between parent and child (expected: parent=105, child=110; got: parent=$result_p, child=$result_c)"
fi

# Test 26: Constructor with parameters
kk_test_start "Constructor with initialization parameters"
defineClass "TParentWithInit" "" \
    "property" "name" \
    "property" "initialValue" \
    "constructor" 'name="$1"; initialValue="${2:-0}"' \
    "method" "getName" 'echo "$name"' \
    "method" "getValue" 'echo "$initialValue"'

TParentWithInit.new initialized "TestName" 42
result_name=$(initialized.getName)
result_value=$(initialized.getValue)

if [[ "$result_name" == "TestName" ]] && [[ "$result_value" == "42" ]]; then
    kk_test_pass "Constructor with initialization parameters"
else
    kk_test_fail "Constructor with initialization parameters (name: '$result_name', value: '$result_value')"
fi

# Test 27: Child inherits and extends constructor
kk_test_start "Child constructor invokes parent with parameters"
defineClass "TChildWithInit" "TParentWithInit" \
    "property" "childName" \
    "constructor" 'TParentWithInit.constructor "$@"; childName="${1}-child"' \
    "method" "getChildName" 'echo "$childName"'

TChildWithInit.new child_init "Parent" 99
result_parent_name=$(child_init.getName)
result_child_name=$(child_init.getChildName)
result_parent_value=$(child_init.getValue)

if [[ "$result_parent_name" == "Parent" ]] && [[ "$result_parent_value" == "99" ]] && [[ "$result_child_name" == "Parent-child" ]]; then
    kk_test_pass "Child constructor invokes parent with parameters"
else
    kk_test_fail "Child constructor invokes parent with parameters (parent_name: '$result_parent_name', value: '$result_parent_value', child_name: '$result_child_name')"
fi

# Clean up remaining instances

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
