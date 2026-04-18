#!/bin/bash
# ================================================================
#  modules/02_configure_options.sh — Interactive feature flags.
#  Honours pre-set env vars so automated runs skip the prompts.
#  Depends on: lib/common.sh, lib/config.sh
# ================================================================

configure_options() {
    STEP "Configuration"

    # Debug mode — skip prompt if already set via environment
    if [[ "$ENABLE_DEBUG" == "1" ]]; then
        INFO "Debug mode: ENABLED (via environment)"
        set -x
    elif ask "Enable debug mode (verbose build logs)?" "n"; then
        ENABLE_DEBUG=1
        set -x
        INFO "Debug mode enabled."
    else
        ENABLE_DEBUG=0
        INFO "Debug mode disabled."
    fi

    # BitNet — skip prompt if already set via environment
    if [[ "$ENABLE_BITNET" == "1" ]]; then
        INFO "BitNet support: ENABLED (via environment)"
    elif ask "Enable BitNet support (experimental)?" "n"; then
        ENABLE_BITNET=1
        INFO "BitNet support enabled."
    else
        ENABLE_BITNET=0
        INFO "BitNet disabled."
    fi

    # Export so subprocesses see them
    export ENABLE_DEBUG ENABLE_BITNET
}
