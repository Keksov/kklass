#!/bin/bash

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/../kklass_autoload.sh"

workdir="$(mktemp -d)"
unit_file="$workdir/counter_pascal.kkp"

cat > "$unit_file" <<'EOF'
unit CounterPascal;

interface

type
  CounterUnit = class
  private
    FValue: Integer;
  public
    class var TotalCreated: Integer;
    constructor Create(
      InitialValue: Integer
    );
    procedure Increment(
      Step: Integer
    );
    function GetValue(
    ): Integer;
    class function GetTotal(
    ): Integer;
  end;

implementation

constructor CounterUnit.Create(
  InitialValue: Integer
);
begin
FValue="${1:-0}"
TotalCreated=$((TotalCreated + 1))
end;

procedure CounterUnit.Increment(
  Step: Integer
);
begin
FValue=$((FValue + ${1:-1}))
end;

function CounterUnit.GetValue(
): Integer;
begin
RESULT="$FValue"
end;

class function CounterUnit.GetTotal(
): Integer;
begin
RESULT="$TotalCreated"
end;

end.
EOF

kkload "$unit_file"
CounterUnit.TotalCreated = "0"

CounterUnit.new one 5
CounterUnit.new two 10
one.Increment 2

echo "One: $(one.GetValue)"
echo "Two: $(two.GetValue)"
echo "Total created: $(CounterUnit.GetTotal)"

one.delete
two.delete
rm -rf "$workdir"