#!/usr/bin/env bash
# FriendTables — pins the "Friend tables (for framework units)" contract of the
# kklass book (chapter Internals), which kcl's fv.views relies on (kcl
# docs/dev/fv P2_DESIGN.md §1.11, decision D19). No runtime cost, no helper
# functions: these are the variables and function names themselves.
#
#   F1  ${inst}_class                   a plain string = the instance's OWN class
#   F2  ${inst}_data                    an associative array, one key per
#                                       assigned `var` field; a field never
#                                       assigned has no key (read it `${d[F]-}`)
#   F3  a friend write of a declared field (d[F]=v, unset 'd[F]') is what the
#       instance's own methods and accessors see
#   F4  ${CLASS}_class_method_owner     method -> defining class, copied down
#                                       and overridden per class, read live
#   F5  kk._exec kk._call kk._parent kk._constructor_exec   exist as functions;
#       a test shim may wrap and unwrap them (rc, RESULT, call counts intact)
#   F6  lifetimes: created at .new / build, removed at .delete

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "FriendTables" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"
source "$KKLASS_DIR/kklass_pascal.sh"

check() {   # NAME WANT GOT
    if [[ "$3" == "$2" ]]; then kt_test_pass "$1"; else kt_test_fail "$1: got '$3' want '$2'"; fi
}

ft_attr() { local -n __ft_n=$1; FT_A=${__ft_n@a}; }   # attributes of the variable NAME (nameref-safe)

class TFtBase
    public
        var X
        var Y
        constructor Create
        proc SetX
        func GetX
        func GetY
        proc Plain
        func Ping
end
TFtBase.Create() { :; }
TFtBase.SetX() { X=$1; }
TFtBase.GetX() { RESULT="${X-<unset>}"; }
TFtBase.GetY() { RESULT="${Y-<unset>}"; }
TFtBase.Plain() { :; }
TFtBase.Ping() { RESULT="base-ping"; }
build TFtBase

class TFtKid : TFtBase
    public
        override func Ping
        proc Own
end
TFtKid.Ping() { inherited Ping; RESULT="kid+$RESULT"; }
TFtKid.Own() { :; }
build TFtKid

class TFtNoMethods
    public
        var Q
end
build TFtNoMethods

TFtBase.new fb
TFtKid.new fk

# ---------------------------------------------------------------------------
kt_test_start "F1 \${inst}_class is a plain (non-array, non-nameref) string holding the instance's OWN class"
ft_attr fb_class; a1=$FT_A; ft_attr fk_class; a2=$FT_A
check "F1 base" "TFtBase|" "$fb_class|$a1"
check "F1 kid"  "TFtKid|"  "$fk_class|$a2"
# the class's methods are inherited, the instance's class name is not
check "F1 own class, not the definer of Plain" "TFtKid" "$fk_class"

# ---------------------------------------------------------------------------
kt_test_start "F2 \${inst}_data is an associative array: empty after .new, a key per assigned field"
declare -n fbd=fb_data
ft_attr fb_data; check "F2 type" "A" "${FT_A//[^A]/}"
check "F2 empty"      "0"  "${#fbd[@]}"
check "F2 unset read" ""   "${fbd[X]-}"
fb.SetX 5
check "F2 key after method write" "1|5" "${#fbd[@]}|${fbd[X]}"
fb.property Y = "two words"
check "F2 key after .property write, a value with a blank" "2|two words" "${#fbd[@]}|${fbd[Y]}"
check "F2 keys are the field names" "X Y" "$(printf '%s\n' "${!fbd[@]}" | sort | tr '\n' ' ' | sed 's/ $//')"

# ---------------------------------------------------------------------------
kt_test_start "F2 set -u: a never-assigned field is unset - \${d[X]-} is safe, a bare \${d[X]} is an unbound variable"
fb.delete; TFtBase.new fb; declare -n fbd=fb_data
o=$( set -u; echo "[${fbd[X]-}]" 2>&1 )
check "F2 \${d[X]-} under set -u" "[]" "$o"
o=$( ( set -u; : "${fbd[X]}" ) 2>&1; echo "rc=$?" )
if [[ $o == *"unbound variable"* && $o != *"rc=0" ]]; then kt_test_pass "F2 bare ${d[X]} under set -u is an unbound variable"; else kt_test_fail "F2 bare read under set -u: '$o'"; fi
# the instance's own accessors honour the same rule
fb.GetY; r0=$RESULT; o=$( set -u; fb.GetY )
check "F2 own method reads an unassigned field under set -u (direct and in a subshell)" "<unset>|<unset>" "$r0|$o"
o=$( set -u; fb.property Y )
check "F2 .property read of an unassigned field under set -u" "" "$o"

# ---------------------------------------------------------------------------
kt_test_start "F3 a friend write of a declared field is seen by the instance's own method and accessor; its own write is seen by the friend"
fb.delete; TFtBase.new fb; declare -n fbd=fb_data
fbd[X]=friend
fb.GetX
check "F3 d[X]=v seen by a method" "friend" "$RESULT"
check "F3 d[X]=v seen by .property" "friend" "$(fb.property X)"
fb.SetX "from-method"
check "F3 method write seen through d[X]" "from-method" "${fbd[X]-}"
unset 'fbd[X]'
fb.GetX
check "F3 unset 'd[X]' returns the field to never-assigned" "<unset>|0" "$RESULT|${#fbd[@]}"
# a friend write into ANOTHER instance of a derived class
declare -n fkd=fk_data
fkd[X]=kidx; fkd[Y]=kidy
fk.GetX; r1=$RESULT; fk.GetY
check "F3 inherited fields of a derived instance" "kidx|kidy" "$r1|$RESULT"

# ---------------------------------------------------------------------------
kt_test_start "F4 \${CLASS}_class_method_owner is an associative array: method -> defining class, inherited entries copied down"
declare -n ob=TFtBase_class_method_owner ok=TFtKid_class_method_owner
ft_attr TFtBase_class_method_owner; t1=${FT_A//[^A]/}; ft_attr TFtKid_class_method_owner; check "F4 type" "A|A" "$t1|${FT_A//[^A]/}"
check "F4 base owns its methods" "TFtBase TFtBase TFtBase TFtBase TFtBase" "${ob[SetX]} ${ob[GetX]} ${ob[GetY]} ${ob[Plain]} ${ob[Ping]}"
check "F4 kid: inherited methods name the BASE" "TFtBase TFtBase TFtBase TFtBase" "${ok[SetX]} ${ok[GetX]} ${ok[GetY]} ${ok[Plain]}"
check "F4 kid: an override and a new method name the KID" "TFtKid TFtKid" "${ok[Ping]} ${ok[Own]}"
check "F4 base is untouched by the kid" "TFtBase" "${ob[Ping]}"
check "F4 a method that does not exist has no entry" "" "${ok[Nope]-}"
check "F4 the constructor is not an entry" "" "${ob[Create]-}${ok[Create]-}"
ft_attr TFtNoMethods_class_method_owner; declare -n nm=TFtNoMethods_class_method_owner; check "F4 a class without methods has an empty table" "A|0" "${FT_A//[^A]/}|${#nm[@]}"

# ---------------------------------------------------------------------------
kt_test_start "F4 defineMethod re-points the entry of the class it is applied to ; the parent's table is not touched"
defineMethod TFtKid Plain 'RESULT=kid-plain'
check "F4 after defineMethod: kid entry" "TFtKid" "${ok[Plain]}"
check "F4 after defineMethod: base entry" "TFtBase" "${ob[Plain]}"
defineMethod TFtKid Extra ':'
check "F4 after defineMethod: a new method gets an entry" "TFtKid" "${ok[Extra]}"

# ---------------------------------------------------------------------------
kt_test_start "F4 a destructor is an entry; a rebuild (kk.class --forget + the class again) re-declares and refills the table (a friend reads it per use, never caches)"
class TFtRbBase
    public
        constructor Create
        destructor Done
        proc M
        proc N
end
TFtRbBase.Create() { :; }
TFtRbBase.Done() { :; }
TFtRbBase.M() { RESULT=base-m; }
TFtRbBase.N() { RESULT=base-n; }
build TFtRbBase
class TFtRb : TFtRbBase
    public
        override proc M
end
TFtRb.M() { RESULT=rb-m; }
build TFtRb
TFtRb.new rb
declare -n rbo=TFtRb_class_method_owner
check "F4 destructor entry and an override" "TFtRbBase TFtRb" "${rbo[Done]} ${rbo[M]}"
kk.class --forget TFtRb 2>/dev/null
class TFtRb : TFtRbBase
    public
        override proc N
        proc Z
end
TFtRb.N() { :; }
TFtRb.Z() { :; }
build TFtRb
check "F4 after a rebuild: new owners, old override gone" "TFtRbBase TFtRb TFtRb" "${rbo[M]} ${rbo[N]} ${rbo[Z]}"
rb.delete
# ---------------------------------------------------------------------------
kt_test_start "F5 the four dispatcher names are functions"
for f in kk._exec kk._call kk._parent kk._constructor_exec; do
    if declare -F "$f" >/dev/null; then kt_test_pass "F5 $f exists"; else kt_test_fail "F5 $f is not a function"; fi
done

# ---------------------------------------------------------------------------
kt_test_start "F5 a wrap-and-unwrap counting shim keeps rc and RESULT and counts the calls"
FT_CALLS=0
ft_shim_on() {
    local f src
    for f in kk._exec kk._call kk._parent kk._constructor_exec; do
        declare -F "$f" >/dev/null || return 1
        declare -F "__ft_orig_$f" >/dev/null && continue
        src=$(declare -f "$f")
        eval "__ft_orig_${src}"
        eval "$f() { FT_CALLS=\$(( FT_CALLS + 1 )); __ft_orig_$f \"\$@\"; }"
    done
}
ft_shim_off() {
    local f src
    for f in kk._exec kk._call kk._parent kk._constructor_exec; do
        declare -F "__ft_orig_$f" >/dev/null || continue
        src=$(declare -f "__ft_orig_$f")
        eval "${src#__ft_orig_}"
        unset -f "__ft_orig_$f"
    done
}
class TFtShim
    public
        var N
        constructor Create
        func Val
        func Two
        proc Fail
end
TFtShim.Create() { N=${1:-1}; }
TFtShim.Val() { RESULT="$(( N + 1 ))"; }
TFtShim.Two() { $this.Val; RESULT="two:$RESULT"; }
TFtShim.Fail() { return 7; }
build TFtShim
class TFtShimKid : TFtShim
    public
        override func Val
end
TFtShimKid.Val() { inherited Val; RESULT="$(( RESULT * 10 ))"; }
build TFtShimKid

ft_shim_on
FT_CALLS=0; TFtShimKid.new sk 4
check "F5 .new = 1 constructor_exec" "1" "$FT_CALLS"
FT_CALLS=0; sk.Two
check "F5 Two -> \$this.Val -> inherited Val: result" "two:50" "$RESULT"
check "F5 Two -> \$this.Val -> inherited Val: 3 dispatches (exec, exec, parent)" "3" "$FT_CALLS"
FT_CALLS=0; sk.call Val
check "F5 .call: result and 2 dispatches (call, parent)" "50|2" "$RESULT|$FT_CALLS"
FT_CALLS=0; sk.Fail; rc=$?
check "F5 rc of a body passes through the shim" "7|1" "$rc|$FT_CALLS"
set -e; FT_CALLS=0; sk.Val; set +e
check "F5 under set -e (Val + inherited Val)" "50|2" "$RESULT|$FT_CALLS"
FT_CALLS=0; o=$(sk.Val)
check "F5 in a \$( ) subshell the func echoes its RESULT" "50" "$o"
ft_shim_off
for f in kk._exec kk._call kk._parent kk._constructor_exec; do
    if declare -F "__ft_orig_$f" >/dev/null; then kt_test_fail "F5 unwrap left __ft_orig_$f"; fi
done
FT_CALLS=0; sk.Two
check "F5 after unwrap: same result, no counting" "two:50|0" "$RESULT|$FT_CALLS"

# ---------------------------------------------------------------------------
kt_test_start "F6 lifetimes: _class and _data exist from .new to .delete (both removed); the owner table is built with the class and outlives instances"
TFtBase.new fl
ft_attr fl_data; check "F6 live" "set|A" "${fl_class+set}|${FT_A//[^A]/}"
fl.delete
check "F6 _class removed by .delete" "" "${fl_class+set}"
check "F6 _data removed by .delete" "" "${fl_data+set}"
check "F6 _data really gone (declare -p fails)" "1" "$(declare -p fl_data >/dev/null 2>&1; echo $?)"
check "F6 owner table survives instances" "TFtBase" "${ob[Plain]}"
for i in fb fk sk; do "$i.delete"; done

kt_test_log "151_FriendTables.sh completed"
