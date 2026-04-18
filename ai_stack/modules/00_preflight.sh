#!/bin/bash
# ================================================================
#  modules/00_preflight.sh — System and asset checks before
#  any installation begins. Fails fast on unrecoverable issues.
#  Depends on: lib/common.sh, lib/config.sh
# ================================================================

preflight() {
    STEP "System check"

    [[ "$(uname -m)" == "x86_64" ]] || ERR "x86_64 architecture required."

    # ── Asset check (fail here, not halfway through install) ──────
    INFO "Checking bundled assets…"
    validate_assets

    # ── GPU detection ─────────────────────────────────────────────
    echo -e "${W}  GPU detection:${N}"

    if clinfo 2>/dev/null | grep -i "Device Name" | grep -iq "Arc"; then
        OK "Intel Arc GPU visible via OpenCL"
    else
        WARN "Intel Arc GPU NOT visible via OpenCL (drivers may not be installed yet)"
    fi

    if lspci | grep -qi "Arc A770"; then
        OK "Intel Arc A770 confirmed via lspci."
    else
        WARN "Could not confirm Arc A770 via lspci — verify your GPU."
        lspci | grep -i "VGA\|Display\|3D" || true
    fi

    # ── Public IP warning ─────────────────────────────────────────
    if [[ "$LLAMA_HOST" == "0.0.0.0" ]]; then
        WARN "llama-server will bind to 0.0.0.0 — accessible on your LAN."
        WARN "If this machine has a public IP, consider changing LLAMA_HOST in lib/config.sh."
    fi

    # ── Disk / RAM ─────────────────────────────────────────────────
    echo ""
    INFO "Available disk : $(df -h "$HOME" | awk 'NR==2{print $4}') free"
    INFO "System RAM     : $(free -h | awk '/Mem:/ {print $2}')"
    WARN "The 8B model download is ~5 GB. Ensure you have at least 8 GB free total."

    ask "Continue with installation?" || exit 0
}
