#!/bin/bash
# UnifiedPropertySyntax
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "UnifiedPropertySyntax" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 39.1: Simple property without getter/setter
kt_test_start "Unified syntax - simple property"
defineClass "SimpleProp" "" \
    "property" "name"

SimpleProp.new obj1
obj1.name = "test"
result=$(obj1.name)

if [[ "$result" == "test" ]]; then
    kt_test_pass "Unified syntax - simple property"
else
    kt_test_fail "Simple property failed (expected: 'test', got: '$result')"
fi

obj1.delete

# Test 39.2: Property with getter only
kt_test_start "Unified syntax - getter only"
defineClass "GetterOnly" "" \
    "property" "base" \
    "property" "computed" "getComputed" \
    "method" "getComputed" 'echo "computed_${base}"'

GetterOnly.new obj2
obj2.base = "value"
result=$(obj2.computed)

if [[ "$result" == "computed_value" ]]; then
    kt_test_pass "Unified syntax - getter only"
else
    kt_test_fail "Getter only failed (expected: 'computed_value', got: '$result')"
fi

obj2.delete

# Test 39.3: Property with setter only
kt_test_start "Unified syntax - setter only"
defineClass "SetterOnly" "" \
    "property" "raw_input" \
    "property" "normalized" "setNormalized" \
    "method" "setNormalized" 'raw_input="norm_$1"'

SetterOnly.new obj3
obj3.normalized = "input"
result=$(obj3.raw_input)

if [[ "$result" == "norm_input" ]]; then
    kt_test_pass "Unified syntax - setter only"
else
    kt_test_fail "Setter only failed (expected: 'norm_input', got: '$result')"
fi

obj3.delete

# Test 39.4: Property with both getter and setter
kt_test_start "Unified syntax - both getter and setter"
defineClass "BothAccessors" "" \
    "property" "first" \
    "property" "last" \
    "property" "full" "getFull" "setFull" \
    "method" "getFull" 'echo "$first $last"' \
    "method" "setFull" 'local f l; IFS=" " read -r f l <<< "$1"; first="$f"; last="$l"'

BothAccessors.new obj4
obj4.first = "John"
obj4.last = "Doe"
result1=$(obj4.full)

if [[ "$result1" == "John Doe" ]]; then
    obj4.full = "Jane Smith"
    result2=$(obj4.first)
    result3=$(obj4.last)
    
    if [[ "$result2" == "Jane" ]] && [[ "$result3" == "Smith" ]]; then
        kt_test_pass "Unified syntax - both getter and setter"
    else
        kt_test_fail "Both accessors - setter failed (first: '$result2', last: '$result3')"
    fi
else
    kt_test_fail "Both accessors - getter failed (expected: 'John Doe', got: '$result1')"
fi

obj4.delete

# Test 39.5: Multiple properties with mixed accessors
kt_test_start "Unified syntax - mixed properties"
defineClass "MixedProps" "" \
    "property" "id" \
    "property" "title" \
    "property" "slug" "getSlug" \
    "property" "tags" "setTags" \
    "property" "display" "getDisplay" "setDisplay" \
    "method" "getSlug" 'echo "$title" | tr " " "-" | tr "[:upper:]" "[:lower:]"' \
    "method" "setTags" 'tags="[$1]"' \
    "method" "getDisplay" 'echo "[${id}] $title"' \
    "method" "setDisplay" 'id="$1"'

MixedProps.new obj5
obj5.id = "123"
obj5.title = "Hello World"

slug=$(obj5.slug)
obj5.tags = "test"
tags=$(obj5.tags)
display=$(obj5.display)
obj5.display = "456"
id=$(obj5.id)

if [[ "$slug" == "hello-world" ]] && [[ "$tags" == "[test]" ]] && [[ "$display" == "[123] Hello World" ]] && [[ "$id" == "456" ]]; then
    kt_test_pass "Unified syntax - mixed properties"
else
    kt_test_fail "Mixed properties failed (slug: '$slug', tags: '$tags', display: '$display', id: '$id')"
fi

obj5.delete

# Test 39.6: Getter/setter detection stops at next keyword
kt_test_start "Unified syntax - keyword boundary detection"
defineClass "KeywordBoundary" "" \
    "property" "value" "getValue" \
    "method" "getValue" 'echo "get_${value}"' \
    "method" "helper" 'echo "helper"'

KeywordBoundary.new obj6
obj6.value = "test"
result=$(obj6.getValue)

if [[ "$result" == "get_test" ]]; then
    kt_test_pass "Unified syntax - keyword boundary detection"
else
    kt_test_fail "Keyword boundary detection failed (expected: 'get_test', got: '$result')"
fi

obj6.delete

# Test 39.7: Methods with get/set prefix but not for same property
kt_test_start "Unified syntax - prefix detection specificity"
defineClass "PrefixTest" "" \
    "property" "raw_x" \
    "property" "x" "getX" "setX" \
    "property" "y" \
    "method" "getX" 'echo "x=${raw_x}"' \
    "method" "setX" 'raw_x="set_$1"' \
    "method" "getY" 'echo "separate_method"'

PrefixTest.new obj7
obj7.x = "10"
result1=$(obj7.x)
obj7.x = "20"
result2=$(obj7.x)

if [[ "$result1" == "x=set_10" ]] && [[ "$result2" == "x=set_20" ]]; then
    kt_test_pass "Unified syntax - prefix detection specificity"
else
    kt_test_fail "Prefix detection failed (result1: '$result1', result2: '$result2')"
fi

obj7.delete

# Test 39.8: Property with _getter (underscore-prefixed getter)
kt_test_start "Unified syntax - underscore getter (_get)"
defineClass "UnderscoreGetter" "" \
    "property" "base" \
    "property" "derived" "_getComputed" \
    "method" "_getComputed" 'echo "result_${base}"'

UnderscoreGetter.new obj8
obj8.base = "value"
result=$(obj8.derived)

if [[ "$result" == "result_value" ]]; then
    kt_test_pass "Unified syntax - underscore getter (_get)"
else
    kt_test_fail "Underscore getter failed (expected: 'result_value', got: '$result')"
fi

obj8.delete

# Test 39.9: Property with _setter (underscore-prefixed setter)
kt_test_start "Unified syntax - underscore setter (_set)"
defineClass "UnderscoreSetter" "" \
    "property" "internal" \
    "property" "external" "_setInternal" \
    "method" "_setInternal" 'internal="priv_$1"'

UnderscoreSetter.new obj9
obj9.external = "data"
result=$(obj9.internal)

if [[ "$result" == "priv_data" ]]; then
    kt_test_pass "Unified syntax - underscore setter (_set)"
else
    kt_test_fail "Underscore setter failed (expected: 'priv_data', got: '$result')"
fi

obj9.delete

# Test 39.10: Property with both _getter and _setter
kt_test_start "Unified syntax - both underscore accessors (_get and _set)"
defineClass "UnderscoreBoth" "" \
    "property" "first" \
    "property" "last" \
    "property" "full" "_getFull" "_setFull" \
    "method" "_getFull" 'echo "$first $last"' \
    "method" "_setFull" 'local f l; IFS=" " read -r f l <<< "$1"; first="$f"; last="$l"'

UnderscoreBoth.new obj10
obj10.first = "Alice"
obj10.last = "Wonder"
result1=$(obj10.full)

if [[ "$result1" == "Alice Wonder" ]]; then
    obj10.full = "Bob Jones"
    result2=$(obj10.first)
    result3=$(obj10.last)
    
    if [[ "$result2" == "Bob" ]] && [[ "$result3" == "Jones" ]]; then
        kt_test_pass "Unified syntax - both underscore accessors (_get and _set)"
    else
        kt_test_fail "Both underscore - setter failed (first: '$result2', last: '$result3')"
    fi
else
    kt_test_fail "Both underscore - getter failed (expected: 'Alice Wonder', got: '$result1')"
fi

obj10.delete

# Test 39.11: Mixed regular and underscore accessors
kt_test_start "Unified syntax - mixed regular and underscore accessors"
defineClass "MixedAccessors" "" \
    "property" "temp" \
    "property" "upper" "getUpper" \
    "property" "lower" "_getLower" \
    "property" "reversed" "_setReversed" \
    "property" "modified" "getMod" "_setMod" \
    "method" "getUpper" 'echo "${temp^^}"' \
    "method" "_getLower" 'echo "${temp,,}"' \
    "method" "_setReversed" 'local str="$1"; temp=""; for ((i=${#str}-1; i>=0; i--)); do temp+="${str:$i:1}"; done' \
    "method" "getMod" 'echo "MOD:$temp"' \
    "method" "_setMod" 'temp="mod_$1"'

MixedAccessors.new obj11
obj11.temp = "Hello"

upper=$(obj11.upper)
lower=$(obj11.lower)
obj11.reversed = "world"
rev=$(obj11.temp)
obj11.modified = "test"
mod=$(obj11.modified)

if [[ "$upper" == "HELLO" ]] && [[ "$lower" == "hello" ]] && [[ "$rev" == "dlrow" ]] && [[ "$mod" == "MOD:mod_test" ]]; then
    kt_test_pass "Unified syntax - mixed regular and underscore accessors"
else
    kt_test_fail "Mixed accessors failed (upper: '$upper', lower: '$lower', rev: '$rev', mod: '$mod')"
fi

obj11.delete

# TODO: Migrate this test completely:
# - Replace kt_test_start() with kt_test_start()
# - Replace kt_test_pass() with kt_test_pass()
# - Replace kt_test_fail() with kt_test_fail()
# - Use kt_assert_* functions for better assertions
