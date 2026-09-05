#!/bin/bash
# kklass.sh - Working class system for bash with dot notation

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${KKLASS_DIR}/../kkore/klib.sh"
source "${KKLASS_DIR}/../kkore/kerr.sh"
source "${KKLASS_DIR}/../kkore/kvar.sh"

# Registry of class name -> the source file that defined (finalized) it. Used
# to refuse an accidental SECOND definition of the same class name from a
# DIFFERENT file (a real bug: e.g. TStopwatch defined in two files, or a user
# class colliding with a library one). A re-registration from the SAME file is
# allowed — the diamond-include case (e.g. tstringlist.sh + tlist.sh both
# pulling in tlist.sh) is legitimate and must keep working. Declared
# idempotently so a re-source of this framework never wipes it.
[[ -v _KKLASS_CLASS_SOURCE ]] || declare -gA _KKLASS_CLASS_SOURCE
# "$PWD|raw BASH_SOURCE string" -> canonical path. The canonicalization below
# forks once ($(cd ..)); with the owner check now also running at declareClass
# time (P1/F2) this cache keeps it to ONE fork per distinct source file per
# working directory instead of one per class.
[[ -v _KKLASS_CANON_CACHE ]] || declare -gA _KKLASS_CANON_CACHE

# Resolve the innermost call-stack entry that is NOT a kklass framework file —
# i.e. the unit/user script that invoked the class-building verb — CANONICALIZED
# so the same file reached through different path spellings compares equal.
# Result in __kk_caller_src; falls back to "(unknown)".
#
# Canonicalization matters: tstringlist.sh sources tlist.sh as
# "$DIR/../tlist/tlist.sh" while a test may source "kcl/tlist/tlist.sh" — the
# SAME file, different strings. Comparing raw strings would raise a false
# "collision" and break legitimate diamond includes. The cd+pwd idiom (the one
# every unit header already uses) resolves .., relative paths, and MSYS vs
# Windows drive forms to one canonical path. The single subshell runs only at
# class-build time — load time, never a runtime path (unit headers fork the
# same way). A false NEGATIVE here merely degrades to no-protection; a false
# POSITIVE would break working code, so we err toward matching.
kk._caller_source_file() {
    local __i __src __base __d __b
    __kk_caller_src="(unknown)"
    for (( __i = 0; __i < ${#BASH_SOURCE[@]}; __i++ )); do
        __src="${BASH_SOURCE[__i]}"
        __base="${__src##*/}"
        case "$__base" in
            kklass.sh|kklass_decl.sh|kklass_pascal.sh|kklass_kkp.sh|kklass_serializable.sh|kklass_autoload.sh|kklass_compiler.sh) continue ;;
        esac
        if [[ -n "${_KKLASS_CANON_CACHE[$PWD|$__src]+x}" ]]; then
            __kk_caller_src="${_KKLASS_CANON_CACHE[$PWD|$__src]}"
            return 0
        fi
        __d="${__src%/*}"; __b="${__src##*/}"
        [[ "$__d" == "$__src" ]] && __d="."     # no slash -> current dir
        __kk_caller_src="$( cd "$__d" 2>/dev/null && printf '%s/%s' "$PWD" "$__b" )" \
            || __kk_caller_src="$__src"
        _KKLASS_CANON_CACHE["$PWD|$__src"]="$__kk_caller_src"
        return 0
    done
    return 0
}

# Duplicate-name protection shared by declareClass (check only, BEFORE any
# declarative state is reset — F2) and kk._build_class_runtime ("register").
# Refuses when NAME is already owned by a DIFFERENT canonical file; a rebuild
# from the same file (diamond include, deliberate re-source) passes. Leaves the
# resolved caller in __kk_caller_src (declare it local in the caller).
kk._check_class_owner() {
    local __kk_cls="$1" __kk_mode="${2:-check}"
    kk._caller_source_file
    if [[ -n "${_KKLASS_CLASS_SOURCE[$__kk_cls]+x}" \
          && "${_KKLASS_CLASS_SOURCE[$__kk_cls]}" != "$__kk_caller_src" ]]; then
        echo "kklass: class '${__kk_cls}' is already registered (from ${_KKLASS_CLASS_SOURCE[$__kk_cls]}); refusing to redefine it from ${__kk_caller_src}" >&2
        return 1
    fi
    if [[ "$__kk_mode" == "register" ]]; then
        _KKLASS_CLASS_SOURCE["$__kk_cls"]="$__kk_caller_src"
    fi
    return 0
}

# Scratch global used by kk._find_method to return the resolving class
# without forking a subshell.
declare -g __kk_find_class=""

kk._return() {
    local return_value="$1"

    # -v, not `declare -p ... &>/dev/null`: declare -p formats the variable
    # (and every enclosing scope lookup) on every function return (P4b).
    if [[ -v __kk_return_set ]]; then
        __kk_return_set=1
        __kk_return_value="$return_value"
    fi

    RESULT="$return_value"

    # Automatically enable echo if we're in a subshell context
    if [[ $BASH_SUBSHELL -gt 0 && "${__kk_return_silent:-0}" != "1" ]]; then
        # In subshell: echo the value
        echo -n "$return_value"
        return
    fi
}

kk.call_silent() {
    local instance_name="$1"
    local method_name="$2"
    shift 2

    local had_silent=0
    local previous_silent=""
    if [[ ${__kk_return_silent+x} ]]; then
        had_silent=1
        previous_silent="$__kk_return_silent"
    fi

    __kk_return_silent=1
    "${instance_name}.call" "$method_name" "$@"
    local call_status=$?
    local call_result="$RESULT"

    if (( had_silent )); then
        __kk_return_silent="$previous_silent"
    else
        unset __kk_return_silent
    fi

    RESULT="$call_result"
    return "$call_status"
}

kk._processMethodBody() {
    local class_name="$1"
    local method_name="$2"
    local method_body="$3"
    local meth_type="${4:-method}"
    local -n meths_array="$5"  # Reference to methods array
    
    # Replace all $this.METHOD_NAME patterns with $__inst__.call METHOD_NAME
    for wm in "${meths_array[@]}"; do
        # Replace $this.method with proper call syntax
        method_body="${method_body//\$this.${wm}/\$__inst__.call ${wm}}"
        # Also handle ${this}.method syntax
        method_body="${method_body//\$\{this\}.${wm}/\$__inst__.call ${wm}}"
    done
    
    # For function type, append kk._return call
    if [[ "$meth_type" == "function" ]]; then
        #method_body+=$'\n'"kk._return \"${class_name}_${method_name}\" \"\$RESULT\""
        method_body+=$'\n'"kk._return \"\$RESULT\""
    fi
    
    METHOD_BODY="$method_body"
}

kk._class_derives_from() {
    local candidate_class="$1"
    local ancestor_class="$2"
    local parent_var=""

    if [[ -z "$candidate_class" || -z "$ancestor_class" ]]; then
        return 1
    fi

    if [[ "$candidate_class" == "$ancestor_class" ]]; then
        return 0
    fi

    parent_var="${candidate_class}_parent_class"
    while [[ -n "${!parent_var}" ]]; do
        if [[ "${!parent_var}" == "$ancestor_class" ]]; then
            return 0
        fi
        candidate_class="${!parent_var}"
        parent_var="${candidate_class}_parent_class"
    done

    return 1
}

kk._warn_visibility() {
    local class_name="$1"
    local member_type="$2"
    local member_name="$3"
    local visibility_var="${class_name}_${member_type}_visibility"
    local owner_var="${class_name}_${member_type}_owner"
    local visibility="public"
    local owner_class="$class_name"
    local current_frame=""
    local current_class=""
    local warn_key=""

    if ! declare -p "$visibility_var" &>/dev/null; then
        return 0
    fi

    local -n visibility_ref="$visibility_var"
    visibility="${visibility_ref[$member_name]:-public}"
    if [[ "$visibility" == "public" || -z "$visibility" ]]; then
        return 0
    fi

    if declare -p "$owner_var" &>/dev/null; then
        local -n owner_ref="$owner_var"
        owner_class="${owner_ref[$member_name]:-$class_name}"
    fi

    kv.frameCurrent >/dev/null 2>&1 || true
    current_frame="$RESULT"
    if [[ -n "$current_frame" ]]; then
        kv.frameClass "$current_frame" >/dev/null 2>&1 || true
        current_class="$RESULT"
    fi

    case "$visibility" in
        private)
            if [[ "$current_class" == "$owner_class" ]]; then
                return 0
            fi
            ;;
        protected)
            if [[ "$current_class" == "$owner_class" ]] || kk._class_derives_from "$current_class" "$owner_class"; then
                return 0
            fi
            ;;
        *)
            return 0
            ;;
    esac

    declare -gA __KK_VIS_WARNED
    warn_key="${current_class:-external}:${owner_class}:${member_type}:${member_name}:${visibility}"
    if [[ -n "${__KK_VIS_WARNED[$warn_key]:-}" ]]; then
        return 0
    fi

    __KK_VIS_WARNED["$warn_key"]=1
    echo "[kk] warning: ${visibility} ${member_type%_*} '${owner_class}.${member_name}' accessed from '${current_class:-external}'" >&2
}

# Text of one per-instance method wrapper (template form, __INST__ placeholder).
# Shared by the class build and by defineMethod (F3) so the latter can find and
# replace the exact wrapper the build emitted. Result in METHOD_WRAPPER.
kk._method_wrapper_text() {
    METHOD_WRAPPER=$'\n'"__INST__.$1() { kk._exec __INST__ $1 $2 \"\$@\"; }"
}

# Run a class's constructor body in the CURRENT frame (used by parent-constructor
# chaining). The body is looked up indirectly and eval'd — never embedded into a
# generated function, so a body containing quotes/semicolons is safe. Extra args
# become the constructor's positional parameters ($1, $2, ...).
kk._invoke_constructor() {
    local __kk_ctor_cls="$1"
    shift
    local __kk_ctor_var="${__kk_ctor_cls}_constructor_body"
    if [[ -n "${!__kk_ctor_var}" ]]; then
        eval "${!__kk_ctor_var}"
    fi
}

# ---------------------------------------------------------------------------
# Shared instance runtime (P4a). ONE copy per shell, not per instance: an
# instance is a data array, a class variable and one-line wrappers that call
# these with the instance name as the first argument. Before P4a every .new
# eval'd its own ~8 KB copy of all of this (dispatch, frames, accessors, find,
# call, parent, delete). Behaviour is unchanged; only the copies are gone.
# Every local here is __kk_-prefixed: a method body is eval'd inside
# kk._run_frame_body and sees the whole dynamic scope chain.

kk._property() {   # INST NAME [= VALUE]
    local -n __kk_d="${1}_data"
    if [[ "$3" == "=" ]]; then
        __kk_d["$2"]="$4"
    else
        # printf, not echo -e: values are data and must round-trip verbatim.
        printf '%s\n' "${__kk_d["$2"]}"
    fi
}

# Visibility gate shared by the accessors: a class whose every member is public
# (<Class>_has_nonpublic=0, set at endImplementation) skips the check entirely.
# Unset flag (a class built outside the declarative path) = do the full check.
kk._prop_plain() {   # INST CLASS PROP [= VALUE]
    local __kk_np="${2}_has_nonpublic"
    [[ "${!__kk_np:-1}" == "0" ]] || kk._warn_visibility "$2" property "$3"
    local -n __kk_d="${1}_data"
    if [[ "$4" == "=" ]]; then
        __kk_d["$3"]="$5"
    else
        printf '%s\n' "${__kk_d["$3"]}"
    fi
}

kk._prop_computed() {   # INST CLASS PROP GETTER SETTER [= VALUE]
    local __kk_np="${2}_has_nonpublic"
    [[ "${!__kk_np:-1}" == "0" ]] || kk._warn_visibility "$2" property "$3"
    local __kk_inst="$1" __kk_prop="$3" __kk_getter="$4" __kk_setter="$5"
    if [[ "$6" == "=" ]]; then
        if [[ -n "$__kk_setter" ]]; then
            kk._call "$__kk_inst" "$__kk_setter" "$7"
        else
            kk._property "$__kk_inst" "$__kk_prop" = "$7"
        fi
        return
    fi
    if [[ -z "$__kk_getter" ]]; then
        kk._property "$__kk_inst" "$__kk_prop"
        return
    fi
    # D1 (amended): a computed property follows the kk._return contract every
    # kcl unit relies on: a DIRECT read is silent and sets RESULT, a
    # $(obj.prop) capture prints the value exactly once. The getter chain runs
    # silent so no inner kk._return echoes; the single echo happens here, only
    # in a subshell and only if the caller was not already silent.
    local __kk_outer_silent="${__kk_return_silent:-0}"
    local __kk_return_silent=1
    kk._call "$__kk_inst" "$__kk_getter" || return $?
    if (( BASH_SUBSHELL > 0 )) && [[ "$__kk_outer_silent" != "1" ]]; then
        printf '%s' "$RESULT"
    fi
}

kk._prop_lazy() {   # INST CLASS PROP INIT SETTER [= VALUE]
    local __kk_np="${2}_has_nonpublic"
    [[ "${!__kk_np:-1}" == "0" ]] || kk._warn_visibility "$2" property "$3"
    local __kk_inst="$1" __kk_prop="$3" __kk_init="$4" __kk_setter="$5"
    if [[ "$6" == "=" ]]; then
        if [[ -n "$__kk_setter" ]]; then
            kk._call "$__kk_inst" "$__kk_setter" "$7"
        else
            kk._property "$__kk_inst" "$__kk_prop" = "$7"
        fi
        return
    fi
    local __kk_lv="${__kk_inst}_lazy_${__kk_prop}"
    if [[ ! -v "$__kk_lv" ]]; then
        local __kk_val
        __kk_val="$("${__kk_inst}.${__kk_init}")"
        declare -g "${__kk_lv}=${__kk_val}"
    fi
    printf '%s\n' "${!__kk_lv}"
}

# Run BODY with the instance context in scope: this/__inst__/__class__, the
# `state` nameref to the data array, one nameref per property (including
# inherited ones; the list is the one of the instance class) and one per
# static property (bound to the DEFINING class storage).
kk._run_frame_body() {   # INST ACTIVE_CLASS BODY ARGS...
    local __kk_inst="$1" __class__="$2" __kk_method_body="$3"
    shift 3
    local this="$__kk_inst"
    local __inst__="$__kk_inst"
    local -n state="${__kk_inst}_data"
    local __kk_cv="${__kk_inst}_class"
    local __kk_cls="${!__kk_cv}"
    local -n __kk_props="${__kk_cls}_class_properties"
    local __kk_p
    for __kk_p in "${__kk_props[@]}"; do
        local -n "${__kk_p}=${__kk_inst}_data[${__kk_p}]"
    done
    local -n __kk_sprops="${__kk_cls}_class_static_properties"
    if (( ${#__kk_sprops[@]} )); then
        local -n __kk_sowner="${__kk_cls}_class_static_property_owner"
        for __kk_p in "${__kk_sprops[@]}"; do
            local -n "${__kk_p}=${__kk_sowner[$__kk_p]:-$__kk_cls}_static_${__kk_p}"
        done
    fi

    eval "$__kk_method_body"
}

# Frame push/pop + RESULT protocol around one body execution. The frame
# push/pop is kv.framePush/kv.framePop inlined (P4b): same three kkore arrays,
# so kv.frameCurrent / kv.frameClass in kk._parent and kk._warn_visibility see
# exactly the same stack — minus three function calls per method call. The
# body must stay in its own function (kk._run_frame_body): a `return` inside
# it must come back HERE so the frame is always popped.
kk._invoke() {   # INST ACTIVE_CLASS BODY ARGS...
    local __kk_inst="$1" __kk_active_class="$2" __kk_body="$3"
    shift 3
    local this="$__kk_inst"
    local __kk_caller_result="$RESULT"
    local __kk_return_set=0
    local __kk_return_value=""
    local __kk_frame_id=${#__KLIB_FRAME_STACK[@]}
    __KLIB_FRAME_STACK[__kk_frame_id]=$__kk_frame_id
    __KLIB_FRAME_INSTANCE[__kk_frame_id]="$__kk_inst"
    __KLIB_FRAME_CLASS[__kk_frame_id]="$__kk_active_class"

    kk._run_frame_body "$__kk_inst" "$__kk_active_class" "$__kk_body" "$@"
    local __kk_status=$?

    unset "__KLIB_FRAME_STACK[$__kk_frame_id]" "__KLIB_FRAME_INSTANCE[$__kk_frame_id]" "__KLIB_FRAME_CLASS[$__kk_frame_id]"
    if (( __kk_return_set )); then
        RESULT="$__kk_return_value"
    else
        RESULT="$__kk_caller_result"
    fi
    return $__kk_status
}

# Static dispatch used by the per-instance method wrappers: the wrapper names
# the DEFINING class (owner) of the method, so `inherited`/.parent inside the
# body walks up from where the body was defined (Pascal semantics).
kk._exec() {   # INST METHOD OWNER ARGS...
    local __kk_inst="$1" __kk_m="$2" __kk_owner="$3"
    shift 3
    local __kk_bv="${__kk_owner}_method_body_${__kk_m}"
    local __kk_body="${!__kk_bv}"
    if [[ -z "$__kk_body" ]]; then
        echo "Error: Method '$__kk_m' not found in class '$__kk_owner'" >&2
        return 1
    fi
    local __kk_np="${__kk_owner}_has_nonpublic"
    [[ "${!__kk_np:-1}" == "0" ]] || kk._warn_visibility "$__kk_owner" method "$__kk_m"
    kk._invoke "$__kk_inst" "$__kk_owner" "$__kk_body" "$@"
}

# Find the first class in the chain starting at SEARCH_CLASS that holds a body
# for METHOD. Result in __kk_find_class (empty = not found), no fork.
kk._find_method() {   # METHOD SEARCH_CLASS
    local __kk_m="$1" __kk_cls="$2"
    local __kk_bv="${__kk_cls}_method_body_${__kk_m}"
    __kk_find_class=""
    if [[ -n "${!__kk_bv}" ]]; then
        __kk_find_class="$__kk_cls"
        return 0
    fi
    local __kk_pv="${__kk_cls}_parent_class"
    local __kk_parent="${!__kk_pv}"
    while [[ -n "$__kk_parent" ]]; do
        __kk_bv="${__kk_parent}_method_body_${__kk_m}"
        if [[ -n "${!__kk_bv}" ]]; then
            __kk_find_class="$__kk_parent"
            return 0
        fi
        __kk_pv="${__kk_parent}_parent_class"
        __kk_parent="${!__kk_pv}"
    done
    return 1
}

# VIRTUAL dispatch (Pascal semantics): resolve from the own class of the
# instance so subclass overrides win even from inside an inherited body; the
# resolved class is mapped to the DEFINING class so nested `inherited`
# continues from the right level.
kk._call() {   # INST METHOD ARGS...
    local __kk_inst="$1" __kk_m="$2"
    shift 2
    local __kk_cv="${__kk_inst}_class"
    local __kk_search="${!__kk_cv}"

    local __kk_cache_cell="${__kk_search}_method_cache[${__kk_m}]"
    local __kk_found="${!__kk_cache_cell}"
    if [[ -z "$__kk_found" ]]; then
        kk._find_method "$__kk_m" "$__kk_search"
        __kk_found="$__kk_find_class"
        if [[ -z "$__kk_found" ]]; then
            echo "Error: Method '$__kk_m' not found in class hierarchy" >&2
            return 1
        fi
        local __kk_ov="${__kk_found}_class_method_owner[${__kk_m}]"
        [[ -n "${!__kk_ov}" ]] && __kk_found="${!__kk_ov}"
        local -n __kk_cache="${__kk_search}_method_cache"
        __kk_cache["$__kk_m"]="$__kk_found"
    fi

    local __kk_bv="${__kk_found}_method_body_${__kk_m}"
    local __kk_np="${__kk_found}_has_nonpublic"
    [[ "${!__kk_np:-1}" == "0" ]] || kk._warn_visibility "$__kk_found" method "$__kk_m"
    kk._invoke "$__kk_inst" "$__kk_found" "${!__kk_bv}" "$@"
}

# `inherited` / $this.parent: STATIC resolution from the parent of the class
# that owns the CURRENTLY RUNNING body (frame class), not of the instance.
kk._parent() {   # INST METHOD ARGS...
    local __kk_inst="$1" __kk_m="$2"
    shift 2
    # Internal dispatch (see kk._call): result via RESULT, no echo.
    local __kk_return_silent=1
    local __kk_cv="${__kk_inst}_class"
    local __kk_active="${!__kk_cv}"
    local __kk_frame=""
    kv.frameCurrent >/dev/null 2>&1 || true
    __kk_frame="$RESULT"
    if [[ -n "$__kk_frame" ]]; then
        kv.frameClass "$__kk_frame"
        __kk_active="$RESULT"
    fi

    local __kk_pv="${__kk_active}_parent_class"
    local __kk_parent_of="${!__kk_pv}"
    if [[ -z "$__kk_parent_of" ]]; then
        echo "Error: No parent class for '${__kk_active}'" >&2
        return 1
    fi

    local __kk_key="${__kk_active}_parent_${__kk_m}"
    local __kk_cache_cell="${__kk_active}_method_cache[${__kk_key}]"
    local __kk_found="${!__kk_cache_cell}"
    if [[ -z "$__kk_found" ]]; then
        kk._find_method "$__kk_m" "$__kk_parent_of"
        __kk_found="$__kk_find_class"
        if [[ -z "$__kk_found" ]]; then
            echo "Error: Parent method '$__kk_m' not found" >&2
            return 1
        fi
        local __kk_ov="${__kk_found}_class_method_owner[${__kk_m}]"
        [[ -n "${!__kk_ov}" ]] && __kk_found="${!__kk_ov}"
        local -n __kk_cache="${__kk_active}_method_cache"
        __kk_cache["$__kk_key"]="$__kk_found"
    fi

    local __kk_bv="${__kk_found}_method_body_${__kk_m}"
    local __kk_np="${__kk_found}_has_nonpublic"
    [[ "${!__kk_np:-1}" == "0" ]] || kk._warn_visibility "$__kk_found" method "$__kk_m"
    kk._invoke "$__kk_inst" "$__kk_found" "${!__kk_bv}" "$@"
}

# Run the class constructor body (if any) in a frame of CLASS.
kk._constructor_exec() {   # INST CLASS ARGS...
    local __kk_inst="$1" __kk_cls="$2"
    shift 2
    local __kk_bv="${__kk_cls}_constructor_body"
    [[ -n "${!__kk_bv}" ]] || return 0
    kk._invoke "$__kk_inst" "$__kk_cls" "${!__kk_bv}" "$@"
}

# Destroy an instance: destructor (if the class declares one), lazy globals,
# data + class vars, every per-instance wrapper. The wrapper list comes from
# the class tables (props + methods + the four fixed ones), so it also covers
# methods added later with defineMethod. No fork, no compgen (F1).
kk._delete() {   # INST
    local __kk_inst="$1"
    local __kk_cv="${__kk_inst}_class"
    local __kk_cls="${!__kk_cv}"
    local __kk_dv="${__kk_cls}_destructor_name"
    local __kk_dtor="${!__kk_dv}"
    [[ -n "$__kk_dtor" ]] && kk._call "$__kk_inst" "$__kk_dtor"

    local -n __kk_ms="${__kk_cls}_class_methods"
    local -n __kk_ps="${__kk_cls}_class_properties"
    local -n __kk_lz="${__kk_cls}_lazy_inits"
    local __kk_x
    for __kk_x in "${!__kk_lz[@]}"; do unset "${__kk_inst}_lazy_${__kk_x}"; done
    unset "${__kk_inst}_data" "${__kk_inst}_class"
    local -a __kk_fns=("${__kk_inst}.property" "${__kk_inst}.call" "${__kk_inst}.parent" "${__kk_inst}.delete")
    for __kk_x in "${__kk_ms[@]}" "${__kk_ps[@]}"; do
        __kk_fns+=("${__kk_inst}.${__kk_x}")
    done
    unset -f "${__kk_fns[@]}"
}

kk._build_class_runtime() {
    local class_name="$1"
    local parent_class="$2"
    shift 2

    # SECURITY: class_name, parent_class and every member name below are
    # interpolated into eval'd metadata assignments and generated function
    # names. The declarative defineClass path validates these before calling
    # us, but this function is also reachable directly and via other builders,
    # so validate here too (defense in depth). Reject anything that is not a
    # plain bash identifier.
    if [[ -z "$class_name" ]]; then
        echo "kk._build_class_runtime: class name is required" >&2
        return 1
    fi
    kk.decl._validate_ident "$class_name" "class name" || return 1
    kk.decl._validate_ident "$parent_class" "parent class name" || return 1

    # Duplicate-name protection. Refuse to build over a class that a DIFFERENT
    # file already registered — an accidental second definition (same class in
    # two files) or a user class colliding with a library one. This check runs
    # BEFORE any runtime state is created/replaced below, so the already-built
    # original class is left fully intact. A rebuild from the SAME file (a
    # diamond include, or a deliberate re-source) is allowed to proceed.
    local __kk_caller_src
    kk._check_class_owner "$class_name" register || return 1

    # Collect properties and methods (including inherited)
    local -a props_arr=()
    local -a meths_arr=()
    local -A meth_bodies
    local -A meth_index  # For fast lookup
    local -A meth_owner=()  # method -> DEFINING class (Pascal 'inherited' semantics)
    local -A own_raw_bodies=()  # methods declared HERE: raw body, processed after the parse (F11)
    local -A own_meth_type=()
    local constructor_body=""
    
    # Static members support (lazy initialization)
    local has_static_members=false
    local -a static_props_arr=()
    local -a static_meths_arr=()
    local -A static_meth_bodies
    local -A static_prop_owner=()
    local -A static_prop_index=()
    local -A static_meth_owner=()
    local -A static_meth_index=()
    
    # Computed and lazy properties support
    local -A computed_getters=()
    local -A computed_setters=()
    local -A lazy_inits=()

    # Inherit from parent class if specified
    if [[ -n "$parent_class" ]]; then
        # Copy parent properties using name reference (bash 4.3+)
        local parent_props_var="${parent_class}_class_properties"
        if declare -p "$parent_props_var" &>/dev/null; then
            local -n parent_props_ref="$parent_props_var"
            props_arr+=("${parent_props_ref[@]}")
        fi

        # Copy parent methods using name reference
        local parent_meths_var="${parent_class}_class_methods"
        if declare -p "$parent_meths_var" &>/dev/null; then
            local -n parent_meths_ref="$parent_meths_var"
            meths_arr+=("${parent_meths_ref[@]}")

            # Copy parent method bodies and index. The OWNER (defining class)
            # travels along: for a method the parent itself inherited, keep the
            # original defining class, not the parent.
            for m in "${parent_meths_ref[@]}"; do
                local parent_body_var="${parent_class}_method_body_${m}"
                meth_bodies["$m"]="${!parent_body_var}"
                meth_index["$m"]=1
                local parent_owner_var="${parent_class}_class_method_owner[$m]"
                meth_owner["$m"]="${!parent_owner_var:-$parent_class}"
            done
        fi

        local parent_getters_var="${parent_class}_computed_getters"
        if declare -p "$parent_getters_var" &>/dev/null; then
            local -n parent_getters_ref="$parent_getters_var"
            for p in "${!parent_getters_ref[@]}"; do
                computed_getters["$p"]="${parent_getters_ref[$p]}"
            done
        fi

        local parent_setters_var="${parent_class}_computed_setters"
        if declare -p "$parent_setters_var" &>/dev/null; then
            local -n parent_setters_ref="$parent_setters_var"
            for p in "${!parent_setters_ref[@]}"; do
                computed_setters["$p"]="${parent_setters_ref[$p]}"
            done
        fi

        local parent_lazy_var="${parent_class}_lazy_inits"
        if declare -p "$parent_lazy_var" &>/dev/null; then
            local -n parent_lazy_ref="$parent_lazy_var"
            for p in "${!parent_lazy_ref[@]}"; do
                lazy_inits["$p"]="${parent_lazy_ref[$p]}"
            done
        fi

        local parent_static_props_var="${parent_class}_class_static_properties"
        local parent_static_prop_owner_var="${parent_class}_class_static_property_owner"
        if declare -p "$parent_static_props_var" &>/dev/null; then
            local -n parent_static_props_ref="$parent_static_props_var"
            local -n parent_static_prop_owner_ref="$parent_static_prop_owner_var"
            local inherited_static_prop
            for inherited_static_prop in "${parent_static_props_ref[@]}"; do
                if [[ -z "${static_prop_index[$inherited_static_prop]+x}" ]]; then
                    static_props_arr+=("$inherited_static_prop")
                    static_prop_index["$inherited_static_prop"]=1
                fi
                static_prop_owner["$inherited_static_prop"]="${parent_static_prop_owner_ref[$inherited_static_prop]:-$parent_class}"
            done
            if (( ${#parent_static_props_ref[@]} > 0 )); then
                has_static_members=true
            fi
        fi

        local parent_static_meths_var="${parent_class}_class_static_methods"
        local parent_static_meth_owner_var="${parent_class}_class_static_method_owner"
        if declare -p "$parent_static_meths_var" &>/dev/null; then
            local -n parent_static_meths_ref="$parent_static_meths_var"
            local -n parent_static_meth_owner_ref="$parent_static_meth_owner_var"
            local inherited_static_method
            for inherited_static_method in "${parent_static_meths_ref[@]}"; do
                if [[ -z "${static_meth_index[$inherited_static_method]+x}" ]]; then
                    static_meths_arr+=("$inherited_static_method")
                    static_meth_index["$inherited_static_method"]=1
                fi
                static_meth_owner["$inherited_static_method"]="${parent_static_meth_owner_ref[$inherited_static_method]:-$parent_class}"
                local static_body_owner="${static_meth_owner[$inherited_static_method]}"
                local parent_static_body_var="${static_body_owner}_static_method_body_${inherited_static_method}"
                static_meth_bodies["$inherited_static_method"]="${!parent_static_body_var}"
            done
            if (( ${#parent_static_meths_ref[@]} > 0 )); then
                has_static_members=true
            fi
        fi
    fi

    # Parse class definition (can override parent methods)
    while [[ $# -gt 0 ]]; do
        case "$1" in
            static_property)
                kk.decl._validate_ident "$2" "static property name" || return 1
                has_static_members=true
                if [[ -z "${static_prop_index[$2]+x}" ]]; then
                    static_props_arr+=("$2")
                    static_prop_index["$2"]=1
                fi
                static_prop_owner["$2"]="$class_name"
                shift 2
                ;;
            static_method)
                kk.decl._validate_ident "$2" "static method name" || return 1
                has_static_members=true
                if [[ -z "${static_meth_index[$2]+x}" ]]; then
                    static_meths_arr+=("$2")
                    static_meth_index["$2"]=1
                fi
                static_meth_owner["$2"]="$class_name"
                static_meth_bodies["$2"]="$3"
                shift 3
                ;;
            property)
                kk.decl._validate_ident "$2" "property name" || return 1
                local prop_name="$2"
                props_arr+=("$prop_name")
                shift 2
                
                # Check if next arguments are getter/setter methods
                # Method names starting with "get" or "set" are treated as computed accessors
                # Consume following getter/setter methods until we hit a keyword or non-accessor
                local keyword_str=" property static_property static_method method procedure function lazy_property constructor "
                while [[ $# -gt 0 ]]; do
                    # Peek at next argument
                    local peek_arg="$1"
                    
                    # Check if it's a keyword
                    if [[ "$keyword_str" == *" $peek_arg "* ]]; then
                        break
                    fi
                    
                    # Check if it's a getter/setter by prefix
                    # Allows both "get"/"set" and "_get"/"_set"
                    case "$peek_arg" in
                        get* | _get*)
                            kk.decl._validate_ident "$peek_arg" "getter name" || return 1
                            computed_getters["$prop_name"]="$peek_arg"
                            shift
                            ;;
                        set* | _set*)
                            kk.decl._validate_ident "$peek_arg" "setter name" || return 1
                            computed_setters["$prop_name"]="$peek_arg"
                            shift
                            ;;
                        *)
                            # Not a getter/setter, stop processing
                            break
                            ;;
                    esac
                done
                ;;
            lazy_property)
                # usage: lazy_property PROP INIT_METHOD
                kk.decl._validate_ident "$2" "lazy property name" || return 1
                kk.decl._validate_ident "$3" "lazy init method name" || return 1
                props_arr+=("$2")
                lazy_inits["$2"]="$3"
                shift 3
                ;;
            method|procedure|function)
                kk.decl._validate_ident "$2" "method name" || return 1
                local meth_type="$1"
                # Check if method already exists (override) using fast lookup
                if [[ -z "${meth_index[$2]}" ]]; then
                    meths_arr+=("$2")
                    meth_index["$2"]=1
                fi
                # Declared (or overridden) here: this class is the defining one.
                meth_owner["$2"]="$class_name"

                # Keep the raw body; the $this.method rewrite runs after the
                # whole definition is parsed so it sees methods declared LATER
                # in the same class too (F11).
                own_raw_bodies["$2"]="$3"
                own_meth_type["$2"]="$meth_type"
                shift 3
                ;;
            constructor)
                # Store constructor body for processing later (after all methods are collected)
                constructor_body="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    # Process the bodies declared here against the COMPLETE method list.
    local __kk_om
    for __kk_om in "${!own_raw_bodies[@]}"; do
        kk._processMethodBody "$class_name" "$__kk_om" "${own_raw_bodies[$__kk_om]}" "${own_meth_type[$__kk_om]}" "meths_arr"
        meth_bodies["$__kk_om"]="$METHOD_BODY"
    done

    # Store class metadata for inheritance
    eval "${class_name}_class_properties=(\"\${props_arr[@]}\")"
    eval "${class_name}_class_methods=(\"\${meths_arr[@]}\")"
    eval "${class_name}_class_static_properties=(\"\${static_props_arr[@]}\")"
    eval "${class_name}_class_static_methods=(\"\${static_meths_arr[@]}\")"
    eval "declare -gA ${class_name}_class_static_property_owner=()"
    eval "declare -gA ${class_name}_class_static_method_owner=()"
    eval "${class_name}_parent_class=\"$parent_class\""
    for p in "${!static_prop_owner[@]}"; do
        eval "${class_name}_class_static_property_owner[\"$p\"]=\"${static_prop_owner[$p]}\""
    done
    for m in "${!static_meth_owner[@]}"; do
        eval "${class_name}_class_static_method_owner[\"$m\"]=\"${static_meth_owner[$m]}\""
    done
    # Instance-method owners (defining class of each body) — the anchor for
    # Pascal-correct `inherited`/.parent resolution.
    eval "declare -gA ${class_name}_class_method_owner=()"
    for m in "${!meth_owner[@]}"; do
        eval "${class_name}_class_method_owner[\"$m\"]=\"${meth_owner[$m]}\""
    done
    
    # Store computed property getters/setters
    eval "declare -gA ${class_name}_computed_getters"
    eval "declare -gA ${class_name}_computed_setters"
    for p in "${!computed_getters[@]}"; do
        eval "${class_name}_computed_getters[\"$p\"]=\"${computed_getters[$p]}\""
    done
    for p in "${!computed_setters[@]}"; do
        eval "${class_name}_computed_setters[\"$p\"]=\"${computed_setters[$p]}\""
    done
    eval "declare -gA ${class_name}_lazy_inits"
    for p in "${!lazy_inits[@]}"; do
        eval "${class_name}_lazy_inits[\"$p\"]=\"${lazy_inits[$p]}\""
    done
    
    # Create method resolution cache for performance
    eval "declare -gA ${class_name}_method_cache"
    
    for m in "${meths_arr[@]}"; do
        eval "${class_name}_method_body_${m}=\${meth_bodies[\$m]}"

        # Pre-populate cache: method resolves to its DEFINING class (owner), so
        # dispatch pushes the owner as the frame class and `inherited`/.parent
        # inside the body walks up from where the body was defined (Pascal
        # semantics), not from the instance's class.
        eval "${class_name}_method_cache[\"${m}\"]=\"${meth_owner[$m]:-$class_name}\""
    done

    for m in "${static_meths_arr[@]}"; do
        eval "${class_name}_static_method_body_${m}=\${static_meth_bodies[\$m]}"
    done
    
    # Process constructor body to replace $this.METHOD calls (after all methods are collected)
    # Note: Unlike regular methods, constructor doesn't need the local this/local __inst__ setup
    # because __inst__ is provided by the .new() function
    if [[ -n "$constructor_body" ]]; then
        # Replace all $this.METHOD_NAME patterns with $__inst__.call METHOD_NAME
        for wm in "${meths_arr[@]}"; do
            # Replace $this.method with proper call syntax
            constructor_body="${constructor_body//\$this.${wm}/\$__inst__.call ${wm}}"
            # Also handle ${this}.method syntax
            constructor_body="${constructor_body//\$\{this\}.${wm}/\$__inst__.call ${wm}}"
        done
    fi

    # ---- instance template (P4a) -------------------------------------------
    # An instance is: its data array, its class variable and ONE-LINE wrappers
    # that forward to the shared kk._* runtime with the instance name as the
    # first argument. `__INST__` is replaced by the (validated) instance name at
    # .new time. Nothing else is generated per instance any more.
    local prop_funcs=""
    for p in "${props_arr[@]}"; do
        if [[ -n "${computed_getters[$p]:-}${computed_setters[$p]:-}" ]]; then
            prop_funcs+=$'\n'"__INST__.$p() { kk._prop_computed __INST__ $class_name $p '${computed_getters[$p]:-}' '${computed_setters[$p]:-}' \"\$@\"; }"
        elif [[ -n "${lazy_inits[$p]:-}" ]]; then
            prop_funcs+=$'\n'"__INST__.$p() { kk._prop_lazy __INST__ $class_name $p ${lazy_inits[$p]} '' \"\$@\"; }"
        else
            prop_funcs+=$'\n'"__INST__.$p() { kk._prop_plain __INST__ $class_name $p \"\$@\"; }"
        fi
    done

    local meth_funcs=""
    for m in "${meths_arr[@]}"; do
        # The wrapper names the DEFINING class (owner) of the method, see kk._exec.
        kk._method_wrapper_text "$m" "${meth_owner[$m]:-$class_name}"
        meth_funcs+="$METHOD_WRAPPER"
    done

    local parent_func=""
    if [[ -n "$parent_class" ]]; then
        parent_func=$'\n'"__INST__.parent() { kk._parent __INST__ \"\$@\"; }"
    fi

    local instance_template
    instance_template="declare -gA __INST___data
__INST___class=\"${class_name}\"
__INST__.property() { kk._property __INST__ \"\$@\"; }${prop_funcs}${meth_funcs}
__INST__.call() { kk._call __INST__ \"\$@\"; }${parent_func}
__INST__.delete() { kk._delete __INST__ \"\$@\"; }"

    # Store template for this class (.new evals it; the compiler dumps it)
    eval "${class_name}_instance_template=\$instance_template"

    # Process constructor body to support parent.constructor syntax
    if [[ -n "$parent_class" && "$constructor_body" == *"parent.constructor"* ]]; then
        # Replace parent.constructor with actual parent class constructor call
        constructor_body="${constructor_body//parent.constructor/${parent_class}.constructor}"
    fi
    
    # Store constructor body
    eval "${class_name}_constructor_body=\$constructor_body"
    
    # Create static members if needed (lazy approach)
    if [[ "$has_static_members" == "true" ]]; then
        # Initialize static properties as global variables
        for sp in "${static_props_arr[@]}"; do
            local static_owner="${static_prop_owner[$sp]:-$class_name}"
            if [[ "$static_owner" == "$class_name" ]]; then
                eval "${class_name}_static_${sp}=\"\""
            fi
        done
        
        # Create static property accessors: Class.property = value / Class.property
        for sp in "${static_props_arr[@]}"; do
            local static_owner="${static_prop_owner[$sp]:-$class_name}"
            eval "${class_name}.${sp}() {
                if [[ \"\$1\" == \"=\" ]]; then
                    ${static_owner}_static_${sp}=\"\$2\"
                else
                    echo \"\${${static_owner}_static_${sp}}\"
                fi
            }"
        done
        
        # Create static methods: Class.method args
        #
        # The body ALWAYS lives in its own function Class.__static_NAME (F5): a
        # `return N` inside it then comes back to the wrapper, which finishes
        # its bookkeeping and returns N. Before, the body was inlined into the
        # wrapper, so `return` aborted the wrapper mid-way: the 5.2 path leaked
        # its scratch file and lost stdout, the 5.3 funsub path swallowed the
        # status, and a failing last command reported printf's 0 on both.
        # Static-property namerefs are declared in the wrapper and reach the
        # body through bash's dynamic scoping.
        #
        # Two dispatcher shapes (pinned by test 114):
        #   * no static properties -> THIN: stdout flows straight through, no
        #     capture, no fork on any bash version (the string.* utility path).
        #   * static properties    -> CAPTURING: stdout is captured into REPLY
        #     and re-printed. REPLY is the return channel for a STATEFUL static
        #     method (a singleton's getInstance, test 026): `$(Class.m)` would
        #     run it in a subshell and lose the state mutation, so callers do
        #     `Class.m >/dev/null; use "$REPLY"`. bash 5.3+ captures with a
        #     funsub (no fork); 5.2 uses a scratch file (as before).
        local __kk_has_funsub=0
        if (( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 3) )); then
            __kk_has_funsub=1
        fi

        for sm in "${static_meths_arr[@]}"; do
            local sm_body="${static_meth_bodies[$sm]}"
            local static_namerefs=""
            for sp in "${static_props_arr[@]}"; do
                local static_owner="${static_prop_owner[$sp]:-$class_name}"
                static_namerefs+="local -n $sp=${static_owner}_static_${sp}; "
            done

            eval "${class_name}.__static_${sm}() {
                ${sm_body}
            }"

            if (( ${#static_props_arr[@]} == 0 )); then
                eval "${class_name}.${sm}() {
                    local __kk_return_set=0
                    local __kk_return_value=\"\"
                    local __kk_return_silent=1
                    ${class_name}.__static_${sm} \"\$@\"
                    local __kk_status=\$?
                    if (( __kk_return_set )); then
                        printf \"%s\" \"\$__kk_return_value\"
                    fi
                    return \$__kk_status
                }"
            elif (( __kk_has_funsub )); then
                # The assignment's status is the funsub's status = the body's.
                eval "${class_name}.${sm}() {
                    ${static_namerefs}
                    local __kk_return_set=0
                    local __kk_return_value=\"\"
                    local __kk_return_silent=1
                    REPLY=\${ ${class_name}.__static_${sm} \"\$@\"; }
                    local __kk_status=\$?
                    if (( __kk_return_set )); then
                        REPLY+=\"\$__kk_return_value\"
                    fi
                    printf \"%s\" \"\$REPLY\"
                    return \$__kk_status
                }"
            else
                eval "${class_name}.${sm}() {
                    ${static_namerefs}
                    local __kk_return_set=0
                    local __kk_return_value=\"\"
                    local __kk_return_silent=1
                    local __kk_static_out=\"\${TMPDIR:-/tmp}/.kk_static_\${BASHPID}_\${RANDOM}\${RANDOM}\"
                    ${class_name}.__static_${sm} \"\$@\" >\"\$__kk_static_out\"
                    local __kk_status=\$?
                    REPLY=\"\$(<\"\$__kk_static_out\")\"
                    rm -f \"\$__kk_static_out\"
                    if (( __kk_return_set )); then
                        REPLY+=\"\$__kk_return_value\"
                    fi
                    printf \"%s\" \"\$REPLY\"
                    return \$__kk_status
                }"
            fi
        done
    fi
    
    # Constructor function: materialize the instance by substituting the
    # (validated) instance name into the class template with a pure-bash
    # replacement and eval'ing it (no fork). Methods added later with
    # defineMethod are already in the template (F3), so nothing else to do.
    eval "${class_name}.new() {
        local instname=\"\$1\"
        shift
        [[ \"\$instname\" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || { echo \"Invalid instance name: \$instname\" >&2; return 1; }
        eval \"\${${class_name}_instance_template//__INST__/\$instname}\"

        if [[ -n \"\$${class_name}_constructor_body\" ]]; then
            local __inst__=\"\$instname\"
            kk._constructor_exec \"\$instname\" \"${class_name}\" \"\$@\"
        fi
    }"

    # Constructor caller for explicit parent-constructor chaining. A thin wrapper
    # to the generic helper — the body is never embedded here (a body with quotes
    # or semicolons would otherwise corrupt this generated function).
    eval "${class_name}.constructor() { kk._invoke_constructor ${class_name} \"\$@\"; }"

    if [[ "${VERBOSE_KKLASS:-1}" == "debug" ]]; then echo "$class_name class created"; fi
}

defineClass() {
    local class_name="$1"
    local parent_class="$2"
    local -a declared_methods=()
    local -A declared_method_seen=()
    local -A declared_method_body=()
    local constructor_body=""
    local keyword_str=" property static_property static_method method procedure function lazy_property constructor "

    [[ -n "$class_name" ]] || {
        echo "defineClass: Usage: defineClass CLASS_NAME PARENT_CLASS [definition tokens...]" >&2
        return 1
    }

    shift 2

    declareClass "$class_name" "$parent_class" || return 1

    while [[ $# -gt 0 ]]; do
        case "$1" in
            static_property)
                kk.decl._remember_static_property "$class_name" "$2" || return 1
                shift 2
                ;;
            static_method)
                kk.decl._remember_static_method "$class_name" "$2" "$3" || return 1
                shift 3
                ;;
            property)
                local prop_name="$2"
                local -a prop_decl=("$prop_name")
                local has_read_accessor=0
                local has_write_accessor=0
                shift 2

                while [[ $# -gt 0 ]]; do
                    local peek_arg="$1"
                    if [[ "$keyword_str" == *" $peek_arg "* ]]; then
                        break
                    fi

                    case "$peek_arg" in
                        get*|_get*)
                            prop_decl+=("read" "$peek_arg")
                            has_read_accessor=1
                            shift
                            ;;
                        set*|_set*)
                            prop_decl+=("write" "$peek_arg")
                            has_write_accessor=1
                            shift
                            ;;
                        *)
                            break
                            ;;
                    esac
                done

                if (( has_read_accessor )) && (( ! has_write_accessor )); then
                    prop_decl+=("write" "$prop_name")
                elif (( has_write_accessor )) && (( ! has_read_accessor )); then
                    prop_decl+=("read" "$prop_name")
                fi

                property "${prop_decl[@]}" || return 1
                ;;
            lazy_property)
                kk.decl._remember_lazy_property "$class_name" "$2" "$3" || return 1
                shift 3
                ;;
            method|procedure|function)
                local legacy_kind="$1"
                local method_name="$2"
                local method_body="$3"

                if [[ "$legacy_kind" == "function" ]]; then
                    func "$method_name" || return 1
                else
                    procedure "$method_name" || return 1
                fi

                if [[ -z "${declared_method_seen[$method_name]:-}" ]]; then
                    declared_methods+=("$method_name")
                    declared_method_seen["$method_name"]=1
                fi
                declared_method_body["$method_name"]="$method_body"
                shift 3
                ;;
            constructor)
                constructor || return 1
                constructor_body="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    endClass || return 1

    local method_name
    for method_name in "${declared_methods[@]}"; do
        implement "$class_name.$method_name" "${declared_method_body[$method_name]}" || return 1
    done

    if [[ -n "$constructor_body" ]]; then
        implementConstructor "$class_name" "$constructor_body" || return 1
    fi

    endImplementation "$class_name"
}

_defineMethodType() {
    local class_name="$1"
    local method_name="$2"
    local method_body="$3"
    local meth_type="${4:-method}"
    local func_name="${5:-Method}"
    
    # Validate inputs
    [[ -z "$class_name" || -z "$method_name" || -z "$method_body" ]] && {
        echo "define${func_name}: Usage: define${func_name} CLASS_NAME METHOD_NAME BODY" >&2
        return 1
    }
    
    # Check if class exists
    local class_meths_var="${class_name}_class_methods"
    if ! declare -p "$class_meths_var" &>/dev/null; then
        echo "define${func_name}: Class '$class_name' does not exist" >&2
        return 1
    fi
    
    # Get existing methods array
    local -n meths_ref="${class_name}_class_methods"
    local -A meth_index
    
    # Build index of existing methods
    for m in "${meths_ref[@]}"; do
        meth_index["$m"]=1
    done
    
    # Check if method already exists (will override it)
    if [[ -z "${meth_index[$method_name]}" ]]; then
        meths_ref+=("$method_name")
    fi
    
    # Process method body using shared logic from defineClass
    kk._processMethodBody "$class_name" "$method_name" "$method_body" "$meth_type" "meths_ref"
    eval "${class_name}_method_body_${method_name}=\$METHOD_BODY"

    # Update class methods array in global scope
    eval "${class_name}_class_methods=(\"\${meths_ref[@]}\")"

    # F3: this class now DEFINES the method. For an INHERITED method the
    # template wrapper and the .call cache still named the parent as owner, so
    # the new body was silently ignored. Re-point owner + cache, and rewrite
    # (or add) the wrapper in the instance template so new instances get it.
    declare -p "${class_name}_class_method_owner" &>/dev/null || eval "declare -gA ${class_name}_class_method_owner=()"
    declare -p "${class_name}_method_cache" &>/dev/null || eval "declare -gA ${class_name}_method_cache=()"
    local -n __kk_dm_owner_ref="${class_name}_class_method_owner"
    local -n __kk_dm_cache_ref="${class_name}_method_cache"
    local -n __kk_dm_tpl_ref="${class_name}_instance_template"
    local __kk_dm_old_owner="${__kk_dm_owner_ref[$method_name]:-$class_name}"
    __kk_dm_owner_ref["$method_name"]="$class_name"
    __kk_dm_cache_ref["$method_name"]="$class_name"
    kk._method_wrapper_text "$method_name" "$__kk_dm_old_owner"
    local __kk_dm_old_wrapper="$METHOD_WRAPPER"
    kk._method_wrapper_text "$method_name" "$class_name"
    local __kk_dm_new_wrapper="$METHOD_WRAPPER"
    if [[ "$__kk_dm_tpl_ref" == *"$__kk_dm_old_wrapper"* ]]; then
        __kk_dm_tpl_ref="${__kk_dm_tpl_ref/"$__kk_dm_old_wrapper"/$__kk_dm_new_wrapper}"
    else
        __kk_dm_tpl_ref="${__kk_dm_tpl_ref/__INST__.delete() \{/${__kk_dm_new_wrapper}
__INST__.delete() \{}"
    fi

    # Known limitation: subclasses built BEFORE this call carry their own copy
    # of the method table (bodies are copied down at build time) and keep
    # resolving to what they copied. Say so once per affected subclass.
    local __kk_dm_sub __kk_dm_pv
    for __kk_dm_sub in "${!_KKLASS_CLASS_SOURCE[@]}"; do
        __kk_dm_pv="${__kk_dm_sub}_parent_class"
        if [[ "${!__kk_dm_pv:-}" == "$class_name" ]]; then
            echo "[kk] warning: define${func_name} ${class_name}.${method_name}: subclass '${__kk_dm_sub}' was built earlier and does not pick up this change" >&2
        fi
    done
    
    if [[ "${VERBOSE_KKLASS:-1}" == "debug" ]]; then 
        echo "${func_name} '$method_name' added to class '$class_name'"
    fi
}

defineMethod() {
    _defineMethodType "$1" "$2" "$3" "method" "Method"
}

defineProcedure() {
    _defineMethodType "$1" "$2" "$3" "procedure" "Procedure"
}

defineFunction() {
    _defineMethodType "$1" "$2" "$3" "function" "Function"
}

kk.register_static_methods() {
    local class_name="$1"
    local public_prefix="$2"
    local display_name="${3:-$1}"
    shift 3

    local -a method_names=("$@")
    local -a class_args=()
    local method_name public_name impl_name method_decl

    for method_name in "${method_names[@]}"; do
        public_name="${public_prefix}.${method_name}"
        impl_name="${public_prefix}.__impl_${method_name}"

        if ! declare -F "$public_name" >/dev/null; then
            echo "Error: ${display_name} method '$public_name' is not defined" >&2
            return 1
        fi

        method_decl="$(declare -f "$public_name")"
        method_decl="${method_decl#*$'\n'}"
        eval "${impl_name}() ${method_decl}"
        class_args+=("static_method" "$method_name" "${impl_name} \"\$@\"")
    done

    defineClass "$class_name" "" "${class_args[@]}" || return 1

    for method_name in "${method_names[@]}"; do
        public_name="${public_prefix}.${method_name}"
        impl_name="${public_prefix}.__impl_${method_name}"
        eval "${public_name}() { ${impl_name} \"\$@\"; }"
    done
}

source "${KKLASS_DIR}/kklass_decl.sh"

if [[ "${KKLASS_EXPORT_FUNCTIONS:-0}" == "1" ]]; then
    export -f kk._processMethodBody kk.call_silent kk._class_derives_from kk._warn_visibility kk._build_class_runtime _defineMethodType defineClass defineMethod defineProcedure defineFunction kk.register_static_methods
fi