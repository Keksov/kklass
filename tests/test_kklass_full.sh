#!/bin/bash
# test_kklass_full.sh - Comprehensive test suite for kklass system
# Tests both core functionality and autoload/compilation features

set -e  # Exit on any error

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KKLASS_DIR="$SCRIPT_DIR/.."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test result functions
test_start() {
    echo -e "${BLUE}[TEST]${NC} $1"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

test_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

test_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

test_section() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

# Cleanup function
cleanup() {
    # Clean up any remaining instances
    for cleanup_func in $(declare -F | grep -E '\.delete$' | sed 's/ declare -f //' | head -20); do
        instance_name=$(echo "$cleanup_func" | sed 's/\.delete$//')
        if declare -F | grep -q "^declare -f $instance_name\."; then
            test_info "Cleaning up $instance_name"
            $instance_name.delete 2>/dev/null || true
        fi
    done
    
    # Clean up test files
    rm -f test_system.kk .ckk/test_system.ckk.sh 2>/dev/null || true
    rm -rf .ckk 2>/dev/null || true
}

# Set up cleanup trap
trap cleanup EXIT

# Source the class system
source "$KKLASS_DIR/kklass.sh"

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Comprehensive Kklass Test Suite${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# =============================================================================
# SECTION 1: CORE FUNCTIONALITY TESTS (27 tests)
# =============================================================================
test_section "SECTION 1: Core Functionality Tests"

# Test 1: Basic class creation
test_start "Basic class creation"
defineClass "TestClass" "" \
    "property" "name" \
    "property" "value" \
    "method" "greet" 'echo "Hello, I am $name"' \
    "method" "getValue" 'echo "$value"'

if declare -F | grep -q "TestClass.new"; then
    test_pass "Basic class creation"
else
    test_fail "Basic class creation"
fi

# Test 2: Instance creation
test_start "Instance creation"
TestClass.new myobj
if declare -F | grep -q "myobj\."; then
    test_pass "Instance creation"
else
    test_fail "Instance creation"
fi

# Test 3: Property assignment and access
test_start "Property assignment and access"
myobj.name = "TestObject"
myobj.value = "42"

if [[ "$(myobj.name)" == "TestObject" ]] && [[ "$(myobj.value)" == "42" ]]; then
    test_pass "Property assignment and access"
else
    test_fail "Property assignment and access"
fi

# Test 4: Method calls
test_start "Method calls"
result=$(myobj.greet)
expected="Hello, I am TestObject"
if [[ "$result" == "$expected" ]]; then
    test_pass "Method calls"
else
    test_fail "Method calls (expected: '$expected', got: '$result')"
fi

# Test 5: Single inheritance
test_start "Single inheritance"
defineClass "Animal" "" \
    "property" "species" \
    "method" "speak" 'echo "Some generic sound"'

defineClass "Dog" "Animal" \
    "property" "breed" \
    "method" "speak" 'echo "Woof!"'

Dog.new dog1
dog1.species = "Canine"
dog1.breed = "Golden Retriever"

if [[ "$(dog1.species)" == "Canine" ]] && [[ "$(dog1.breed)" == "Golden Retriever" ]]; then
    test_pass "Single inheritance"
else
    test_fail "Single inheritance"
fi

# Test 6: Method overriding
test_start "Method overriding"
result=$(dog1.speak)
if [[ "$result" == "Woof!" ]]; then
    test_pass "Method overriding"
else
    test_fail "Method overriding (expected: 'Woof!', got: '$result')"
fi

# Test 7: Parent method calls
test_start "Parent method calls"
defineClass "Cat" "Animal" \
    "method" "speak" 'echo "Meow!"' \
    "method" "speakAsAnimal" 'echo -n "Cat sound: "; $this.speak; echo -n "Animal sound: "; $this.parent speak'

Cat.new cat1
result=$(cat1.speakAsAnimal)
expected="Cat sound: Meow!Animal sound: Some generic sound"
if [[ "$result" == "$expected" ]]; then
    test_pass "Parent method calls"
else
    test_fail "Parent method calls (expected: '$expected', got: '$result')"
fi

# Test 8: Multiple inheritance levels
test_start "Multiple inheritance levels"
defineClass "GrandParent" "" \
    "method" "generation" 'echo "GrandParent"'

defineClass "Parent" "GrandParent" \
    "method" "generation" 'echo "Parent"; $this.parent generation'

defineClass "Child" "Parent" \
    "method" "generation" 'echo "Child"; $this.parent generation'

Child.new child1
result=$(child1.generation)
expected="ChildParentGrandParent"
if [[ "$result" == "$expected" ]]; then
    test_pass "Multiple inheritance levels"
else
    test_fail "Multiple inheritance levels (expected: '$expected', got: '$result')"
fi

# Test 9: Resource cleanup
test_start "Resource cleanup"
myobj.delete
if ! declare -F | grep -q "myobj\."; then
    test_pass "Resource cleanup"
else
    test_fail "Resource cleanup"
fi

# Test 10: Method with parameters
test_start "Method with parameters"
defineClass "Calculator" "" \
    "method" "add" 'echo $(($1 + $2))' \
    "method" "multiply" 'echo $(($1 * $2))'

Calculator.new calc
result=$(calc.add 5 3)
if [[ "$result" == "8" ]]; then
    test_pass "Method with parameters"
else
    test_fail "Method with parameters (expected: '8', got: '$result')"
fi

# Test 11: Property inheritance
test_start "Property inheritance"
defineClass "BaseWithProps" "" \
    "property" "baseProp"

defineClass "DerivedWithProps" "BaseWithProps" \
    "property" "derivedProp"

DerivedWithProps.new derived
derived.baseProp = "inherited"
derived.derivedProp = "own"

if [[ "$(derived.baseProp)" == "inherited" ]] && [[ "$(derived.derivedProp)" == "own" ]]; then
    test_pass "Property inheritance"
else
    test_fail "Property inheritance"
fi

# Test 12: Property access and computation in methods
test_start "Property access and computation in methods"
defineClass "Calculator2" "" \
    "property" "value" \
    "method" "double" 'echo $((value * 2))' \
    "method" "triple" 'echo $((value * 3))'

Calculator2.new calc2
calc2.value = "7"
result1=$(calc2.double)
result2=$(calc2.triple)
if [[ "$result1" == "14" ]] && [[ "$result2" == "21" ]]; then
    test_pass "Property access and computation in methods"
else
    test_fail "Property access and computation in methods (expected: '14' and '21', got: '$result1' and '$result2')"
fi

# Test 13: Multiple instances of same class
test_start "Multiple instances of same class"
defineClass "Point" "" \
    "property" "x" \
    "property" "y" \
    "method" "coordinates" 'echo "($x,$y)"'

Point.new point1
Point.new point2
point1.x = "10"
point1.y = "20"
point2.x = "30"
point2.y = "40"

if [[ "$(point1.coordinates)" == "(10,20)" ]] && [[ "$(point2.coordinates)" == "(30,40)" ]]; then
    test_pass "Multiple instances of same class"
else
    test_fail "Multiple instances of same class"
fi

# Test 14: Property values with spaces
test_start "Property values with spaces"
defineClass "Person" "" \
    "property" "fullName" \
    "method" "introduce" 'echo "My name is $fullName"'

Person.new person1
person1.fullName = "John Doe Smith"
result=$(person1.introduce)
expected="My name is John Doe Smith"
if [[ "$result" == "$expected" ]]; then
    test_pass "Property values with spaces"
else
    test_fail "Property values with spaces (expected: '$expected', got: '$result')"
fi

# Test 15: Nested method calls with $this
test_start "Nested method calls with \$this"
defineClass "Nested" "" \
    "method" "a" 'echo "A"' \
    "method" "b" 'echo -n "B:"; $this.a' \
    "method" "c" 'echo -n "C:"; $this.b'

Nested.new nested1
result=$(nested1.c)
expected="C:B:A"
if [[ "$result" == "$expected" ]]; then
    test_pass "Nested method calls with \$this"
else
    test_fail "Nested method calls with \$this (expected: '$expected', got: '$result')"
fi

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

# Test 17: Property used in inherited method
test_start "Property used in inherited method"
defineClass "Vehicle" "" \
    "property" "speed" \
    "method" "getSpeed" 'echo "Speed: $speed km/h"'

defineClass "Car" "Vehicle" \
    "property" "brand" \
    "method" "info" 'echo "Brand: $brand"; $this.getSpeed'

Car.new car1
car1.brand = "Toyota"
car1.speed = "120"
result=$(car1.info)
expected="Brand: ToyotaSpeed: 120 km/h"
if [[ "$result" == "$expected" ]]; then
    test_pass "Property used in inherited method"
else
    test_fail "Property used in inherited method (expected: '$expected', got: '$result')"
fi

# Test 18: Method calling parent and using properties
test_start "Method calling parent and using properties"
defineClass "Shape" "" \
    "property" "name" \
    "method" "describe" 'echo "Shape: $name"'

defineClass "Rectangle" "Shape" \
    "property" "width" \
    "property" "height" \
    "method" "describe" 'echo -n "Rectangle "; $this.parent describe; echo -n " ($width x $height)"'

Rectangle.new rect1
rect1.name = "MyRect"
rect1.width = "10"
rect1.height = "5"
result=$(rect1.describe)
expected="Rectangle Shape: MyRect (10 x 5)"
if [[ "$result" == "$expected" ]]; then
    test_pass "Method calling parent and using properties"
else
    test_fail "Method calling parent and using properties (expected: '$expected', got: '$result')"
fi

# Test 19: $this.method ensures current class context
test_start "\$this.method calls method in current class context"
defineClass "Base" "" \
    "method" "greet" 'echo "BaseGreeting"' \
    "method" "sayHello" 'echo -n "From Base: "; $this.greet'

defineClass "Derived" "Base" \
    "method" "greet" 'echo "DerivedGreeting"' \
    "method" "test" '$this.parent sayHello'

Derived.new derived1
result=$(derived1.test)
expected="From Base: BaseGreeting"
if [[ "$result" == "$expected" ]]; then
    test_pass "\$this.method calls method in current class context"
else
    test_fail "\$this.method calls method in current class context (expected: '$expected', got: '$result')"
fi

# Test 20: Method with multiple parameters and property access
test_start "Method with multiple parameters and property access"
defineClass "MathOps" "" \
    "property" "base" \
    "method" "addToBase" 'echo $((base + $1))' \
    "method" "multiplyBase" 'echo $((base * $1))'

MathOps.new math1
math1.base = "10"
result1=$(math1.addToBase 5)
result2=$(math1.multiplyBase 3)
if [[ "$result1" == "15" ]] && [[ "$result2" == "30" ]]; then
    test_pass "Method with multiple parameters and property access"
else
    test_fail "Method with multiple parameters and property access"
fi

# Test 21: Property access via .property method
test_start "Property access via .property method"
defineClass "TestProp" "" \
    "property" "data"

TestProp.new testprop
testprop.property "data" = "test_value"
result=$(testprop.property "data")
if [[ "$result" == "test_value" ]]; then
    test_pass "Property access via .property method"
else
    test_fail "Property access via .property method (expected: 'test_value', got: '$result')"
fi

# Test 22: Method modifying properties
test_start "Method modifying properties"
defineClass "ModifyTest" "" \
    "property" "name" \
    "property" "value" \
    "method" "greet" 'echo "Hello, I am $name"' \
    "method" "getValue" 'echo "$value"' \
    "method" "setName" 'name="$1"'

ModifyTest.new modtest
modtest.name = "InitialName"

# Call setName to modify property
modtest.setName "UpdatedName"

# Verify property was updated
result=$(modtest.greet)
expected="Hello, I am UpdatedName"
if [[ "$result" == "$expected" ]]; then
    test_pass "Method modifying properties"
else
    test_fail "Method modifying properties (expected: '$expected', got: '$result')"
fi

# Test 23: Method overriding with multiple derived classes
test_start "Method overriding with multiple derived classes"
defineClass "AnimalBase" "" \
    "property" "name" \
    "method" "speak" 'echo "Some generic animal sound"'

defineClass "DogClass" "AnimalBase" \
    "property" "breed" \
    "method" "speak" 'echo "Woof! Woof!"'

defineClass "CatClass" "AnimalBase" \
    "property" "color" \
    "method" "speak" 'echo "Meow!"'

DogClass.new dogtest
CatClass.new cattest

dogtest.name = "Buddy"
dogtest.breed = "Golden Retriever"
cattest.name = "Whiskers"
cattest.color = "Gray"

dog_sound=$(dogtest.speak)
cat_sound=$(cattest.speak)

if [[ "$dog_sound" == "Woof! Woof!" ]] && [[ "$cat_sound" == "Meow!" ]]; then
    test_pass "Method overriding with multiple derived classes"
else
    test_fail "Method overriding with multiple derived classes (expected: 'Woof! Woof!' and 'Meow!', got: '$dog_sound' and '$cat_sound')"
fi

dogtest.delete
cattest.delete

# Test 24: Static properties and methods
test_start "Static properties and methods"
defineClass "StaticCounter" "" \
    "static_property" "instance_count" \
    "static_property" "class_name" \
    "property" "id" \
    "static_method" "getInstanceCount" 'echo "$instance_count"' \
    "static_method" "getClassName" 'echo "$class_name"' \
    "static_method" "incrementCount" 'instance_count=$((instance_count + 1))' \
    "method" "initialize" 'id=$((instance_count + 1)); StaticCounter.incrementCount'

StaticCounter.class_name = "StaticCounter"
StaticCounter.instance_count = "0"

StaticCounter.new sc1
StaticCounter.new sc2
sc1.initialize
sc2.initialize

result_count=$(StaticCounter.getInstanceCount)
result_id1=$(sc1.id)
result_id2=$(sc2.id)
result_name=$(StaticCounter.getClassName)

if [[ "$result_count" == "2" ]] && [[ "$result_id1" == "1" ]] && [[ "$result_id2" == "2" ]] && [[ "$result_name" == "StaticCounter" ]]; then
    test_pass "Static properties and methods"
else
    test_fail "Static properties and methods (count: '$result_count', id1: '$result_id1', id2: '$result_id2', name: '$result_name')"
fi

sc1.delete
sc2.delete

# Test 25: Factory pattern with static counters
test_start "Factory pattern with static counters"
defineClass "Product" "" \
    "property" "id" \
    "property" "name" \
    "method" "getInfo" 'echo "Product #$id: $name"'

defineClass "Registry" "" \
    "static_property" "total_count" \
    "static_method" "register" '((total_count++)) || true' \
    "static_method" "getTotal" 'echo "$total_count"'

Registry.total_count = "0"

Product.new prod1
prod1.id = "1"
prod1.name = "Widget"
Registry.register

Product.new prod2
prod2.id = "2"
prod2.name = "Gadget"
Registry.register

result1=$(prod1.getInfo)
result2=$(prod2.getInfo)
count=$(Registry.getTotal)

if [[ "$result1" == "Product #1: Widget" ]] && [[ "$result2" == "Product #2: Gadget" ]] && [[ "$count" == "2" ]]; then
    test_pass "Factory pattern with static counters"
else
    test_fail "Factory pattern with static counters (got: '$result1', '$result2', count: '$count')"
fi

prod1.delete
prod2.delete

# Test 26: Singleton pattern with static properties
test_start "Singleton pattern with static properties"
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
            test_pass "Singleton pattern with static properties"
        else
            test_fail "Singleton pattern - state changes not shared (debug: '$debug1', '$debug2', '$debug3')"
        fi
    else
        test_fail "Singleton pattern - configuration not shared properly"
    fi
else
    test_fail "Singleton pattern - instances not identical ($instance1_ref, $instance2_ref, $instance3_ref)"
fi

$instance1_ref.delete 2>/dev/null || true

# =============================================================================
# SECTION 2: AUTOLOAD AND COMPILATION TESTS
# =============================================================================
test_section "SECTION 2: Autoload and Compilation Tests"

# Clean up any previous test files
rm -f test_system.kk .ckk/test_system.ckk.sh
rm -rf .ckk 2>/dev/null || true

# Create test class file
cat > test_system.kk <<'EOF'
defineClass Counter "" \
    property value \
    method increment 'value=$((value + 1)); echo $value' \
    method getValue 'echo $value'

defineClass Timer Counter \
    property start_time \
    method startTimer 'start_time=$(date +%s); echo "Timer started"' \
    method elapsed 'local now=$(date +%s); echo $((now - start_time))'
EOF

test_info "Created test_system.kk"

# Test 27: First load with autocompilation
test_start "Auto-compilation (first load)"
output=$(bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload test_system.kk" 2>&1)
if echo "$output" | grep -q "Compilation successful" && [[ -f .ckk/test_system.ckk.sh ]]; then
    test_pass "Auto-compilation (first load)"
else
    test_fail "Auto-compilation (first load)"
fi

# Test 28: Second load (use cached)
test_start "Using cached compiled version"
output=$(bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload test_system.kk" 2>&1)
if echo "$output" | grep -q "cached"; then
    test_pass "Using cached compiled version"
else
    test_fail "Using cached compiled version"
fi

# Test 29: Modify source and auto-recompile
test_start "Auto-recompilation on source change"
sleep 1
touch test_system.kk
output=$(bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload test_system.kk" 2>&1)
if echo "$output" | grep -q "newer\|Compiling"; then
    test_pass "Auto-recompilation on source change"
else
    test_fail "Auto-recompilation on source change"
fi

# Test 30: Force compilation
test_start "Force recompilation"
output=$(bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkrecompile test_system.kk" 2>&1)
if echo "$output" | grep -q "Force\|Compiling"; then
    test_pass "Force recompilation"
else
    test_fail "Force recompilation"
fi

# Test 31: Runtime mode (--no-compile)
test_start "Runtime mode (--no-compile)"
rm -f .ckk/test_system.ckk.sh
output=$(bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload test_system.kk --no-compile" 2>&1)
if echo "$output" | grep -q "runtime\|No compiled"; then
    test_pass "Runtime mode (--no-compile)"
else
    test_fail "Runtime mode (--no-compile)"
fi

# Test 32: Functional test with compiled classes
test_start "Functional test with compiled classes"
bash -c "source '$KKLASS_DIR/kklass_autoload.sh' && kkload test_system.kk --force-compile" >/dev/null 2>&1
result=$(bash -c "source .ckk/test_system.ckk.sh && Counter.new cnt && cnt.value = 7 && cnt.increment")
if [[ "$result" == "8" ]]; then
    test_pass "Functional test with compiled classes"
else
    test_fail "Functional test with compiled classes (expected: 8, got: $result)"
fi

# Test 33: Inheritance in compiled classes
test_start "Inheritance in compiled classes"
result=$(bash -c "source .ckk/test_system.ckk.sh && Timer.new tmr && tmr.value = 5 && tmr.increment")
if [[ "$result" == "6" ]]; then
    test_pass "Inheritance in compiled classes"
else
    test_fail "Inheritance in compiled classes (expected: 6, got: $result)"
fi

# =============================================================================
# SECTION 3: EDGE CASES AND ERROR HANDLING
# =============================================================================
test_section "SECTION 3: Edge Cases and Error Handling"

# Test 34: Error handling - non-existent method
test_start "Error handling - non-existent method"
defineClass "ErrorTest" "" \
    "method" "existingMethod" 'echo "exists"'

ErrorTest.new errortest
if ! errortest.nonExistentMethod 2>/dev/null; then
    test_pass "Error handling - non-existent method"
else
    test_fail "Error handling - non-existent method"
fi

# Test 35: Complex property names
test_start "Complex property names"
defineClass "ComplexTest" "" \
    "property" "file_name" \
    "property" "file_size"

ComplexTest.new complextest
complextest.file_name = "test.txt"
complextest.file_size = "1024"

if [[ "$(complextest.file_name)" == "test.txt" ]] && [[ "$(complextest.file_size)" == "1024" ]]; then
    test_pass "Complex property names"
else
    test_fail "Complex property names"
fi

# Test 36: Deep inheritance chain
test_start "Deep inheritance chain with properties"
defineClass "A" "" \
    "property" "propA" \
    "method" "showA" 'echo "A:$propA"'

defineClass "B" "A" \
    "property" "propB" \
    "method" "showB" 'echo "B:$propB"'

defineClass "C" "B" \
    "property" "propC" \
    "method" "showAll" '$this.showA; $this.showB; echo "C:$propC"'

C.new obj_c
obj_c.propA = "1"
obj_c.propB = "2"
obj_c.propC = "3"
result=$(obj_c.showAll)
expected="A:1B:2C:3"
if [[ "$result" == "$expected" ]]; then
    test_pass "Deep inheritance chain with properties"
else
    test_fail "Deep inheritance chain with properties (expected: '$expected', got: '$result')"
fi

# Test 37: Composition patterns (objects containing other objects)
test_start "Composition patterns"
defineClass "Engine" "" \
    "property" "type" \
    "property" "horsepower" \
    "method" "getInfo" 'echo "Engine: $type ($horsepower HP)"'

defineClass "Wheel" "" \
    "property" "position" \
    "property" "size" \
    "method" "getInfo" 'echo "Wheel $position: $size inches"'

defineClass "CarComposition" "" \
    "property" "make" \
    "property" "model" \
    "property" "engine" \
    "property" "wheels" \
    "method" "assemble" 'Engine.new engine; Wheel.new wheel1; Wheel.new wheel2; engine.type = "V8"; engine.horsepower = "350"; wheel1.position = "front"; wheel2.position = "rear"; wheel1.size = "18"; wheel2.size = "18"; engine="engine"; wheels="wheel1 wheel2"' \
    "method" "getInfo" 'echo "$make $model"; $engine.getInfo; for w in $wheels; do $w.getInfo; done'

CarComposition.new mycar
mycar.make = "Toyota"
mycar.model = "Camry"
mycar.assemble

result=$(mycar.getInfo)
if [[ "$result" == *"Toyota Camry"* ]] && [[ "$result" == *"V8"* ]] && [[ "$result" == *"18 inches"* ]]; then
    test_pass "Composition patterns"
else
    test_fail "Composition patterns (expected car with engine and wheels, got: '$result')"
fi

mycar.delete

# Test 38: Computed properties
test_start "Computed properties (getter and setter)"
defineClass "UserWithComputed" "" \
    "property" "first_name" \
    "property" "last_name" \
    "computed_property" "full_name" "get_full_name" "set_full_name" \
    "method" "get_full_name" 'echo "$first_name $last_name"' \
    "method" "set_full_name" 'local full="$1"; local f l; IFS=" " read -r f l <<< "$full"; first_name="$f"; last_name="$l"'

UserWithComputed.new user_comp

user_comp.first_name = "John"
user_comp.last_name = "Doe"
result1=$(user_comp.full_name)

if [[ "$result1" == "John Doe" ]]; then
    # Test computed setter
    user_comp.full_name = "Jane Smith"
    result2=$(user_comp.first_name)
    result3=$(user_comp.last_name)
    
    if [[ "$result2" == "Jane" ]] && [[ "$result3" == "Smith" ]]; then
        test_pass "Computed properties (getter and setter)"
    else
        test_fail "Computed properties - setter failed (first: '$result2', last: '$result3')"
    fi
else
    test_fail "Computed properties - getter failed (expected: 'John Doe', got: '$result1')"
fi

user_comp.delete

# Test 39: Lazy properties
test_start "Lazy properties (lazy initialization)"
defineClass "LazyTest" "" \
    "property" "base_value" \
    "lazy_property" "expensive" "compute_expensive" \
    "method" "compute_expensive" 'echo "computed_from_${base_value}"'

LazyTest.new lazy_obj
lazy_obj.base_value = "test"

# Access lazy property - should compute
result1=$(lazy_obj.expensive)

# Verify it computed correctly
if [[ "$result1" == "computed_from_test" ]]; then
    # Change base value
    lazy_obj.base_value = "changed"
    result2=$(lazy_obj.expensive)
    
    # Note: Due to bash subshell limitations, lazy caching only works within same shell context
    # This test just verifies the lazy property computes correctly
    if [[ "$result2" == "computed_from_changed" ]]; then
        test_pass "Lazy properties (lazy initialization)"
    else
        test_fail "Lazy properties failed on recompute (result2: '$result2')"
    fi
else
    test_fail "Lazy properties failed on first compute (result1: '$result1')"
fi

lazy_obj.delete

# Test 40: Observer pattern
test_start "Observer pattern"
defineClass "ObserverTest" "" \
    "property" "name" \
    "property" "last_message" \
    "method" "update" 'last_message="$1"'

defineClass "EmailNotifierTest" "ObserverTest"
defineClass "LoggerObserverTest" "ObserverTest"

EmailNotifierTest.new emailNotifier
emailNotifier.name = "Email"
LoggerObserverTest.new loggerObs
loggerObs.name = "Logger"

# Test 1: Both observers receive notification
emailNotifier.update "Test news"
loggerObs.update "Test news"
result1=$(emailNotifier.last_message)
result2=$(loggerObs.last_message)

if [[ "$result1" == "Test news" ]] && [[ "$result2" == "Test news" ]]; then
    # Test 2: Only one observer receives update
    loggerObs.update "Second news"
    result3=$(emailNotifier.last_message)
    result4=$(loggerObs.last_message)
    
    if [[ "$result3" == "Test news" ]] && [[ "$result4" == "Second news" ]]; then
        test_pass "Observer pattern"
    else
        test_fail "Observer pattern - selective update failed (email: '$result3', logger: '$result4')"
    fi
else
    test_fail "Observer pattern - update failed (email: '$result1', logger: '$result2')"
fi

emailNotifier.delete
loggerObs.delete

# Test 41: Builder pattern
test_start "Builder pattern"
defineClass "Computer" "" \
    "property" "cpu" \
    "property" "ram" \
    "property" "storage" \
    "property" "gpu" \
    "property" "os" \
    "property" "accessories" \
    "method" "getSpecs" 'echo "CPU: $cpu, RAM: $ram, Storage: $storage, GPU: $gpu, OS: $os, Accessories: $accessories"'

defineClass "ComputerBuilder" "" \
    "property" "computer" \
    "property" "counter" \
    "method" "createComputer" 'counter=$((counter + 1)); local name="comp_$counter"; Computer.new "$name"; computer="$name"' \
    "method" "setCPU" 'eval "$computer.cpu = \"\$1\""' \
    "method" "setRAM" 'eval "$computer.ram = \"\$1\""' \
    "method" "setStorage" 'eval "$computer.storage = \"\$1\""' \
    "method" "setGPU" 'eval "$computer.gpu = \"\$1\""' \
    "method" "setOS" 'eval "$computer.os = \"\$1\""' \
    "method" "addAccessory" 'local acc="$(eval "$computer.accessories")"; eval "$computer.accessories = \"\$acc \$1\""' \
    "method" "build" 'echo "$computer"'

ComputerBuilder.new builder_test
builder_test.createComputer
builder_test.setCPU "Intel i9-12900K"
builder_test.setRAM "32GB DDR5"
builder_test.setStorage "2TB NVMe SSD"
builder_test.setGPU "NVIDIA RTX 4080"
builder_test.setOS "Windows 11"
builder_test.addAccessory "Gaming Keyboard"
builder_test.addAccessory "Gaming Mouse"
gaming_computer=$(builder_test.build)

specs=$(eval "$gaming_computer.getSpecs")
if [[ "$specs" == *"Intel i9-12900K"* ]] && [[ "$specs" == *"32GB DDR5"* ]] && [[ "$specs" == *"Gaming Mouse"* ]]; then
    # Build second computer to test reusability
    builder_test.createComputer
    builder_test.setCPU "AMD Ryzen 9"
    builder_test.setRAM "64GB DDR4"
    workstation_computer=$(builder_test.build)
    
    specs2=$(eval "$workstation_computer.getSpecs")
    if [[ "$specs2" == *"AMD Ryzen 9"* ]] && [[ "$specs2" == *"64GB DDR4"* ]] && [[ "$specs2" != *"Gaming Mouse"* ]]; then
        test_pass "Builder pattern"
    else
        test_fail "Builder pattern - second build failed (got: '$specs2')"
    fi
    
    eval "$workstation_computer.delete" 2>/dev/null || true
else
    test_fail "Builder pattern - first build failed (got: '$specs')"
fi

builder_test.delete
eval "$gaming_computer.delete" 2>/dev/null || true

# Test 42: Strategy pattern
test_start "Strategy pattern"
defineClass "SortStrategy" "" \
    "property" "name" \
    "method" "sort" 'echo "[$name] Generic sorting strategy"'

defineClass "BubbleSort" "SortStrategy" \
    "method" "sort" 'echo "[$name] Using bubble sort algorithm"'

defineClass "QuickSort" "SortStrategy" \
    "method" "sort" 'echo "[$name] Using quick sort algorithm"'

defineClass "MergeSort" "SortStrategy" \
    "method" "sort" 'echo "[$name] Using merge sort algorithm"'

defineClass "Sorter" "" \
    "property" "strategy" \
    "property" "data" \
    "method" "setStrategy" 'strategy="$1"' \
    "method" "setData" 'data="$1"' \
    "method" "performSort" 'echo "Sorting data: $data"; eval "${strategy}.sort"' \
    "method" "getStrategyName" 'eval "${strategy}.name"'

Sorter.new sorter_test
BubbleSort.new bubbleSort_test
bubbleSort_test.name = "BubbleSort"
QuickSort.new quickSort_test
quickSort_test.name = "QuickSort"
MergeSort.new mergeSort_test
mergeSort_test.name = "MergeSort"

# Test strategy switching
sorter_test.setStrategy "bubbleSort_test"
sorter_test.setData "5 3 8 1 9 2"
result1=$(sorter_test.getStrategyName)
result2=$(sorter_test.performSort)

sorter_test.setStrategy "quickSort_test"
result3=$(sorter_test.getStrategyName)

sorter_test.setStrategy "mergeSort_test"
result4=$(sorter_test.getStrategyName)

if [[ "$result1" == "BubbleSort" ]] && [[ "$result2" == *"Sorting data: 5 3 8 1 9 2"* ]] && \
   [[ "$result2" == *"bubble sort algorithm"* ]] && \
   [[ "$result3" == "QuickSort" ]] && [[ "$result4" == "MergeSort" ]]; then
    test_pass "Strategy pattern"
else
    test_fail "Strategy pattern (result1: '$result1', result3: '$result3', result4: '$result4')"
fi

sorter_test.delete
bubbleSort_test.delete
quickSort_test.delete
mergeSort_test.delete

# Cleanup remaining instances
cleanup

# =============================================================================
# SECTION 4: SERIALIZATION TESTS
# =============================================================================
test_section "SECTION 4: Serialization Tests"

# Load serialization module
source "$KKLASS_DIR/kklass_serializable.sh"

# Test 43: String serialization with defineSerializableClass
test_start "String serialization with defineSerializableClass"
defineSerializableClass "UserStr" "" ":" "string" \
    "property" "id" \
    "property" "username" \
    "property" "email" \
    "method" "getInfo" 'echo "User: $username ($email)"'

UserStr.new user_str1
user_str1.id = "1"
user_str1.username = "john_doe"
user_str1.email = "john@example.com"

serialized=$(user_str1.toString)
UserStr.new user_str_restored
user_str_restored.fromString "$serialized" >/dev/null

if [[ "$(user_str1.username)" == "$(user_str_restored.username)" ]] && \
   [[ "$(user_str1.email)" == "$(user_str_restored.email)" ]]; then
    test_pass "String serialization with defineSerializableClass"
else
    test_fail "String serialization with defineSerializableClass"
fi

user_str1.delete
user_str_restored.delete

# Test 44: JSON serialization with addSerializable
test_start "JSON serialization with addSerializable"
defineClass "UserJSON" "" \
    "property" "id" \
    "property" "username" \
    "property" "email" \
    "method" "getInfo" 'echo "User: $username ($email)"'

addSerializable "UserJSON" "" "json"

UserJSON.new user_json1
user_json1.id = "2"
user_json1.username = "jane_smith"
user_json1.email = "jane@example.com"

json_data=$(user_json1.toJSON)
UserJSON.new user_json_restored
user_json_restored.fromJSON "$json_data"

if [[ "$(user_json1.username)" == "$(user_json_restored.username)" ]] && \
   [[ "$(user_json1.email)" == "$(user_json_restored.email)" ]]; then
    test_pass "JSON serialization with addSerializable"
else
    test_fail "JSON serialization with addSerializable"
fi

user_json1.delete
user_json_restored.delete

# Test 45: Nested object serialization (string format)
test_start "Nested object serialization (string format)"
defineClass "Address" "" \
    "property" "street" \
    "property" "city" \
    "property" "zipcode"

defineClass "PersonNested" "" \
    "property" "name" \
    "property" "age" \
    "property" "address_data"

addSerializable "Address" ":" "string"
addSerializable "PersonNested" "|" "string"

Address.new addr_test
addr_test.street = "123 Main St"
addr_test.city = "New York"
addr_test.zipcode = "10001"

PersonNested.new person_test
person_test.name = "Test User"
person_test.age = "30"
person_test.address_data = "$(addr_test.toString)"

person_str=$(person_test.toString)
PersonNested.new person_test_restored
person_test_restored.fromString "$person_str"

Address.new addr_test_restored
addr_test_restored.fromString "$(person_test_restored.address_data)"

if [[ "$(person_test.name)" == "$(person_test_restored.name)" ]] && \
   [[ "$(addr_test.city)" == "$(addr_test_restored.city)" ]]; then
    test_pass "Nested object serialization (string format)"
else
    test_fail "Nested object serialization (string format)"
fi

addr_test.delete
person_test.delete
person_test_restored.delete
addr_test_restored.delete

# Test 46: Mixed format serialization (string and JSON)
test_start "Mixed format serialization (string and JSON)"
defineClass "Item" "" \
    "property" "code" \
    "property" "description" \
    "property" "quantity"

addSerializable "Item" ":" "string"
addSerializable "Item" "" "json"

Item.new item1
item1.code = "ITM001"
item1.description = "Test Item"
item1.quantity = "10"

# Test both toString and toJSON work
str_data=$(item1.toString)
json_data=$(item1.toJSON)

Item.new item_from_str
item_from_str.fromString "$str_data"

Item.new item_from_json
item_from_json.fromJSON "$json_data"

if [[ "$(item1.code)" == "$(item_from_str.code)" ]] && \
   [[ "$(item1.code)" == "$(item_from_json.code)" ]]; then
    test_pass "Mixed format serialization (string and JSON)"
else
    test_fail "Mixed format serialization (string and JSON)"
fi

item1.delete
item_from_str.delete
item_from_json.delete

# Cleanup serialization test instances
cleanup

# =============================================================================
# FINAL RESULTS
# =============================================================================
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Test Results Summary${NC}"
echo -e "${CYAN}========================================${NC}"
echo "Total tests: $TESTS_TOTAL"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed.${NC}"
    exit 1
fi
