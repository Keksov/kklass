#!/bin/bash
# VirtualOverrideAbstract

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "VirtualOverrideAbstract" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

kt_test_start "virtual method can be overridden"
declareClass "AnimalVirt" ""
virtual
procedure "Speak"
endClass
implement "AnimalVirt.Speak" 'echo "sound"'
endImplementation "AnimalVirt"

declareClass "DogVirt" "AnimalVirt"
override
procedure "Speak"
endClass
implement "DogVirt.Speak" 'echo "woof"'
endImplementation "DogVirt"

DogVirt.new dog_virt
result="$(dog_virt.Speak)"
if [[ "$result" == "woof" ]]; then
    kt_test_pass "virtual method can be overridden"
else
    kt_test_fail "virtual method can be overridden"
fi

kt_test_start "override of non-virtual method fails"
declareClass "BaseNoVirtual" ""
procedure "Ping"
endClass
implement "BaseNoVirtual.Ping" 'echo "ping"'
endImplementation "BaseNoVirtual"

declareClass "BrokenOverride" "BaseNoVirtual"
override
procedure "Ping"
if ! endClass 2>/dev/null; then
    kt_test_pass "override of non-virtual method fails"
else
    kt_test_fail "override of non-virtual method fails"
fi

kt_test_start "abstract parent can be concretized in child"
declareClass "ShapeVirt" ""
abstract
func "Area"
endClass
endImplementation "ShapeVirt"

declareClass "SquareVirt" "ShapeVirt"
field "FSize"
property "Size" read "FSize" write "FSize"
override
func "Area"
endClass
implement "SquareVirt.Area" 'RESULT=$((FSize * FSize))'
endImplementation "SquareVirt"

SquareVirt.new square_virt
square_virt.Size = "4"
result="$(square_virt.Area)"
if [[ "$result" == "16" ]]; then
    kt_test_pass "abstract parent can be concretized in child"
else
    kt_test_fail "abstract parent can be concretized in child"
fi