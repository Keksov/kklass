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
#
# K1: bodies are functions defined once (__kkm.OWNER.METHOD, __kkc.CLASS).
#
# K3: one dispatcher per call (kk._exec / kk._parent / kk._invoke) runs the body
# function directly; the K3 section pins the protocols on all three.

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
# K2: the body binds `state`, every property and every static
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

kt_test_start "K2.11 a compiled cache holds the templates (format 5 and later) and its classes bind in a fresh shell; a format-4 cache is refused"
cat > "$K2T/k2.kk" <<'EOF'
defineClass CK2P "" property a static_property s method show 'echo "a=$a b=${b-none} s=${s-none}"'
defineClass CK2C CK2P property b
EOF
( cd "$K2T" && bash "$KKLASS_DIR/kklass_compiler.sh" k2.kk k2.ckk.sh >/dev/null 2>"$K2T/k2.err" ); k2rc=$?
k2out=$(cd "$K2T" && bash -c 'set -u; source ./k2.ckk.sh; echo "${CK2C_class_binds[*]}"; CK2C.new o; o.a = A; o.b = B; CK2P.s = S; o.show' 2>&1)
check "K2.11 compile" "0|" "$k2rc|$(<"$K2T/k2.err")"
check "K2.11 header" "kk._ckk_format $__KK_CKK_FORMAT" "$(grep '^kk._ckk_format ' "$K2T/k2.ckk.sh")"
check "K2.11 dump" "1" "$(grep -c '^declare -ga CK2C_class_binds=' "$K2T/k2.ckk.sh")"
check "K2.11 load" "state=@_data a=@_data[a] b=@_data[b] s=CK2P_static_s|a=A b=B s=S" "${k2out//$'\n'/|}"
sed -e "s/^kk._ckk_format $__KK_CKK_FORMAT\$/kk._ckk_format 4/" "$K2T/k2.ckk.sh" > "$K2T/k2old.ckk.sh"
k2out=$(cd "$K2T" && bash -c 'source ./k2old.ckk.sh; echo "rc=$?"; declare -F CK2C.new >/dev/null && echo loaded' 2>&1)
check "K2.11 format 4 refused" "1|rc=1" "$(grep -c "has cache format 4, this kklass reads format $__KK_CKK_FORMAT" <<<"$k2out")|$(grep -v '^kklass:' <<<"$k2out" | tr '\n' '|' | sed 's/|$//')"

kt_test_start "K2.12 a class with tables but no template (a pre-U2b cache sourced directly) gets it rebuilt on its first call, also under set -u"
defineClass TK2NoT "" property q static_property s method m 'q=7; s=8; echo "q=$q s=$s"'
TK2NoT.new k2nt
unset TK2NoT_class_binds
k2out=$( set -u; k2nt.m; echo "${TK2NoT_class_binds[*]}" )
check "K2.12" "q=7 s=8|state=@_data q=@_data[q] s=TK2NoT_static_s" "${k2out//$'\n'/|}"

# ---------------------------------------------------------------------------
# K1: every method / constructor body is a function defined once when it is
# stored (kk._body_fn): __kkm.OWNER.METHOD, __kkc.CLASS — with the field binds
# as its prologue, so the binds and the body share one scope as they did
# around `eval "$body"`. The trampoline calls the function; nothing on the
# call path evals body text any more.
K1T="$(cd "$(kt_fixture_tmpdir)" && pwd)"

kt_test_start "K1.1 one function per DEFINING class (none for an inherited copy), one per constructor; the body is the function's frame (D2)"
defineClass TK1P "" property v method who 'echo "f0=${FUNCNAME[0]} f1=${FUNCNAME[1]} f2=${FUNCNAME[2]}"' method shared 'echo p' constructor 'v=$1'
defineClass TK1C TK1P method shared 'echo c'
k1f=""
for f in __kkm.TK1P.who __kkm.TK1P.shared __kkm.TK1C.shared __kkm.TK1C.who __kkc.TK1P __kkc.TK1C; do
    declare -F "$f" >/dev/null && k1f+="$f "
done
TK1C.new k1c
check "K1.1 functions" "__kkm.TK1P.who __kkm.TK1P.shared __kkm.TK1C.shared __kkc.TK1P " "$k1f"
check "K1.1 frames" "f0=__kkm.TK1P.who f1=kk._exec f2=k1c.who" "$(k1c.who)"   # K3: the dispatcher calls FN directly
check "K1.1 text kept" "echo c" "$TK1C_method_body_shared"

kt_test_start "K1.2 return N and the RESULT protocol: the status comes back, the caller's RESULT is restored unless kk._return ran; an empty body is rc 0"
defineClass TK1R "" method r7 'RESULT=inner; return 7' method rbare 'false; return' function fret 'kk._return got; return 4' \
    method empty '' method lastfail 'false'
TK1R.new k1r
k1o=""
for m in r7 rbare fret empty lastfail; do RESULT=outer; k1r.$m >/dev/null; k1o+="$m:$?:$RESULT "; done
RESULT=outer; k1r.call r7; k1o+="call:$?:$RESULT"
check "K1.2" "r7:7:outer rbare:1:outer fret:4:got empty:0:outer lastfail:1:outer call:7:outer" "$k1o"

kt_test_start "K1.3 local / declare / unset of a bound name in a body keeps its pre-K1 meaning (binds and body share one scope)"
defineClass TK1L "" property Count static_property S \
    method peek 'K1_PEEK="Count=${Count-U}"' \
    method run 'eval "$1"; K1_IN="Count=${Count-U} S=${S-U} st=${state[Count]-U} gS=${TK1L_static_S-U} this=${this-U}"; $this.peek' \
    method lone 'local Count=5; Count=6; K1_IN=$Count'
TK1L.new k1l
k1o=""
for st in 'local Count=5' 'local Count' 'local -a Count' 'unset Count' 'local S=5' 'local S' 'local this=zz' 'Count=4' 'S=4'; do
    k1l.Count = 1; TK1L.S = 1; K1_PEEK=""
    k1l.run "$st" 2>/dev/null
    k1o+="[$st] $K1_IN $K1_PEEK after=${k1l_data[Count]-U}/$TK1L_static_S"$'\n'
done
k1l.Count = 1; k1l.lone
k1o+="lone: in=$K1_IN after=${k1l_data[Count]}"
check "K1.3" "[local Count=5] Count=5 S=1 st=1 gS=1 this=k1l Count=5 after=1/1
[local Count] Count=U S=1 st=1 gS=1 this=k1l Count=U after=1/1
[local -a Count] Count=U S=1 st=1 gS=1 this=k1l Count=U after=1/1
[unset Count] Count=U S=1 st=U gS=1 this=k1l Count=U after=U/1
[local S=5] Count=1 S=5 st=1 gS=5 this=k1l Count=1 after=1/1
[local S] Count=1 S=U st=1 gS=U this=k1l Count=1 after=1/1
[local this=zz] Count=1 S=1 st=1 gS=1 this=zz  after=1/1
[Count=4] Count=4 S=1 st=4 gS=1 this=k1l Count=4 after=4/1
[S=4] Count=1 S=4 st=1 gS=4 this=k1l Count=1 after=1/4
lone: in=6 after=1" "$k1o"

kt_test_start "K1.4 set -a: the body runs with the caller's allexport (a bare assignment reaches a child), the binds never do; allexport stays on after the call"
defineClass TK1A "" property P method exp 'K1_X=1; command env | command grep -cE "^(K1_X|P)="'
TK1A.new k1a; k1a.P = pv
k1o=$( set -a; k1a.exp; [[ $- == *a* ]] && echo on; set +a; unset K1_X; k1a.exp )
check "K1.4" "1|on|0" "${k1o//$'\n'/|}"

kt_test_start "K1.5 set -e stops in the body; set -u callers; ERR (set -E) fires once for a failing body command; with set -T a RETURN trap sees the body function's return too (K3: wrapper, dispatcher, body function = 3)"
defineClass TK1E "" method boom 'false; echo after' method r 'return 0'
TK1E.new k1e
k1o=$( ( set -eu; k1e.boom; echo survived ); echo "rc=$?"
       ( set -E; n=0; trap 'n=$((n+1))' ERR; k1e.boom >/dev/null; echo "err=$n" )
       ( set -T; n=0; trap 'n=$((n+1))' RETURN; k1e.r; trap - RETURN; echo "ret=$n" ) )
check "K1.5" "rc=1|err=1|ret=3" "${k1o//$'\n'/|}"

kt_test_start "K1.6 heredoc bodies; a body that does not parse — also one with an unmatched } — falls back to the eval of its text at every call (rc 2, nothing of it run at build; a MATCHED } … { early close is not detected, see the book)"
defineClass TK1H "" method h 'cat <<EOF
one $1
EOF' method h2 'cat <<-"EOT"
	raw $x
	EOT' method bad 'if true; then echo x' method brace "echo a; }; echo BUILD >> '$K1T/k1build'" method bs 'echo a \'
TK1H.new k1h
k1o="$(k1h.h arg)|$(k1h.h2)|bs=$(k1h.bs)"
k1b=$( k1h.bad 2>&1 ); k1o+="|bad=$?"
[[ -e "$K1T/k1build" ]] && k1o+="|RAN-AT-BUILD"
k1b=$( k1h.brace 2>&1 ); k1o+="|brace=$?"
[[ -e "$K1T/k1build" ]] && k1o+="|RAN-AT-CALL"
check "K1.6" "one arg|raw \$x|bs=a \\|bad=2|brace=2" "$k1o"

kt_test_start "K1.7 defineMethod (re)defines the function; overrides and inherited run per owner"
defineClass TK1B "" method who 'echo base' method say '$this.who'
defineClass TK1S TK1B method who 'echo -n "sub+"; inherited who'
TK1S.new k1s
k1o="$(k1s.say)|$(k1s.call who)"
defineMethod TK1S who 'echo redefined' 2>/dev/null
defineMethod TK1B added 'echo "added:$1"'
TK1B.new k1b
k1o+="|$(k1s.who)|$(k1b.call added zz)|$(declare -F __kkm.TK1B.added)"
check "K1.7" "sub+base|sub+base|redefined|added:zz|__kkm.TK1B.added" "$k1o"

kt_test_start "K1.8 a rebuild (kk.class --forget): the functions follow the variables — a method now inherited runs the inherited text on an older instance, a dropped constructor loses its function"
defineClass TK1RP "" method m 'echo parent-m'
defineClass TK1RC TK1RP method m 'echo own-m' constructor ':'
TK1RC.new k1old
kk.class --forget TK1RC 2>/dev/null
defineClass TK1RC TK1RP
TK1RC.new k1new
check "K1.8" "parent-m|parent-m|no-ctor" "$(k1old.m)|$(k1new.m)|$(declare -F __kkc.TK1RC || echo no-ctor)"

kt_test_start "K1.9 the call path evals no body text (the trampoline and its callers have no eval)"
check "K1.9" "0" "$(declare -f kk._invoke kk._exec kk._call kk._parent kk._constructor_exec | grep -c 'eval ')"

kt_test_start "K1.10 kk._call / kk._parent with the body variable unset after the cache resolved it: an empty body, rc 0, allexport kept (kk._body_none)"
defineClass TK1G "" method gone 'echo stale'
TK1G.new k1g; k1g.call gone >/dev/null
unset TK1G_method_body_gone
k1o=$( set -a; k1g.call gone; echo "rc=$? a=$([[ $- == *a* ]] && echo on)" )
check "K1.10" "rc=0 a=on" "$k1o"

kt_test_start "K1.11 a Pascal class without a constructor gets its parent's, as a function of its own"
class TK1PP
    public
        property v
        constructor Create
end
TK1PP.Create() { v="made:$1"; }
build TK1PP
class TK1PC : TK1PP
end
build TK1PC
TK1PC.new k1pc w
check "K1.11" "__kkc.TK1PC|made:w" "$(declare -F __kkc.TK1PC)|$(k1pc.v)"

kt_test_start "K1.12 a class without template and body functions (a pre-U2b cache sourced directly) gets both on its first call — own, inherited and overridden bodies and the constructor — also under set -u"
defineClass TK1OP "" property p method base 'echo "base p=$p"' method ov 'echo "pov"'
defineClass TK1OC TK1OP property q method ov 'echo -n "cov q=$q "; inherited ov' constructor 'q=$1'
unset TK1OC_class_binds TK1OP_class_binds
unset -f __kkm.TK1OP.base __kkm.TK1OP.ov __kkm.TK1OC.ov __kkc.TK1OC
k1o=$( set -u; TK1OC.new k1oc Q; k1oc.p = P; k1oc.base; k1oc.ov; declare -F __kkm.TK1OP.base __kkm.TK1OP.ov __kkm.TK1OC.ov __kkc.TK1OC | tr '\n' ' ' )
check "K1.12" "base p=P|cov q=Q pov|__kkm.TK1OP.base __kkm.TK1OP.ov __kkm.TK1OC.ov __kkc.TK1OC " "${k1o//$'\n'/|}"

kt_test_start "K1.13 a compiled cache (format 6) dumps the body texts, not the functions, and makes the functions again when it loads (kk._body_fns_for); it runs in a fresh shell; a format-5 cache is refused"
cat > "$K1T/k1.kk" <<'EOF'
defineClass CK1P "" property a method show 'echo "a=$a"' method ov 'echo -n "p "'
defineClass CK1C CK1P property b method ov 'echo -n "c "; inherited ov; echo "b=$b"' constructor 'b=$1'
EOF
( cd "$K1T" && bash "$KKLASS_DIR/kklass_compiler.sh" k1.kk k1.ckk.sh >/dev/null 2>"$K1T/k1.err" ); k1rc=$?
check "K1.13 compile" "0|" "$k1rc|$(<"$K1T/k1.err")"
check "K1.13 header" "kk._ckk_format 6" "$(grep '^kk._ckk_format ' "$K1T/k1.ckk.sh")"
check "K1.13 dump" "0|kk._body_fns_for CK1C|kk._body_fns_for CK1P|" \
    "$(grep -cE '^__kk[mc]\.' "$K1T/k1.ckk.sh")|$(grep '^kk._body_fns_for ' "$K1T/k1.ckk.sh" | tr '\n' '|')"
k1o=$(cd "$K1T" && bash -c 'set -u; source ./k1.ckk.sh; CK1C.new o B; o.a = A; o.show; o.ov' 2>&1)
check "K1.13 load" "a=A|c p b=B" "${k1o//$'\n'/|}"
sed -e 's/^kk._ckk_format 6$/kk._ckk_format 5/' "$K1T/k1.ckk.sh" > "$K1T/k1old.ckk.sh"
k1o=$(cd "$K1T" && bash -c 'source ./k1old.ckk.sh; echo "rc=$?"; declare -F CK1C.new >/dev/null && echo loaded' 2>&1)
check "K1.13 format 5 refused" "1|rc=1" "$(grep -c 'has cache format 5, this kklass reads format 6 (.*format 6: method bodies as functions)' <<<"$k1o")|$(grep -v '^kklass:' <<<"$k1o" | tr '\n' '|' | sed 's/|$//')"

kt_test_start "K1.14 a class declared again from another file is refused (Duplicate identifier) and leaves the original's body functions alone"
printf '%s\n' "defineClass TK1Dup \"\" method m 'echo first' constructor 'K1_CT=first'" > "$K1T/dupa.sh"
printf '%s\n' "defineClass TK1Dup \"\" method m 'echo second' constructor 'K1_CT=second'" > "$K1T/dupb.sh"
source "$K1T/dupa.sh"
source "$K1T/dupb.sh" 2>/dev/null; k1rc=$?
TK1Dup.new k1dup
check "K1.14" "1|first|first" "$k1rc|$(k1dup.m)|$K1_CT"

kt_test_start "K1.15 __kkm and __kkc are kklass's declared namespaces: no class and no instance of that name"
k1o=""
defineClass __kkm "" property a 2>/dev/null; k1o+="class=$? "
TK1R.new __kkc 2>/dev/null; k1o+="inst=$? "
k1o+="owner=${__KK_NAMESPACES[__kkm]%%$__KK_SEP*}/${__KK_NAMESPACES[__kkc]%%$__KK_SEP*} taken=${_KKLASS_TAKEN[__kkm]-}"
check "K1.15" "class=1 inst=1 owner=kklass/kklass taken=ns" "$k1o"

kt_test_start "K1.16 a cache compiled from a source that turns extglob on loads whole in a shell with extglob off (every class); the extglob body fails only when called (rc 2, as before K1) and matches once extglob is on"
mkdir -p "$K1T/ext"
cat > "$K1T/ext/e.kk" <<'EOF'
shopt -s extglob
defineClass CK1E "" method m 'case $1 in @(a|b)) echo match;; *) echo nomatch;; esac' method ok 'echo ok'
defineClass CK1F "" method f 'echo f'
EOF
( cd "$K1T/ext" && bash "$KKLASS_DIR/kklass_compiler.sh" e.kk e.ckk.sh >/dev/null 2>"$K1T/ext/e.err" ); k1rc=$?
k1o=$(cd "$K1T/ext" && bash -c 'shopt -u extglob; source ./e.ckk.sh; echo "src=$?"; CK1E.new o; o.ok; CK1F.new g; g.f; o.m a >/dev/null 2>&1; echo "m=$?"; shopt -s extglob; o.m a' 2>&1)
check "K1.16" "0|src=0|ok|f|m=2|match" "$k1rc|${k1o//$'\n'/|}"

kt_test_start "K1.17 a parent from a pre-U2b cache (tables, no template, no body functions) and a child built from source: the child's build repairs the parent (kk._body_fns_old) — inherited body, .call and the parent's constructor body via the child"
defineClass TK1OldP "" property p method base 'echo "base p=$p"' constructor 'p=$1'
unset TK1OldP_class_binds
unset -f __kkm.TK1OldP.base __kkc.TK1OldP
defineClass TK1OldC TK1OldP property q method own 'echo "own q=$q"'
TK1OldP.new k1op PP
TK1OldC.new k1oc; k1oc.p = P
check "K1.17" "base p=P|base p=P|base p=PP|state=@_data p=@_data[p]" "$(k1oc.base)|$(k1oc.call base)|$(k1op.base)|${TK1OldP_class_binds[*]}"

kt_test_start "K1.18 a body with >&\"\$fd\" through a compiled cache writes to the descriptor (the body text, not a declare -f print of it, is what the cache holds: bash 5.1 prints >&\"\$fd\" as &> \"\$fd\")"
mkdir -p "$K1T/fd"
cat > "$K1T/fd/w.kk" <<'EOF'
defineClass CK1W "" method w 'local fd=$1; printf x >&"$fd"'
EOF
( cd "$K1T/fd" && bash "$KKLASS_DIR/kklass_compiler.sh" w.kk w.ckk.sh >/dev/null 2>&1 )
k1o=$(cd "$K1T/fd" && bash -c 'source ./w.ckk.sh; CK1W.new o; exec {f}>out.txt; o.w "$f"; exec {f}>&-; printf "%s|" "$(<out.txt)"; ls' 2>&1)
check "K1.18" "x|out.txt w.ckk.sh w.kk" "${k1o//$'\n'/ }"


# ---------------------------------------------------------------------------
# K3: the call path is the wrapper -> ONE dispatcher (kk._exec for obj.M and
# $this.M, kk._parent for inherited, kk._invoke for .call and constructors)
# -> the body function. kk._run_frame_body is gone; the dispatchers carry THE
# CORE inline (isolation shadow, frame, localvar_unset, RESULT protocol) and
# the rare branches (errors, a parent-cache miss, a class without template)
# are helpers. What the restructuring must not change is pinned here, on
# every dispatcher.
K3T="$(cd "$(kt_fixture_tmpdir)" && pwd)"

kt_test_start "K3.1 THE CORE is the same text in kk._invoke, kk._exec and kk._parent (ACTIVE and the body-function call normalized)"
k3core() {   # FUNCTION FNCALL-TEXT ACTIVE-TOKEN...
    local f=$1 call=$2 line out="" on=0 tok
    shift 2
    while IFS= read -r line; do
        [[ $line == *'[[ -R __kk_props'* ]] && on=1
        (( on )) || continue
        [[ $line == *"$call"* ]] && line=FNCALL
        for tok in "$@"; do line=${line//"$tok"/ACTIVE}; done
        out+="$line"$'\n'
    done < <(declare -f "$f")
    printf '%s' "$out"
}
k3i=$(k3core kk._invoke '"$3" "${@:4}"' '$2')
k3e=$(k3core kk._exec '"__kkm.$3.$2" "${@:4}"' '$3')
k3p=$(k3core kk._parent '"$__kk_fn" "${@:3}"' '${__kk_ac}' '$__kk_ac')
k3n=$(grep -c . <<<"$k3i")
if [[ -n $k3i && $k3i == "$k3e" && $k3i == "$k3p" && $k3n -ge 14 ]]; then
    kt_test_pass "K3.1 ($k3n lines)"
else
    kt_test_fail "K3.1: the copies differ: $(diff <(echo "$k3i") <(echo "$k3e") | head -5) | $(diff <(echo "$k3i") <(echo "$k3p") | head -5)"
fi
check "K3.1 no trampoline" "none" "$(declare -F kk._run_frame_body || echo none)"
check "K3.1 one dispatcher per call" "0" "$(declare -f kk._exec kk._parent | grep -c -E '^ +kk[.]_(invoke|exec|call|parent) ')"

defineClass TK3P "" property v \
    method pset 'RESULT=fromP' \
    function pget 'RESULT=pval' \
    method rc 'return "$1"' \
    method lvu 'shopt -q localvar_unset && K3_LVU+=on, || K3_LVU+=off,' \
    method lvuoff 'shopt -u localvar_unset; $this.lvu' \
    method env 'echo "a=$([[ $- == *a* ]] && echo on || echo off) leak=$(command env | command grep -c -E "^(__kk_|this=|__inst__=|__class__=|v=)")"' \
    method who 'echo "f1=${FUNCNAME[1]}"' \
    method depth 'echo "d=${#__KLIB_FRAME_STACK[@]}"' \
    method nest 'RESULT=keep; $this.pset; K3_A=$RESULT; RESULT=keep; $this.pget >/dev/null; K3_B=$RESULT; RESULT=keep; $this.call pset; K3_C=$RESULT; RESULT=keep; $this.call pget >/dev/null; K3_D=$RESULT; RESULT=keep; $this.rc 6; K3_R=$?; $this.depth; $this.rc 0; RESULT=$K3_R' \
    constructor 'K3_CTOR="f1=${FUNCNAME[1]} d=${#__KLIB_FRAME_STACK[@]}"'
defineClass TK3C TK3P \
    method pset 'RESULT=fromC; $this.parent pset; K3_E=$RESULT' \
    function pget '$this.parent pget; RESULT="c+$RESULT"' \
    method rc '$this.parent rc "$1"; return $(( $? + 1 ))' \
    method who '$this.parent who' \
    method lvu '$this.parent lvu' \
    method env '$this.parent env'
TK3P.new k3p
TK3C.new k3c

kt_test_start "K3.2 RESULT protocol across nesting on every dispatcher: a proc restores the caller's RESULT, a func passes its value, also through inherited and .call; the outer caller's RESULT survives"
K3_A= K3_B= K3_C= K3_D= K3_E=
RESULT=outer; k3c.nest >/dev/null
k3o="A=$K3_A B=$K3_B C=$K3_C D=$K3_D E=$K3_E outer=$RESULT"
RESULT=outer; k3c.pget; k3o+=" pget=$RESULT"
RESULT=outer; k3c.call pget; k3o+=" call=$RESULT"
RESULT=outer; kk._parent k3c pget; k3o+=" parent=$RESULT"
check "K3.2" "A=keep B=c+pval C=keep D=c+pval E=fromC outer=outer pget=c+pval call=c+pval parent=pval" "$k3o"
check "K3.2 capture prints once (inherited is silent)" "c+pval|" "$(k3c.pget)|$(kk._parent k3c pget)"

kt_test_start "K3.3 return N comes back through kk._exec, kk._parent and kk._invoke (.call)"
k3o=""
k3p.rc 7; k3o+="exec=$? "
k3c.rc 4; k3o+="parent=$? "
k3p.call rc 9; k3o+="call=$? "
k3c.call rc 2; k3o+="call+parent=$?"
check "K3.3" "exec=7 parent=5 call=9 call+parent=3" "$k3o"

kt_test_start "K3.4 set -a callers: the body runs with allexport, its children see none of the frame's locals, allexport is back on after every dispatcher and every error exit"
k3o=$( set -a
    k3p.env; k3c.env; k3p.call env
    kk._exec k3p nosuch TK3P 2>/dev/null; echo "nf=$? ${-//[^a]/}"
    k3p.call nosuch 2>/dev/null; echo "cnf=$? ${-//[^a]/}"
    kk._parent k3p pset 2>/dev/null; echo "np=$? ${-//[^a]/}"
    kk._parent k3c nosuch 2>/dev/null; echo "pnf=$? ${-//[^a]/}" )
check "K3.4" "a=on leak=0|a=on leak=0|a=on leak=0|nf=1 a|cnf=1 a|np=1 a|pnf=1 a" "${k3o//$'\n'/|}"
k3o=$( k3p.env; kk._exec k3p nosuch TK3P 2>/dev/null; echo "after=${-//[^a]/}" )
check "K3.4 off stays off" "a=off leak=0|after=" "${k3o//$'\n'/|}"

kt_test_start "K3.5 set -u callers: calls without arguments and every not-found exit run without an unbound-variable error"
k3o=$( { set -u; RESULT=outer
    k3c.nest >/dev/null; k3c.pget >/dev/null; echo "r=$RESULT"; k3c.call pget >/dev/null; kk._parent k3c pget; echo "r=$RESULT"
    kk._exec k3p nosuch TK3P; kk._parent k3p pset; kk._parent k3c nosuch; k3p.call nosuch
    echo "end"; } 2>&1 )
check "K3.5" "r=c+pval|r=pval|Error: Method 'nosuch' not found in class 'TK3P'|Error: No parent class for 'TK3P'|Error: Parent method 'nosuch' not found|Error: Method 'nosuch' not found in class hierarchy|end" "${k3o//$'\n'/|}"

kt_test_start "K3.6 set -e callers: a failing status stops the caller with that status; a missing method stops it with rc 1; the frame stack is empty afterwards (subshell) and in the caller"
k3o=""
( set -e; k3p.rc 3; echo survived ); k3o+="exec=$? "
( set -e; k3c.rc 3; echo survived ); k3o+="parent=$? "
( set -e; k3p.call rc 5; echo survived ); k3o+="call=$? "
( set -e; kk._exec k3p nosuch TK3P 2>/dev/null; echo survived ); k3o+="nf=$? "
( set -e; kk._parent k3c nosuch 2>/dev/null; echo survived ); k3o+="pnf=$? "
k3o+="err=[$( set -e; kk._parent k3c nosuch 2>&1 )] "
k3o+="frames=${#__KLIB_FRAME_STACK[@]}/${#__KLIB_FRAME_INSTANCE[@]}/${#__KLIB_FRAME_CLASS[@]}"
check "K3.6" "exec=3 parent=3 call=5 nf=1 pnf=1 err=[] frames=0/0/0" "$k3o"

kt_test_start "K3.7 frame depth: one frame per running body (inherited and .call included), back to the caller's depth after a failing nested call and after every error exit"
k3o="$(k3p.depth)|$(k3c.nest)"
k3p.rc 1; kk._exec k3p nosuch TK3P 2>/dev/null; k3p.call nosuch 2>/dev/null; kk._parent k3c nosuch 2>/dev/null; kk._parent k3p x 2>/dev/null
k3o+="|${#__KLIB_FRAME_STACK[@]}/${#__KLIB_FRAME_INSTANCE[@]}/${#__KLIB_FRAME_CLASS[@]}"
check "K3.7" "d=1|d=2|0/0/0" "$k3o"

kt_test_start "K3.8 the outermost call turns localvar_unset on for the body and restores the caller's setting (off -> off, on -> on, owner flag clear), also when the body turns it off, and through inherited and .call"
k3o=$( shopt -u localvar_unset
    K3_LVU=; k3p.lvu; k3c.lvu; k3p.call lvu; echo "in=$K3_LVU after=$(shopt -q localvar_unset && echo on || echo off) own=[${__KK_LVU_OWN-}]"
    K3_LVU=; k3p.lvuoff; echo "bodyoff=$K3_LVU after=$(shopt -q localvar_unset && echo on || echo off)"
    kk._exec k3p nosuch TK3P 2>/dev/null; echo "nf=$(shopt -q localvar_unset && echo on || echo off)"
    shopt -s localvar_unset
    K3_LVU=; k3p.lvu; k3c.lvu; echo "in=$K3_LVU after=$(shopt -q localvar_unset && echo on || echo off) own=[${__KK_LVU_OWN-}]" )
check "K3.8" "in=on,on,on, after=off own=[]|bodyoff=off, after=off|nf=off|in=on,on, after=on own=[]" "${k3o//$'\n'/|}"

kt_test_start "K3.9 FUNCNAME[1] of a body is its dispatcher: kk._exec, kk._parent (inherited), kk._invoke (.call, constructor)"
K3_CTOR=; TK3P.new k3p2
check "K3.9" "f1=kk._exec|f1=kk._parent|f1=kk._invoke|f1=kk._invoke d=1" "$(k3p.who)|$(k3c.who)|$(k3p.call who)|$K3_CTOR"

kt_test_start "K3.10 scope isolation on every dispatcher: a callee of another class sees none of the caller's fields (read, unset + assign), through the wrapper, .call and an inherited body"
defineClass TK3IA "" property a method peek 'K3_SEEN+="s=${secret-unset}${ssec+LEAK} "' method poke 'unset secret; secret=x; K3_SEEN+="p=$secret "'
defineClass TK3IB TK3IA method peek2 '$this.parent peek; $this.parent poke'
defineClass TK3IH "" property secret static_property ssec \
    method run 'K3_SEEN=; $1.peek; $1.call peek; $1.peek2; $1.poke; $1.call poke; K3_SEEN+="own=$secret/${ssec-}"'
TK3IB.new k3ib; TK3IH.new k3ih; k3ih.secret = S; TK3IH.ssec = SS
k3ih.run k3ib
check "K3.10" "s=unset s=unset s=unset p=x p=x p=x own=S/SS" "$K3_SEEN"

kt_test_start "K3.11 visibility warnings on every dispatcher: protected via .call from outside, private of the parent via inherited; protected from a subclass body is silent"
class TK3V
    public
        proc Pub
    protected
        proc Sec
    private
        proc Priv
end
TK3V.Pub() { :; }
TK3V.Sec() { :; }
TK3V.Priv() { :; }
build TK3V
class TK3W : TK3V
    public
        proc UseSec
end
TK3W.UseSec() { $this.Sec; $this.parent Priv; }
build TK3W
TK3W.new k3w
k3o="$( { k3w.UseSec; k3w.call Sec; } 2>&1 )"
check "K3.11" "[kk] warning: private method 'TK3V.Priv' accessed from 'TK3W'|[kk] warning: protected method 'TK3V.Sec' accessed from 'external'" "${k3o//$'\n'/|}"

kt_test_start "K3.12 a method called from a DEBUG trap (set -T) between the outermost call's localvar_unset toggle and its frame push leaves the option on for the outer body: unset isolation holds on obj.m, .call, inherited (K3 critic)"
defineClass TK3Log "" method tick ':'
defineClass TK3Callee "" method poke 'unset y; y=CLOBBERED'
defineClass TK3Car "" property y method run 'k3callee.poke; echo "y=[$y]"'
defineClass TK3CarC TK3Car method run 'inherited run'
TK3Log.new k3log; TK3Callee.new k3callee; TK3Car.new k3car; TK3CarC.new k3carc
k3car.property y = orig; k3carc.property y = orig
k3o=$( shopt -u localvar_unset; set -T; trap 'k3log.tick' DEBUG
       k3car.run; k3car.call run; k3carc.run
       trap - DEBUG; set +T
       echo "lvu=$(shopt -q localvar_unset && echo on || echo off) own=[${__KK_LVU_OWN-}]" )
check "K3.12" "y=[orig]|y=[orig]|y=[orig]|lvu=off own=[]" "${k3o//$'\n'/|}"
check "K3.12 stored" "orig orig" "$(k3car.property y) $(k3carc.property y)"

kt_test_start "K3.13 the dispatchers' return code survives an IFS that contains digits"
defineClass TK3Rc "" method r 'return 17'
TK3Rc.new k3rc
k3o=$( IFS=17; k3rc.r; echo "rc=$?"; k3rc.call r; echo "rc=$?" )
check "K3.13" "rc=17|rc=17" "${k3o//$'\n'/|}"

kt_test_log "150_PerfRoundK.sh completed"
