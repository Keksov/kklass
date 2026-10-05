#!/bin/bash

if [[ -n "${_KKLASS_DECL_SOURCED:-}" ]]; then
    return
fi
declare -g _KKLASS_DECL_SOURCED=1

declare -g KK_DECL_CURRENT_CLASS=""
declare -g KK_DECL_CURRENT_VISIBILITY="public"
declare -ga KK_DECL_NEXT_MODIFIERS=()

kk.decl._remember_static_property() {
    local class_name="$1"
    local property_name="$2"
    local static_props_var="${class_name}_decl_static_properties"

    [[ -n "$class_name" && -n "$property_name" ]] || {
        kk.decl._error "static property metadata requires class and property name"
        return 1
    }
    kk.decl._validate_ident "$class_name" "class name" || return 1
    kk.decl._validate_static "$property_name" "static property name" || return 1
    kk.decl._static_clash "$class_name" "$property_name" property || return 1
    kk.decl._prop_clash "$class_name" "$property_name" static || return 1

    kk.decl._append_unique "$static_props_var" "$property_name"
}

kk.decl._remember_static_method() {
    local class_name="$1"
    local method_name="$2"
    local method_body="$3"
    local static_methods_var="${class_name}_decl_static_methods"
    local static_bodies_var="${class_name}_decl_static_method_body"

    [[ -n "$class_name" && -n "$method_name" ]] || {
        kk.decl._error "static method metadata requires class and method name"
        return 1
    }
    kk.decl._validate_ident "$class_name" "class name" || return 1
    kk.decl._validate_static "$method_name" "static method name" || return 1
    kk.decl._static_clash "$class_name" "$method_name" method || return 1

    kk.decl._append_unique "$static_methods_var" "$method_name"
    local -n static_bodies_ref="$static_bodies_var"
    static_bodies_ref["$method_name"]="$method_body"
}

kk.decl._remember_lazy_property() {
    local class_name="$1"
    local property_name="$2"
    local init_method="$3"
    local props_var="${class_name}_decl_properties"
    local vis_var="${class_name}_decl_property_visibility"
    local mode_var="${class_name}_decl_property_mode"
    local lazy_init_var="${class_name}_decl_property_lazy_init"
    local -n vis_ref="$vis_var"
    local -n mode_ref="$mode_var"
    local -n lazy_init_ref="$lazy_init_var"

    [[ -n "$class_name" && -n "$property_name" && -n "$init_method" ]] || {
        kk.decl._error "lazy property metadata requires class, property, and init method"
        return 1
    }
    kk.decl._validate_ident "$class_name" "class name" || return 1
    kk.decl._validate_member "$property_name" "lazy property name" || return 1
    kk.decl._validate_member "$init_method" "lazy init method name" || return 1
    kk.decl._prop_clash "$class_name" "$property_name" instance || return 1

    kk.decl._append_unique "$props_var" "$property_name"
    vis_ref["$property_name"]="$KK_DECL_CURRENT_VISIBILITY"
    mode_ref["$property_name"]="lazy"
    lazy_init_ref["$property_name"]="$init_method"
}

kk.decl._error() {
    echo "$1" >&2
    return 1
}

# Validate that a name is a safe bash identifier before it is interpolated into
# generated code / variable names (defense against code injection via class,
# property or method names). Empty values are allowed here so callers can keep
# their own "required" checks; only non-empty invalid names are rejected.
#
# The reserved sets below (here, in kk.decl._validate_member and in
# kk.decl._validate_static) are case-SENSITIVE, as bash names are: under
# `shopt -s nocasematch` a `case` folds case, and `result`, `ifs`, `reply`,
# `__KK_x`, a method `Delete` or a static `New` used to be refused as if they
# were RESULT, IFS, REPLY, __kk_x, delete, new (round 4 / P12, finding L1/C10,
# decision DR13). So the three validators run with nocasematch OFF and give
# the caller's setting back (kk.decl._ncm_off). The probe `[[ a == A ]]` is true
# only under nocasematch (cheap; $BASHOPTS confirms it).
kk.decl._ncm_off() {   # CMD... — run CMD with nocasematch off, restore it, keep CMD's rc
    shopt -u nocasematch
    "$@"
    local __kk_rc=$?
    shopt -s nocasematch
    return "$__kk_rc"
}

kk.decl._validate_ident() {
    [[ a == A && $BASHOPTS == *nocasematch* ]] && { kk.decl._ncm_off kk.decl._validate_ident "$@"; return; }
    local name="$1"
    local label="${2:-name}"

    # kk._is_ident (kkore/klib.sh since round 4 / P12): locale-exact,
    # BASH_REMATCH untouched.
    if [[ -n "$name" ]] && ! kk._is_ident "$name"; then
        kk.decl._error "Invalid ${label}: '${name}' (must be a valid identifier: letters, digits, underscore; not starting with a digit)"
        return 1
    fi

    # Reserved (decision D2): names a method body sees by contract (this,
    # __inst__, __class__), the result channels (RESULT, REPLY) and IFS. A
    # member with one of these names would shadow it and silently break
    # dispatch or word splitting. `state` is deliberately NOT reserved: the
    # instance-data nameref is shadowed by a property of that name (test 066,
    # a well-defined choice of the class author).
    case "$name" in
        this|__inst__|__class__|RESULT|REPLY|IFS)
            kk.decl._error "Reserved ${label}: '${name}' (this, __inst__, __class__, RESULT, REPLY and IFS are visible inside method bodies by contract and cannot be member names)"
            return 1
            ;;
        __kk_*)
            kk.decl._error "Reserved ${label}: '${name}' (the __kk_ prefix belongs to the kklass runtime's own locals)"
            return 1
            ;;
    esac

    return 0
}

# Validate an INSTANCE member name (method, property, field, lazy property and
# its init method, accessor): everything kk.decl._validate_ident checks, plus
# the names of the per-instance built-ins (round 2 / R2_P8, divergence d). Every
# instance carries the wrapper functions INST.call, INST.delete, INST.property
# and INST.parent; a member of the same name either replaced the built-in or was
# replaced by it — with the old `$this.NAME` text rewrite the two call forms even
# disagreed (`$this.delete` ran the user method, `inst.delete` destroyed the
# instance). `new` is the class's constructor verb (Class.new). Static members
# are class-level (Class.NAME) and are not checked here.
kk.decl._validate_member() {
    [[ a == A && $BASHOPTS == *nocasematch* ]] && { kk.decl._ncm_off kk.decl._validate_member "$@"; return; }
    local name="$1"
    local label="${2:-member name}"

    kk.decl._validate_ident "$name" "$label" || return 1
    case "$name" in
        call|delete|property|parent|new)
            kk.decl._error "Reserved ${label}: '${name}' (call, delete, property and parent are the built-in instance functions inst.call/.delete/.property/.parent and new is the constructor verb Class.new; they cannot be member names)"
            return 1
            ;;
    esac
    return 0
}

# Validate a STATIC member name (round 3 / P11, finding M1, decision DR9): a
# static member is the class-level function CLASS.NAME, so it must not take a
# name kklass itself generates at class level — CLASS.new (constructor verb),
# CLASS.constructor (parent-constructor chaining), CLASS.__decl_new_impl (the
# real constructor behind the abstract-class guard), CLASS.__static_<m> (the
# body of every static method) and the __decl_ prefix (the declarative
# layer's own names). Before P11 such a member was silently lost (rc 0) or
# hijacked .new. Everything kk.decl._validate_ident checks applies as well.
# Instance members are checked by kk.decl._validate_member instead.
kk.decl._validate_static() {
    [[ a == A && $BASHOPTS == *nocasematch* ]] && { kk.decl._ncm_off kk.decl._validate_static "$@"; return; }
    local name="$1"
    local label="${2:-static member name}"

    kk.decl._validate_ident "$name" "$label" || return 1
    case "$name" in
        new|constructor|__decl_new_impl|__static_*|__decl_*)
            kk.decl._error "Reserved ${label}: '${name}' (a static member is the function CLASS.NAME; new, constructor, __decl_new_impl and the __static_* / __decl_* names are generated by kklass for every class and cannot be static member names)"
            return 1
            ;;
        # P11 review R3 — the per-class STORAGE of statics: a static property
        # SP lives in the variable CLASS_static_SP and the body of a static
        # method M in CLASS_static_method_body_M (kk._build_class_runtime; the
        # only CLASS_static_* families). A static property named
        # method_body_M therefore IS static method M's stored body: its
        # initialisation emptied it and a subclass inherited an empty body
        # (syntax error at build, rc 127 on call). Refused for every static
        # (properties and methods alike, one rule).
        method_body_*)
            kk.decl._error "Reserved ${label}: '${name}' (the method_body_ prefix is kklass's storage of static method bodies: CLASS_static_method_body_NAME; a static named method_body_* would overwrite one)"
            return 1
            ;;
    esac
    return 0
}

# kk.decl._static_clash CLASS NAME KIND — KIND is property|method. rc 1 + error
# when NAME is already a static of the OTHER kind in CLASS (declared so far) or
# in its BUILT parent chain: a static property and a static method of the same
# name would both be the function CLASS.NAME, and the method dispatcher used to
# replace the property accessor silently (P11/M1). kk._build_class_runtime
# repeats the check over the merged lists (a parent built later, a raw build).
kk.decl._static_clash() {
    local class_name="$1" name="$2" kind="$3"
    local parent_var="${class_name}_decl_parent"
    local parent="${!parent_var:-}"
    local clash=0

    if [[ "$kind" == property ]]; then
        if kk.decl._array_contains "${class_name}_decl_static_methods" "$name"; then
            clash=1
        elif declare -p "${class_name}_decl_method_static" &>/dev/null; then
            local -n __kk_sc_static="${class_name}_decl_method_static"
            [[ "${__kk_sc_static[$name]:-0}" == 1 ]] && clash=1
        fi
        if (( ! clash )) && [[ -n "$parent" ]] && declare -p "${parent}_class_static_methods" &>/dev/null \
            && kk.decl._array_contains "${parent}_class_static_methods" "$name"; then
            clash=1
        fi
    else
        if kk.decl._array_contains "${class_name}_decl_static_properties" "$name"; then
            clash=1
        elif [[ -n "$parent" ]] && declare -p "${parent}_class_static_properties" &>/dev/null \
            && kk.decl._array_contains "${parent}_class_static_properties" "$name"; then
            clash=1
        fi
    fi

    if (( clash )); then
        kk.decl._error "Static member clash in class '${class_name}': '${name}' is both a static property and a static method (both would be the function ${class_name}.${name})"
        return 1
    fi
    return 0
}

# kk.decl._prop_clash CLASS NAME KIND — KIND is instance|static (the kind of
# property being declared). rc 1 + error when NAME is already a property of
# the OTHER kind in CLASS (declared so far: fields, properties incl. lazy and
# read/write ones / static properties incl. classVar) or in its BUILT parent
# chain (the parent's merged _class_properties / _class_static_properties).
# Round 4 / P12 (finding V1, decision DR10): inside a member body every
# instance property AND every static property is a plain variable name
# (kk._run_frame_body binds the instance namerefs, then the static ones), so
# with both of one name the static HID the instance property — `x=v` in a
# body wrote the static, on every path, own or inherited, either order.
# kk._build_class_runtime repeats the check over the merged lists (a raw
# build, a parent built later). Methods do not collide and are not checked.
kk.decl._prop_clash() {
    local class_name="$1" name="$2" kind="$3"
    local parent_var="${class_name}_decl_parent"
    local parent="${!parent_var:-}"
    local clash=0

    if [[ "$kind" == instance ]]; then
        if kk.decl._array_contains "${class_name}_decl_static_properties" "$name"; then
            clash=1
        elif [[ -n "$parent" ]] && declare -p "${parent}_class_static_properties" &>/dev/null \
            && kk.decl._array_contains "${parent}_class_static_properties" "$name"; then
            clash=1
        fi
    else
        if kk.decl._array_contains "${class_name}_decl_fields" "$name" \
            || kk.decl._array_contains "${class_name}_decl_properties" "$name"; then
            clash=1
        elif [[ -n "$parent" ]] && declare -p "${parent}_class_properties" &>/dev/null \
            && kk.decl._array_contains "${parent}_class_properties" "$name"; then
            clash=1
        fi
    fi

    if (( clash )); then
        kk.decl._prop_clash_error "$class_name" "$name"
        return 1
    fi
    return 0
}

kk.decl._prop_clash_error() {   # CLASS NAME
    kk.decl._error "Instance/static property clash in class '${1}': '${2}' is both an instance property and a static property (inside a member body both are the variable ${2}, and the static one would hide the instance property)"
}

# ---------------------------------------------------------------------------
# The poison flag (round 3 / P11, finding M2, decision DR8). A member refused
# by a declarative verb while its class is OPEN used to print an error and
# nothing else: endClass / endImplementation / Pascal end + build then BUILT
# the class without it, rc 0. Now the refusal marks the open class:
#   ${CLASS}_decl_refused = <the refused member>   (first refusal wins)
# set by the verbs (field, property, procedure/func and their class_ forms,
# classVar, constructor; the Pascal DSL through them), cleared by declareClass.
# endClass then returns 1 naming class + member and CLOSES the class (finalized
# stays 0); endImplementation and Pascal build check the flag FIRST. The flag
# deliberately does NOT live in kk.decl._error: that one is stateless and is
# also reached from non-declarative paths (kk._build_class_runtime,
# defineMethod, …), which must not poison whatever class happens to be open.
kk.decl._poison() {   # MEMBER — mark the open class as refused; always rc 1
    [[ -n "$KK_DECL_CURRENT_CLASS" ]] || return 1
    local __kk_pv="${KK_DECL_CURRENT_CLASS}_decl_refused"
    if [[ -z "${!__kk_pv:-}" ]]; then
        printf -v "$__kk_pv" '%s' "${1:-(unnamed member)}"
    fi
    return 1
}

# The tables declareClass resets. A REdefinition of an already-built class
# snapshots them first (declareClass); if the redefinition is refused
# (poisoned) they are put back, so the old class keeps its decl tables, its
# runtime flag tables and its abstract flag (DR8; before P11 a refused
# redefinition left decl_methods=() and class_abstract=0 behind the intact old
# runtime — an abstract class became instantiable). Indexed arrays, assoc
# arrays and scalars; a name unset at snapshot time is unset again on restore
# (the Pascal DSL adds __pascal_overrides and decl_destructor_name).
declare -ga __KK_DECL_SNAP_ARRAYS=(decl_fields decl_properties decl_methods abstract_methods
    decl_static_properties decl_static_methods _pascal_overrides)
declare -ga __KK_DECL_SNAP_ASSOCS=(decl_property_visibility decl_property_read decl_property_write
    decl_property_mode decl_property_lazy_init decl_field_visibility decl_static_method_body
    decl_method_kind decl_method_visibility decl_method_abstract decl_method_override
    decl_method_virtual decl_method_static decl_method_body
    method_virtual method_override method_abstract method_visibility)
declare -ga __KK_DECL_SNAP_SCALARS=(decl_parent decl_constructor_body decl_constructor_name
    decl_declared decl_finalized class_abstract decl_destructor_name)

kk.decl._snap_copy() {   # FROM_PREFIX TO_PREFIX
    local __kk_f="$1" __kk_t="$2" __kk_n __kk_k
    for __kk_n in "${__KK_DECL_SNAP_ARRAYS[@]}"; do
        unset "${__kk_t}${__kk_n}"
        declare -p "${__kk_f}${__kk_n}" &>/dev/null || continue
        declare -ga "${__kk_t}${__kk_n}"
        local -n __kk_src="${__kk_f}${__kk_n}" __kk_dst="${__kk_t}${__kk_n}"
        __kk_dst=("${__kk_src[@]}")
        unset -n __kk_src __kk_dst
    done
    for __kk_n in "${__KK_DECL_SNAP_ASSOCS[@]}"; do
        unset "${__kk_t}${__kk_n}"
        declare -p "${__kk_f}${__kk_n}" &>/dev/null || continue
        declare -gA "${__kk_t}${__kk_n}"
        local -n __kk_src="${__kk_f}${__kk_n}" __kk_dst="${__kk_t}${__kk_n}"
        for __kk_k in "${!__kk_src[@]}"; do
            __kk_dst["$__kk_k"]="${__kk_src[$__kk_k]}"
        done
        unset -n __kk_src __kk_dst
    done
    for __kk_n in "${__KK_DECL_SNAP_SCALARS[@]}"; do
        unset "${__kk_t}${__kk_n}"
        declare -p "${__kk_f}${__kk_n}" &>/dev/null || continue
        local -n __kk_src="${__kk_f}${__kk_n}"
        printf -v "${__kk_t}${__kk_n}" '%s' "$__kk_src"   # no local of that name: lands global
        unset -n __kk_src
    done
}

kk.decl._snap_drop() {   # CLASS
    local __kk_n
    [[ -n "${__kk_decl_snap_taken[$1]+x}" ]] || return 0
    for __kk_n in "${__KK_DECL_SNAP_ARRAYS[@]}" "${__KK_DECL_SNAP_ASSOCS[@]}" "${__KK_DECL_SNAP_SCALARS[@]}"; do
        unset "__kk_decl_snap_${1}_${__kk_n}"
    done
    unset "__kk_decl_snap_taken[$1]"
}
declare -gA __kk_decl_snap_taken=()

# Close the open class CLASS after a refusal: restore the snapshot of a
# refused REdefinition, keep finalized=0, clear the open-class state.
kk.decl._close_refused() {   # CLASS
    local class_name="$1"
    if [[ -n "${__kk_decl_snap_taken[$class_name]+x}" ]]; then
        kk.decl._snap_copy "__kk_decl_snap_${class_name}_" "${class_name}_"
        kk.decl._snap_drop "$class_name"
    fi
    declare -g "${class_name}_decl_finalized=0"
    KK_DECL_CURRENT_CLASS=""
    KK_DECL_CURRENT_VISIBILITY="public"
    kk.decl._reset_next_modifiers
}

# defineClass's exit after a refused token: poison (if the verb did not) and
# close quietly — the refusal itself already printed its error.
kk.decl._abandon_class() {   # CLASS MEMBER
    [[ "$KK_DECL_CURRENT_CLASS" == "$1" ]] || return 1
    kk.decl._poison "$2"
    kk.decl._close_refused "$1"
    return 1
}

kk.decl._reset_next_modifiers() {
    KK_DECL_NEXT_MODIFIERS=()
}

kk.decl._push_next_modifier() {
    KK_DECL_NEXT_MODIFIERS+=("$1")
}

kk.decl._require_current_class() {
    if [[ -z "$KK_DECL_CURRENT_CLASS" ]]; then
        kk.decl._error "No active class declaration"
        return 1
    fi

    RESULT="$KK_DECL_CURRENT_CLASS"
}

kk.decl._append_unique() {
    local array_name="$1"
    local value="$2"
    local -n array_ref="$array_name"
    local current_value

    for current_value in "${array_ref[@]}"; do
        if [[ "$current_value" == "$value" ]]; then
            return 0
        fi
    done

    array_ref+=("$value")
}

kk.decl._array_contains() {
    local array_name="$1"
    local value="$2"
    local -n array_ref="$array_name"
    local current_value

    for current_value in "${array_ref[@]}"; do
        if [[ "$current_value" == "$value" ]]; then
            return 0
        fi
    done

    return 1
}

kk.decl._remove_value() {
    local array_name="$1"
    local value="$2"
    local -n array_ref="$array_name"
    local filtered=()
    local current_value

    for current_value in "${array_ref[@]}"; do
        if [[ "$current_value" != "$value" ]]; then
            filtered+=("$current_value")
        fi
    done

    array_ref=("${filtered[@]}")
}

kk.decl._parent_of() {
    local class_name="$1"
    local decl_parent_var="${class_name}_decl_parent"
    local runtime_parent_var="${class_name}_parent_class"

    if declare -p "$decl_parent_var" &>/dev/null; then
        RESULT="${!decl_parent_var:-}"
    elif declare -p "$runtime_parent_var" &>/dev/null; then
        RESULT="${!runtime_parent_var:-}"
    else
        RESULT=""
    fi
}

kk.decl._field_declared() {
    local class_name="$1"
    local field_name="$2"
    local fields_var="${class_name}_decl_fields"

    if ! declare -p "$fields_var" &>/dev/null; then
        return 1
    fi

    kk.decl._array_contains "$fields_var" "$field_name"
}

kk.decl._method_declared() {
    local class_name="$1"
    local method_name="$2"
    local method_kind_var="${class_name}_decl_method_kind"

    if ! declare -p "$method_kind_var" &>/dev/null; then
        return 1
    fi

    local -n method_kind_ref="$method_kind_var"
    [[ -n "${method_kind_ref[$method_name]+x}" ]]
}

kk.decl._runtime_method_exists() {
    local class_name="$1"
    local method_name="$2"
    local methods_var="${class_name}_class_methods"

    if ! declare -p "$methods_var" &>/dev/null; then
        return 1
    fi

    kk.decl._array_contains "$methods_var" "$method_name"
}

kk.decl._rewrite_inherited() {
    local class_name="$1"
    local method_body="$2"
    local parent_class=""
    local parent_methods_var=""
    local parent_method=""

    kk.decl._parent_of "$class_name"
    parent_class="$RESULT"

    while [[ -n "$parent_class" ]]; do
        parent_methods_var="${parent_class}_class_methods"
        if declare -p "$parent_methods_var" &>/dev/null; then
            local -n parent_methods_ref="$parent_methods_var"
            for parent_method in "${parent_methods_ref[@]}"; do
                method_body="${method_body//inherited ${parent_method}/\$this.parent ${parent_method}}"
            done
        else
            parent_methods_var="${parent_class}_decl_methods"
            if declare -p "$parent_methods_var" &>/dev/null; then
                local -n parent_methods_ref="$parent_methods_var"
                for parent_method in "${parent_methods_ref[@]}"; do
                    method_body="${method_body//inherited ${parent_method}/\$this.parent ${parent_method}}"
                done
            fi
        fi

        kk.decl._parent_of "$parent_class"
        parent_class="$RESULT"
    done

    printf '%s' "$method_body"
}

# Is METHOD (as declared in CLASS or an ancestor) a `function`, i.e. does it
# return through RESULT? Walks the declarative parent chain.
kk.decl._method_kind_is_function() {
    local class_name="$1"
    local method_name="$2"
    local kind_cell

    while [[ -n "$class_name" ]]; do
        kind_cell="${class_name}_decl_method_kind[$method_name]"
        if [[ -n "${!kind_cell+x}" ]]; then
            [[ "${!kind_cell:-}" == "function" ]]
            return
        fi
        kk.decl._parent_of "$class_name"
        class_name="$RESULT"
    done

    return 1
}

kk.decl._build_property_getter_body() {
    local class_name="$1"
    local property_name="$2"
    local read_target="$3"

    if [[ -z "$read_target" ]]; then
        printf 'echo "Error: Property '\''%s'\'' is write-only" >&2\nreturn 1' "$property_name"
        return 0
    fi

    if [[ "$read_target" == "$property_name" ]]; then
        printf 'RESULT="$%s"' "$property_name"
        return 0
    fi

    if kk.decl._field_declared "$class_name" "$read_target"; then
        printf 'RESULT="$%s"' "$read_target"
        return 0
    fi

    # F7/D1: a RESULT-returning (`function`) getter runs in the CURRENT shell —
    # no subshell, so its side effects persist and no fork is paid per read
    # (the fork cost 16-45 ms once the shell held a few hundred objects).
    # RESULT is cleared first so a getter that sets nothing yields "" rather
    # than a stale value. An echo-style (`procedure`/legacy `method`) getter
    # still needs its stdout captured.
    if kk.decl._method_kind_is_function "$class_name" "$read_target"; then
        # The getter's exit status must reach the caller (kcl: predicates answer
        # by rc): keep it across the kk._return trailer that endImplementation
        # appends to every func (found_in_P6 P6-F1).
        printf 'RESULT=""; $__inst__.call %s; local __kk_grc=$?; kk._return "$RESULT"; return "$__kk_grc"' "$read_target"
        return 0
    fi

    printf 'RESULT="$($__inst__.call %s)"' "$read_target"
}

kk.decl._build_property_setter_body() {
    local class_name="$1"
    local property_name="$2"
    local write_target="$3"

    if [[ -z "$write_target" ]]; then
        printf 'echo "Error: Property '\''%s'\'' is read-only" >&2\nreturn 1' "$property_name"
        return 0
    fi

    if [[ "$write_target" == "$property_name" ]]; then
        printf '%s="$1"' "$property_name"
        return 0
    fi

    if kk.decl._field_declared "$class_name" "$write_target"; then
        printf '%s="$1"' "$write_target"
        return 0
    fi

    printf '$__inst__.call %s "$1"' "$write_target"
}

kk.decl._compute_unresolved_abstracts() {
    local class_name="$1"
    local output_array_name="$2"
    local -n output_ref="$output_array_name"
    local parent_class=""
    local method_name=""

    output_ref=()
    kk.decl._parent_of "$class_name"
    parent_class="$RESULT"

    if [[ -n "$parent_class" ]]; then
        local parent_abstract_var="${parent_class}_abstract_methods"
        if declare -p "$parent_abstract_var" &>/dev/null; then
            local -n parent_abstract_ref="$parent_abstract_var"
            output_ref=("${parent_abstract_ref[@]}")
        fi
    fi

    local methods_var="${class_name}_decl_methods"
    local abstract_var="${class_name}_decl_method_abstract"
    if ! declare -p "$methods_var" &>/dev/null || ! declare -p "$abstract_var" &>/dev/null; then
        return 0
    fi

    local -n methods_ref="$methods_var"
    local -n abstract_ref="$abstract_var"
    for method_name in "${methods_ref[@]}"; do
        if [[ "${abstract_ref[$method_name]:-0}" == "1" ]]; then
            kk.decl._append_unique "$output_array_name" "$method_name"
        else
            kk.decl._remove_value "$output_array_name" "$method_name"
        fi
    done
}

kk.decl._parent_method_is_virtual() {
    local class_name="$1"
    local method_name="$2"
    local parent_class=""

    kk.decl._parent_of "$class_name"
    parent_class="$RESULT"

    while [[ -n "$parent_class" ]]; do
        local method_abstract_var="${parent_class}_method_abstract"
        local method_virtual_var="${parent_class}_method_virtual"
        local method_override_var="${parent_class}_method_override"

        if declare -p "$method_abstract_var" &>/dev/null; then
            local -n method_abstract_ref="$method_abstract_var"
            local -n method_virtual_ref="$method_virtual_var"
            local -n method_override_ref="$method_override_var"
            if [[ -n "${method_abstract_ref[$method_name]+x}" ]]; then
                if [[ "${method_abstract_ref[$method_name]:-0}" == "1" || "${method_virtual_ref[$method_name]:-0}" == "1" || "${method_override_ref[$method_name]:-0}" == "1" ]]; then
                    return 0
                fi
                return 1
            fi
        fi

        local decl_method_kind_var="${parent_class}_decl_method_kind"
        if declare -p "$decl_method_kind_var" &>/dev/null; then
            local -n decl_method_kind_ref="$decl_method_kind_var"
            if [[ -n "${decl_method_kind_ref[$method_name]+x}" ]]; then
                local decl_abstract_var="${parent_class}_decl_method_abstract"
                local decl_virtual_var="${parent_class}_decl_method_virtual"
                local decl_override_var="${parent_class}_decl_method_override"
                local -n decl_abstract_ref="$decl_abstract_var"
                local -n decl_virtual_ref="$decl_virtual_var"
                local -n decl_override_ref="$decl_override_var"
                if [[ "${decl_abstract_ref[$method_name]:-0}" == "1" || "${decl_virtual_ref[$method_name]:-0}" == "1" || "${decl_override_ref[$method_name]:-0}" == "1" ]]; then
                    return 0
                fi
                return 1
            fi
        fi

        kk.decl._parent_of "$parent_class"
        parent_class="$RESULT"
    done

    return 1
}

kk.decl._install_new_wrapper() {
    local class_name="$1"
    local abstract_flag_var="${class_name}_class_abstract"

    if ! declare -f "${class_name}.__decl_new_impl" >/dev/null 2>&1; then
        local new_definition
        new_definition="$(declare -f "${class_name}.new")" || return 1
        new_definition="${new_definition/${class_name}.new ()/${class_name}.__decl_new_impl ()}"
        eval "$new_definition"
    fi

    eval "${class_name}.new() {
        local __kk_class_abstract_var=\"${abstract_flag_var}\"
        if [[ \"\${!__kk_class_abstract_var:-0}\" == \"1\" ]]; then
            echo \"Abstract class '${class_name}' cannot be instantiated\" >&2
            return 1
        fi

        ${class_name}.__decl_new_impl \"\$@\"
    }"
}

# Every declarative method verb (procedure, func, classProcedure,
# classFunction, the Pascal proc/func/destructor) ends here: a refusal poisons
# the open class (P11/M2, DR8).
kk.decl._declare_method() {
    kk.decl._declare_method_core "$@" || kk.decl._poison "${2:-}"
}

kk.decl._declare_method_core() {
    local method_kind="$1"
    local method_name="$2"

    kk.decl._require_current_class || return 1
    local class_name="$RESULT"

    [[ -n "$method_name" ]] || {
        kk.decl._error "Method name is required"
        return 1
    }
    case "$method_kind" in
        class_procedure|class_function)
            kk.decl._validate_static "$method_name" "static method name" || return 1
            kk.decl._static_clash "$class_name" "$method_name" method || return 1
            ;;
        *)
            kk.decl._validate_member "$method_name" "method name" || return 1 ;;
    esac

    local methods_var="${class_name}_decl_methods"
    local abstract_var="${class_name}_decl_method_abstract"
    local override_var="${class_name}_decl_method_override"
    local virtual_var="${class_name}_decl_method_virtual"
    local visibility_var="${class_name}_decl_method_visibility"
    local kind_var="${class_name}_decl_method_kind"
    local static_var="${class_name}_decl_method_static"
    local -n methods_ref="$methods_var"
    local -n abstract_ref="$abstract_var"
    local -n override_ref="$override_var"
    local -n virtual_ref="$virtual_var"
    local -n visibility_ref="$visibility_var"
    local -n kind_ref="$kind_var"
    local -n static_ref="$static_var"
    local modifier

    # P11 review R3 — the declarative layer keeps instance AND class methods in
    # ONE set of per-class tables keyed by name (CLASS_decl_methods,
    # CLASS_decl_method_kind/_static/_body, …; the Pascal DSL also shares the
    # one scratch function CLASS.NAME). `procedure x` + `classProcedure x`
    # therefore overwrote each other's entry and one of the two was silently
    # lost. Re-declaring a name of the SAME kind stays allowed.
    if [[ -n "${kind_ref[$method_name]+x}" ]]; then
        local __kk_was_static=0 __kk_is_static=0
        [[ "${kind_ref[$method_name]}" == class_* ]] && __kk_was_static=1
        [[ "$method_kind" == class_* ]] && __kk_is_static=1
        if (( __kk_was_static != __kk_is_static )); then
            kk.decl._error "Method name clash in class '${class_name}': '${method_name}' is declared both as an instance and as a class (static) method (the declaration tables hold one entry per name)"
            return 1
        fi
    fi

    kk.decl._append_unique "$methods_var" "$method_name"

    abstract_ref["$method_name"]=0
    override_ref["$method_name"]=0
    virtual_ref["$method_name"]=0
    visibility_ref["$method_name"]="$KK_DECL_CURRENT_VISIBILITY"
    kind_ref["$method_name"]="$method_kind"
    static_ref["$method_name"]=0

    case "$method_kind" in
        class_procedure|class_function)
            static_ref["$method_name"]=1
            ;;
    esac

    for modifier in "${KK_DECL_NEXT_MODIFIERS[@]}"; do
        case "$modifier" in
            abstract)
                abstract_ref["$method_name"]=1
                ;;
            override)
                override_ref["$method_name"]=1
                ;;
            virtual)
                virtual_ref["$method_name"]=1
                ;;
            *)
                kk.decl._error "Unsupported modifier '$modifier' for method '$method_name'"
                return 1
                ;;
        esac
    done

    kk.decl._reset_next_modifiers
}

declareClass() {
    local class_name="$1"
    local parent_class="${2:-}"

    [[ -n "$class_name" ]] || {
        kk.decl._error "declareClass: CLASS_NAME is required"
        return 1
    }
    kk.decl._validate_ident "$class_name" "class name" || return 1
    kk.decl._validate_ident "$parent_class" "parent class name" || return 1

    # F2: refuse a cross-file redefinition HERE, before any of the declarative
    # tables below are reset — otherwise a refused build still wiped the
    # original's abstract flag and member visibility.
    local __kk_caller_src
    kk._check_class_owner "$class_name" || return 1

    # P11/M2 (DR8): a REdefinition of a class the declarative layer already
    # built keeps a copy of the tables reset below; a refused (poisoned)
    # redefinition puts them back (kk.decl._close_refused). Dropped by a clean
    # endClass. A first declaration pays nothing.
    kk.decl._snap_drop "$class_name"
    local __kk_declared_var="${class_name}_decl_declared"
    if [[ -n "${!__kk_declared_var:-}" ]] && declare -F "${class_name}.new" >/dev/null; then
        kk.decl._snap_copy "${class_name}_" "__kk_decl_snap_${class_name}_"
        __kk_decl_snap_taken["$class_name"]=1
    fi
    declare -g "${class_name}_decl_refused="

    eval "declare -ga ${class_name}_decl_fields=()"
    eval "declare -ga ${class_name}_decl_properties=()"
    eval "declare -ga ${class_name}_decl_methods=()"
    eval "declare -ga ${class_name}_abstract_methods=()"
    eval "declare -gA ${class_name}_decl_property_visibility=()"
    eval "declare -gA ${class_name}_decl_property_read=()"
    eval "declare -gA ${class_name}_decl_property_write=()"
    eval "declare -gA ${class_name}_decl_property_mode=()"
    eval "declare -gA ${class_name}_decl_property_lazy_init=()"
    eval "declare -gA ${class_name}_decl_field_visibility=()"
    eval "declare -ga ${class_name}_decl_static_properties=()"
    eval "declare -ga ${class_name}_decl_static_methods=()"
    eval "declare -gA ${class_name}_decl_static_method_body=()"
    eval "declare -gA ${class_name}_decl_method_kind=()"
    eval "declare -gA ${class_name}_decl_method_visibility=()"
    eval "declare -gA ${class_name}_decl_method_abstract=()"
    eval "declare -gA ${class_name}_decl_method_override=()"
    eval "declare -gA ${class_name}_decl_method_virtual=()"
    eval "declare -gA ${class_name}_decl_method_static=()"
    eval "declare -gA ${class_name}_decl_method_body=()"
    eval "declare -gA ${class_name}_method_virtual=()"
    eval "declare -gA ${class_name}_method_override=()"
    eval "declare -gA ${class_name}_method_abstract=()"
    eval "declare -gA ${class_name}_method_visibility=()"
    eval "${class_name}_decl_parent=\"$parent_class\""
    eval "${class_name}_decl_constructor_body=''"
    eval "${class_name}_decl_constructor_name='Create'"
    eval "${class_name}_decl_declared=1"
    eval "${class_name}_decl_finalized=0"
    eval "${class_name}_class_abstract=0"

    KK_DECL_CURRENT_CLASS="$class_name"
    KK_DECL_CURRENT_VISIBILITY="public"
    kk.decl._reset_next_modifiers
}

privateSection() {
    kk.decl._require_current_class || return 1
    KK_DECL_CURRENT_VISIBILITY="private"
}

protectedSection() {
    kk.decl._require_current_class || return 1
    KK_DECL_CURRENT_VISIBILITY="protected"
}

publicSection() {
    kk.decl._require_current_class || return 1
    KK_DECL_CURRENT_VISIBILITY="public"
}

# The public member verbs below poison the open class on a refusal (P11/M2,
# DR8); the work is done by the kk.decl._<verb> bodies.
classVar() { kk.decl._classVar "$@" || kk.decl._poison "${1:-}"; }
field() { kk.decl._field "$@" || kk.decl._poison "${1:-}"; }
property() { kk.decl._property "$@" || kk.decl._poison "${1:-}"; }
constructor() { kk.decl._constructor "$@" || kk.decl._poison "${1:-Create}"; }

kk.decl._classVar() {
    local property_name="$1"

    kk.decl._require_current_class || return 1
    local class_name="$RESULT"

    [[ -n "$property_name" ]] || {
        kk.decl._error "classVar: PROPERTY_NAME is required"
        return 1
    }
    kk.decl._validate_ident "$property_name" "class variable name" || return 1

    if [[ ${#KK_DECL_NEXT_MODIFIERS[@]} -gt 0 ]]; then
        kk.decl._error "classVar: Modifiers are not supported for class variables"
        return 1
    fi

    kk.decl._remember_static_property "$class_name" "$property_name"
}

virtual() {
    kk.decl._require_current_class || return 1
    kk.decl._push_next_modifier "virtual"
}

override() {
    kk.decl._require_current_class || return 1
    kk.decl._push_next_modifier "override"
}

abstract() {
    kk.decl._require_current_class || return 1
    kk.decl._push_next_modifier "abstract"
}

kk.decl._field() {
    local field_name="$1"
    kk.decl._require_current_class || return 1
    local class_name="$RESULT"

    [[ -n "$field_name" ]] || {
        kk.decl._error "field: FIELD_NAME is required"
        return 1
    }
    kk.decl._validate_member "$field_name" "field name" || return 1
    kk.decl._prop_clash "$class_name" "$field_name" instance || return 1

    if [[ ${#KK_DECL_NEXT_MODIFIERS[@]} -gt 0 ]]; then
        kk.decl._error "field: Modifiers are not supported for fields"
        return 1
    fi

    local fields_var="${class_name}_decl_fields"
    local visibility_var="${class_name}_decl_field_visibility"
    local -n visibility_ref="$visibility_var"
    kk.decl._append_unique "$fields_var" "$field_name"
    visibility_ref["$field_name"]="$KK_DECL_CURRENT_VISIBILITY"
}

kk.decl._property() {
    local property_name="$1"
    shift

    kk.decl._require_current_class || return 1
    local class_name="$RESULT"

    [[ -n "$property_name" ]] || {
        kk.decl._error "property: PROPERTY_NAME is required"
        return 1
    }
    kk.decl._validate_member "$property_name" "property name" || return 1
    kk.decl._prop_clash "$class_name" "$property_name" instance || return 1

    if [[ ${#KK_DECL_NEXT_MODIFIERS[@]} -gt 0 ]]; then
        kk.decl._error "property: Modifiers are not supported for properties in this phase"
        return 1
    fi

    local read_target=""
    local write_target=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            read)
                [[ -n "$2" ]] || {
                    kk.decl._error "property: read target is required"
                    return 1
                }
                read_target="$2"
                shift 2
                ;;
            write)
                [[ -n "$2" ]] || {
                    kk.decl._error "property: write target is required"
                    return 1
                }
                write_target="$2"
                shift 2
                ;;
            *)
                kk.decl._error "property: Unsupported token '$1'"
                return 1
                ;;
        esac
    done

    local props_var="${class_name}_decl_properties"
    local vis_var="${class_name}_decl_property_visibility"
    local read_var="${class_name}_decl_property_read"
    local write_var="${class_name}_decl_property_write"
    local -n vis_ref="$vis_var"
    local -n read_ref="$read_var"
    local -n write_ref="$write_var"
    local mode_var="${class_name}_decl_property_mode"
    local -n mode_ref="$mode_var"

    kk.decl._append_unique "$props_var" "$property_name"
    vis_ref["$property_name"]="$KK_DECL_CURRENT_VISIBILITY"
    read_ref["$property_name"]="$read_target"
    write_ref["$property_name"]="$write_target"
    mode_ref["$property_name"]="normal"
}

procedure() {
    kk.decl._declare_method "procedure" "$1"
}

declareProcedure() {
    procedure "$@"
}

func() {
    kk.decl._declare_method "function" "$1"
}

declareFunction() {
    func "$@"
}

classProcedure() {
    kk.decl._declare_method "class_procedure" "$1"
}

classFunction() {
    kk.decl._declare_method "class_function" "$1"
}

kk.decl._constructor() {
    local constructor_name="${1:-Create}"
    kk.decl._require_current_class || return 1
    local class_name="$RESULT"

    if [[ ${#KK_DECL_NEXT_MODIFIERS[@]} -gt 0 ]]; then
        kk.decl._error "constructor: Modifiers are not supported for constructors in this phase"
        return 1
    fi
    # P11 review R2: the name is interpolated into an eval'd assignment below
    # (and is the function name the Pascal build extracts) — validate it FIRST;
    # `constructor '$(cmd)'` used to run cmd. A refusal poisons the class
    # through the constructor() wrapper (DR8).
    kk.decl._validate_ident "$constructor_name" "constructor name" || return 1

    eval "${class_name}_decl_constructor_name=\"$constructor_name\""
}

endClass() {
    kk.decl._require_current_class || return 1
    local class_name="$RESULT"
    local override_var="${class_name}_decl_method_override"
    local methods_var="${class_name}_decl_methods"
    local -n override_ref="$override_var"
    local -n methods_ref="$methods_var"
    local method_name

    for method_name in "${methods_ref[@]}"; do
        if [[ "${override_ref[$method_name]:-0}" == "1" ]]; then
            if ! kk.decl._parent_method_is_virtual "$class_name" "$method_name"; then
                kk.decl._error "Method '${class_name}.${method_name}' cannot override a non-virtual parent method"
                kk.decl._poison "$method_name"
                break
            fi
        fi
    done

    # P11/M2 (DR8): a member refused while the class was open fails the class
    # here — rc 1 naming class + member, the class is CLOSED (no stray verb
    # attaches to it), finalized stays 0, a refused redefinition gets the old
    # tables back. endImplementation / build refuse it too until the next
    # declareClass of the same name.
    local refused_var="${class_name}_decl_refused"
    if [[ -n "${!refused_var:-}" ]]; then
        kk.decl._error "endClass: class '${class_name}' is not finalized: member '${!refused_var}' was refused (the class is closed and will not be built)"
        kk.decl._close_refused "$class_name"
        return 1
    fi

    eval "${class_name}_decl_finalized=1"
    KK_DECL_CURRENT_CLASS=""
    KK_DECL_CURRENT_VISIBILITY="public"
    kk.decl._reset_next_modifiers
    kk.decl._snap_drop "$class_name"
}

finalizeClass() {
    endClass "$@"
}

implement() {
    local qualified_name="$1"
    local method_body="$2"

    [[ "$qualified_name" == *.* ]] || {
        kk.decl._error "implement: Use ClassName.MethodName"
        return 1
    }

    local class_name="${qualified_name%%.*}"
    local method_name="${qualified_name#*.}"
    local body_var="${class_name}_decl_method_body"
    local abstract_var="${class_name}_decl_method_abstract"

    kk.decl._method_declared "$class_name" "$method_name" || {
        kk.decl._error "implement: '${qualified_name}' was not declared"
        return 1
    }

    local -n body_ref="$body_var"
    local -n abstract_ref="$abstract_var"
    if [[ "${abstract_ref[$method_name]:-0}" == "1" ]]; then
        kk.decl._error "implement: '${qualified_name}' is abstract and cannot be implemented in the same class"
        return 1
    fi

    method_body="$(kk.decl._rewrite_inherited "$class_name" "$method_body")"
    body_ref["$method_name"]="$method_body"
}

implementConstructor() {
    local class_name="$1"
    local constructor_body="$2"

    [[ -n "$class_name" ]] || {
        kk.decl._error "implementConstructor: CLASS_NAME is required"
        return 1
    }
    # P11 review R2: CLASS_NAME is spliced into an eval'd assignment below.
    kk.decl._validate_ident "$class_name" "class name" || return 1

    constructor_body="$(kk.decl._rewrite_inherited "$class_name" "$constructor_body")"
    eval "${class_name}_decl_constructor_body=\$constructor_body"
}

endImplementation() {
    local class_name="$1"
    [[ -n "$class_name" ]] || {
        kk.decl._error "endImplementation: CLASS_NAME is required"
        return 1
    }
    kk.decl._validate_ident "$class_name" "class name" || return 1

    # P11/M2 (DR8): the poison flag FIRST — a class whose declaration refused a
    # member is never built, and the refusal is what gets named.
    local refused_var="${class_name}_decl_refused"
    if [[ -n "${!refused_var:-}" ]]; then
        kk.decl._error "endImplementation: class '${class_name}' is not built: member '${!refused_var}' was refused in its declaration"
        return 1
    fi

    local finalized_var="${class_name}_decl_finalized"
    if [[ "${!finalized_var:-0}" != "1" ]]; then
        kk.decl._error "endImplementation: Class '${class_name}' must be closed with endClass first"
        return 1
    fi

    local parent_var="${class_name}_decl_parent"
    local parent_class="${!parent_var:-}"
    if [[ -n "$parent_class" ]]; then
        local parent_ready=0
        if declare -f "${parent_class}.new" >/dev/null 2>&1; then
            parent_ready=1
        fi
        if [[ $parent_ready -eq 0 ]]; then
            kk.decl._error "endImplementation: Parent class '${parent_class}' must be implemented before '${class_name}'"
            return 1
        fi
    fi

    local methods_var="${class_name}_decl_methods"
    local kind_var="${class_name}_decl_method_kind"
    local body_var="${class_name}_decl_method_body"
    local abstract_var="${class_name}_decl_method_abstract"
    local fields_var="${class_name}_decl_fields"
    local props_var="${class_name}_decl_properties"
    local prop_read_var="${class_name}_decl_property_read"
    local prop_write_var="${class_name}_decl_property_write"
    local prop_mode_var="${class_name}_decl_property_mode"
    local prop_lazy_var="${class_name}_decl_property_lazy_init"
    local static_props_var="${class_name}_decl_static_properties"
    local static_methods_var="${class_name}_decl_static_methods"
    local static_bodies_var="${class_name}_decl_static_method_body"
    local virtual_var="${class_name}_decl_method_virtual"
    local override_var="${class_name}_decl_method_override"
    local visibility_var="${class_name}_decl_method_visibility"
    local constructor_var="${class_name}_decl_constructor_body"
    local -n methods_ref="$methods_var"
    local -n kind_ref="$kind_var"
    local -n body_ref="$body_var"
    local -n abstract_ref="$abstract_var"
    local -n fields_ref="$fields_var"
    local -n props_ref="$props_var"
    local -n prop_read_ref="$prop_read_var"
    local -n prop_write_ref="$prop_write_var"
    local -n prop_mode_ref="$prop_mode_var"
    local -n prop_lazy_ref="$prop_lazy_var"
    local -n static_props_ref="$static_props_var"
    local -n static_methods_ref="$static_methods_var"
    local -n static_bodies_ref="$static_bodies_var"
    local -n virtual_ref="$virtual_var"
    local -n override_ref="$override_var"
    local -n visibility_ref="$visibility_var"
    local -a class_args=("$class_name" "$parent_class")
    local -a unresolved_abstracts=()
    local field_name
    local property_name
    local method_name

    for field_name in "${static_props_ref[@]}"; do
        class_args+=("static_property" "$field_name")
    done

    for method_name in "${methods_ref[@]}"; do
        if [[ "${abstract_ref[$method_name]:-0}" != "1" && -z "${body_ref[$method_name]+x}" ]]; then
            kk.decl._error "endImplementation: Missing body for '${class_name}.${method_name}'"
            return 1
        fi
    done

    for field_name in "${fields_ref[@]}"; do
        class_args+=("property" "$field_name")
    done

    for property_name in "${props_ref[@]}"; do
        local read_target="${prop_read_ref[$property_name]:-}"
        local write_target="${prop_write_ref[$property_name]:-}"
        local property_mode="${prop_mode_ref[$property_name]:-normal}"
        if [[ "$property_mode" == "lazy" ]]; then
            class_args+=("lazy_property" "$property_name" "${prop_lazy_ref[$property_name]}")
        elif [[ -z "$read_target" && -z "$write_target" ]]; then
            class_args+=("property" "$property_name")
        else
            local getter_name="_get_${property_name}"
            local setter_name="_set_${property_name}"
            local getter_body
            local setter_body

            getter_body="$(kk.decl._build_property_getter_body "$class_name" "$property_name" "$read_target")"
            setter_body="$(kk.decl._build_property_setter_body "$class_name" "$property_name" "$write_target")"

            class_args+=("property" "$property_name" "$getter_name" "$setter_name")
            class_args+=("function" "$getter_name" "$getter_body")
            class_args+=("procedure" "$setter_name" "$setter_body")
        fi
    done

    for method_name in "${methods_ref[@]}"; do
        local method_kind="${kind_ref[$method_name]}"
        local method_body="${body_ref[$method_name]:-}"

        if [[ "${abstract_ref[$method_name]:-0}" == "1" ]]; then
            method_body="echo \"Error: Abstract method '${class_name}.${method_name}' is not implemented\" >&2
return 1"
        fi

        case "$method_kind" in
            procedure)
                class_args+=("procedure" "$method_name" "$method_body")
                ;;
            function)
                class_args+=("function" "$method_name" "$method_body")
                ;;
            class_procedure)
                class_args+=("static_method" "$method_name" "$method_body")
                ;;
            class_function)
                class_args+=("static_method" "$method_name" "$method_body
kk._return \"\$RESULT\"")
                ;;
            *)
                kk.decl._error "endImplementation: Unsupported method kind '$method_kind'"
                return 1
                ;;
        esac
    done

    for method_name in "${static_methods_ref[@]}"; do
        class_args+=("static_method" "$method_name" "${static_bodies_ref[$method_name]}")
    done

    if [[ -n "${!constructor_var:-}" ]]; then
        class_args+=("constructor" "${!constructor_var:-}")
    fi

    kk._build_class_runtime "${class_args[@]}" || return 1

    kk.decl._compute_unresolved_abstracts "$class_name" unresolved_abstracts
    eval "${class_name}_abstract_methods=(\"\${unresolved_abstracts[@]}\")"
    if (( ${#unresolved_abstracts[@]} > 0 )); then
        eval "${class_name}_class_abstract=1"
    else
        eval "${class_name}_class_abstract=0"
    fi

    eval "declare -gA ${class_name}_method_virtual=()"
    eval "declare -gA ${class_name}_method_override=()"
    eval "declare -gA ${class_name}_method_abstract=()"
    eval "declare -gA ${class_name}_method_visibility=()"
    eval "declare -gA ${class_name}_method_owner=()"
    eval "declare -gA ${class_name}_property_visibility=()"
    eval "declare -gA ${class_name}_property_owner=()"

    local runtime_virtual_var="${class_name}_method_virtual"
    local runtime_override_var="${class_name}_method_override"
    local runtime_abstract_var="${class_name}_method_abstract"
    local runtime_visibility_var="${class_name}_method_visibility"
    local runtime_method_owner_var="${class_name}_method_owner"
    local runtime_property_visibility_var="${class_name}_property_visibility"
    local runtime_property_owner_var="${class_name}_property_owner"
    local -n runtime_virtual_ref="$runtime_virtual_var"
    local -n runtime_override_ref="$runtime_override_var"
    local -n runtime_abstract_ref="$runtime_abstract_var"
    local -n runtime_visibility_ref="$runtime_visibility_var"
    local -n runtime_method_owner_ref="$runtime_method_owner_var"
    local -n runtime_property_visibility_ref="$runtime_property_visibility_var"
    local -n runtime_property_owner_ref="$runtime_property_owner_var"

    if [[ -n "$parent_class" ]]; then
        local parent_method_virtual_var="${parent_class}_method_virtual"
        local parent_method_override_var="${parent_class}_method_override"
        local parent_method_abstract_var="${parent_class}_method_abstract"
        local parent_method_visibility_var="${parent_class}_method_visibility"
        local parent_method_owner_var="${parent_class}_method_owner"
        local parent_property_visibility_var="${parent_class}_property_visibility"
        local parent_property_owner_var="${parent_class}_property_owner"
        local inherited_name

        if declare -p "$parent_method_virtual_var" &>/dev/null; then
            local -n parent_method_virtual_ref="$parent_method_virtual_var"
            local -n parent_method_override_ref="$parent_method_override_var"
            local -n parent_method_abstract_ref="$parent_method_abstract_var"
            local -n parent_method_visibility_ref="$parent_method_visibility_var"
            local -n parent_method_owner_ref="$parent_method_owner_var"
            for inherited_name in "${!parent_method_visibility_ref[@]}"; do
                runtime_virtual_ref["$inherited_name"]="${parent_method_virtual_ref[$inherited_name]:-0}"
                runtime_override_ref["$inherited_name"]="${parent_method_override_ref[$inherited_name]:-0}"
                runtime_abstract_ref["$inherited_name"]="${parent_method_abstract_ref[$inherited_name]:-0}"
                runtime_visibility_ref["$inherited_name"]="${parent_method_visibility_ref[$inherited_name]:-public}"
                runtime_method_owner_ref["$inherited_name"]="${parent_method_owner_ref[$inherited_name]:-$parent_class}"
            done
        fi

        if declare -p "$parent_property_visibility_var" &>/dev/null; then
            local -n parent_property_visibility_ref="$parent_property_visibility_var"
            local -n parent_property_owner_ref="$parent_property_owner_var"
            for inherited_name in "${!parent_property_visibility_ref[@]}"; do
                runtime_property_visibility_ref["$inherited_name"]="${parent_property_visibility_ref[$inherited_name]:-public}"
                runtime_property_owner_ref["$inherited_name"]="${parent_property_owner_ref[$inherited_name]:-$parent_class}"
            done
        fi
    fi

    local field_visibility_var="${class_name}_decl_field_visibility"
    local -n field_visibility_ref="$field_visibility_var"
    for field_name in "${fields_ref[@]}"; do
        runtime_property_visibility_ref["$field_name"]="${field_visibility_ref[$field_name]:-public}"
        runtime_property_owner_ref["$field_name"]="$class_name"
    done

    local prop_visibility_var="${class_name}_decl_property_visibility"
    local -n prop_visibility_ref="$prop_visibility_var"
    for property_name in "${props_ref[@]}"; do
        runtime_property_visibility_ref["$property_name"]="${prop_visibility_ref[$property_name]:-public}"
        runtime_property_owner_ref["$property_name"]="$class_name"
    done

    for method_name in "${methods_ref[@]}"; do
        runtime_virtual_ref["$method_name"]="${virtual_ref[$method_name]:-0}"
        runtime_override_ref["$method_name"]="${override_ref[$method_name]:-0}"
        runtime_abstract_ref["$method_name"]="${abstract_ref[$method_name]:-0}"
        runtime_visibility_ref["$method_name"]="${visibility_ref[$method_name]:-public}"
        runtime_method_owner_ref["$method_name"]="$class_name"
    done

    # P4b: hot-path gate for kk._warn_visibility. 0 = every method and
    # property (own and inherited) is public, so the dispatcher skips the
    # visibility lookup altogether; 1 = at least one non-public member.
    local __kk_np=0 __kk_vis
    for __kk_vis in "${runtime_visibility_ref[@]}" "${runtime_property_visibility_ref[@]}"; do
        if [[ "$__kk_vis" != "public" && -n "$__kk_vis" ]]; then
            __kk_np=1
            break
        fi
    done
    eval "${class_name}_has_nonpublic=$__kk_np"

    kk.decl._install_new_wrapper "$class_name"
}

finalizeImplementation() {
    endImplementation "$@"
}

if [[ "${KKLASS_EXPORT_FUNCTIONS:-0}" == "1" ]]; then
    export -f declareClass privateSection protectedSection publicSection virtual override abstract
    export -f field property classVar procedure declareProcedure func declareFunction classProcedure classFunction constructor
    export -f endClass finalizeClass implement implementConstructor endImplementation finalizeImplementation
fi