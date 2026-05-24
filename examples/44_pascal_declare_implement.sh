#!/bin/bash

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/../kklass.sh"

declareClass "CounterPascal" ""
privateSection
field "FValue"
publicSection
property "Value" read "FValue" write "FValue"
classVar "TotalCreated"
constructor "Create"
procedure "Increment"
classFunction "GetTotalCreated"
endClass

implementConstructor "CounterPascal" 'FValue="${1:-0}"; TotalCreated=$((TotalCreated + 1))'
implement "CounterPascal.Increment" 'FValue=$((FValue + ${1:-1}))'
implement "CounterPascal.GetTotalCreated" 'RESULT="$TotalCreated"'
endImplementation "CounterPascal"

CounterPascal.TotalCreated = "0"

CounterPascal.new first 3
CounterPascal.new second 10
first.Increment 2

echo "First value: $(first.Value)"
echo "Second value: $(second.Value)"
echo "Total created: $(CounterPascal.GetTotalCreated)"

first.delete
second.delete