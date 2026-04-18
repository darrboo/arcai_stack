#!/bin/bash
# ================================================================
#  scripts/configure_shell.sh — Write AI stack env vars to shell rc.
#  Depends on: lib/common.sh
# ================================================================

configure_shell() {
    STEP "Shell configuration"

    local rc="$HOME/.bashrc"
    [[ -f "$HOME/.zshrc" ]] && rc="$HOME/.zshrc"

    local -a lines=(
        '# AI Stack'
        '[ -f /opt/intel/oneapi/setvars.sh ] && source /opt/intel/oneapi/setvars.sh --force >/dev/null 2>&1 || true'
        'export ONEAPI_DEVICE_SELECTOR="level_zero:0"'
        'export SYCL_DEVICE_FILTER="level_zero:gpu"'
        'export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"'
    )

    for line in "${lines[@]}"; do
        grep -qF "$line" "$rc" 2>/dev/null || echo "$line" >> "$rc"
    done

    OK "Shell configured ($rc). Run: source $rc"
}
