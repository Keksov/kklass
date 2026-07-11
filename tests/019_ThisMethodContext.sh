#!/bin/bash
# ThisMethodContext
# Auto-migrated from kklass test framework

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "ThisMethodContext" "$(dirname "$0")" "$@"

# Source kklass if needed
KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$KKLASS_DIR/kklass.sh" ]] && source "$KKLASS_DIR/kklass.sh"



# Test 19: $this.method dispatches VIRTUALLY (Pascal virtual+override model).
# All kklass dispatch is dynamic: when a parent body calls $this.greet on a
# derived instance, the DERIVED override must win — even though the calling
# body lives in Base. (Static, defining-class resolution is exactly what
# $this.parent / `inherited` is for.) Historically this test pinned the
# opposite (frame-scoped static resolution); that model also caused inherited
# bodies to re-run themselves in non-overridden chains and was replaced by
# owner-class frames + instance-class .call resolution.
kt_test_start "\$this.method dispatches virtually from a parent body"
defineClass "Base" "" \
    "method" "greet" 'echo "BaseGreeting"' \
    "method" "sayHello" 'echo -n "From Base: "; $this.greet'

defineClass "Derived" "Base" \
    "method" "greet" 'echo "DerivedGreeting"' \
    "method" "test" '$this.parent sayHello'

Derived.new derived1
result=$(derived1.test)
expected="From Base: DerivedGreeting"
if [[ "$result" == "$expected" ]]; then
    kt_test_pass "\$this.method dispatches virtually from a parent body"
else
    kt_test_fail "\$this.method dispatches virtually from a parent body (expected: '$expected', got: '$result')"
fi

# The static counterpart: the SAME shape, but the parent body asks for the
# parent's own implementation explicitly via $this.parent — that must keep
# resolving from the defining class upwards.
kt_test_start "\$this.parent resolves statically from the defining class"
defineClass "BaseS" "" \
    "method" "greet" 'echo "BaseGreeting"' \
    "method" "sayHello" 'echo -n "From Base: "; $this.greet'

defineClass "DerivedS" "BaseS" \
    "method" "greet" 'echo "DerivedGreeting"; $this.parent greet' \
    "method" "test" '$this.greet'

DerivedS.new derived2
result=$(derived2.test)
expected="$(printf 'DerivedGreeting\nBaseGreeting')"
if [[ "$result" == "$expected" ]]; then
    kt_test_pass "\$this.parent resolves statically from the defining class"
else
    kt_test_fail "\$this.parent resolves statically from the defining class (expected: '$expected', got: '$result')"
fi
