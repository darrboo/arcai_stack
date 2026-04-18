#!/bin/bash
# ================================================================
#  lib/cmake_guard.sh — CMake generator consistency guard.
#  Call before every cmake -B invocation that specifies -G.
#  Depends on: lib/common.sh
# ================================================================

ensure_cmake_generator() {
    local build_dir="$1"
    local desired_gen="$2"
    local cache_file="$build_dir/CMakeCache.txt"

    if [[ ! -f "$cache_file" ]]; then
        INFO "No existing CMake cache — fresh configure."
        return 0
    fi

    local current_gen
    current_gen=$(grep "CMAKE_GENERATOR:INTERNAL=" "$cache_file" \
        | cut -d= -f2 || true)

    if [[ -z "$current_gen" ]]; then
        WARN "Could not detect existing generator — cleaning to be safe."
        rm -rf "$build_dir"
        return 0
    fi

    if [[ "$current_gen" == "$desired_gen" ]]; then
        OK "CMake generator matches ($desired_gen) — reusing build directory."
        return 0
    fi

    echo ""
    WARN "CMake generator mismatch detected:"
    echo -e "  Existing: ${Y}$current_gen${N}"
    echo -e "  Required: ${Y}$desired_gen${N}"
    echo ""

    if ask "Clean build directory to fix this automatically?"; then
        INFO "Cleaning build directory…"
        rm -rf "$build_dir"
        OK "Build directory reset."
    else
        ERR "Cannot continue with mismatched generator."
    fi
}
