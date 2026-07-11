#!/bin/bash
# PascalBuildStatus — regression tests for the exit status of the Pascal DSL
# `build` verb.
#
# THE BUG (found while porting TStringList : TList): build's final statement
# was `[[ -n "${parent_destructor}" ]] && eval ...` — for a class whose PARENT
# declares NO destructor the condition is false, the `&&` chain leaves status 1
# and build silently fails (`source file.sh` then aborted with no message).
# Classes with no parent, or whose parent HAS a destructor, never hit it.

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "PascalBuildStatus" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass_pascal.sh"

# --- parent WITHOUT a destructor, child inherits from it (the bug) ----------
class TNoDtorBase
    public
        var  Name
        proc Hello
end
TNoDtorBase.Hello() { echo "hi"; }
build TNoDtorBase

kt_test_start "build succeeds for a child of a destructor-less parent (the bug)"
class TNoDtorChild : TNoDtorBase
    public
        proc Bye
end
TNoDtorChild.Bye() { echo "bye"; }
if build TNoDtorChild; then
    kt_test_pass "build succeeds for a child of a destructor-less parent (the bug)"
else
    kt_test_fail "build succeeds for a child of a destructor-less parent (got status $?, want 0)"
fi

kt_test_start "the child class is actually usable after build"
TNoDtorChild.new c1
c1.Name = "x"
if [[ "$(c1.Name)" == "x" && "$(c1.Bye)" == "bye" && "$(c1.Hello)" == "hi" ]]; then
    kt_test_pass "the child class is actually usable after build"
else
    kt_test_fail "the child class is actually usable after build (Name/Bye/Hello mismatch)"
fi
c1.delete

# --- parent WITH a destructor: status 0 AND the name is inherited -----------
class TDtorBase
    public
        constructor Create
        destructor  Destroy
        static var  Alive
        static func AliveCount
end
TDtorBase.Create()     { Alive=$(( Alive + 1 )); }
TDtorBase.Destroy()    { Alive=$(( Alive - 1 )); }
TDtorBase.AliveCount() { RESULT="$Alive"; }
build TDtorBase

kt_test_start "build succeeds when the parent HAS a destructor"
class TDtorChild : TDtorBase
    public
        proc Noop
end
TDtorChild.Noop() { :; }
if build TDtorChild; then
    kt_test_pass "build succeeds when the parent HAS a destructor"
else
    kt_test_fail "build succeeds when the parent HAS a destructor (got status $?)"
fi

kt_test_start "child inherits the parent destructor name"
dtor_var="TDtorChild_destructor_name"
if [[ "${!dtor_var}" == "Destroy" ]]; then
    kt_test_pass "child inherits the parent destructor name"
else
    kt_test_fail "child inherits the parent destructor name (got '${!dtor_var}', want 'Destroy')"
fi

kt_test_start "inherited destructor actually runs on delete"
TDtorBase.Alive = "0"
TDtorChild.new d1
TDtorChild.new d2
d1.delete
d2.delete
count="$(TDtorBase.AliveCount)"
if [[ "$count" == "0" ]]; then
    kt_test_pass "inherited destructor actually runs on delete"
else
    kt_test_fail "inherited destructor actually runs on delete (Alive '$count', want 0)"
fi

# --- no parent at all: still status 0 ---------------------------------------
kt_test_start "build succeeds for a parentless class without destructor"
class TLoneClass
    public
        proc Ping
end
TLoneClass.Ping() { echo "pong"; }
if build TLoneClass; then
    kt_test_pass "build succeeds for a parentless class without destructor"
else
    kt_test_fail "build succeeds for a parentless class without destructor (got status $?)"
fi
