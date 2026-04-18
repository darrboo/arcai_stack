#!/bin/bash
# ================================================================
#  modules/04_rust.sh — Rust toolchain installation.
#  Depends on: lib/common.sh
# ================================================================

install_rust() {
    STEP "3/7  Rust toolchain"

    if command -v cargo &>/dev/null; then
        OK "Rust already present: $(rustc --version)"
    else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
            | sh -s -- -y --no-modify-path
        # shellcheck source=/dev/null
        source "$HOME/.cargo/env"
        OK "Rust installed: $(rustc --version)"
    fi

    export PATH="$HOME/.cargo/bin:$PATH"
}
