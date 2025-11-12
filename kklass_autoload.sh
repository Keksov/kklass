#!/bin/bash
# kklass_autoload.sh - Transparent auto-compilation mechanism for classes

# Get the directory where this script is located
KKLASS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Auto-load classes with transparent compilation
# Usage: autoloadClasses <source.kk> [--force-compile] [--no-compile]
autoloadClasses() {
    local source_file="$1"
    local force_compile=false
    local no_compile=false
    
    # Parse options
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force-compile|-f)
                force_compile=true
                shift
                ;;
            --no-compile|-n)
                no_compile=true
                shift
                ;;
            *)
                echo "Warning: Unknown option: $1" >&2
                shift
                ;;
        esac
    done
    
    # Validate source file
    if [[ ! -f "$source_file" ]]; then
        echo "Error: Source file not found: $source_file" >&2
        return 1
    fi
    
    # Generate compiled filename (.kk -> .ckk/filename.ckk.sh)
    local source_dir="$(dirname "$source_file")"
    local source_name="$(basename "$source_file")"
    local ckk_dir="$(pwd)/.ckk"
    local compiled_file="$ckk_dir/${source_name%.kk}.ckk.sh"
    
    # Create .ckk directory if it doesn't exist
    if [[ ! -d "$ckk_dir" ]]; then
        mkdir -p "$ckk_dir" 2>/dev/null || {
            echo "Warning: Could not create $ckk_dir, using source directory" >&2
            compiled_file="${source_file%.kk}.ckk.sh"
        }
    fi
    
    # Decision logic
    local needs_compilation=false
    
    if [[ "$force_compile" == true ]]; then
        needs_compilation=true
        echo "[autoload] Force compilation requested" >&2
    elif [[ "$no_compile" == true ]]; then
        needs_compilation=false
        if [[ ! -f "$compiled_file" ]]; then
            echo "[autoload] No compiled file found, using runtime mode" >&2
            source "$KKLASS_LIB_DIR/kklass.sh"
            source "$source_file"
            return 0
        fi
    elif [[ ! -f "$compiled_file" ]]; then
        needs_compilation=true
        echo "[autoload] Compiled file not found: $compiled_file" >&2
    else
        # Compare modification times
        local source_mtime=$(stat -c %Y "$source_file" 2>/dev/null || stat -f %m "$source_file" 2>/dev/null)
        local compiled_mtime=$(stat -c %Y "$compiled_file" 2>/dev/null || stat -f %m "$compiled_file" 2>/dev/null)
        
        if [[ -z "$source_mtime" || -z "$compiled_mtime" ]]; then
            # Fallback: use ls -l and date parsing (Windows compatibility)
            needs_compilation=true
            echo "[autoload] Cannot compare timestamps, recompiling" >&2
        elif [[ "$source_mtime" -gt "$compiled_mtime" ]]; then
            needs_compilation=true
            echo "[autoload] Source file is newer, recompiling" >&2
        else
            needs_compilation=false
        fi
    fi
    
    # Compile if needed
    if [[ "$needs_compilation" == true ]]; then
        echo "[autoload] Compiling: $source_file -> $compiled_file" >&2
        
        # Run compiler
        bash "$KKLASS_LIB_DIR/kklass_compiler.sh" "$source_file" "$compiled_file" >&2
        
        if [[ $? -ne 0 ]]; then
            echo "[autoload] Compilation failed! Falling back to runtime mode" >&2
            source "$KKLASS_LIB_DIR/kklass.sh"
            source "$source_file"
            return 0
        fi
        
        echo "[autoload] Compilation successful" >&2
    else
        echo "[autoload] Using cached compiled file: $compiled_file" >&2
    fi
    
    # Load compiled file
    source "$compiled_file"
    
    # Set flag to indicate compiled mode is active
    export KKLASS_COMPILED_MODE=1
    export KKLASS_COMPILED_FILE="$compiled_file"
    
    return 0
}

# Quick wrapper for common use case
# Usage: kkload <file.kk>
kkload() {
    autoloadClasses "$@"
}

# Force recompilation
# Usage: kkrecompile <file.kk>
kkrecompile() {
    autoloadClasses "$1" --force-compile
}

# Show information about loaded classes
kkinfo() {
    if [[ -n "$KKLASS_COMPILED_MODE" ]]; then
        echo "Mode: Compiled"
        echo "File: $KKLASS_COMPILED_FILE"
        
        # Extract class list from compiled file
        local classes=$(grep "^# Compiled classes:" "$KKLASS_COMPILED_FILE" | sed 's/^# Compiled classes: //')
        echo "Classes: $classes"
    else
        echo "Mode: Runtime (no compiled classes loaded)"
    fi
}

# Export functions
export -f autoloadClasses
export -f kkload
export -f kkrecompile
export -f kkinfo
