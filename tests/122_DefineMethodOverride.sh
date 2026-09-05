#!/bin/bash
# DefineMethodOverride (P0 regression for F3, see PLAN.md).
# defineMethod/defineFunction on an EXISTING class must be able to override a
# method the class INHERITED. Before the fix the instance-template wrapper and
# the class method cache still pointed at the parent's body, so the override was
# silently ignored by inst.m, inst.call m and $this.m alike.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "DefineMethodOverride" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"

defineClass TDmParent "" property name \
    method greet 'echo "parent:$name"' \
    method twice '$this.greet; $this.greet'
defineClass TDmChild TDmParent property extra

# ---------------------------------------------------------------------------
kt_test_start "sanity: defineMethod adds a NEW method (already worked)"
defineMethod TDmChild shout 'echo "SHOUT:$name"'
TDmChild.new c0; c0.name = a
out="$(c0.shout)"; c0.delete
[[ "$out" == "SHOUT:a" ]] && kt_test_pass "new method visible" || kt_test_fail "got '$out'"

# ---------------------------------------------------------------------------
kt_test_start "defineMethod overrides an inherited method: direct call (F3)"
defineMethod TDmChild greet 'echo "child:$name"'
TDmChild.new c1; c1.name = b
out="$(c1.greet)"
[[ "$out" == "child:b" ]] && kt_test_pass "c1.greet -> child body" || kt_test_fail "c1.greet -> '$out'"

# ---------------------------------------------------------------------------
kt_test_start "defineMethod override via inst.call (F3)"
out="$(c1.call greet)"
[[ "$out" == "child:b" ]] && kt_test_pass "c1.call greet -> child body" || kt_test_fail "c1.call greet -> '$out'"

# ---------------------------------------------------------------------------
kt_test_start "defineMethod override is virtual from an inherited body (F3)"
out="$(c1.twice)"
[[ "$out" == $'child:b\nchild:b' ]] && kt_test_pass "twice -> child greet x2" || kt_test_fail "twice -> '$out'"
c1.delete

# ---------------------------------------------------------------------------
kt_test_start "parent is untouched by the child's override"
TDmParent.new p1; p1.name = p
out="$(p1.greet)"; p1.delete
[[ "$out" == "parent:p" ]] && kt_test_pass "parent still parent" || kt_test_fail "parent -> '$out'"

kt_test_log "122_DefineMethodOverride.sh completed"
