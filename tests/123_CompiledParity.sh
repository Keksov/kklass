#!/bin/bash
# CompiledParity (P0 regression for F4, see PLAN.md).
# The same scenario must print the same thing whether the classes are loaded in
# runtime mode (source the .kk) or compiled mode (source the .ckk.sh produced by
# kklass_compiler.sh). Before the fix the compiler pre-filled the method cache
# with the class name instead of the DEFINING class and did not export
# _class_method_owner, so on a 3-level chain `c.call hello` ran the middle body
# twice in compiled mode.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "CompiledParity" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TMPD="${TMPDIR:-/tmp}/kk123_$$"
mkdir -p "$TMPD"
trap 'rm -rf "$TMPD"' EXIT

cat > "$TMPD/par.kk" <<'EOF'
defineClass PA "" property tag \
    method hello 'echo "A.hello($tag)"' \
    static_property hits static_method bump 'hits=$((hits+1)); echo "hits=$hits"'
defineClass PB PA \
    method hello 'echo "B.hello"; $this.parent hello'
defineClass PC PB \
    lazy_property lz initLz method initLz 'echo "lazy-init"' \
    method run '$this.call hello; echo "lz=$($this.lz)"'
EOF

# The scenario: identical for both modes.
cat > "$TMPD/scenario.sh" <<'EOF'
PC.new c1; c1.tag = t
echo "--- direct"; c1.hello
echo "--- call";   c1.call hello
echo "--- run";    c1.run
echo "--- lazy again"; c1.lz
echo "--- static"; PC.bump; PA.bump; echo; echo "hits=$(PA.hits)"
c1.delete
echo "left=$(compgen -A function c1. | wc -l | tr -d ' ')"
EOF

runtime_out="$(cd "$TMPD" && bash -c "source '$KKLASS_DIR/kklass.sh'; source par.kk; source scenario.sh" 2>&1)"

( cd "$TMPD" && bash "$KKLASS_DIR/kklass_compiler.sh" par.kk par.ckk.sh >/dev/null 2>"$TMPD/cerr.txt" ); crc=$?

# ---------------------------------------------------------------------------
kt_test_start "compiler produces the compiled file"
if [[ $crc -eq 0 && -s "$TMPD/par.ckk.sh" ]]; then
    kt_test_pass "compiled (rc=0)"
else
    kt_test_fail "rc=$crc err='$(<"$TMPD/cerr.txt")'"
fi

compiled_out="$(cd "$TMPD" && bash -c "source par.ckk.sh; source scenario.sh" 2>&1)"

# ---------------------------------------------------------------------------
kt_test_start "runtime scenario output is the expected reference"
expected='--- direct
B.hello
A.hello(t)
--- call
B.hello
A.hello(t)
--- run
B.hello
A.hello(t)
lz=lazy-init
--- lazy again
lazy-init
--- static
hits=1hits=2
hits=2
left=0'
if [[ "$runtime_out" == "$expected" ]]; then
    kt_test_pass "runtime reference matches"
else
    kt_test_fail "runtime output differs from reference:
$runtime_out"
fi

# ---------------------------------------------------------------------------
kt_test_start "compiled mode prints exactly what runtime mode prints (F4)"
if [[ "$compiled_out" == "$runtime_out" ]]; then
    kt_test_pass "parity"
else
    kt_test_fail "compiled output differs:
--- runtime ---
$runtime_out
--- compiled ---
$compiled_out"
fi

# ---------------------------------------------------------------------------
kt_test_start "compiler fails loudly on a broken input file"
printf 'defineClass Broken "" method x "echo"\nthis_is_not_a_command_kk123\n' > "$TMPD/broken.kk"
( cd "$TMPD" && bash "$KKLASS_DIR/kklass_compiler.sh" broken.kk broken.ckk.sh >/dev/null 2>"$TMPD/berr.txt" ); brc=$?
if [[ $brc -ne 0 && -s "$TMPD/berr.txt" ]]; then
    kt_test_pass "rc=$brc with a message"
else
    kt_test_fail "rc=$brc err='$(<"$TMPD/berr.txt")' (expected non-zero + message)"
fi

kt_test_log "123_CompiledParity.sh completed"
