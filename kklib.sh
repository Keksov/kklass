#!/bin/bash

kk.write() {
    echo -en "$@"
}

kk.writeln() {
    echo -e "$@"
}


#set -eo pipefail

# Control flag for error trap (allow code to suppress intentional errors)
TRAP_ERRORS_ENABLED=true

# Error handling function
kk.errorHandler() {
    local exit_code=$?
    
    # Skip error output if disabled, but return the error code
    if [[ "$TRAP_ERRORS_ENABLED" == "false" ]]; then
        TRAP_ERRORS_ENABLED=true
        return $exit_code
    fi
    local line_number=$1
    local bash_lineno=$2
    local last_command="${BASH_COMMAND}"
    local func_name="${FUNCNAME[1]:-main}"
    
    echo "============================================" >&2
    echo "SCRIPT ERROR" >&2
    echo "============================================" >&2
    echo "Script:        ${BASH_SOURCE[1]:-$0}" >&2
    echo "Function:      $func_name" >&2
    echo "Line:          $line_number" >&2
    echo "Error code:    $exit_code" >&2
    echo "Command:       $last_command" >&2
    echo "============================================" >&2
    
    # Display call stack
    if [ ${#FUNCNAME[@]} -gt 2 ]; then
        echo "Call stack:" >&2
        local frame=0
        while caller $frame >&2; do
            ((frame++))
        done
        echo "============================================" >&2
    fi
    
    # Display code context (3 lines before and after error)
    if [ -f "${BASH_SOURCE[1]}" ]; then
        echo "Code context:" >&2
        local start=$((line_number - 3))
        local end=$((line_number + 3))
        [ $start -lt 1 ] && start=1
        
        awk -v start=$start -v end=$end -v err=$line_number '
            NR >= start && NR <= end {
                prefix = (NR == err) ? ">>> " : "    "
                printf "%s%4d: %s\n", prefix, NR, $0
            }
        ' "${BASH_SOURCE[1]}" >&2
        echo "============================================" >&2
    fi
    
    # Display environment variables (optional)
    # echo "Environment variables:" >&2
    # env | sort >&2
    
    exit $exit_code
    #return 0
}

trap 'kk.errorHandler ${LINENO} ${BASH_LINENO}' ERR