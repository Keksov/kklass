#!/bin/bash
# ProceduresAndFunctions
# Auto-migrated from kklass test framework

KKTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../kktests" && pwd)"
source "$KKTESTS_LIB_DIR/kk-test.sh"

kk_test_init "ProceduresAndFunctions" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 36a: Basic procedure definition and execution
kk_test_start "Basic procedure definition"
defineClass "Logger" "" \
    "property" "messages"

defineProcedure "Logger" "log" '
    if [[ -z "$messages" ]]; then
        messages="$1"
    else
        messages="$messages"$'\n'"$1"
    fi
'

Logger.new logger
logger.log "First message"
logger.log "Second message"

result=$(logger.messages)
if [[ "$result" == *"First message"* ]] && [[ "$result" == *"Second message"* ]]; then
    kk_test_pass "Basic procedure definition"
else
    kk_test_fail "Basic procedure definition"
fi

# Test 36b: Procedure that modifies multiple properties
kk_test_start "Procedure modifying multiple properties"
defineClass "Rectangle" "" \
    "property" "width" \
    "property" "height" \
    "property" "area"

defineProcedure "Rectangle" "setDimensions" '
    width="$1"
    height="$2"
    area=$((width * height))
'

Rectangle.new rect
rect.setDimensions "5" "10"

w=$(rect.width)
h=$(rect.height)
a=$(rect.area)

if [[ "$w" == "5" ]] && [[ "$h" == "10" ]] && [[ "$a" == "50" ]]; then
    kk_test_pass "Procedure modifying multiple properties"
else
    kk_test_fail "Procedure modifying multiple properties"
fi

# Test 36c: Basic function definition and result retrieval
kk_test_start "Basic function with result"
defineClass "Calculator" "" \
    "property" "value"

defineFunction "Calculator" "square" '
    RESULT=$((value * value))
'

Calculator.new calc
calc.value = "7"
calc.square

if [[ "${CALCULATOR_SQUARE}" == "49" ]]; then
    kk_test_pass "Basic function with result"
else
    kk_test_fail "Basic function with result"
fi

# Test 36d: Function with parameter handling
kk_test_start "Function with parameter handling"
defineClass "StringUtils" ""

defineFunction "StringUtils" "reverseString" '
    local str="$1"
    local reversed=""
    local len=${#str}
    for ((i=len-1; i>=0; i--)); do
        reversed="${reversed}${str:$i:1}"
    done
    RESULT="$reversed"
'

StringUtils.new strutil
strutil.reverseString "hello"

if [[ "${STRINGUTILS_REVERSESTRING}" == "olleh" ]]; then
    kk_test_pass "Function with parameter handling"
else
    kk_test_fail "Function with parameter handling"
fi

# Test 36e: Function computing from property and returning value
kk_test_start "Function using property"
defineClass "Temperature" "" \
    "property" "celsius"

defineFunction "Temperature" "toFahrenheit" '
    RESULT=$((celsius * 9 / 5 + 32))
'

Temperature.new temp
temp.celsius = "100"
temp.toFahrenheit

if [[ "${TEMPERATURE_TOFAHRENHEIT}" == "212" ]]; then
    kk_test_pass "Function using property"
else
    kk_test_fail "Function using property"
fi

# Test 36f: Multiple procedures on same class
kk_test_start "Multiple procedures on same class"
defineClass "Counter" "" \
    "property" "count"

defineProcedure "Counter" "increment" '
    count=$((count + 1))
'

defineProcedure "Counter" "decrement" '
    count=$((count - 1))
'

defineProcedure "Counter" "reset" '
    count="0"
'

Counter.new counter
counter.count = "5"
counter.increment
counter.increment
counter.decrement
counter.reset

if [[ "$(counter.count)" == "0" ]]; then
    kk_test_pass "Multiple procedures on same class"
else
    kk_test_fail "Multiple procedures on same class"
fi

# Test 36g: Function that returns property value
kk_test_start "Function returning property"
defineClass "Person" "" \
    "property" "firstName" \
    "property" "lastName"

defineFunction "Person" "fullName" '
    RESULT="$firstName $lastName"
'

Person.new person
person.firstName = "John"
person.lastName = "Doe"
person.fullName

if [[ "${PERSON_FULLNAME}" == "John Doe" ]]; then
    kk_test_pass "Function returning property"
else
    kk_test_fail "Function returning property"
fi

# Test 36h: Procedure calling a function  
kk_test_start "Procedure calling function"
defineClass "Calculator2" "" \
    "property" "x" \
    "property" "y"

defineFunction "Calculator2" "getSum" '
    RESULT=$((x + y))
'

defineProcedure "Calculator2" "setup" '
    x="$1"
    y="$2"
'

Calculator2.new calc2
calc2.setup "5" "3"
calc2.getSum

if [[ "${CALCULATOR2_GETSUM}" == "8" ]]; then
    kk_test_pass "Procedure calling function"
else
    kk_test_fail "Procedure calling function"
fi

# Test 36i: Error handling in defineProcedure
kk_test_start "Error handling for invalid class"
if ! defineProcedure "NonExistentClass" "test" 'echo "test"' 2>/dev/null; then
    kk_test_pass "Error handling for invalid class"
else
    kk_test_fail "Error handling for invalid class"
fi

# Test 36j: Error handling in defineFunction
kk_test_start "Error handling for missing arguments"
if ! defineFunction "" "test" 'RESULT="test"' 2>/dev/null; then
    kk_test_pass "Error handling for missing arguments"
else
    kk_test_fail "Error handling for missing arguments"
fi

# TODO: Migrate this test completely:
# - Replace kk_test_start() with kk_test_start()
# - Replace kk_test_pass() with kk_test_pass()
# - Replace kk_test_fail() with kk_test_fail()
# - Use kk_assert_* functions for better assertions
