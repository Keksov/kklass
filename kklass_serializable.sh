#!/bin/bash
# kklass_serializable.sh - Serialization mixin for kklass
# Adds automatic serialization/deserialization methods to classes

# Requires kklass.sh to be loaded first
if ! declare -f defineClass &>/dev/null; then
    echo "Error: kklass.sh must be loaded before kklass_serializable.sh" >&2
    return 1
fi

# Helper: Define a serializable class (wrapper around defineClass)
# Usage: defineSerializableClass CLASS_NAME PARENT_CLASS SEPARATOR FORMAT property prop1 property prop2 method meth1 "body1" ...
defineSerializableClass() {
    local class_name="$1"
    local parent_class="$2"
    local separator="${3:-:}"
    local format="${4:-string}"
    shift 4
    
    # Collect properties first to generate serialization methods
    local -a props_arr=()
    local -a args_copy=("$@")
    local i=0
    while [[ $i -lt ${#args_copy[@]} ]]; do
        if [[ "${args_copy[$i]}" == "property" ]]; then
            props_arr+=("${args_copy[$((i+1))]}")
            ((i+=2))
        else
            # Skip other definitions
            case "${args_copy[$i]}" in
                method|static_method|computed_property)
                    ((i+=3))
                    ;;
                lazy_property)
                    ((i+=3))
                    ;;
                constructor|static_property)
                    ((i+=2))
                    ;;
                *)
                    ((i++))
                    ;;
            esac
        fi
    done
    
    # Generate serialization methods based on format
    local toString_method=""
    local fromString_method=""
    
    if [[ "$format" == "string" ]]; then
        # Build property values string
        local prop_values=""
        local prop_read=""
        local prop_assign=""
        
        for prop in "${props_arr[@]}"; do
            prop_values+="\${$prop}${separator}"
            prop_read+="$prop "
            prop_assign+="$prop=\"\$$prop\"; "
        done
        prop_values="${prop_values%$separator}"
        
        toString_method="echo \"${class_name}${separator}${prop_values}\""
        fromString_method="local input=\"\$1\"; input=\"\${input#${class_name}${separator}}\"; input=\"\${input%$'\\n'}\"; IFS=\"${separator}\" read -r ${prop_read} <<< \"\$input\"; ${prop_assign} echo \"\$this\""
    fi
    
    # Call defineClass with original args plus serialization methods
    defineClass "$class_name" "$parent_class" "$@" \
        "method" "toString" "$toString_method" \
        "method" "fromString" "$fromString_method"
}


# Add serialization methods to an existing class
# Usage: addSerializable CLASS_NAME [SEPARATOR] [FORMAT]
#   CLASS_NAME - name of the class to extend
#   SEPARATOR  - field separator (default: ":")
#   FORMAT     - "string" (default) or "json"
# NOTE: Must be called IMMEDIATELY AFTER defineClass, BEFORE creating instances
addSerializable() {
    local class_name="$1"
    local separator="${2:-:}"
    local format="${3:-string}"
    
    # Validate class exists
    local props_var="${class_name}_class_properties"
    if ! declare -p "$props_var" &>/dev/null; then
        echo "Error: Class '$class_name' not found" >&2
        return 1
    fi
    
    # Get class properties
    local -n props_ref="$props_var"
    local props_list="${props_ref[*]}"
    
    case "$format" in
        string)
            _addSerializable_string "$class_name" "$separator" "$props_list"
            ;;
        json)
            _addSerializable_json "$class_name" "$props_list"
            ;;
        *)
            echo "Error: Unknown format '$format'. Use 'string' or 'json'" >&2
            return 1
            ;;
    esac
    
    # Force regeneration of instance template by calling defineClass constructor update
    # This is a hack: we rebuild the constructor with updated method lists
    _regenerateConstructor "$class_name"
    
    if [[ "${VERBOSE_KKLASS:-1}" == "debug" ]]; then echo "Serialization methods added to $class_name (format: $format)"; fi
    
}

# Internal: Add string-based serialization
_addSerializable_string() {
    local class_name="$1"
    local separator="$2"
    local props_list="$3"
    
    # Escape separator for use in regex
    local sep_escaped="${separator//\\/\\\\}"
    sep_escaped="${sep_escaped//\//\\/}"
    sep_escaped="${sep_escaped//./\\.}"
    
    # Build property list for serialization
    local prop_values=""
    local prop_read=""
    local prop_assign=""
    
    for prop in $props_list; do
        prop_values+="\${$prop}${separator}"
        prop_read+="$prop "
        prop_assign+="$prop=\"\$$prop\"; "
    done
    prop_values="${prop_values%$separator}"
    
    # Create toString method
    local toString_body="echo \"${class_name}${separator}${prop_values}\""
    
    # Create fromString method
    local fromString_body="
        local input=\"\$1\"
        input=\"\${input#${class_name}${separator}}\"
        IFS=\"${separator}\" read -r ${prop_read} <<< \"\$input\"
        ${prop_assign}
        echo \"\$this\"
    "
    
    # Add methods to class
    local meths_var="${class_name}_class_methods"
    local -n meths_ref="$meths_var"
    
    # Add toString if not exists
    if [[ ! " ${meths_ref[*]} " =~ " toString " ]]; then
        meths_ref+=("toString")
    fi
    eval "${class_name}_method_body_toString=\$toString_body"
    
    # Add fromString if not exists
    if [[ ! " ${meths_ref[*]} " =~ " fromString " ]]; then
        meths_ref+=("fromString")
    fi
    eval "${class_name}_method_body_fromString=\$fromString_body"
    
    # Update method cache
    eval "${class_name}_method_cache[\"toString\"]=\"${class_name}\""
    eval "${class_name}_method_cache[\"fromString\"]=\"${class_name}\""
}

# Internal: Add JSON-based serialization
_addSerializable_json() {
    local class_name="$1"
    local props_list="$2"
    
    # Build JSON serialization
    local json_fields=""
    local prop_assign=""
    
    for prop in $props_list; do
        json_fields+="\"$prop\":\"\${$prop}\","
        prop_assign+="
            \"$prop\")
                $prop=\${value%\\\"}
                $prop=\${$prop#\\\"}
                ;;
        "
    done
    json_fields="${json_fields%,}"
    
    # Create toJSON method
    local toJSON_body="echo \"{\\\"__class__\\\":\\\"${class_name}\\\",${json_fields}}\""
    
    # Create fromJSON method
    local fromJSON_body="
        local input=\"\$1\"
        input=\"\${input#\{}\"
        input=\"\${input%\}}\"
        
        local IFS=','
        local -a pairs
        read -ra pairs <<< \"\$input\"
        
        local pair key value
        for pair in \"\${pairs[@]}\"; do
            IFS=':' read -r key value <<< \"\$pair\"
            key=\${key#\\\"}
            key=\${key%\\\"}
            
            case \"\$key\" in
                __class__)
                    ;;
                ${prop_assign}
            esac
        done
        echo \"\$this\"
    "
    
    # Add methods to class
    local meths_var="${class_name}_class_methods"
    local -n meths_ref="$meths_var"
    
    # Add toJSON if not exists
    if [[ ! " ${meths_ref[*]} " =~ " toJSON " ]]; then
        meths_ref+=("toJSON")
    fi
    eval "${class_name}_method_body_toJSON=\$toJSON_body"
    
    # Add fromJSON if not exists
    if [[ ! " ${meths_ref[*]} " =~ " fromJSON " ]]; then
        meths_ref+=("fromJSON")
    fi
    eval "${class_name}_method_body_fromJSON=\$fromJSON_body"
    
    # Update method cache
    eval "${class_name}_method_cache[\"toJSON\"]=\"${class_name}\""
    eval "${class_name}_method_cache[\"fromJSON\"]=\"${class_name}\""
}

# Internal: Regenerate constructor after adding methods
_regenerateConstructor() {
    local class_name="$1"
    
    # Get updated method list
    local meths_var="${class_name}_class_methods"
    local props_var="${class_name}_class_properties"
    local -n meths_ref="$meths_var"
    local -n props_ref="$props_var"
    
    # Build new method functions
    local new_meth_funcs=""
    for m in "${meths_ref[@]}"; do
        new_meth_funcs+="
__INST__.$m() {
    __INST__._exec \"$m\" \"$class_name\" \"\$@\"
}
"
    done
    
    # Get existing template and update it with new methods
    local template_var="${class_name}_instance_template"
    local existing_template="${!template_var}"
    
    # Find where methods section ends (__INST__.delete)
    # Insert new method functions before delete
    local updated_template="${existing_template//__INST__.delete()/${new_meth_funcs}__INST__.delete()}"
    
    # Store updated template
    eval "${class_name}_instance_template=\$updated_template"
}

# Utility: Serialize multiple objects to a file
saveObjects() {
    local file="$1"
    shift
    
    : > "$file"
    
    for obj in "$@"; do
        if declare -F "${obj}.toString" &>/dev/null; then
            echo "$(${obj}.toString)" >> "$file"
        elif declare -F "${obj}.toJSON" &>/dev/null; then
            echo "$(${obj}.toJSON)" >> "$file"
        else
            echo "Warning: Object '$obj' has no serialization method" >&2
        fi
    done
}

# Utility: Load serialized objects from file
loadObjects() {
    local file="$1"
    local class_name="$2"
    local -n instances_array="$3"
    
    if [[ ! -f "$file" ]]; then
        echo "Error: File '$file' not found" >&2
        return 1
    fi
    
    local line
    local count=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        
        local inst_name="${class_name}_loaded_${count}"
        ${class_name}.new "$inst_name"
        
        if [[ "$line" =~ ^\{ ]]; then
            ${inst_name}.fromJSON "$line" >/dev/null
        else
            ${inst_name}.fromString "$line" >/dev/null
        fi
        
        instances_array+=("$inst_name")
        ((count++))
    done < "$file"
    
    echo "Loaded $count objects from $file"
}

export -f defineSerializableClass
export -f addSerializable
export -f _addSerializable_string
export -f _addSerializable_json
export -f _regenerateConstructor
export -f saveObjects
export -f loadObjects
