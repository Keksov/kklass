#!/bin/bash
# KkpMultilineSignatures

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "KkpMultilineSignatures" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(mktemp -d)"
unit_file="$workdir/multiline_counter.kkp"
translated_file="$workdir/multiline_counter.runtime.sh"
compiled_file="$workdir/multiline_counter.ckk.sh"
autoload_compiled_file="$(pwd)/.ckk/multiline_counter.ckk.sh"

cat > "$unit_file" <<'EOF'
unit MultilineCounter;

interface

type
  CounterMulti = class
  private
    FValue: Integer;
  public
    property Value: Integer
      read FValue
      write FValue;
    class var TotalMutations: Integer;
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

  FancyCounterMulti = class(
    CounterMulti
  )
  public
    procedure Increment(
      Step: Integer
    );
  end;

implementation

constructor CounterMulti.Create(
  InitialValue: Integer
);
begin
FValue="${1:-0}"
end;

procedure CounterMulti.Increment(
  Step: Integer
);
begin
FValue=$((FValue + ${1:-1}))
TotalMutations=$((TotalMutations + ${1:-1}))
end;

function CounterMulti.GetValue(
): Integer;
begin
RESULT="$FValue"
end;

class function CounterMulti.GetTotal(
): Integer;
begin
RESULT="$TotalMutations"
end;

procedure FancyCounterMulti.Increment(
  Step: Integer
);
begin
inherited Increment "$1"
FValue=$((FValue + ${1:-1}))
TotalMutations=$((TotalMutations + ${1:-1}))
end;

end.
EOF

kt_test_start "kkp multiline direct translation"
bash "$KKLASS_DIR/kklass_kkp.sh" "$unit_file" "$translated_file" >/dev/null 2>&1
result="$(bash -c "source '$KKLASS_DIR/kklass.sh'; source '$translated_file'; CounterMulti.TotalMutations = 0; CounterMulti.new base 1; FancyCounterMulti.new cnt; cnt.Value = 1; cnt.Increment 2; printf '%s:%s:%s' \"\$(base.GetValue)\" \"\$(cnt.GetValue)\" \"\$(CounterMulti.GetTotal)\"")"
if [[ "$result" == "1:5:4" ]]; then
    kt_test_pass "kkp multiline direct translation"
else
    kt_test_fail "kkp multiline direct translation (got: '$result')"
fi

kt_test_start "kkp multiline compiler and autoload"
rm -f "$autoload_compiled_file"
bash "$KKLASS_DIR/kklass_compiler.sh" "$unit_file" "$compiled_file" >/dev/null 2>&1
result_compiled="$(bash -c "source '$compiled_file'; CounterMulti.TotalMutations = 0; CounterMulti.new base 1; FancyCounterMulti.new cnt; cnt.Value = 1; cnt.Increment 2; printf '%s:%s:%s' \"\$(base.GetValue)\" \"\$(cnt.GetValue)\" \"\$(CounterMulti.GetTotal)\"")"
result_autoload="$(bash -c "source '$KKLASS_DIR/kklass_autoload.sh'; kkload '$unit_file' >/dev/null 2>&1; CounterMulti.TotalMutations = 0; CounterMulti.new base 1; FancyCounterMulti.new cnt; cnt.Value = 1; cnt.Increment 2; printf '%s:%s:%s' \"\$(base.GetValue)\" \"\$(cnt.GetValue)\" \"\$(CounterMulti.GetTotal)\"")"
if [[ "$result_compiled" == "1:5:4" ]] && [[ "$result_autoload" == "1:5:4" ]]; then
    kt_test_pass "kkp multiline compiler and autoload"
else
    kt_test_fail "kkp multiline compiler and autoload (compiled: '$result_compiled', autoload: '$result_autoload')"
fi

rm -rf "$workdir"