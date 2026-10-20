#!/usr/bin/env bash
[[ ${__KK_UNITS[@]@a} == A* ]] || source "${BASH_SOURCE%kklass_pascal.sh}../kbool.sh" || return
kk.unit kklass_pascal || return $__kk_unit_rc
# kklass_pascal.sh - Laconic Pascal-style front-end for kklass.
#
# Write the class STRUCTURE first (interface), then the method BODIES as real
# bash functions (real syntax highlighting, real quoting), then `build`.
#
#   class TAnimal
#       public
#           var         Name
#           proc        Speak
#           func        Describe
#           constructor Create
#           destructor  Destroy
#           static var  Count
#           static func GetCount
#       private
#           var         Secret
#   end
#
#   TAnimal.Speak()    { echo "$Name makes a sound"; }
#   TAnimal.Describe() { RESULT="$Name"; }
#   ...
#   build TAnimal
#
# Bodies are extracted from the real functions via `declare -f` and fed to the
# existing kklass runtime unchanged (same mechanism as kk.register_static_methods).
#
# Keywords:
#   class N [: P] ... end        class + optional inheritance
#   public | private | protected visibility sections (repeatable, any order)
#   var X                        stored field (obj.X)
#   property X read G write S     computed property (G/S are declared methods)
#   proc X                       method, no return value
#   func X                       method, returns via RESULT
#   constructor [C]              constructor (default name Create)
#   destructor  [D]              destructor (default name Destroy); runs on .delete
#   static  <var|proc|func>      class member (shared), not per-instance
#   abstract <proc|func>         no body; class cannot be instantiated until overridden
#   override <proc|func>         guard: errors unless an ancestor has the method
#   build N                      extract bodies + finalize the class
#   uses A B ...                 load units once (= kk.uses; kbool.sh must be loaded)
#
# A unit (uses U3): the two header lines above; kklass comes through kk.uses.

kk.uses kklass || return

# Per-declaration modifier flags (consumed by the next var/proc/func).
declare -g __KK_PASCAL_STATIC=""
declare -g __KK_PASCAL_OVERRIDE=""

# ---- class header / footer -------------------------------------------------

class() {
    [[ a == A && $BASHOPTS == *nocasematch* ]] && { kk.decl._ncm_off class "$@"; return; }   # exact names (K3)
    local name="$1" parent=""
    if [[ "${2:-}" == ":" ]]; then
        parent="$3"          # class TDog : TAnimal
    else
        parent="${2:-}"     # class TDog TAnimal  (positional, also allowed)
    fi

    declareClass "$name" "$parent" || return 1
    # the same site again (uses U20): the class is not rebuilt, nothing is reset
    [[ ${__KK_SINK_OPEN-} != "$name" ]] || return 0
    eval "declare -ga ${name}__pascal_overrides=()"
    eval "${name}_decl_destructor_name=''"
    __KK_PASCAL_STATIC=""
    __KK_PASCAL_OVERRIDE=""
}

end() {
    [[ a == A && $BASHOPTS == *nocasematch* ]] && { kk.decl._ncm_off end "$@"; return; }   # exact names (K3)
    [[ -z "$KK_DECL_CURRENT_CLASS" ]] || kk.pascal._check_ctor_static "$KK_DECL_CURRENT_CLASS"
    endClass
}

# P11/M1 (DR9): in this DSL the function CLASS.<ctor> (default name Create) is
# the constructor body that build extracts — so a STATIC member of the same
# name (static proc/func/var) cannot coexist with it: the static used to
# consume the one function and the constructor body was silently empty.
# Checked at `end`, where both are known whatever the order; a clash poisons
# the class (endClass then fails it).
kk.pascal._check_ctor_static() {   # CLASS
    local cls="$1"
    local ctor_var="${cls}_decl_constructor_name"
    local ctor="${!ctor_var:-}"
    [[ -n "$ctor" ]] || return 0
    local clash=0
    if declare -p "${cls}_decl_method_static" &>/dev/null; then
        local -n __kk_pc_static="${cls}_decl_method_static"
        [[ "${__kk_pc_static[$ctor]:-0}" == 1 ]] && clash=1
    fi
    if (( ! clash )) && kk.decl._array_contains "${cls}_decl_static_properties" "$ctor"; then
        clash=1
    fi
    if (( clash )); then
        kk.decl._error "Static member '${ctor}' of class '${cls}' has the constructor's name: ${cls}.${ctor} is the constructor body in the Pascal DSL (rename the static member or use 'constructor OtherName')"
        kk.decl._poison "$ctor"
    fi
    return 0
}

# ---- visibility sections (repeatable, any order) ---------------------------

public()    { [[ a == A && $BASHOPTS == *nocasematch* ]] && { kk.decl._ncm_off public "$@"; return; }; publicSection; }
private()   { [[ a == A && $BASHOPTS == *nocasematch* ]] && { kk.decl._ncm_off private "$@"; return; }; privateSection; }
protected() { [[ a == A && $BASHOPTS == *nocasematch* ]] && { kk.decl._ncm_off protected "$@"; return; }; protectedSection; }

# ---- modifiers (prefix form: `static proc X`, `override func Y`) ------------

# In a sink (uses U20/U21, kklass_decl.sh) a modifier only passes the member
# verb on, which the sink swallows — no flag is left behind for the next class.
static()   { [[ a == A && $BASHOPTS == *nocasematch* ]] && { kk.decl._ncm_off static "$@"; return; }; [[ -z ${__KK_SINK_OPEN-} ]] || ! kk.decl._sunk || { "$@"; return; }; __KK_PASCAL_STATIC=1; "$@"; }
override() { [[ a == A && $BASHOPTS == *nocasematch* ]] && { kk.decl._ncm_off override "$@"; return; }; [[ -z ${__KK_SINK_OPEN-} ]] || ! kk.decl._sunk || { "$@"; return; }; __KK_PASCAL_OVERRIDE=1; "$@"; }
abstract() { [[ a == A && $BASHOPTS == *nocasematch* ]] && { kk.decl._ncm_off abstract "$@"; return; }; [[ -z ${__KK_SINK_OPEN-} ]] || ! kk.decl._sunk || { "$@"; return; }; kk.decl._push_next_modifier "abstract"; "$@"; }

# ---- members ---------------------------------------------------------------

var() {
    [[ a == A && $BASHOPTS == *nocasematch* ]] && { kk.decl._ncm_off var "$@"; return; }   # exact names (K3)
    if [[ -n "$__KK_PASCAL_STATIC" ]]; then
        __KK_PASCAL_STATIC=""
        classVar "$1"
    else
        field "$1"
    fi
}

# `property X read G write S` — reuse the declarative property verb verbatim.
# (Its getter/setter targets must be declared as methods with bodies.)

proc() { [[ a == A && $BASHOPTS == *nocasematch* ]] && { kk.decl._ncm_off proc "$@"; return; }; kk.pascal._declare_method "procedure" "$1"; }
func() { [[ a == A && $BASHOPTS == *nocasematch* ]] && { kk.decl._ncm_off func "$@"; return; }; kk.pascal._declare_method "function"  "$1"; }

kk.pascal._declare_method() {
    local kind="$1" name="$2"
    [[ -z ${__KK_SINK_OPEN-} ]] || ! kk.decl._sunk "$name" || return $__kk_sr
    if [[ -n "$__KK_PASCAL_STATIC" ]]; then
        __KK_PASCAL_STATIC=""
        kind="class_${kind}"          # class_procedure | class_function
    fi
    local is_override="$__KK_PASCAL_OVERRIDE"
    __KK_PASCAL_OVERRIDE=""

    # Call the declarative core directly (not the `func`/`proc` public verbs) to
    # avoid recursing into our own shadowing definitions.
    kk.decl._declare_method "$kind" "$name" || return 1

    if [[ -n "$is_override" ]]; then
        local class="$KK_DECL_CURRENT_CLASS"
        eval "${class}__pascal_overrides+=(\"$name\")"
    fi
}

# constructor / destructor

# `constructor [Name]` — reuse the declarative verb (records the constructor name).

destructor() {
    [[ a == A && $BASHOPTS == *nocasematch* ]] && { kk.decl._ncm_off destructor "$@"; return; }   # exact names (K3)
    local name="${1:-Destroy}"
    [[ -z ${__KK_SINK_OPEN-} ]] || ! kk.decl._sunk "$name" || return $__kk_sr
    kk.decl._require_current_class || return 1
    local class_name="$RESULT"
    # P11 review R2: validate BEFORE the eval below (`destructor '$(cmd)'` used
    # to run cmd); same rule as any method name; a refusal poisons the class.
    if ! kk.decl._validate_member "$name" "destructor name"; then
        kk.decl._poison "$name"
        return 1
    fi
    eval "${class_name}_decl_destructor_name=\"$name\""
    # A destructor is just a normal (parameterless) method that .delete calls.
    procedure "$name"
}

# ---- build: extract bodies from the real functions, then finalize ----------

# Extract the bare body (statements between the braces) of a defined function.
# Round 5 / P14 (K1): the build path forks no `$( )` any more. These three
# helpers return through the CALLER's `local __kk_btxt` (build declares it),
# with every trailing newline stripped exactly as `$( )` stripped it; the
# `declare -f` text itself comes from kk._fn_text (kklass.sh).
kk.pascal._body() {   # FN -> __kk_btxt
    kk._fn_text "$1" __kk_btxt || return 1
    __kk_btxt="${__kk_btxt#*$'\n'}"        # drop the "name ()" line
    __kk_btxt="${__kk_btxt#*$'\n'}"        # drop the "{" line
    __kk_btxt="${__kk_btxt%$'\n'\}}"       # drop the trailing "}"
    while [[ $__kk_btxt == *$'\n' ]]; do __kk_btxt=${__kk_btxt%$'\n'}; done
}

# Turn a BARE `inherited` (Pascal shorthand, no method name) in a method/destructor
# body into `inherited <method>`, which the runtime then rewrites to a parent call.
# Explicit `inherited Method` is left for the existing rewrite. The whitespace guard
# (bare inherited is always preceded by indentation in declare -f output) avoids
# touching things like $inherited. `method` is the enclosing method's name.
kk.pascal._name_bare_inherited() {
    local body="$1" method="$2"
    if [[ $body == *inherited* ]]; then                  # P17 (E5): else nothing to rewrite
        body="${body// inherited;/ inherited ${method};}"
        body="${body//$'\n'inherited;/$'\n'inherited ${method};}"
        body="${body// inherited$'\n'/ inherited ${method}$'\n'}"
        body="${body//$'\n'inherited$'\n'/$'\n'inherited ${method}$'\n'}"
        if [[ "$body" == *[$' \n\t']inherited ]]; then   # bare inherited as last statement
            body="${body%inherited}inherited ${method}"
        fi
    fi
    __kk_btxt=$body                                      # -> __kk_btxt
    while [[ $__kk_btxt == *$'\n' ]]; do __kk_btxt=${__kk_btxt%$'\n'}; done
}

# In a CONSTRUCTOR body, `inherited` / `inherited <Ctor>` means "call the parent
# constructor" (a constructor is not a method), so map it to parent.constructor
# with all current args forwarded.
kk.pascal._ctor_inherited() {
    local body="$1" ctor="$2"
    if [[ $body == *inherited* ]]; then                  # P17 (E5): else nothing to rewrite
        body="${body//inherited ${ctor}/parent.constructor \"\$@\"}"     # explicit form
        body="${body// inherited;/ parent.constructor \"\$@\";}"
        body="${body//$'\n'inherited;/$'\n'parent.constructor \"\$@\";}"
        if [[ "$body" == *[$' \n\t']inherited ]]; then
            body="${body%inherited}parent.constructor \"\$@\""
        fi
    fi
    __kk_btxt=$body                                      # -> __kk_btxt
    while [[ $__kk_btxt == *$'\n' ]]; do __kk_btxt=${__kk_btxt%$'\n'}; done
}

build() {
    [[ a == A && $BASHOPTS == *nocasematch* ]] && { kk.decl._ncm_off build "$@"; return; }   # exact names (K3)
    local class_name="$1"
    [[ -n "$class_name" ]] || { echo "build: class name required" >&2; return 1; }
    kk.decl._validate_ident "$class_name" "class name" || return 1

    # A class in the sink (uses U20/U21): this build ends it — the body
    # functions the re-run defined are dropped and the static API restored.
    if [[ -n ${__KK_SINK-} ]] && kk.decl._sink_mode "$class_name"; then
        local __kk_bs=$__kk_sr
        kk.decl._sink_close "$class_name"
        return "$__kk_bs"
    fi

    # P11/M2 (DR8): the poison flag FIRST — nothing extracted, nothing built.
    local refused_var="${class_name}_decl_refused"
    if [[ -n "${!refused_var:-}" ]]; then
        echo "build: class '${class_name}' is not built: member '${!refused_var}' was refused in its declaration" >&2
        return 1
    fi

    local methods_var="${class_name}_decl_methods"
    local abstract_var="${class_name}_decl_method_abstract"
    declare -p "$methods_var" &>/dev/null || {
        echo "build: '$class_name' was not declared with class ... end" >&2
        return 1
    }
    local -n methods_ref="$methods_var"
    local -n abstract_ref="$abstract_var"
    local m fn body __kk_btxt

    # The write side of the capture pair is held for this loop only (one open
    # per class; released on every way out — P14 review F2).
    kk._fn_text_hold
    # Instance / static / destructor method bodies.
    for m in "${methods_ref[@]}"; do
        if [[ "${abstract_ref[$m]:-0}" == "1" ]]; then
            continue                       # abstract: no body function expected
        fi
        fn="${class_name}.${m}"
        if ! declare -F "$fn" >/dev/null; then
            echo "build: missing implementation function ${fn}()" >&2
            kk._fn_text_release
            return 1
        fi
        kk.pascal._body "$fn"; body=$__kk_btxt
        kk.pascal._name_bare_inherited "$body" "$m"; body=$__kk_btxt
        implement "${class_name}.${m}" "$body" || { kk._fn_text_release; return 1; }
        unset -f "$fn"                      # remove the authoring scratch function
    done

    # Constructor body (declared name, default Create).
    local ctor_var="${class_name}_decl_constructor_name"
    local ctor="${!ctor_var:-}"
    if [[ -n "$ctor" ]] && declare -F "${class_name}.${ctor}" >/dev/null; then
        kk.pascal._body "${class_name}.${ctor}"; body=$__kk_btxt
        kk.pascal._ctor_inherited "$body" "$ctor"; body=$__kk_btxt
        implementConstructor "$class_name" "$body" || { kk._fn_text_release; return 1; }
        unset -f "${class_name}.${ctor}"
    fi
    kk._fn_text_release

    endImplementation "$class_name" || return 1

    # Pascal semantics: a class that declares no constructor inherits its
    # parent's (kklass does not inherit constructors on its own).
    local cbody_var="${class_name}_constructor_body"
    if [[ -z "${!cbody_var:-}" ]]; then
        local cpvar="${class_name}_parent_class"
        local cparent="${!cpvar:-}"
        if [[ -n "$cparent" ]]; then
            local pcbody_var="${cparent}_constructor_body"
            [[ -n "${!pcbody_var:-}" ]] && eval "${class_name}_constructor_body=\${${cparent}_constructor_body}"
        fi
    fi

    # override typo-guard: every `override` must actually replace an ancestor method.
    local ov_var="${class_name}__pascal_overrides"
    if declare -p "$ov_var" &>/dev/null; then
        local -n ov_ref="$ov_var"
        for m in "${ov_ref[@]}"; do
            if ! kk.pascal._ancestor_has_method "$class_name" "$m"; then
                echo "build: override '${class_name}.${m}' overrides nothing (no ancestor defines '$m')" >&2
                return 1
            fi
        done
    fi

    # Register the destructor name for the runtime .delete hook, inheriting the
    # parent's destructor if this class did not declare its own.
    local dtor_decl_var="${class_name}_decl_destructor_name"
    if [[ -n "${!dtor_decl_var:-}" ]]; then
        eval "${class_name}_destructor_name=\"${!dtor_decl_var:-}\""
    else
        local pvar="${class_name}_parent_class"
        local parent="${!pvar:-}"
        if [[ -n "$parent" ]]; then
            local pdtor_var="${parent}_destructor_name"
            # A plain `[[ -n ]] && eval` here would leak status 1 out of build
            # when the parent has NO destructor (child of a destructor-less
            # parent) — build must succeed in that case, hence the full `if`.
            if [[ -n "${!pdtor_var:-}" ]]; then
                eval "${class_name}_destructor_name=\"${!pdtor_var:-}\""
            fi
        fi
    fi

    return 0
}

# ---- uses (Pascal `uses A, B;`, USES_PLAN.md U32) ---------------------------

# `uses A B ...` — the Pascal-DSL synonym of kkore's `kk.uses A B ...` (load
# units once: a NAME is looked up from the calling file's folder, then the
# project and system paths; a PATH is relative to the calling file). Only
# meaningful when kbool.sh is loaded in this shell (a unit's header loads it);
# otherwise rc 2 with a message. It calls kk.uses' body with the CALLER's file
# (a plain `kk.uses "$@"` here would resolve names from kklass_pascal.sh's
# folder); the frames below it are kk.uses' own, so kk.uses' cycle and
# incomplete-unit checks see the same stack.
uses() {
    if [[ ${__KK_LOADED[@]@a} != A ]] || ! declare -F kk._uses >/dev/null; then
        echo "uses: kbool.sh is not loaded in this shell (uses = kk.uses; source kbool.sh first, or start the file with a unit header)" >&2
        return 2
    fi
    kk._uses "${BASH_SOURCE[1]-}" "$@"
}

kk.pascal._ancestor_has_method() {
    local class="$1" method="$2"
    local pvar="${class}_parent_class"
    local parent="${!pvar:-}"
    while [[ -n "$parent" ]]; do
        local bvar="${parent}_method_body_${method}"
        [[ -n "${!bvar:-}" ]] && return 0
        pvar="${parent}_parent_class"
        parent="${!pvar:-}"
    done
    return 1
}
