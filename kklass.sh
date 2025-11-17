#!/bin/bash
# kklass.sh - Working class system for bash with dot notation

KKLASS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${KKLASS_DIR}/kklib.sh"

# Global variable to control echoing of function results
KK_ECHO_RESULT=false

kk._var() {
    local str="${1^^}" # Convert to upper case
    str="${str// /_}"
    KK_VAR="${str//./_}"
}

kk._result() {
    local var_name="$1"
    local var_value="$2"
    local echo_result="${3:-$KK_ECHO_RESULT}"
    
    kk._var "$var_name"
    #eval "declare -gx ${KK_VAR}='${var_value//\'/\'\\\'\'}'"
    #echo declare -gx "${KK_VAR}"="${var_value}"
    #declare -gx "${KK_VAR}"="${var_value}"
    printf -v "$KK_VAR" '%s' "$var_value"

    if [[ "$echo_result" == "true" ]]; then
        echo "$var_value"
    fi
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
    
    # Inject "local this" setup if not already present (optimized check)
    if [[ "$method_body" != *"local this="* ]]; then
        local this_setup="local this=\"\${FUNCNAME[0]%%.*}\"
    local __inst__=\"\$this\""
        method_body="$this_setup"$'\n'"$method_body"
    fi
    
    # For function type, append kk._result call
    if [[ "$meth_type" == "function" ]]; then
        method_body+=$'\n'"kk._result \"${class_name}_${method_name}\" \"\$RESULT\""
    fi
    
    METHOD_BODY="$method_body"
}

defineClass() {
    local class_name="$1"
    local parent_class="$2"
    shift 2

    # Collect properties and methods (including inherited)
    local -a props_arr=()
    local -a meths_arr=()
    local -A meth_bodies
    local -A meth_index  # For fast lookup
    local constructor_body=""
    
    # Static members support (lazy initialization)
    local has_static_members=false
    local -a static_props_arr=()
    local -a static_meths_arr=()
    local -A static_meth_bodies
    
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

            # Copy parent method bodies and index
            for m in "${parent_meths_ref[@]}"; do
                local parent_body_var="${parent_class}_method_body_${m}"
                meth_bodies["$m"]="${!parent_body_var}"
                meth_index["$m"]=1
            done
        fi
    fi

    # Parse class definition (can override parent methods)
    while [[ $# -gt 0 ]]; do
        case "$1" in
            static_property)
                has_static_members=true
                static_props_arr+=("$2")
                shift 2
                ;;
            static_method)
                has_static_members=true
                static_meths_arr+=("$2")
                static_meth_bodies["$2"]="$3"
                shift 3
                ;;
            property)
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
                            computed_getters["$prop_name"]="$peek_arg"
                            shift
                            ;;
                        set* | _set*)
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
                props_arr+=("$2")
                lazy_inits["$2"]="$3"
                shift 3
                ;;
            method|procedure|function)
                local meth_type="$1"
                # Check if method already exists (override) using fast lookup
                if [[ -z "${meth_index[$2]}" ]]; then
                    meths_arr+=("$2")
                    meth_index["$2"]=1
                fi

                # Process method body using shared logic
                #local processed_method=$(kk._processMethodBody "$class_name" "$2" "$3" "$meth_type" "meths_arr")
                kk._processMethodBody "$class_name" "$2" "$3" "$meth_type" "meths_arr"
                meth_bodies["$2"]="$METHOD_BODY"
                shift 3
                ;;
            constructor)
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
    eval "${class_name}_parent_class=\"$parent_class\""
    
    # Store computed property getters/setters
    eval "declare -gA ${class_name}_computed_getters"
    eval "declare -gA ${class_name}_computed_setters"
    for p in "${!computed_getters[@]}"; do
        eval "${class_name}_computed_getters[\"$p\"]=\"${computed_getters[$p]}\""
    done
    for p in "${!computed_setters[@]}"; do
        eval "${class_name}_computed_setters[\"$p\"]=\"${computed_setters[$p]}\""
    done
    
    # Create method resolution cache for performance
    eval "declare -gA ${class_name}_method_cache"
    
    for m in "${meths_arr[@]}"; do
        eval "${class_name}_method_body_${m}=\${meth_bodies[\$m]}"
        
        # Pre-populate cache: method resolves to this class
        eval "${class_name}_method_cache[\"${m}\"]=\"${class_name}\""
    done

    # Pre-generate property injection code with mutation detection (optimization: avoid subshell per method)
    # Includes: property injection, original value backup for mutation detection, and write-back for mutated properties
    local props_injection=""
    local props_backup=""
    local props_writeback=""
    
    for p in "${props_arr[@]}"; do
        props_injection+="local $p=\"\${__INST___data[\"$p\"]}\"; "
        props_backup+="local __orig_$p=\"\$${p}\"; "
        props_writeback+="if [[ \"\$${p}\" != \"\$__orig_${p}\" ]]; then __INST___data[\"$p\"]=\"\$${p}\"; fi; "
    done
    
    # Add static properties injection if available
    if [[ "$has_static_members" == "true" ]]; then
        for sp in "${static_props_arr[@]}"; do
            props_injection+="local $sp=\"\${${class_name}_static_${sp}}\"; "
        done
    fi

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
        if [ \"\$1\" == \"=\" ]; then
            __INST__.property \"$p\" = \"\$2\"
        else
            __INST__.property \"$p\"
        fi
    }"
        fi
    done

    # Create shared method executor to reduce per-method code size (optimization)
    local exec_method_func="
    __INST__._exec() {
        local method_name=\"\$1\" target_class=\"\$2\"
        shift 2
        local saved_class=\"\${__INST___class}\"
        __INST___class=\"\$target_class\"
        ${props_injection}
        ${props_backup}
        local method_var=\"\${target_class}_method_body_\${method_name}\"
        # Execute in current shell (redirect stdout, mutations persist); strip newlines for clean output concatenation
        # exec
        #local __tmp_out
        #__tmp_out=\"\$(mktemp)\"
        #eval \"\${!method_var}\" >\"\$__tmp_out\" 2>&1
        #cat \"\$__tmp_out\" | tr -d '\n'
        #rm -f \"\$__tmp_out\"
        eval \"\${!method_var}\" 2>\&1 || true
        ${props_writeback}
        __INST___class=\"\$saved_class\"
        }"

    local meth_funcs=""
    for m in "${meths_arr[@]}"; do
        meth_funcs+="
        __INST__.$m() {
            __INST__._exec \"$m\" \"$class_name\" \"\$@\"
        }"
    done

    # Add helper function to find method in hierarchy (DRY principle)
    local find_method_func="
    __INST__._find_method() {
        local method_name=\"\$1\" search_class=\"\$2\"
        local method_var=\"\${search_class}_method_body_\${method_name}\"
        
        # Check current class
        if [[ -n \"\${!method_var}\" ]]; then
            echo -e \"\$search_class\"
            return 0
        fi
        
        # Search parent chain
        local parent_var=\"\${search_class}_parent_class\"
        local parent_class=\"\${!parent_var}\"
        
        while [[ -n \"\$parent_class\" ]]; do
            method_var=\"\${parent_class}_method_body_\${method_name}\"
            if [[ -n \"\${!method_var}\" ]]; then
                echo -e \"\$parent_class\"
                return 0
            fi
            parent_var=\"\${parent_class}_parent_class\"
            parent_class=\"\${!parent_var}\"
        done
        
        return 1
    }"

    # Add call method to invoke methods in current class context
    local call_func="
    __INST__.call() {
        local method_name=\"\$1\"
        shift
        
        # Check cache first (optimization: avoid repeated hierarchy traversal)
        local cache_var=\"\${__INST___class}_method_cache[\${method_name}]\"
        local found_class=\"\${!cache_var}\"
        
        if [[ -z \"\$found_class\" ]]; then
            # Cache miss: search hierarchy and populate cache
            found_class=\$(__INST__._find_method \"\$method_name\" \"\${__INST___class}\")
            
            if [[ -z \"\$found_class\" ]]; then
                echo \"Error: Method '\$method_name' not found in class hierarchy\" >&2
                return 1
            fi
            
            # Populate cache for next call
            eval \"\${__INST___class}_method_cache[\\\"\${method_name}\\\"]=\"\$found_class\"\"
        fi
        
        # Inject all properties (pre-generated, no loop/eval)
        ${props_injection}
        ${props_backup}
        
        # Get method body from found class
        local method_var=\"\${found_class}_method_body_\${method_name}\"
        local method_body=\"\${!method_var}\"
        
        # Execute in current shell (redirect stdout, mutations persist); strip newlines for clean output concatenation
        # call
        #local __tmp_out
        #__tmp_out=\"\$(mktemp)\"
        #eval \"\$method_body\" >\"\$__tmp_out\" 2>&1
        #cat \"\$__tmp_out\" | tr -d '\n'
        #rm -f \"\$__tmp_out\"
        eval \"\$method_body\" 2>\&1 || true
        ${props_writeback}
        }"

    # Add parent method caller if there's a parent class
    local parent_func=""
    if [[ -n "$parent_class" ]]; then
        parent_func="
    __INST__.parent() {
        local method_name=\"\$1\"
        shift

        # Get parent class of current context
        local parent_var=\"\${__INST___class}_parent_class\"
        local parent_of_current=\"\${!parent_var}\"
        
        if [[ -z \"\$parent_of_current\" ]]; then
            echo \"Error: No parent class for '\${__INST___class}'\" >&2
            return 1
        fi
        
        # Check cache first for parent resolution (optimization)
        local parent_cache_key=\"\${__INST___class}_parent_\${method_name}\"
        local parent_cache_var=\"\${__INST___class}_method_cache[\${parent_cache_key}]\"
        local found_class=\"\${!parent_cache_var}\"
        
        if [[ -z \"\$found_class\" ]]; then
            # Cache miss: search parent hierarchy
            found_class=\$(__INST__._find_method \"\$method_name\" \"\$parent_of_current\")
            
            if [[ -z \"\$found_class\" ]]; then
                echo \"Error: Parent method '\$method_name' not found\" >&2
                return 1
            fi
            
            # Populate cache with special parent key
            eval \"\${__INST___class}_method_cache[\\\"\${parent_cache_key}\\\"]=\"\$found_class\"\"
        fi

        # Temporarily update class context to parent
        local saved_class=\"\${__INST___class}\"
        __INST___class=\"\$found_class\"

        # Inject all properties (pre-generated, no loop/eval)
        ${props_injection}
        ${props_backup}

        # Get method body
        local method_var=\"\${found_class}_method_body_\${method_name}\"
        local parent_method_body=\"\${!method_var}\"
        
        # Execute in current shell (redirect stdout, mutations persist); suppress trailing newline via command substitution + printf
        # parent
        #local __tmp_out
        #__tmp_out=\"\$(mktemp)\"
        #eval \"\$parent_method_body\" >\"\$__tmp_out\" 2>&1
        #printf %s \"\$(cat \"\$__tmp_out\")\"
        #rm -f \"\$__tmp_out\"
        eval \"\$parent_method_body\" 2>\&1 || true
        ${props_writeback}

        # Restore class context
        __INST___class=\"\$saved_class\"
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
        echo -e "${__INST___data["$1"]}"
    fi
}
__PROP_FUNCS__
__EXEC_FUNC__
__METH_FUNCS__
__FIND_FUNC__
__CALL_FUNC__
__PARENT_FUNC__
__INST__.delete() {
    unset __INST___data __INST___class
    unset -f $(compgen -A function __INST__.)
}
INSTANCE_TPL

    # Replace compile-time placeholders (pure bash, no subprocess)
    instance_template="${instance_template//__CLASS_NAME__/$class_name}"
    instance_template="${instance_template//__PROP_FUNCS__/$prop_funcs}"
    instance_template="${instance_template//__EXEC_FUNC__/$exec_method_func}"
    instance_template="${instance_template//__METH_FUNCS__/$meth_funcs}"
    instance_template="${instance_template//__FIND_FUNC__/$find_method_func}"
    instance_template="${instance_template//__CALL_FUNC__/$call_func}"
    instance_template="${instance_template//__PARENT_FUNC__/$parent_func}"

    # Store template for this class (for compiler support)
    eval "${class_name}_instance_template=\$instance_template"

    # Store constructor body
    eval "${class_name}_constructor_body=\$constructor_body"
    
    # Create static members if needed (lazy approach)
    if [[ "$has_static_members" == "true" ]]; then
        # Initialize static properties as global variables
        for sp in "${static_props_arr[@]}"; do
            eval "${class_name}_static_${sp}=\"\""
        done
        
        # Create static property accessors: Class.property = value / Class.property
        for sp in "${static_props_arr[@]}"; do
            eval "${class_name}.${sp}() {
                if [[ \"\$1\" == \"=\" ]]; then
                    ${class_name}_static_${sp}=\"\$2\"
                else
                    echo \"\${${class_name}_static_${sp}}\"
                fi
            }"
        done
        
        # Create static methods: Class.method args
        for sm in "${static_meths_arr[@]}"; do
            # Get the actual method body
            local sm_body="${static_meth_bodies[$sm]}"
            
            # Create name references for static properties (bash 4.3+)
            # This creates local variables that directly reference the global static properties
            local static_namerefs=""
            for sp in "${static_props_arr[@]}"; do
                static_namerefs+="local -n $sp=${class_name}_static_${sp}; "
            done
            
            # Create the static method function with name references
            # Execute in current shell and capture stdout to REPLY to preserve static property mutations
            eval "${class_name}.${sm}() {
                ${static_namerefs}
                local __tmp_out=\"\$(mktemp)\"
                ${sm_body} >\"\$__tmp_out\"
                REPLY=\"\$(cat \"\$__tmp_out\")\"
                rm -f \"\$__tmp_out\"
                printf \"%s\" \"\$REPLY\"
            }"
        done
    fi
    
    # Create constructor function (uses source+sed for instance name substitution)
    eval "${class_name}.new() {
        local instname=\"\$1\"
        shift
        [[ \"\$instname\" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || { echo \"Invalid instance name: \$instname\" >&2; return 1; }
        source <(sed \"s/__INST__/\$instname/g\" <<< \"\$${class_name}_instance_template\")
        
        # If methods were added via defineMethod, create them on the instance
        if [[ \"\$${class_name}_has_dynamic_methods\" == \"1\" ]]; then
            for __meth_nm in \"\${${class_name}_class_methods[@]}\"; do
                # Skip if method already in template
                if ! declare -f \${instname}.\$__meth_nm >/dev/null 2>&1; then
                    eval \"\${instname}.\${__meth_nm}() { \${instname}._exec \\\"\${__meth_nm}\\\" \\\"${class_name}\\\" \\\"\\\$@\\\"; }\"
                fi
            done
        fi
        
        # Run constructor if defined
        if [[ -n \"\$${class_name}_constructor_body\" ]]; then
            # Inject properties into constructor context
            ${props_injection}
            # Execute constructor with passed arguments
            eval \"\$${class_name}_constructor_body\"
            # Save modified properties back
            local __prop__
            for __prop__ in ${props_arr[@]}; do
                eval \"\${instname}_data[\\\"\$__prop__\\\"]=\"\${!__prop__}\"\"
            done
        fi
    }
    
    # Create constructor caller function for explicit parent constructor calls
    eval \"${class_name}.constructor() {
        # This function executes the constructor body for use in derived classes
        # Properties should already be injected by the caller
        if [[ -n \\\"\$${class_name}_constructor_body\\\" ]]; then
            eval \\\"\$${class_name}_constructor_body\\\"
        fi
    }\""

    if [[ "${VERBOSE_KKLASS:-1}" == "debug" ]]; then echo "$class_name class created"; fi
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

export -f kk._processMethodBody kk._result kk._var _defineMethodType defineClass defineMethod defineProcedure defineFunction