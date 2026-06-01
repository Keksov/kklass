#!/bin/bash

if [[ -n "$_KKLASS_DECL_SOURCED" ]]; then
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
    kk.decl._validate_ident "$property_name" "static property name" || return 1

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
    kk.decl._validate_ident "$method_name" "static method name" || return 1

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
    kk.decl._validate_ident "$property_name" "lazy property name" || return 1
    kk.decl._validate_ident "$init_method" "lazy init method name" || return 1

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
kk.decl._validate_ident() {
    local name="$1"
    local label="${2:-name}"

    if [[ -n "$name" && ! "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        kk.decl._error "Invalid ${label}: '${name}' (must be a valid identifier: letters, digits, underscore; not starting with a digit)"
        return 1
    fi

    return 0
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
        RESULT="${!decl_parent_var}"
    elif declare -p "$runtime_parent_var" &>/dev/null; then
        RESULT="${!runtime_parent_var}"
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

kk.decl._declare_method() {
    local method_kind="$1"
    local method_name="$2"

    kk.decl._require_current_class || return 1
    local class_name="$RESULT"

    [[ -n "$method_name" ]] || {
        kk.decl._error "Method name is required"
        return 1
    }
    kk.decl._validate_ident "$method_name" "method name" || return 1

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

classVar() {
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

field() {
    local field_name="$1"
    kk.decl._require_current_class || return 1
    local class_name="$RESULT"

    [[ -n "$field_name" ]] || {
        kk.decl._error "field: FIELD_NAME is required"
        return 1
    }
    kk.decl._validate_ident "$field_name" "field name" || return 1

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

property() {
    local property_name="$1"
    shift

    kk.decl._require_current_class || return 1
    local class_name="$RESULT"

    [[ -n "$property_name" ]] || {
        kk.decl._error "property: PROPERTY_NAME is required"
        return 1
    }
    kk.decl._validate_ident "$property_name" "property name" || return 1

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

constructor() {
    local constructor_name="${1:-Create}"
    kk.decl._require_current_class || return 1
    local class_name="$RESULT"

    if [[ ${#KK_DECL_NEXT_MODIFIERS[@]} -gt 0 ]]; then
        kk.decl._error "constructor: Modifiers are not supported for constructors in this phase"
        return 1
    fi

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
                return 1
            fi
        fi
    done

    eval "${class_name}_decl_finalized=1"
    KK_DECL_CURRENT_CLASS=""
    KK_DECL_CURRENT_VISIBILITY="public"
    kk.decl._reset_next_modifiers
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

    constructor_body="$(kk.decl._rewrite_inherited "$class_name" "$constructor_body")"
    eval "${class_name}_decl_constructor_body=\$constructor_body"
}

endImplementation() {
    local class_name="$1"
    [[ -n "$class_name" ]] || {
        kk.decl._error "endImplementation: CLASS_NAME is required"
        return 1
    }

    local finalized_var="${class_name}_decl_finalized"
    if [[ "${!finalized_var:-0}" != "1" ]]; then
        kk.decl._error "endImplementation: Class '${class_name}' must be closed with endClass first"
        return 1
    fi

    local parent_var="${class_name}_decl_parent"
    local parent_class="${!parent_var}"
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

    if [[ -n "${!constructor_var}" ]]; then
        class_args+=("constructor" "${!constructor_var}")
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