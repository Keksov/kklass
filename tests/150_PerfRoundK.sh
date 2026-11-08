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
check "K1.1 frames" "f0=__kkm.TK1P.who f1=kk._run_frame_body f2=kk._invoke" "$(k1c.who)"
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

kt_test_start "K1.5 set -e stops in the body; set -u callers; ERR (set -E) fires once for a failing body command; with set -T a RETURN trap sees the body function's return too (one more than before K1)"
defineClass TK1E "" method boom 'false; echo after' method r 'return 0'
TK1E.new k1e
k1o=$( ( set -eu; k1e.boom; echo survived ); echo "rc=$?"
       ( set -E; n=0; trap 'n=$((n+1))' ERR; k1e.boom >/dev/null; echo "err=$n" )
       ( set -T; n=0; trap 'n=$((n+1))' RETURN; k1e.r; trap - RETURN; echo "ret=$n" ) )
check "K1.5" "rc=1|err=1|ret=5" "${k1o//$'\n'/|}"

kt_test_start "K1.6 heredoc bodies; a body that does not parse falls back to the eval of its text at every call (rc 2, nothing run at build — not even after a stray })"
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
check "K1.9" "0" "$(declare -f kk._run_frame_body kk._invoke kk._exec kk._call kk._parent kk._constructor_exec | grep -c 'eval ')"

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

kt_test_start "K1.13 a compiled cache holds the body functions (format 6) and runs in a fresh shell; a format-5 cache is refused"
cat > "$K1T/k1.kk" <<'EOF'
defineClass CK1P "" property a method show 'echo "a=$a"' method ov 'echo -n "p "'
defineClass CK1C CK1P property b method ov 'echo -n "c "; inherited ov; echo "b=$b"' constructor 'b=$1'
EOF
( cd "$K1T" && bash "$KKLASS_DIR/kklass_compiler.sh" k1.kk k1.ckk.sh >/dev/null 2>"$K1T/k1.err" ); k1rc=$?
check "K1.13 compile" "0|" "$k1rc|$(<"$K1T/k1.err")"
check "K1.13 header" "kk._ckk_format 6" "$(grep '^kk._ckk_format ' "$K1T/k1.ckk.sh")"
check "K1.13 dump" "__kkc.CK1C|__kkm.CK1C.ov|__kkm.CK1P.ov|__kkm.CK1P.show|" \
    "$(grep -E '^__kk[mc]\.' "$K1T/k1.ckk.sh" | sed 's/ .*//' | LC_ALL=C sort | tr '\n' '|')"
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

kt_test_log "150_PerfRoundK.sh completed"
