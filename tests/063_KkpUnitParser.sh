#!/bin/bash
# KkpUnitParser
#
# Hermetic since 2026-09-06 (kcl review "task 6" / decision R15): the autoload
# cache is this test's private dir via KKLASS_CKK_DIR, and the work dir is the
# fixture temp dir (auto-removed at teardown) instead of a bare mktemp -d. The
# old version hard-coded $(pwd)/.ckk, so a sweep started from a kcl unit
# directory left a stray <unit>/.ckk behind.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "KkpUnitParser" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

workdir="$(cd "$(kt_fixture_tmpdir)" && pwd)"
ckk_dir="$workdir/ckk"
export KKLASS_CKK_DIR="$ckk_dir"
mkdir -p "$ckk_dir"
unit_file="$workdir/sample_counter.kkp"
translated_file="$workdir/sample_counter.runtime.sh"
compiled_file="$workdir/sample_counter.ckk.sh"
autoload_compiled_file="$ckk_dir/sample_counter.ckk.sh"

cat > "$unit_file" <<'EOF'
unit SampleCounter;

interface

type
  CounterKkp = class
  private
    FValue: Integer;
  public
    property Value read FValue write FValue;
    procedure Increment;
    function GetValue;
  end;

  FancyCounterKkp = class(CounterKkp)
  public
    procedure Increment;
  end;

implementation

procedure CounterKkp.Increment;
begin
FValue=$((FValue + 1))
end;

function CounterKkp.GetValue;
begin
RESULT="$FValue"
end;

procedure FancyCounterKkp.Increment;
begin
inherited Increment
FValue=$((FValue + 9))
end;

end.
EOF

kt_test_start "kkp direct translation"
bash "$KKLASS_DIR/kklass_kkp.sh" "$unit_file" "$translated_file" >/dev/null 2>&1
result="$(bash -c "source '$KKLASS_DIR/kklass.sh'; source '$translated_file'; FancyCounterKkp.new cnt; cnt.Value = 1; cnt.Increment; cnt.GetValue; printf '%s' \"\$RESULT\"")"
if [[ "$result" == "11" ]]; then
    kt_test_pass "kkp direct translation"
else
    kt_test_fail "kkp direct translation"
fi

kt_test_start "kkp compiler input"
bash "$KKLASS_DIR/kklass_compiler.sh" "$unit_file" "$compiled_file" >/dev/null 2>&1
result="$(bash -c "source '$compiled_file'; FancyCounterKkp.new cnt; cnt.Value = 1; cnt.Increment; cnt.GetValue; printf '%s' \"\$RESULT\"")"
if [[ "$result" == "11" ]]; then
    kt_test_pass "kkp compiler input"
else
    kt_test_fail "kkp compiler input"
fi

kt_test_start "kkp autoload runtime mode"
rm -f "$autoload_compiled_file"
result="$(bash -c "source '$KKLASS_DIR/kklass_autoload.sh'; kkload '$unit_file' --no-compile >/dev/null 2>&1; FancyCounterKkp.new cnt; cnt.Value = 1; cnt.Increment; cnt.GetValue; printf '%s' \"\$RESULT\"")"
if [[ "$result" == "11" ]]; then
    kt_test_pass "kkp autoload runtime mode"
else
    kt_test_fail "kkp autoload runtime mode"
fi

kt_test_start "kkp autoload compiled mode"
rm -f "$autoload_compiled_file"
result="$(bash -c "source '$KKLASS_DIR/kklass_autoload.sh'; kkload '$unit_file' >/dev/null 2>&1; FancyCounterKkp.new cnt; cnt.Value = 1; cnt.Increment; cnt.GetValue; printf '%s' \"\$RESULT\"")"
if [[ "$result" == "11" ]]; then
    kt_test_pass "kkp autoload compiled mode"
else
    kt_test_fail "kkp autoload compiled mode"
fi

