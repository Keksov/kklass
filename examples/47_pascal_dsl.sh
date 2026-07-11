#!/bin/bash
# Example 47: Pascal-style DSL (kklass_pascal.sh)
#
# Write the class STRUCTURE first (Pascal "interface"), then the method BODIES as
# real bash functions (real syntax highlighting, real quoting), then `build`.
# Bodies are extracted from the functions via `declare -f` and fed to the normal
# kklass runtime — so everything you already know still applies.
#
# Grammar:
#   class N [: P] ... end          class, optional inheritance (: Parent)
#   public | private | protected   visibility sections (repeatable, any order)
#   var X                          stored field         ->  obj.X
#   property X read G write S       computed property (G/S are declared methods)
#   proc X                         method, no return value
#   func X                         method, returns via RESULT
#   constructor [C]                constructor (default Create); inherited if absent
#   destructor  [D]                destructor  (default Destroy); runs on obj.delete
#   static <var|proc|func>         class-level member (shared), not per-instance
#   abstract <proc|func>           no body; class cannot be instantiated until overridden
#   override <proc|func>           guard: errors unless an ancestor defines the method
#   build N                        extract bodies + finalize the class
#
# Inside a body, `inherited` (or `inherited Name`) calls the parent's version —
# works in methods, constructors (forwards args), and destructors, just like Pascal.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../kklass_pascal.sh"

# Tiny self-check helper: check "label" actual expected
check() {
    if [[ "$2" == "$3" ]]; then
        echo "  OK  $1"
    else
        echo "  XX  $1  (expected '$3', got '$2')"
        exit 1
    fi
}

echo "=== kklass Pascal-style DSL Example ==="

# ---------------------------------------------------------------------------
echo
echo ">>> 1. Basics: var, constructor, proc (no return), func (returns via RESULT)"

class TGreeter
    public
        var         Name
        constructor Create
        proc        Greet
        func        Salutation
end

TGreeter.Create()     { Name="${1:-World}"; }
TGreeter.Greet()      { echo "Hello, $Name!"; }
TGreeter.Salutation() { RESULT="Greetings from $Name"; }
build TGreeter

TGreeter.new g "Alice"
check "constructor set the field"       "$(g.Name)"       "Alice"
check "proc prints"                     "$(g.Greet)"      "Hello, Alice!"
check "func returns a value (RESULT)"   "$(g.Salutation)" "Greetings from Alice"
g.delete

# ---------------------------------------------------------------------------
echo
echo ">>> 2. Properties: read/write accessors and a read-only property"

class TTemperature
    public
        var      Celsius
        property Fahrenheit read GetF write SetF   # read + write accessors
        func     GetF
        proc     SetF
        property Label      read GetLabel          # read-only (no write)
        func     GetLabel
end

TTemperature.GetF()     { RESULT=$(( Celsius * 9 / 5 + 32 )); }
TTemperature.SetF()     { Celsius=$(( ($1 - 32) * 5 / 9 )); }
TTemperature.GetLabel() { RESULT="${Celsius}C"; }
build TTemperature

TTemperature.new t
t.Celsius = 100
check "computed getter"        "$(t.Fahrenheit)" "212"
t.Fahrenheit = 32                              # setter converts back to Celsius
check "computed setter"        "$(t.Celsius)"    "0"
check "read-only property"     "$(t.Label)"      "0C"
t.delete

# ---------------------------------------------------------------------------
echo
echo ">>> 3. Visibility sections are repeatable and can appear in any order"

class TVault
    private
        var         Pin
    public
        constructor Create
        func        Check
    protected
        proc        Audit
    private                                    # <-- switch BACK to private
        var         Balance
    public                                     # <-- and back to public again
        proc        Deposit
        func        GetBalance
end

TVault.Create()     { Pin="$1"; Balance="${2:-0}"; }
TVault.Check()      { [[ "$1" == "$Pin" ]] && RESULT="ok" || RESULT="denied"; }
TVault.Audit()      { echo "[audit] balance=$Balance" >&2; }
TVault.Deposit()    { Balance=$(( Balance + $1 )); $this.Audit; }
TVault.GetBalance() { RESULT="$Balance"; }
build TVault

TVault.new v 1234 100
check "public method"                   "$(v.Check 1234)"   "ok"
v.Deposit 50
check "method uses private field"       "$(v.GetBalance)"   "150"
warn="$(v.Pin 2>&1 >/dev/null)"                     # read private field from outside
check "private access is flagged"       "$([[ "$warn" == *private*TVault.Pin* ]] && echo yes)" "yes"
v.delete

# ---------------------------------------------------------------------------
echo
echo ">>> 4. Inheritance + Pascal 'inherited' (constructor chaining + method chaining)"

class TAnimal
    public
        var         Name
        constructor Create
        proc        Speak
        func        Legs
end

TAnimal.Create() { Name="$1"; }
TAnimal.Speak()  { echo "$Name makes a sound"; }
TAnimal.Legs()   { RESULT="4"; }
build TAnimal

class TDog : TAnimal
    public
        var           Breed
        constructor   Create
        override proc Speak
        func          Fetch
end
# `inherited` chains to the parent — in a constructor (args forwarded) and a method.
TDog.Create() { inherited; Breed="${2:-mutt}"; }   # -> TAnimal.Create "$@", then set Breed
TDog.Speak()  { echo "$Name barks"; inherited; }   # -> TAnimal.Speak
TDog.Fetch()  { echo "$Name fetches"; }
build TDog

TDog.new d "Rex" "Labrador"
check "inherited constructor forwards args" "$(d.Name)"   "Rex"
check "own field set after inherited ctor"  "$(d.Breed)"  "Labrador"
check "inherited func"                      "$(d.Legs)"   "4"
check "override + inherited method"         "$(d.Speak)"  "$(printf 'Rex barks\nRex makes a sound')"
d.delete

# ---------------------------------------------------------------------------
echo
echo ">>> 5. Abstract classes cannot be instantiated until overridden"

class TShape
    public
        abstract func Area      # no body -> TShape is abstract
        func          Kind
end
TShape.Kind() { RESULT="shape"; }
build TShape

err="$(TShape.new s 2>&1)"
check "abstract class rejects .new"     "$([[ "$err" == *"cannot be instantiated"* ]] && echo yes)" "yes"

class TSquare : TShape
    public
        var           Side
        override func Area      # implement the abstract method -> concrete
end
TSquare.Area() { RESULT=$(( Side * Side )); }
build TSquare

TSquare.new sq
sq.Side = 5
check "concrete subclass instantiable"  "$(sq.Area)"  "25"
check "inherited concrete method"        "$(sq.Kind)"  "shape"
sq.delete

# ---------------------------------------------------------------------------
echo
echo ">>> 6. Static members: shared var + static func + static proc"

class TWidget
    public
        var         Id
        constructor Create
        static var  Total
        static func Count
        static proc Reset
end

TWidget.Create() { Id="$1"; Total=$(( Total + 1 )); }
TWidget.Count()  { RESULT="$Total"; }
TWidget.Reset()  { Total=0; }
build TWidget

TWidget.Reset
TWidget.new w1 "a"
TWidget.new w2 "b"
check "static counter shared by instances" "$(TWidget.Count)" "2"
w1.delete
w2.delete

# ---------------------------------------------------------------------------
echo
echo ">>> 7. Destructors: run on .delete; inherited by default, or chained with 'inherited'"

class TResource
    public
        var         Tag
        constructor Create
        destructor  Destroy
        static var  Open
        static func OpenCount
end

TResource.Create()    { Tag="$1"; Open=$(( Open + 1 )); }
TResource.Destroy()   { Open=$(( Open - 1 )); }   # runs automatically on .delete
TResource.OpenCount() { RESULT="$Open"; }
build TResource

class TTracked : TResource
    public
        static var  Freed
        static func FreedCount
        destructor  Destroy         # overrides the destructor but chains to the parent
end
# TTracked inherits the constructor (not declared) and CHAINS the destructor via `inherited`.
TTracked.Destroy()    { Freed=$(( Freed + 1 )); inherited; }   # own cleanup, then parent's
TTracked.FreedCount() { RESULT="$Freed"; }
build TTracked

TTracked.Freed = "0"
TResource.new r1 "log"
TTracked.new  t1 "data"                         # constructor inherited (not declared)
check "two resources open"              "$(TResource.OpenCount)" "2"
r1.delete                                       # own destructor
t1.delete                                       # overridden destructor + inherited chain
check "all destructors ran"             "$(TResource.OpenCount)" "0"
check "chained destructor did its part" "$(TTracked.FreedCount)" "1"

# ---------------------------------------------------------------------------
echo
echo ">>> 8. override is a guard: a typo that overrides nothing is caught at build"

class TBase
    public
        proc Handle
end
TBase.Handle() { echo "base"; }
build TBase

class TDerived : TBase
    public
        override proc Hndle     # typo: TBase has 'Handle', not 'Hndle'
end
TDerived.Hndle() { echo "oops"; }
err="$(build TDerived 2>&1)"
check "override guard catches the typo" "$([[ "$err" == *"overrides nothing"* ]] && echo yes)" "yes"

# ---------------------------------------------------------------------------
echo
echo "=== Example completed successfully ==="
