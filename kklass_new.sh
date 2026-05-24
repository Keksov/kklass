#!/bin/bash
# kklass_new.sh - Оптимизированная система классов для bash
# Архитектура:
# - Методы класса определяются один раз (не дублируются)
# - .new() создаёт только ассоциативный массив объекта
# - Маленькие proxy функции для вызова методов
# - nameref для передачи контекста объекта

# Определение класса с методами
# defineClass ClassName method1_name method1_body method2_name method2_body ...
defineClass() {
    local class_name="$1"
    shift
    
    local -A methods=()
    
    # Парсим пары метод/тело
    while [[ $# -gt 0 ]]; do
        local method_name="$1"
        local method_body="$2"
        shift 2
        
        methods["$method_name"]="$method_body"
    done
    
    # Сохраняем метаданные класса
    eval "declare -gA ${class_name}_methods"
    eval "declare -gA ${class_name}_method_bodies"
    
    for m in "${!methods[@]}"; do
        eval "${class_name}_methods[$m]=1"
        eval "${class_name}_method_bodies[$m]=\${methods[$m]}"
    done
    
    # Создаём функции методов класса (один раз для всех объектов)
    for m in "${!methods[@]}"; do
        local body="${methods[$m]}"
        
        # Заменяем $this на __inst__ в теле метода
        body="${body//\$this/\$__inst__}"
        body="${body//\$\{this\}/\$\{__inst__\}}"
        
        # Создаём функцию метода класса, которая принимает объект первым аргументом
        eval "${class_name}.${m}() {
            local -n __inst__=\"\$1\"
            shift
            ${body}
        }"
    done
    
    # Создаём функцию .new() для создания объектов
    eval "${class_name}.new() {
        local obj_name=\"\$1\"
        shift
        
        # Проверяем валидность имени
        [[ \"\$obj_name\" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || {
            echo \"Invalid object name: \$obj_name\" >&2
            return 1
        }
        
        # Создаём глобальный ассоциативный массив объекта
        declare -gA \${obj_name}
        
        # Сохраняем класс объекта
        eval \"\${obj_name}[__class__]='$class_name'\"
        
        # Создаём маленькие proxy функции для каждого метода
        local -n methods_ref=\"${class_name}_methods\"
        for meth in \"\${!methods_ref[@]}\"; do
            eval \"\${obj_name}.\${meth}() {
                ${class_name}.\${meth} \\\"\${obj_name}\\\" \\\"\\\$@\\\"
            }\"
        done
        
        # Вызываем конструктор если он определён
        if declare -f \"${class_name}.constructor\" >/dev/null 2>&1; then
            ${class_name}.constructor \"\$obj_name\" \"\$@\"
        fi
    }"
}

# Пример использования для тестирования
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

# Альтернативный вариант с command_not_found_handle
# (раскомментировать если нужны беспроксийные вызовы)
: <<'COMMAND_NOT_FOUND_HANDLER'
command_not_found_handle() {
    local cmd="$1"
    shift
    
    # Парсим "obj1.method_name"
    if [[ "$cmd" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)\.(.*) ]]; then
        local obj_name="${BASH_REMATCH[1]}"
        local method_name="${BASH_REMATCH[2]}"
        
        # Проверяем, существует ли объект (массив)
        if declare -p "$obj_name" &>/dev/null; then
            local -n obj_ref="$obj_name"
            local class_name="${obj_ref[__class__]}"
            
            # Проверяем, существует ли метод в классе
            if declare -f "${class_name}.${method_name}" >/dev/null 2>&1; then
                "${class_name}.${method_name}" "$obj_name" "$@"
                return $?
            fi
        fi
    fi
    
    echo "bash: $cmd: command not found" >&2
    return 127
}
COMMAND_NOT_FOUND_HANDLER

export -f defineClass
