#!/bin/bash
# kklass_cnfh.sh - Версия с command_not_found_handle
# Полностью беспроксийная архитектура - методы вызываются через перехват команд
# Минусы: нужно использовать конструкцию $(obj.method) или исполнять через eval
# для передачи данных обратно в основную оболочку

defineClass() {
    local class_name="$1"
    shift
    
    local -A methods=()
    
    while [[ $# -gt 0 ]]; do
        local method_name="$1"
        local method_body="$2"
        shift 2
        
        methods["$method_name"]="$method_body"
    done
    
    eval "declare -gA ${class_name}_methods"
    eval "declare -gA ${class_name}_method_bodies"
    
    for m in "${!methods[@]}"; do
        eval "${class_name}_methods[$m]=1"
        eval "${class_name}_method_bodies[$m]=\${methods[$m]}"
    done
    
    # Методы класса - один раз для всех объектов
    for m in "${!methods[@]}"; do
        local body="${methods[$m]}"
        body="${body//\$this/\$__inst__}"
        body="${body//\$\{this\}/\$\{__inst__\}}"
        
        eval "${class_name}.${m}() {
            local -n __inst__=\"\$1\"
            shift
            ${body}
        }"
    done
    
    # .new() создаёт только массив объекта
    eval "${class_name}.new() {
        local obj_name=\"\$1\"
        shift
        
        [[ \"\$obj_name\" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || {
            echo \"Invalid object name: \$obj_name\" >&2
            return 1
        }
        
        # Только создаём массив
        declare -gA \${obj_name}
        eval \"\${obj_name}[__class__]='$class_name'\"
        
        # Конструктор если есть
        if declare -f \"${class_name}.constructor\" >/dev/null 2>&1; then
            ${class_name}.constructor \"\$obj_name\" \"\$@\"
        fi
    }"
}

# Перехват команд вида obj.method для вызова ClassName.method obj
command_not_found_handle() {
    local cmd="$1"
    shift
    
    if [[ "$cmd" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)\.(.*) ]]; then
        local obj_name="${BASH_REMATCH[1]}"
        local method_name="${BASH_REMATCH[2]}"
        
        if declare -p "$obj_name" &>/dev/null; then
            local -n vars_ref="$obj_name"
            local class_name="${vars_ref[__class__]}"
            
            if declare -f "${class_name}.${method_name}" >/dev/null 2>&1; then
                "${class_name}.${method_name}" "$obj_name" "$@"
                return $?
            fi
        fi
    fi
    
    echo "bash: $cmd: command not found" >&2
    return 127
}

declare -gA __TMyClass_vars
TMyClass.create() {
    local obj_name="$1"
    #__TMyClass_vars
}

declare -gA __vars_main_TMyClass_obj1=(
    ["name"]="John Doe"
    ["age"]="30"
    ["id"]="1001"
)

TMyClass.getField() {
    local context_name="main"
    local class_name="TMyClass"
    local obj_name="obj1"
    local field_name="$1"
    
    local vars_name="__vars_${context_name}_${class_name}_${obj_name}"

    if ! declare -p "$vars_name" &>/dev/null; then
        echo "ERROR: array '$vars_name' not found" >&2
        return 1
    elif [[ $(declare -p "$vars_name" 2>/dev/null) != 'declare -A'* ]]; then
        echo "ERROR: '$vars_name' is not an associative array" >&2
        return 2
    fi

    local -n vars_ref="$vars_name"

    if [[ -z "${vars_ref[$field_name]+exists}" ]]; then
        echo "Error: the field '$field_name' doesn't exist" >&2
        return 3
    fi

    if [[ -z "$2" ]]; then
        echo -n "${vars_ref[$field_name]}"
        return 0
    fi

    local -n result_ref="$2" 
    result_ref="${vars_ref[$field_name]}"
}

defineClass Person \
    "constructor" "
        __inst__[name]='John'
        __inst__[age]=30
    " \
    "setName" "
        __inst__[name]=\$1
    " \
    "getName" "
        echo \"\${__inst__[name]}\"
    " \
    "setAge" "
        __inst__[age]=\$1
    " \
    "getAge" "
        echo \"\${__inst__[age]}\"
    " \
    "greet" "
        local name=\${__inst__[name]}
        local age=\${__inst__[age]}
        echo \"Hello, I am \$name and I am \$age years old\"
    " \
    "birthday" "
        local current_age=\${__inst__[age]}
        __inst__[age]=\$((current_age + 1))
        echo \"\${__inst__[name]} is now \${__inst__[age]} years old\"
    "

export -f defineClass command_not_found_handle
