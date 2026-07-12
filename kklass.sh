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
            kklass.sh|kklass_decl.sh|kklass_pascal.sh|kklass_kkp.sh) continue ;;
        esac
        __d="${__src%/*}"; __b="${__src##*/}"
        [[ "$__d" == "$__src" ]] && __d="."     # no slash -> current dir
        __kk_caller_src="$( cd "$__d" 2>/dev/null && printf '%s/%s' "$PWD" "$__b" )" \
            || __kk_caller_src="$__src"
        return 0
    done
    return 0
}

# Scratch global used by instance ._find_method to return the resolving class
# without forking a subshell (replaces the previous $(...) capture).
declare -g __kk_find_class=""
# kk._var() {
#     local str="${1^^}" # Convert to upper case
#     str="${str// /_}"
#     KK_VAR="${str//./_}"
# }
kk._return() {
    local return_value="$1"

    if declare -p __kk_return_set &>/dev/null; then
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
    kk._caller_source_file
    if [[ -n "${_KKLASS_CLASS_SOURCE[$class_name]+x}" \
          && "${_KKLASS_CLASS_SOURCE[$class_name]}" != "$__kk_caller_src" ]]; then
        echo "kklass: class '${class_name}' is already registered (from ${_KKLASS_CLASS_SOURCE[$class_name]}); refusing to redefine it from ${__kk_caller_src}" >&2
        return 1
    fi
    _KKLASS_CLASS_SOURCE["$class_name"]="$__kk_caller_src"

    # Collect properties and methods (including inherited)
    local -a props_arr=()
    local -a meths_arr=()
    local -A meth_bodies
    local -A meth_index  # For fast lookup
    local -A meth_owner=()  # method -> DEFINING class (Pascal 'inherited' semantics)
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
                local keyword_str=" property static_property method procedure function lazy_property constructor "
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

                # Process method body using shared logic
                #local processed_method=$(kk._processMethodBody "$class_name" "$2" "$3" "$meth_type" "meths_arr")
                kk._processMethodBody "$class_name" "$2" "$3" "$meth_type" "meths_arr"
                meth_bodies["$2"]="$METHOD_BODY"
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

    local prop_namerefs=""
    for p in "${props_arr[@]}"; do
        prop_namerefs+="local -n ${p}='__INST___data[\"${p}\"]'; "
    done

    local static_prop_namerefs=""
    if [[ "$has_static_members" == "true" ]]; then
        for sp in "${static_props_arr[@]}"; do
            local static_owner="${static_prop_owner[$sp]:-$class_name}"
            static_prop_namerefs+="local -n ${sp}='${static_owner}_static_${sp}'; "
        done
    fi

    # Create constructor executor with explicit frame context instead of naked property locals.
    local constructor_exec_func="
    __INST__._constructor_exec() {
        local target_class=\"\$1\"
        shift
        local method_var=\"\${target_class}_constructor_body\"
        local constructor_method_body=\"\${!method_var}\"

        if [[ -z \"\$constructor_method_body\" ]]; then
            return 0
        fi

        __INST__._invoke \"\$target_class\" \"\$constructor_method_body\" \"\$@\"
    }"
    
    # Build template parts as strings
    local prop_funcs=""
    for p in "${props_arr[@]}"; do
        # Check if property has computed getter/setter by looking at saved metadata
        local has_computed_getter="${computed_getters[$p]:+1}"
        local has_computed_setter="${computed_setters[$p]:+1}"
        local has_lazy_init="${lazy_inits[$p]:+1}"
        
        if [[ -n "$has_computed_getter" || -n "$has_computed_setter" || -n "$has_lazy_init" ]]; then
            # Generate smart property accessor
            prop_funcs+="
    __INST__.$p() {
        kk._warn_visibility \"$class_name\" \"property\" \"$p\"
        if [ \"\$1\" == \"=\" ]; then"
            
            if [[ -n "$has_computed_setter" ]]; then
                prop_funcs+="
            __INST__.call \"${computed_setters[$p]}\" \"\$2\""
            else
                prop_funcs+="
            __INST__.property \"$p\" = \"\$2\""
            fi
            
            prop_funcs+="
            else"
            
            if [[ -n "$has_computed_getter" ]]; then
                prop_funcs+="
             __INST__.call \"${computed_getters[$p]}\""
            elif [[ -n "$has_lazy_init" ]]; then
                prop_funcs+="
             if [[ ! -v __INST___lazy_$p ]]; then
                 local __lazy_val
                 __lazy_val=\$(__INST__.${lazy_inits[$p]})
                 declare -g __INST___lazy_$p=\"\$__lazy_val\"
             fi
             echo \"\${__INST___lazy_$p}\""
            else
                # No getter, just return the property value
                prop_funcs+="
             __INST__.property \"$p\""
            fi
            
            prop_funcs+="
            fi
            }"
        else
            # Regular property accessor
            prop_funcs+="
    __INST__.$p() {
        kk._warn_visibility \"$class_name\" \"property\" \"$p\"
        if [ \"\$1\" == \"=\" ]; then
            __INST__.property \"$p\" = \"\$2\"
        else
            __INST__.property \"$p\"
        fi
    }"
        fi
    done

    local run_frame_body_func="
    __INST__._run_frame_body() {
        local frame_id=\"\$1\"
        local method_body=\"\$2\"
        shift 2

        local this=\"\${FUNCNAME[0]%%.*}\"
        local __inst__=\"\$this\"
        local __class__
        kv.frameClass \"\$frame_id\"
        __class__=\"\$RESULT\"
        local -n state=__INST___data
        ${prop_namerefs}
        ${static_prop_namerefs}

        eval \"\$method_body\"
    }"

    local invoke_func="
    __INST__._invoke() {
        local active_class=\"\$1\"
        local method_body=\"\$2\"
        shift 2

        local this=\"\${FUNCNAME[0]%%.*}\"
        local caller_result=\"\$RESULT\"
        local __kk_return_set=0
        local __kk_return_value=\"\"
        kv.framePush \"\$this\" \"\$active_class\"
        local frame_id=\"\$RESULT\"

        __INST__._run_frame_body \"\$frame_id\" \"\$method_body\" \"\$@\"
        local method_status=\$?
        local method_result=\"\$caller_result\"

        if (( __kk_return_set )); then
            method_result=\"\$__kk_return_value\"
        fi

        kv.framePop >/dev/null || true
        RESULT=\"\$method_result\"
        return \$method_status
    }"

    # Create shared method executor to reduce per-method code size.
    local exec_method_func="
    __INST__._exec() {
        local method_name=\"\$1\" target_class=\"\$2\"
        shift 2
        local method_var=\"\${target_class}_method_body_\${method_name}\"
        local method_body=\"\${!method_var}\"

        if [[ -z \"\$method_body\" ]]; then
            echo \"Error: Method '\$method_name' not found in class '\$target_class'\" >&2
            return 1
        fi

        kk._warn_visibility \"\$target_class\" \"method\" \"\$method_name\"
        __INST__._invoke \"\$target_class\" \"\$method_body\" \"\$@\"
    }"

    local meth_funcs=""
    for m in "${meths_arr[@]}"; do
        # Dispatch with the method's DEFINING class (owner): the frame then
        # carries the class the body belongs to, so `inherited`/.parent inside
        # an inherited (non-overridden) body resolves from the right level
        # instead of re-running the same body from the instance's class.
        meth_funcs+="
        __INST__.$m() {
            __INST__._exec \"$m\" \"${meth_owner[$m]:-$class_name}\" \"\$@\"
        }"
    done

    # Add helper function to find method in hierarchy (DRY principle)
    local find_method_func="
    __INST__._find_method() {
        local method_name=\"\$1\" search_class=\"\$2\"
        local method_var=\"\${search_class}_method_body_\${method_name}\"
        __kk_find_class=\"\"

        # Check current class
        if [[ -n \"\${!method_var}\" ]]; then
            __kk_find_class=\"\$search_class\"
            return 0
        fi
        
        # Search parent chain
        local parent_var=\"\${search_class}_parent_class\"
        local parent_class=\"\${!parent_var}\"
        
        while [[ -n \"\$parent_class\" ]]; do
            method_var=\"\${parent_class}_method_body_\${method_name}\"
            if [[ -n \"\${!method_var}\" ]]; then
                __kk_find_class=\"\$parent_class\"
                return 0
            fi
            parent_var=\"\${parent_class}_parent_class\"
            parent_class=\"\${!parent_var}\"
        done
        
        return 1
    }"

    # Add call method to invoke methods in current class context.
    # Resolution is VIRTUAL (Pascal semantics): always from the instance's own
    # class, so subclass overrides win even when the call happens inside an
    # inherited body. (Static, defining-class resolution is what .parent /
    # `inherited` does.) The resolved class is then mapped to the method's
    # DEFINING class (owner) so the pushed frame lets nested `inherited`
    # continue from the right level.
    local call_func="
    __INST__.call() {
        local method_name=\"\$1\"
        shift
        local search_class=\"\${__INST___class}\"

        # Check cache first (optimization: avoid repeated hierarchy traversal).
        # The cache stores the OWNER class (pre-populated at class build).
        local cache_var=\"\${search_class}_method_cache[\${method_name}]\"
        local found_class=\"\${!cache_var}\"

        if [[ -z \"\$found_class\" ]]; then
            # Cache miss: search hierarchy and populate cache (fork-free)
            __INST__._find_method \"\$method_name\" \"\$search_class\"
            found_class=\"\$__kk_find_class\"

            if [[ -z \"\$found_class\" ]]; then
                echo \"Error: Method '\$method_name' not found in class hierarchy\" >&2
                return 1
            fi

            # Map to the defining class (bodies are copied down the hierarchy,
            # so _find_method reports the first class holding a copy).
            local __kk_owner_var=\"\${found_class}_class_method_owner[\${method_name}]\"
            [[ -n \"\${!__kk_owner_var}\" ]] && found_class=\"\${!__kk_owner_var}\"

            # Populate cache for next call (nameref, not eval: method_name is a
            # call argument and must never be interpolated into evaluated code)
            local -n __kk_cache_ref=\"\${search_class}_method_cache\"
            __kk_cache_ref[\"\$method_name\"]=\"\$found_class\"
        fi

        # Get method body from found class
        local method_var=\"\${found_class}_method_body_\${method_name}\"
        local method_body=\"\${!method_var}\"

        kk._warn_visibility \"\$found_class\" \"method\" \"\$method_name\"
        __INST__._invoke \"\$found_class\" \"\$method_body\" \"\$@\"
    }"

    # Add parent method caller if there's a parent class
    local parent_func=""
    if [[ -n "$parent_class" ]]; then
        parent_func="
    __INST__.parent() {
        local method_name=\"\$1\"
        shift
        # Internal dispatch (see .call): result via RESULT, no echo.
        local __kk_return_silent=1
        local current_frame=\"\"
        local active_class=\"\${__INST___class}\"

        kv.frameCurrent >/dev/null 2>&1 || true
        current_frame=\"\$RESULT\"
        if [[ -n \"\$current_frame\" ]]; then
            kv.frameClass \"\$current_frame\"
            active_class=\"\$RESULT\"
        fi

        # Get parent class of current context
        local parent_var=\"\${active_class}_parent_class\"
        local parent_of_current=\"\${!parent_var}\"
        
        if [[ -z \"\$parent_of_current\" ]]; then
            echo \"Error: No parent class for '\${active_class}'\" >&2
            return 1
        fi
        
        # Check cache first for parent resolution (optimization)
        local parent_cache_key=\"\${active_class}_parent_\${method_name}\"
        local parent_cache_var=\"\${active_class}_method_cache[\${parent_cache_key}]\"
        local found_class=\"\${!parent_cache_var}\"
        
        if [[ -z \"\$found_class\" ]]; then
            # Cache miss: search parent hierarchy (fork-free)
            __INST__._find_method \"\$method_name\" \"\$parent_of_current\"
            found_class=\"\$__kk_find_class\"

            if [[ -z \"\$found_class\" ]]; then
                echo \"Error: Parent method '\$method_name' not found\" >&2
                return 1
            fi

            # Map to the defining class (bodies are copied down the hierarchy):
            # the frame must carry where the body was DEFINED so that a nested
            # 'inherited' inside it continues from the right level.
            local __kk_powner_var=\"\${found_class}_class_method_owner[\${method_name}]\"
            [[ -n \"\${!__kk_powner_var}\" ]] && found_class=\"\${!__kk_powner_var}\"

            # Populate cache with special parent key (nameref, not eval)
            local -n __kk_pcache_ref=\"\${active_class}_method_cache\"
            __kk_pcache_ref[\"\$parent_cache_key\"]=\"\$found_class\"
        fi

        # Get method body
        local method_var=\"\${found_class}_method_body_\${method_name}\"
        local parent_method_body=\"\${!method_var}\"

        kk._warn_visibility \"\$found_class\" \"method\" \"\$method_name\"
        __INST__._invoke \"\$found_class\" \"\$parent_method_body\" \"\$@\"
    }"
    fi

    # Build instance template with single-quoted heredoc (freeze all $ and ")
    read -r -d '' instance_template <<'INSTANCE_TPL' || true
declare -gA __INST___data
__INST___class="__CLASS_NAME__"

__INST__.property() {
    if [ "$2" == "=" ]; then
        __INST___data["$1"]="$3"
    else
        # printf, not echo -e: property values are data and must round-trip
        # verbatim. echo -e would interpret backslash escapes (e.g. a Windows
        # path 'C:\new' or a literal '\t') and mangle the stored value.
        printf '%s\n' "${__INST___data["$1"]}"
    fi
}
__PROP_FUNCS__
__RUN_FRAME_BODY_FUNC__
__INVOKE_FUNC__
__EXEC_FUNC__
__CONSTRUCTOR_EXEC_FUNC__
__METH_FUNCS__
__FIND_FUNC__
__CALL_FUNC__
__PARENT_FUNC__
__INST__.delete() {
    local __kk_dtor_var="${__INST___class}_destructor_name"
    local __kk_dtor="${!__kk_dtor_var}"
    [[ -n "$__kk_dtor" ]] && __INST__.call "$__kk_dtor"
    unset __INST___data __INST___class
    unset -f $(compgen -A function __INST__.)
}
INSTANCE_TPL

    # Replace compile-time placeholders (pure bash, no subprocess)
    local __kk_patsub_replacement_enabled=0
    if shopt -q patsub_replacement 2>/dev/null; then
        __kk_patsub_replacement_enabled=1
        shopt -u patsub_replacement
    fi

    instance_template="${instance_template//__CLASS_NAME__/$class_name}"
    instance_template="${instance_template//__PROP_FUNCS__/$prop_funcs}"
    instance_template="${instance_template//__RUN_FRAME_BODY_FUNC__/$run_frame_body_func}"
    instance_template="${instance_template//__INVOKE_FUNC__/$invoke_func}"
    instance_template="${instance_template//__EXEC_FUNC__/$exec_method_func}"
    instance_template="${instance_template//__CONSTRUCTOR_EXEC_FUNC__/$constructor_exec_func}"
    instance_template="${instance_template//__METH_FUNCS__/$meth_funcs}"
    instance_template="${instance_template//__FIND_FUNC__/$find_method_func}"
    instance_template="${instance_template//__CALL_FUNC__/$call_func}"
    instance_template="${instance_template//__PARENT_FUNC__/$parent_func}"

    if (( __kk_patsub_replacement_enabled )); then
        shopt -s patsub_replacement
    fi

    # Store template for this class (for compiler support)
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
        # Detect funsub support (bash 5.3+): `REPLY=${ cmds; }` runs in the current
        # shell with no subshell/fork and captures stdout, so static property
        # mutations persist AND output is captured without any temp file.
        local __kk_has_funsub=0
        if (( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 3) )); then
            __kk_has_funsub=1
        fi

        for sm in "${static_meths_arr[@]}"; do
            # Get the actual method body
            local sm_body="${static_meth_bodies[$sm]}"
            
            # Create name references for static properties (bash 4.3+)
            # This creates local variables that directly reference the global static properties
            local static_namerefs=""
            for sp in "${static_props_arr[@]}"; do
                local static_owner="${static_prop_owner[$sp]:-$class_name}"
                static_namerefs+="local -n $sp=${static_owner}_static_${sp}; "
            done

            if (( ${#static_props_arr[@]} == 0 )); then
                # No static properties: the body has no shared state that would need
                # to survive a $(...) subshell, so there is nothing to capture. Run it
                # directly as a thin wrapper — no funsub, no scratch file — which is
                # fast on EVERY bash version (5.2 and 5.3 alike). This is the path a
                # pure static-utility class (e.g. the string.* helpers) takes, and it
                # matches the zero-overhead dispatch of kk.register_static_methods.
                # Body stdout flows straight through; a `func` result recorded via
                # kk._return (silent) is printed once at the end.
                eval "${class_name}.${sm}() {
                    local __kk_return_set=0
                    local __kk_return_value=\"\"
                    local __kk_return_silent=1
                    ${sm_body}
                    local __kk_status=\$?
                    if (( __kk_return_set )); then
                        printf \"%s\" \"\$__kk_return_value\"
                    fi
                    return \$__kk_status
                }"
            elif (( __kk_has_funsub )); then
                # bash 5.3+: capture stdout in-process with a function substitution.
                # The body runs in the current shell (no fork, no temp file) so static
                # property mutations persist and the return value is captured into REPLY.
                eval "${class_name}.${sm}() {
                    ${static_namerefs}
                    local __kk_return_set=0
                    local __kk_return_value=\"\"
                    local __kk_return_silent=1
                    REPLY=\${
                        ${sm_body}
                        if (( __kk_return_set )); then
                            printf \"%s\" \"\$__kk_return_value\"
                        fi
                    }
                    printf \"%s\" \"\$REPLY\"
                }"
            else
                # bash 5.2 fallback: there is no in-memory capture for current-shell
                # code, so a scratch file is used, but without spawning mktemp/cat:
                # the name is generated in shell and $(<file) reads it without a fork.
                eval "${class_name}.${sm}() {
                    ${static_namerefs}
                    local __kk_return_set=0
                    local __kk_return_value=\"\"
                    local __kk_return_silent=1
                    local __kk_static_out=\"\${TMPDIR:-/tmp}/.kk_static_\${BASHPID}_\${RANDOM}\${RANDOM}\"
                    {
                        ${sm_body}
                        if (( __kk_return_set )); then
                            printf \"%s\" \"\$__kk_return_value\"
                        fi
                    } >\"\$__kk_static_out\"
                    REPLY=\"\$(<\"\$__kk_static_out\")\"
                    rm -f \"\$__kk_static_out\"
                    printf \"%s\" \"\$REPLY\"
                }"
            fi
        done
    fi
    
    # Create constructor function (uses source+sed for instance name substitution)
    eval "${class_name}.new() {
        local instname=\"\$1\"
        shift
        [[ \"\$instname\" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || { echo \"Invalid instance name: \$instname\" >&2; return 1; }
        # Materialize the instance by substituting the (validated) instance name
        # into the class template with a pure-bash replacement and eval'ing it.
        # Replaces the previous 'source <(sed ...)' which forked sed + a process
        # substitution on every .new() — the dominant object-creation cost.
        eval \"\${${class_name}_instance_template//__INST__/\$instname}\"
        
        # If methods were added via defineMethod, create them on the instance
        if [[ \"\$${class_name}_has_dynamic_methods\" == \"1\" ]]; then
            for __meth_nm in \"\${${class_name}_class_methods[@]}\"; do
                # Skip if method already in template
                if ! declare -f \${instname}.\$__meth_nm >/dev/null 2>&1; then
                    # Dispatch with the defining class (owner) when known — see
                    # the template methods above.
                    local __kk_dyn_owner_var=\"${class_name}_class_method_owner[\${__meth_nm}]\"
                    local __kk_dyn_owner=\"\${!__kk_dyn_owner_var:-${class_name}}\"
                    eval \"\${instname}.\${__meth_nm}() { \${instname}._exec \\\"\${__meth_nm}\\\" \\\"\${__kk_dyn_owner}\\\" \\\"\\\$@\\\"; }\"
                fi
            done
        fi
        
        # Run constructor if defined
         if [[ -n \"\$${class_name}_constructor_body\" ]]; then
             # Setup __inst__ for constructor context so it can call methods
             local __inst__=\"\$instname\"
             # Inject properties and execute constructor
             \${instname}._constructor_exec \"${class_name}\" \"\$@\"
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
    
    # Set a flag indicating that methods were added dynamically after class definition
    # This is used in .new to create the method wrappers
    eval "${class_name}_has_dynamic_methods=1"
    
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