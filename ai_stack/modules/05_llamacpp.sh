#!/bin/bash
# ================================================================
#  modules/05_llamacpp.sh — llama.cpp SYCL build for Intel Arc.
#  Provides: install_llamacpp_sycl(), update_llamacpp()
#  Depends on: lib/common.sh, lib/config.sh, lib/cmake_guard.sh
# ================================================================

# ── Locate Intel compilers ───────────────────────────────────────
# Exported so update_llamacpp() can reuse without duplicating logic.
_locate_intel_compilers() {
    ICX_BIN=$(command -v icx 2>/dev/null) \
        || ICX_BIN=$(find /opt/intel/oneapi -name icx  -type f 2>/dev/null | sort -r | head -1) \
        || true
    ICPX_BIN=$(command -v icpx 2>/dev/null) \
        || ICPX_BIN=$(find /opt/intel/oneapi -name icpx -type f 2>/dev/null | sort -r | head -1) \
        || true

    [[ -n "$ICX_BIN" && -n "$ICPX_BIN" ]] \
        || ERR "Intel icx/icpx compilers not found. Did step 2 (intel_drivers) succeed?"

    export PATH="$(dirname "$ICX_BIN"):$PATH"
    export SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1
    INFO "Compilers: icx=$ICX_BIN  icpx=$ICPX_BIN"
}

# ── Source oneAPI environment ─────────────────────────────────────
_source_oneapi_env() {
    if [[ -f /opt/intel/oneapi/setvars.sh ]]; then
        INFO "Sourcing Intel oneAPI environment…"
        # shellcheck source=/dev/null
        source /opt/intel/oneapi/setvars.sh --force >/dev/null 2>&1

        if command -v icx &>/dev/null && command -v icpx &>/dev/null; then
            OK "oneAPI environment loaded (icx/icpx in PATH)"
        else
            WARN "setvars.sh loaded but compilers still not in PATH"
        fi
    else
        WARN "setvars.sh not found — attempting manual SYCL detection"

        local SYCL_LIB
        SYCL_LIB=$(find /opt/intel/oneapi -type f -name "libsycl.so*" 2>/dev/null \
                   | sort -r | head -1 | xargs dirname 2>/dev/null) || true
        if [[ -n "$SYCL_LIB" ]]; then
            export LD_LIBRARY_PATH="$SYCL_LIB:${LD_LIBRARY_PATH:-}"
            OK "Found SYCL runtime → $SYCL_LIB"
        else
            WARN "Could not locate libsycl.so — SYCL backend may fail at runtime"
        fi
    fi
}

# ── CMake configure + build ───────────────────────────────────────
_cmake_build() {
    local bitnet_flag=""
    [[ "${ENABLE_BITNET:-0}" == "1" ]] && bitnet_flag="-DGGML_USE_BITNET=ON"

    ensure_cmake_generator "$LLAMACPP_DIR/build" "Ninja"

    INFO "Configuring CMake with SYCL backend${bitnet_flag:+ + BitNet}…"
    cmake -B "$LLAMACPP_DIR/build" \
        -S "$LLAMACPP_DIR" \
        -G Ninja \
        -DGGML_SYCL=ON \
        ${bitnet_flag:+"$bitnet_flag"} \
        -DCMAKE_C_COMPILER="$ICX_BIN" \
        -DCMAKE_CXX_COMPILER="$ICPX_BIN" \
        -DCMAKE_BUILD_TYPE=Release \
        -DGGML_SYCL_F16=ON

    INFO "Building llama.cpp ($(nproc) cores — takes a few minutes)…"
    cmake --build "$LLAMACPP_DIR/build" --config Release -j"$(nproc)"

    [[ -f "$LLAMACPP_BIN" ]] \
        && OK "llama-server built → $LLAMACPP_BIN" \
        || ERR "Build finished but llama-server binary not found — check output above."
}

# ── Public: full install ─────────────────────────────────────────
install_llamacpp_sycl() {
    STEP "4/7  llama.cpp + SYCL backend (Intel Arc A770)"

    if [[ -f "$LLAMACPP_BIN" ]]; then
        if ask "llama-server already exists. Rebuild?" "n"; then
            INFO "Rebuilding…"
        else
            OK "Skipping rebuild — using existing binary."
            return
        fi
    fi

    sudo apt-get install -y --no-install-recommends ninja-build libopenblas-dev

    if [[ -d "$LLAMACPP_DIR/.git" ]]; then
        INFO "Updating existing llama.cpp repo…"
        git -C "$LLAMACPP_DIR" pull --ff-only
    else
        INFO "Cloning llama.cpp…"
        git clone --depth=1 "$LLAMACPP_REPO" "$LLAMACPP_DIR"
    fi

    _source_oneapi_env
    _locate_intel_compilers
    _cmake_build

    PAUSE
}

# ── Public: fast update (pull + rebuild only) ─────────────────────
update_llamacpp() {
    STEP "Updating llama.cpp (pull + rebuild)"

    [[ -d "$LLAMACPP_DIR/.git" ]] \
        || ERR "llama.cpp not installed yet. Run the full installer first."

    INFO "Pulling latest changes…"
    git -C "$LLAMACPP_DIR" fetch --all
    git -C "$LLAMACPP_DIR" reset --hard origin/master

    _source_oneapi_env
    _locate_intel_compilers
    _cmake_build

    OK "llama.cpp updated successfully 🚀"
}
