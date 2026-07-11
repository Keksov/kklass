#!/bin/bash
# Example 48: Deep inheritance (4 levels) + independent instances across scopes
#
# Verifies that each instance keeps its OWN context — properties, `$this`,
# `inherited` chains, the per-call frame stack — no matter how deep the hierarchy
# is or in which scope (top level, a function, a subshell) the instance is used.
#
# Hierarchy:  TAnimal  ->  TMammal  ->  TDog  ->  TPuppy   (four levels)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass_pascal.sh"

check() {
    if [[ "$2" == "$3" ]]; then
        echo "  OK  $1"
    else
        echo "  XX  $1  (expected '$3', got '$2')"
        exit 1
    fi
}

echo "=== Deep inheritance + instance context ==="

# ---------------------------------------------------------------------------
# The four-level hierarchy. Each level:
#   - adds its own field,
#   - chains the constructor to its parent with `inherited` (args forwarded),
#   - appends to the Describe FUNC with `inherited` (each level extends RESULT).
# TAnimal also holds a shared static counter and an (inherited) destructor.
# ---------------------------------------------------------------------------
class TAnimal
    public
        var         Name
        constructor Create
        destructor  Destroy
        func        Describe
        func        WhoAmI
        static var  Alive
        static func Census
end
TAnimal.Create()   { Name="$1"; Alive=$(( Alive + 1 )); }
TAnimal.Destroy()  { Alive=$(( Alive - 1 )); }
TAnimal.Describe() { RESULT="$Name"; }
TAnimal.WhoAmI()   { RESULT="$Name"; }
TAnimal.Census()   { RESULT="$Alive"; }
build TAnimal

class TMammal : TAnimal
    public
        var         Legs
        constructor Create
        func        Describe
end
TMammal.Create()   { inherited; Legs="$2"; }        # inherited -> TAnimal.Create "$@"
TMammal.Describe() { inherited; RESULT="$RESULT, ${Legs} legs"; }   # func chain via inherited
build TMammal

class TDog : TMammal
    public
        var         Breed
        constructor Create
        func        Describe
        proc        Bark
        proc        Meet
end
TDog.Create()   { inherited; Breed="$3"; }
TDog.Describe() { inherited; RESULT="$RESULT, $Breed"; }
TDog.Bark()     { echo "$Name barks"; }
# Meet operates on ANOTHER instance mid-body — a good frame/context stress test.
TDog.Meet() {
    local other="$1"
    echo "$Name meets $($other.WhoAmI)"     # nested subshell call to a different instance
    $other.Bark                             # nested DIRECT call (pushes the other's frame)
    echo "$Name walks away"                 # $Name must be mine again (frame restored)
}
build TDog

class TPuppy : TDog
    public
        var         Age
        constructor Create
        func        Describe
        proc        Bark            # override TDog.Bark
end
TPuppy.Create()   { inherited; Age="$4"; }
TPuppy.Describe() { inherited; RESULT="$RESULT, $Age months old"; }
TPuppy.Bark()     { echo "$Name yips"; }
build TPuppy

TAnimal.Alive = "0"

# ---------------------------------------------------------------------------
echo
echo ">>> 1. One instance, four levels deep (fields + method chain)"
TPuppy.new rex "Rex" 4 "Labrador" 3
check "L1 field (Name)"  "$(rex.Name)"  "Rex"
check "L2 field (Legs)"  "$(rex.Legs)"  "4"
check "L3 field (Breed)" "$(rex.Breed)" "Labrador"
check "L4 field (Age)"   "$(rex.Age)"   "3"
check "constructor chained through all 4 levels" \
      "$(rex.Describe)" "Rex, 4 legs, Labrador, 3 months old"

# ---------------------------------------------------------------------------
echo
echo ">>> 2. Independent instances — state does not bleed between them"
TPuppy.new a "Alpha" 4 "Poodle" 2
TPuppy.new b "Beta"  4 "Boxer"  5
TDog.new   g "Gamma" 4 "Collie"                 # only three levels deep (no Age)
check "instance a"        "$(a.Describe)" "Alpha, 4 legs, Poodle, 2 months old"
check "instance b"        "$(b.Describe)" "Beta, 4 legs, Boxer, 5 months old"
check "instance g (L3)"   "$(g.Describe)" "Gamma, 4 legs, Collie"
a.Breed = "Pug"                                 # mutate only a
check "a mutated"         "$(a.Breed)"   "Pug"
check "b unaffected"      "$(b.Breed)"   "Boxer"
check "rex unaffected"    "$(rex.Breed)" "Labrador"

# ---------------------------------------------------------------------------
echo
echo ">>> 3. Instances created and used in DIFFERENT scopes"
spawn() {                                        # factory: creates in its own function scope
    TPuppy.new "$1" "$2" 4 "Husky" 1
}
spawn scout "Scout"
check "instance from a factory function survives" "$(scout.Name)" "Scout"
check "factory instance describes correctly" \
      "$(scout.Describe)" "Scout, 4 legs, Husky, 1 months old"

# A caller scope with LOCAL variables named like properties must not leak into methods.
shadow_scope() {
    local Name="CALLER-LOCAL"
    local Legs="999"
    check "property reads the instance, not the caller's local" "$(a.Name)" "Alpha"
    check "method sees instance fields, not caller locals" \
          "$(a.Describe)" "Alpha, 4 legs, Pug, 2 months old"
}
shadow_scope

# ---------------------------------------------------------------------------
echo
echo ">>> 4. Cross-instance calls — the frame/context is restored afterwards"
out="$(a.Meet b)"
check "self BEFORE the nested call"  "$(sed -n 1p <<<"$out")" "Alpha meets Beta"
check "the other instance's method ran" "$(sed -n 2p <<<"$out")" "Beta yips"
check "self AFTER the nested call (frame restored)" \
      "$(sed -n 3p <<<"$out")" "Alpha walks away"

# ---------------------------------------------------------------------------
echo
echo ">>> 5. Independent calls inside subshells stay isolated"
combined="$(a.WhoAmI)-$(b.WhoAmI)-$(rex.WhoAmI)-$(g.WhoAmI)"
check "four instances via separate subshell calls" "$combined" "Alpha-Beta-Rex-Gamma"

# ---------------------------------------------------------------------------
echo
echo ">>> 6. Shared static state + destructors inherited through 4 levels"
check "census counts every live instance" "$(TAnimal.Census)" "5"
rex.delete
a.delete
b.delete
g.delete
scout.delete
check "every destructor ran (inherited down the chain)" "$(TAnimal.Census)" "0"

echo
echo "=== Example completed successfully ==="
