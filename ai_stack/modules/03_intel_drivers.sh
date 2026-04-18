#!/bin/bash
# ================================================================
#  modules/03_intel_drivers.sh — Intel Arc GPU drivers + oneAPI.
#  Installs OpenCL ICD, level-zero, and the icx/icpx compilers.
#  Depends on: lib/common.sh
# ================================================================

# ── Repo setup helpers ───────────────────────────────────────────

_add_intel_gpu_repo() {
    if [[ -f /etc/apt/sources.list.d/intel-gpu.list ]]; then
        INFO "Intel GPU repo already configured."
        return
    fi
    INFO "Adding Intel GPU package repository…"
    # Key is fetched over HTTPS from Intel's official domain
    wget -qO - https://repositories.intel.com/gpu/intel-graphics.key \
        | sudo gpg --yes --dearmor \
            -o /usr/share/keyrings/intel-graphics.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] \
https://repositories.intel.com/gpu/ubuntu noble unified" \
        | sudo tee /etc/apt/sources.list.d/intel-gpu.list
    sudo apt-get update -qq || true
}

_add_oneapi_repo() {
    if [[ -f /etc/apt/sources.list.d/oneAPI.list ]]; then
        INFO "oneAPI repo already configured."
        return
    fi
    INFO "Adding Intel oneAPI repository…"
    wget -qO - https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB \
        | sudo gpg --yes --dearmor \
            -o /usr/share/keyrings/oneapi-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] \
https://apt.repos.intel.com/oneapi all main" \
        | sudo tee /etc/apt/sources.list.d/oneAPI.list
    sudo apt-get update -qq || true
}

# ── Driver packages ──────────────────────────────────────────────

_install_gpu_driver_packages() {
    INFO "Checking Intel GPU driver packages…"
    local PKGS=()

    if ! dpkg -l intel-opencl-icd 2>/dev/null | grep -q '^ii'; then
        PKGS+=("intel-opencl-icd")
    else
        INFO "  intel-opencl-icd     ✓ already installed"
    fi

    if dpkg -l libze-intel-gpu1 2>/dev/null | grep -q '^ii' \
    || dpkg -l intel-level-zero-gpu 2>/dev/null | grep -q '^ii'; then
        INFO "  level-zero GPU shim  ✓ already installed"
    else
        PKGS+=("libze-intel-gpu1")
    fi

    if ! dpkg -l libze1 2>/dev/null | grep -q '^ii'; then
        PKGS+=("libze1")
    else
        INFO "  libze1               ✓ already installed"
    fi

    if [[ ${#PKGS[@]} -gt 0 ]]; then
        INFO "  Installing: ${PKGS[*]}"
        sudo apt-get install -y "${PKGS[@]}" || true
    fi

    sudo apt-get install -y --no-install-recommends clinfo libze-dev 2>/dev/null || true
    OK "Intel GPU driver packages ready."
}

# ── oneAPI compiler ──────────────────────────────────────────────

_install_oneapi_compiler() {
    INFO "Checking Intel oneAPI compiler…"

    local ICX_BIN=""
    ICX_BIN=$(command -v icx 2>/dev/null) \
        || ICX_BIN=$(find /opt/intel/oneapi -name icx -type f 2>/dev/null | head -1) \
        || true

    if [[ -n "$ICX_BIN" ]]; then
        OK "Intel icx compiler found: $ICX_BIN"
        return
    fi

    INFO "Installing Intel oneAPI compiler (intel-oneapi-compiler-dpcpp-cpp)…"
    _add_oneapi_repo
    sudo apt-get install -y intel-oneapi-compiler-dpcpp-cpp

    ICX_BIN=$(command -v icx 2>/dev/null) \
        || ICX_BIN=$(find /opt/intel/oneapi -name icx -type f 2>/dev/null | head -1) \
        || true

    [[ -n "$ICX_BIN" ]] \
        && OK "icx installed: $ICX_BIN" \
        || ERR "icx still not found after install — check apt output above."
}

# ── Verify ───────────────────────────────────────────────────────

_verify_gpu_visibility() {
    INFO "GPU visibility check:"

    echo -e "  OpenCL (clinfo):"
    clinfo -l 2>/dev/null | grep -i "intel\|Arc" \
        || WARN "  No Intel GPU detected via OpenCL"

    echo -e "  level-zero backend:"
    if dpkg -l libze-intel-gpu1 2>/dev/null | grep -q '^ii'; then
        OK "  libze-intel-gpu1 installed — SYCL will see the GPU after re-login"
    else
        WARN "  libze-intel-gpu1 NOT installed — SYCL will not find the GPU!"
    fi
}

# ── Public entry point ───────────────────────────────────────────

install_intel_gpu_drivers() {
    STEP "2/7  Intel Arc A770 GPU drivers"

    _add_intel_gpu_repo
    _install_gpu_driver_packages
    _install_oneapi_compiler

    sudo usermod -aG render,video "$USER" 2>/dev/null || true
    OK "User added to render/video groups (re-login required)."

    _verify_gpu_visibility
}
