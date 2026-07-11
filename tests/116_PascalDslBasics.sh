#!/bin/bash
# PascalDslBasics — the Pascal-style DSL front-end (kklass_pascal.sh), basics:
# class ... end, var, proc, func, constructor, properties, visibility sections,
# and build-time diagnostics. Companion examples: examples/47_pascal_dsl.sh.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "PascalDslBasics" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass_pascal.sh"

# --- var / proc / func / constructor -----------------------------------------
class TDslGreeter
    public
        var         Name
        constructor Create
        proc        Greet
        func        Salutation
end
TDslGreeter.Create()     { Name="${1:-World}"; }
TDslGreeter.Greet()      { echo "Hello, $Name!"; }
TDslGreeter.Salutation() { RESULT="Greetings from $Name"; }
build TDslGreeter

kt_test_start "constructor receives .new arguments"
TDslGreeter.new g "Alice"
if [[ "$(g.Name)" == "Alice" ]]; then
    kt_test_pass "constructor receives .new arguments"
else
    kt_test_fail "constructor receives .new arguments (Name='$(g.Name)')"
fi

kt_test_start "proc body echoes"
if [[ "$(g.Greet)" == "Hello, Alice!" ]]; then
    kt_test_pass "proc body echoes"
else
    kt_test_fail "proc body echoes (got '$(g.Greet)')"
fi

kt_test_start "func returns via RESULT"
if [[ "$(g.Salutation)" == "Greetings from Alice" ]]; then
    kt_test_pass "func returns via RESULT"
else
    kt_test_fail "func returns via RESULT (got '$(g.Salutation)')"
fi

kt_test_start "field write via = syntax"
g.Name = "Bob"
if [[ "$(g.Name)" == "Bob" && "$(g.Greet)" == "Hello, Bob!" ]]; then
    kt_test_pass "field write via = syntax"
else
    kt_test_fail "field write via = syntax (Name='$(g.Name)')"
fi
g.delete

# --- properties: computed rw, read-only, stored-read + computed-write --------
class TDslProps
    public
        var      Celsius
        property Fahrenheit read GetF write SetF
        func     GetF
        proc     SetF
        property Label read GetLabel
        func     GetLabel
        property Volume read Volume write _setVolume     # stored read, computed write
        proc     _setVolume
end
TDslProps.GetF()       { RESULT=$(( Celsius * 9 / 5 + 32 )); }
TDslProps.SetF()       { Celsius=$(( ($1 - 32) * 5 / 9 )); }
TDslProps.GetLabel()   { RESULT="${Celsius}C"; }
TDslProps._setVolume() { Volume=$(( $1 < 0 ? 0 : $1 )); }   # clamp negative to 0
build TDslProps

TDslProps.new t
t.Celsius = 100

kt_test_start "computed property getter"
if [[ "$(t.Fahrenheit)" == "212" ]]; then
    kt_test_pass "computed property getter"
else
    kt_test_fail "computed property getter (got '$(t.Fahrenheit)')"
fi

kt_test_start "computed property setter"
t.Fahrenheit = 32
if [[ "$(t.Celsius)" == "0" ]]; then
    kt_test_pass "computed property setter"
else
    kt_test_fail "computed property setter (Celsius='$(t.Celsius)')"
fi

kt_test_start "read-only property rejects writes"
err="$(t.Label = "oops" 2>&1 >/dev/null)"
if [[ "$err" == *read-only* ]]; then
    kt_test_pass "read-only property rejects writes"
else
    kt_test_fail "read-only property rejects writes (stderr: '$err')"
fi

kt_test_start "stored-read + computed-write property (TList pattern)"
t.Volume = "-5"                       # computed setter clamps to 0
volume_now="$(t.Volume)"              # stored read returns the raw value
t.Volume = "42"
if [[ "$volume_now" == "0" && "$(t.Volume)" == "42" ]]; then
    kt_test_pass "stored-read + computed-write property (TList pattern)"
else
    kt_test_fail "stored-read + computed-write (clamped='$volume_now', set='$(t.Volume)')"
fi
t.delete

# --- visibility sections (repeatable) ----------------------------------------
class TDslVault
    private
        var Pin
    public
        constructor Create
        func Check
    private                              # switch BACK to private
        var Secret
    public                               # and back to public
        func GetSecret
end
TDslVault.Create()    { Pin="$1"; Secret="$2"; }
TDslVault.Check()     { [[ "$1" == "$Pin" ]] && RESULT="ok" || RESULT="denied"; }
TDslVault.GetSecret() { RESULT="$Secret"; }
build TDslVault

TDslVault.new v 1234 "sesame"

kt_test_start "public method works; private field flagged on outside access"
warn="$(v.Pin 2>&1 >/dev/null)"
if [[ "$(v.Check 1234)" == "ok" && "$warn" == *private* ]]; then
    kt_test_pass "public method works; private field flagged on outside access"
else
    kt_test_fail "visibility (check='$(v.Check 1234)', warn='$warn')"
fi

kt_test_start "repeated visibility sections keep declarations usable"
if [[ "$(v.GetSecret)" == "sesame" ]]; then
    kt_test_pass "repeated visibility sections keep declarations usable"
else
    kt_test_fail "repeated visibility sections (GetSecret='$(v.GetSecret)')"
fi
v.delete

# --- build diagnostics --------------------------------------------------------
kt_test_start "build reports a missing implementation function"
class TDslMissing
    public
        proc Foo
end
err="$(build TDslMissing 2>&1)"
status=$?
if [[ $status -ne 0 && "$err" == *"missing implementation"* ]]; then
    kt_test_pass "build reports a missing implementation function"
else
    kt_test_fail "build missing-impl (status=$status, err='$err')"
fi

kt_test_start "abstract method blocks instantiation"
class TDslShape
    public
        abstract func Area
end
build TDslShape
err="$(TDslShape.new s1 2>&1)"
if [[ "$err" == *"cannot be instantiated"* ]]; then
    kt_test_pass "abstract method blocks instantiation"
else
    kt_test_fail "abstract instantiation guard (err='$err')"
fi
