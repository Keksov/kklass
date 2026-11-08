#!/usr/bin/env bash
# PerfRoundK (call-path speedup round K, docs/dev/PERF_PLAN.md) — behaviour the
# round's phases pin while they shorten the method call path.
#
# K4: `inherited` (kk._parent) and the visibility check (kk._warn_visibility)
# read the frame class straight from the frame arrays. Before, they went through
# kv.frameCurrent + kv.frameClass, which overwrote RESULT: a body calling
# `inherited X` saw RESULT = its class name afterwards (the parent body's frame
# restored that as "the caller's RESULT").
#
# K2: the fields (state, properties, static properties) of a body are bound by
# one `local -n +x` from the per-class template ${CLASS}_class_binds instead of
# a loop per property (the template is dumped into .ckk caches: format 5).

KTESTS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../ktests" && pwd)"
source "$KTESTS_LIB_DIR/ktest.sh"

kt_test_init "PerfRoundK" "$(dirname "$0")" "$@"

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$KKLASS_DIR/kklass.sh"
source "$KKLASS_DIR/kklass_pascal.sh"

check() {   # NAME WANT GOT
    if [[ "$3" == "$2" ]]; then kt_test_pass "$1"; else kt_test_fail "$1: got '$3' want '$2'"; fi
}

class TK4Base
    public
        proc Nop
        proc Set
        func Get
    protected
        proc Hidden
end
TK4Base.Nop() { :; }
TK4Base.Set() { RESULT=fromparent; }
TK4Base.Get() { kk._return "parentvalue"; }
TK4Base.Hidden() { :; }
build TK4Base

class TK4Child : TK4Base
    public
        override proc Nop
        override proc Set
        override func Get
        proc CallHidden
end
TK4Child.Nop() { RESULT=keep; inherited Nop; K4_SEEN=$RESULT; }
TK4Child.Set() { RESULT=keep; inherited Set; K4_SEEN=$RESULT; }
TK4Child.Get() { inherited Get; kk._return "child+$RESULT"; }
TK4Child.CallHidden() { RESULT=keep; $this.Hidden; K4_SEEN=$RESULT; }
build TK4Child
TK4Child.new k4

kt_test_start "K4.1 after 'inherited X' (parent body sets nothing) a body keeps its own RESULT"
K4_SEEN=""; RESULT=outer; k4.Nop
check "K4.1" "keep" "$K4_SEEN"

kt_test_start "K4.2 a parent body's plain RESULT= is not a return value: the child's RESULT survives"
K4_SEEN=""; RESULT=outer; k4.Set
check "K4.2" "keep" "$K4_SEEN"

kt_test_start "K4.3 the caller's RESULT is restored after a proc that returns nothing"
RESULT=outer; k4.Nop
check "K4.3" "outer" "$RESULT"

kt_test_start "K4.4 a returned value still passes through inherited (func chain)"
RESULT=""; k4.Get
check "K4.4" "child+parentvalue" "$RESULT"

kt_test_start "K4.5 inherited resolves from the frame class at depth (grandchild -> child -> base)"
class TK4Grand : TK4Child
    public
        override func Get
end
TK4Grand.Get() { inherited Get; kk._return "grand+$RESULT"; }
build TK4Grand
TK4Grand.new k4g
RESULT=""; k4g.Get
check "K4.5" "grand+child+parentvalue" "$RESULT"

kt_test_start "K4.6 a protected call from inside the class is silent and keeps RESULT"
K4_SEEN=""; RESULT=outer
k4.CallHidden 2>"$(kt_fixture_tmpdir)/k4.err"
check "K4.6 RESULT" "keep" "$K4_SEEN"
check "K4.6 stderr" "" "$(<"$(kt_fixture_tmpdir)/k4.err")"

kt_test_start "K4.7 a protected call from outside still warns"
k4.Hidden 2>"$(kt_fixture_tmpdir)/k4b.err"
if [[ -s "$(kt_fixture_tmpdir)/k4b.err" ]]; then kt_test_pass "K4.7"; else kt_test_fail "K4.7: no visibility warning"; fi

# ---------------------------------------------------------------------------
# K2: kk._run_frame_body binds `state`, every property and every static
# property with ONE `local -n +x` from the per-class template
# ${CLASS}_class_binds = (state=@_data P=@_data[P] ... S=OWNER_static_S ...),
# written by kk._build_class_runtime; `@` = the instance name.
K2T="$(cd "$(kt_fixture_tmpdir)" && pwd)"

kt_test_start "K2.1 a class with no fields: the template is state only; the body sees state, this, __class__"
defineClass TK2Zero "" method m 'echo "state=${!state} this=$this cls=$__class__"'
TK2Zero.new k2z
check "K2.1 template" "state=@_data" "${TK2Zero_class_binds[*]}"
check "K2.1 body" "state=k2z_data this=k2z cls=TK2Zero" "$(k2z.m)"

kt_test_start "K2.2 one field: read and written through the bind"
defineClass TK2One "" property v method bump 'v=$(( v + 1 ))' method show 'echo "v=$v"'
TK2One.new k2o; k2o.v = 41; k2o.bump
check "K2.2 template" "state=@_data v=@_data[v]" "${TK2One_class_binds[*]}"
check "K2.2 body" "v=42|42" "$(k2o.show)|${k2o_data[v]}"

kt_test_start "K2.3 fourteen fields: every one bound to its own cell, in table order"
k2args=()
for k2i in 01 02 03 04 05 06 07 08 09 10 11 12 13 14; do k2args+=(property "F$k2i"); done
defineClass TK2Many "" "${k2args[@]}" \
    method fill 'local i n=0; for i in F01 F02 F03 F04 F05 F06 F07 F08 F09 F10 F11 F12 F13 F14; do n=$((n+1)); printf -v "$i" "v%s" "$n"; done' \
    method sum 'echo "$F01 $F07 $F14 ${#state[@]}"'
TK2Many.new k2m; k2m.fill
check "K2.3 size" "15" "${#TK2Many_class_binds[@]}"
check "K2.3 last" "F14=@_data[F14]" "${TK2Many_class_binds[14]}"
check "K2.3 body" "v1 v7 v14 14" "$(k2m.sum)"
check "K2.3 storage" "v14" "${k2m_data[F14]}"

kt_test_start "K2.4 inherited fields: the child's template is the parent's plus its own; a parent body on a child instance binds the child's table"
defineClass TK2P "" property a method pshow 'echo "a=$a b=${b-none}"'
defineClass TK2C TK2P property b
TK2C.new k2c; k2c.a = A; k2c.b = B
TK2P.new k2p; k2p.a = PA
check "K2.4 template" "state=@_data a=@_data[a] b=@_data[b]" "${TK2C_class_binds[*]}"
check "K2.4 bodies" "a=A b=B|a=PA b=none" "$(k2c.pshow)|$(k2p.pshow)"

kt_test_start "K2.5 static properties: bound to their DEFINING class's storage, also two levels down"
defineClass TK2SA "" static_property cnt method inc 'cnt=$(( ${cnt:-0} + 1 ))'
defineClass TK2SB TK2SA property y static_property own method inc2 'cnt=$(( ${cnt:-0} + 10 )); own=o'
defineClass TK2SC TK2SB
TK2SC.new k2sc; k2sc.inc; k2sc.inc2
check "K2.5 template" "state=@_data y=@_data[y] cnt=TK2SA_static_cnt own=TK2SB_static_own" "${TK2SC_class_binds[*]}"
check "K2.5 storage" "11 o" "$(TK2SA.cnt) $(TK2SB.own)"

kt_test_start "K2.6 a property named state replaces the state nameref (the order of the loops K2 replaced)"
defineClass TK2St "" property state method show 'echo "state=$state"'
TK2St.new k2st; k2st.state = SV
check "K2.6" "state=SV" "$(k2st.show)"

kt_test_start "K2.7 the placeholder cannot occur in a name: a property or an instance name with @ is refused"
k2err=0
defineClass TK2At "" property 'a@b' 2>/dev/null && k2err=1
TK2One.new 'k2@x' 2>/dev/null && k2err=$(( k2err + 2 ))
check "K2.7" "0 unset" "$k2err ${TK2At_class_binds[*]-unset}"

kt_test_start "K2.8 kk.class --forget + a redefinition with another property set rewrites the template"
defineClass TK2Re "" property a method m 'echo "a=${a-unset} b=${b-unset}"'
kk.class --forget TK2Re 2>/dev/null
defineClass TK2Re "" property b method m 'echo "a=${a-unset} b=${b-unset}"'
TK2Re.new k2re; k2re.b = B2
check "K2.8" "state=@_data b=@_data[b]|a=unset b=B2" "${TK2Re_class_binds[*]}|$(k2re.m)"

kt_test_start "K2.9 set -u caller: fields, statics and a class without fields bind; an instance deleted mid-body still binds state"
defineClass TK2DB "" property p method who 'echo "who cls=$__class__ $(declare -p state)"'
defineClass TK2DC TK2DB method gone 'local me=$this; $this.delete; kk._parent "$me" who'
TK2DC.new k2d; k2d.p = 1
k2out=$( set -u; k2o.show; TK2SA.cnt; k2m.sum; k2sc.inc; k2z.m; k2d.gone; echo "rc=$?" )
check "K2.9" "v=42|11|v1 v7 v14 14|state=k2z_data this=k2z cls=TK2Zero|who cls=TK2DB declare -n state=\"k2d_data\"|rc=0" \
    "${k2out//$'\n'/|}"
check "K2.9 the no-class template" "state=@_data" "${__kk_nocls_class_binds[*]}"

kt_test_start "K2.10 the binds stay invisible to another class's callee (scope isolation, round 5)"
defineClass TK2Peek "" method peek 'echo "F01=${F01-unset} cnt=${cnt-unset} state=${!state}"'
TK2Peek.new k2pk
defineClass TK2Caller "" property F01 static_property cnt method go 'F01=mine; cnt=s; k2pk.peek'
TK2Caller.new k2cl
check "K2.10" "F01=unset cnt=unset state=k2pk_data" "$(k2cl.go)"

kt_test_start "K2.11 a compiled cache holds the templates (format 5) and its classes bind in a fresh shell; a format-4 cache is refused"
cat > "$K2T/k2.kk" <<'EOF'
defineClass CK2P "" property a static_property s method show 'echo "a=$a b=${b-none} s=${s-none}"'
defineClass CK2C CK2P property b
EOF
( cd "$K2T" && bash "$KKLASS_DIR/kklass_compiler.sh" k2.kk k2.ckk.sh >/dev/null 2>"$K2T/k2.err" ); k2rc=$?
k2out=$(cd "$K2T" && bash -c 'set -u; source ./k2.ckk.sh; echo "${CK2C_class_binds[*]}"; CK2C.new o; o.a = A; o.b = B; CK2P.s = S; o.show' 2>&1)
check "K2.11 compile" "0|" "$k2rc|$(<"$K2T/k2.err")"
check "K2.11 header" "kk._ckk_format 5" "$(grep '^kk._ckk_format ' "$K2T/k2.ckk.sh")"
check "K2.11 dump" "1" "$(grep -c '^declare -ga CK2C_class_binds=' "$K2T/k2.ckk.sh")"
check "K2.11 load" "state=@_data a=@_data[a] b=@_data[b] s=CK2P_static_s|a=A b=B s=S" "${k2out//$'\n'/|}"
sed -e 's/^kk._ckk_format 5$/kk._ckk_format 4/' "$K2T/k2.ckk.sh" > "$K2T/k2old.ckk.sh"
k2out=$(cd "$K2T" && bash -c 'source ./k2old.ckk.sh; echo "rc=$?"; declare -F CK2C.new >/dev/null && echo loaded' 2>&1)
check "K2.11 format 4 refused" "1|rc=1" "$(grep -c 'has cache format 4, this kklass reads format 5' <<<"$k2out")|$(grep -v '^kklass:' <<<"$k2out" | tr '\n' '|' | sed 's/|$//')"

kt_test_start "K2.12 a class with tables but no template (a pre-U2b cache sourced directly) gets it rebuilt on its first call, also under set -u"
defineClass TK2NoT "" property q static_property s method m 'q=7; s=8; echo "q=$q s=$s"'
TK2NoT.new k2nt
unset TK2NoT_class_binds
k2out=$( set -u; k2nt.m; echo "${TK2NoT_class_binds[*]}" )
check "K2.12" "q=7 s=8|state=@_data q=@_data[q] s=TK2NoT_static_s" "${k2out//$'\n'/|}"

kt_test_log "150_PerfRoundK.sh completed"
