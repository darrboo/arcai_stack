#!/bin/bash
# ================================================================
#  lib/common.sh — Colours, logging, and user-interaction helpers
#  No dependencies — safe to source first.
# ================================================================

# ── Colours ─────────────────────────────────────────────────────
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m'
C='\033[0;36m' W='\033[1m'    N='\033[0m'

# ── Logging ─────────────────────────────────────────────────────
OK()   { echo -e "${G}  ✅  $*${N}"; }
INFO() { echo -e "${C}  ℹ️   $*${N}"; }
WARN() { echo -e "${Y}  ⚠️   $*${N}"; }
STEP() { echo -e "\n${W}${C}━━━  $*  ━━━${N}"; }

ERR() {
    echo -e "${R}  ❌  $*${N}" >&2
    # Kill any background pids recorded in the session
    if [[ -f "${INSTALL_DIR:-}/.pids" ]]; then
        while IFS= read -r pid; do
            kill "$pid" 2>/dev/null || true
        done < "${INSTALL_DIR}/.pids"
    fi
    exit 1
}

# ── Interaction ─────────────────────────────────────────────────
# ask "Question?" [default: y|n]  →  returns 0 (yes) or 1 (no)
ask() {
    local prompt="$1"
    local default="${2:-y}"
    local yn="[Y/n]"
    [[ "$default" == "n" ]] && yn="[y/N]"
    read -rp "$(echo -e "${Y}  ❓  $prompt $yn: ${N}")" r
    r="${r:-$default}"
    [[ "${r,,}" == "y" ]]
}

# PAUSE — only blocks when running in an interactive terminal
PAUSE() {
    [[ -t 1 ]] || return 0
    read -rp "$(echo -e "${Y}  Press Enter to continue…${N}")"
}
