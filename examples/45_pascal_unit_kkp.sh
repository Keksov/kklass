#!/bin/bash

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
# a `unit X;` file is a unit outside the kbool tree: it finds kbool.sh through
# KBOOL_HOME (the §7.4 user header)
export KBOOL_HOME="${KBOOL_HOME:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../kklass_autoload.sh"

workdir="$(mktemp -d)"
# the unit name is the file stem (U33/U36): unit CounterPascal; lives in CounterPascal.kkp
unit_file="$workdir/CounterPascal.kkp"

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