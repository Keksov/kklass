#!/bin/bash

kk.write() {
    echo -en "$@"
}

kk.writeln() {
    echo -e "$@"
}

kk.getScriptDir() {
    local source_file="${1:-${BASH_SOURCE[1]}}"
    
    #Attempt to resolve symlink (works on Linux, ignores errors on macOS)
    source_file="$(readlink -f "${source_file}" 2>/dev/null || echo "${source_file}")"
    
    cd "$(dirname "${source_file}")" && pwd
}