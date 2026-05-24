#!/bin/bash
# DeclareImplement

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "DeclareImplement" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"

kt_test_start "Declare/implement with field-backed property"
declareClass "PersonDecl" ""
privateSection
field "FName"
publicSection
property "Name" read "FName" write "FName"
func "GetName"
endClass
implement "PersonDecl.GetName" 'RESULT="$FName"'
endImplementation "PersonDecl"

PersonDecl.new person_decl
person_decl.Name = "Alice"
result="$(person_decl.GetName)"

if [[ "$result" == "Alice" ]] && [[ "$(person_decl.Name)" == "Alice" ]]; then
    kt_test_pass "Declare/implement with field-backed property"
else
    kt_test_fail "Declare/implement with field-backed property"
fi

kt_test_start "classFunction returns RESULT"
declareClass "BuildInfoDecl" ""
classFunction "Version"
endClass
implement "BuildInfoDecl.Version" 'RESULT="1.0.0"'
endImplementation "BuildInfoDecl"

result="$(BuildInfoDecl.Version)"
if [[ "$result" == "1.0.0" ]]; then
    kt_test_pass "classFunction returns RESULT"
else
    kt_test_fail "classFunction returns RESULT"
fi

kt_test_start "Abstract class cannot be instantiated"
declareClass "ShapeDecl" ""
abstract
func "Area"
endClass
endImplementation "ShapeDecl"

if ! ShapeDecl.new shape_decl 2>/dev/null; then
    kt_test_pass "Abstract class cannot be instantiated"
else
    kt_test_fail "Abstract class cannot be instantiated"
fi

kt_test_start "inherited rewrite delegates to parent"
declareClass "AnimalDecl" ""
procedure "Speak"
endClass
implement "AnimalDecl.Speak" 'echo "sound"'
endImplementation "AnimalDecl"

declareClass "DogDecl" "AnimalDecl"
procedure "Speak"
endClass
implement "DogDecl.Speak" 'inherited Speak; echo "woof"'
endImplementation "DogDecl"

result="$(DogDecl.new dog_decl; dog_decl.Speak)"
if [[ "$result" == $'sound\nwoof' ]]; then
    kt_test_pass "inherited rewrite delegates to parent"
else
    kt_test_fail "inherited rewrite delegates to parent"
fi