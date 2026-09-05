#!/bin/bash
# GuardKeepsMetadata (P0 regression for F2 + F9, see PLAN.md).
# F2: a REFUSED cross-file redefinition must leave the original class fully
# intact — including the declarative metadata (abstract flag, member
# visibility). Before the fix, defineClass -> declareClass reset `_decl_*`,
# `_method_visibility` and `_class_abstract=0` BEFORE the guard fired, so an
# abstract class silently became instantiable.
# F9: classes built through defineSerializableClass must be registered as owned
# by the USER file, not by kklass_serializable.sh.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "GuardKeepsMetadata" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"
source "$KKLASS_DIR/kklass_serializable.sh"

TMPD="${TMPDIR:-/tmp}/kk121_$$"
mkdir -p "$TMPD"
ERRF="$TMPD/err.txt"
trap 'rm -rf "$TMPD"' EXIT

cat > "$TMPD/orig.sh" <<'EOF'
declareClass TGuardShape ""
    abstract; func Area
    privateSection; procedure Secret
    publicSection; procedure Poke
endClass
implement TGuardShape.Secret 'RESULT=hidden'
implement TGuardShape.Poke '$this.call Secret'
endImplementation TGuardShape
EOF

cat > "$TMPD/imposter.sh" <<'EOF'
defineClass TGuardShape "" property other method Area 'RESULT=0'
EOF

cat > "$TMPD/user_ser.sh" <<'EOF'
defineSerializableClass TGuardSer "" ":" string property a property b
EOF

source "$TMPD/orig.sh"

# ---------------------------------------------------------------------------
kt_test_start "sanity: original is abstract with a private member"
TGuardShape.new g0 2>/dev/null; rc=$?
vis="${TGuardShape_method_visibility[Secret]:-}"
if [[ $rc -ne 0 && "${TGuardShape_class_abstract:-}" == "1" && "$vis" == "private" ]]; then
    kt_test_pass "abstract=1, Secret is private, .new refused"
else
    kt_test_fail "rc=$rc abstract='${TGuardShape_class_abstract:-}' vis='$vis'"
fi

# ---------------------------------------------------------------------------
kt_test_start "cross-file redefinition is refused"
: >"$ERRF"
source "$TMPD/imposter.sh" 2>"$ERRF"; rc=$?
err="$(<"$ERRF")"
if [[ "$err" == *"already registered"* ]]; then
    kt_test_pass "refused (rc=$rc)"
else
    kt_test_fail "not refused: rc=$rc err='$err'"
fi

# ---------------------------------------------------------------------------
kt_test_start "abstract flag survives the refused redefinition (F2)"
TGuardShape.new g1 2>/dev/null; rc=$?
if [[ $rc -ne 0 && "${TGuardShape_class_abstract:-}" == "1" ]]; then
    kt_test_pass "still abstract, .new still refused"
else
    kt_test_fail "abstract flag clobbered: rc=$rc abstract='${TGuardShape_class_abstract:-}'"
fi

# ---------------------------------------------------------------------------
kt_test_start "member visibility survives the refused redefinition (F2)"
vis="${TGuardShape_method_visibility[Secret]:-}"
if [[ "$vis" == "private" ]]; then
    kt_test_pass "Secret still private"
else
    kt_test_fail "visibility clobbered: Secret='$vis'"
fi

# ---------------------------------------------------------------------------
kt_test_start "declarative tables survive the refused redefinition (F2)"
n_methods="${#TGuardShape_decl_methods[@]}"
if [[ "$n_methods" == "3" && "${TGuardShape_decl_method_abstract[Area]:-}" == "1" ]]; then
    kt_test_pass "_decl_methods=3, Area still abstract in decl table"
else
    kt_test_fail "decl tables reset: methods=$n_methods Area_abstract='${TGuardShape_decl_method_abstract[Area]:-}'"
fi

# ---------------------------------------------------------------------------
kt_test_start "serializable class is owned by the user file, not the library (F9)"
source "$TMPD/user_ser.sh"
owner="${_KKLASS_CLASS_SOURCE[TGuardSer]:-}"
if [[ "$owner" == *"user_ser.sh" ]]; then
    kt_test_pass "owner=$owner"
else
    kt_test_fail "owner='$owner' (expected .../user_ser.sh)"
fi

kt_test_log "121_GuardKeepsMetadata.sh completed"
