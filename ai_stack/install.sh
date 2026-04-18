#!/bin/bash
# ================================================================
#  install.sh — AI Stack Installer entry point
#  Ubuntu 24.04 · Intel Arc A770 (SYCL/oneAPI)
#
#  Usage:
#    ./install.sh                   Full install
#    ./install.sh --update-llama    Pull + rebuild llama.cpp only
#    ./install.sh --only=05         Run one module by number
#    ./install.sh --skip=08         Skip one module by number
#    ./install.sh --help
#
#  Env overrides (skip interactive prompts):
#    ENABLE_DEBUG=1 ENABLE_BITNET=1 ./install.sh
# ================================================================
set -euo pipefail
[[ "${DEBUG:-0}" == "1" ]] && set -x

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Load libraries (order matters) ──────────────────────────────
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/cmake_guard.sh"

# ── Load all modules and scripts ────────────────────────────────
for _f in \
    "$SCRIPT_DIR"/modules/[0-9]*.sh \
    "$SCRIPT_DIR"/scripts/*.sh
do
    # shellcheck source=/dev/null
    source "$_f"
done
unset _f

# ── Resolve assets dir now that SCRIPT_DIR is known ─────────────
resolve_assets_dir "$SCRIPT_DIR"

# ================================================================
#  Helpers
# ================================================================
usage() {
    echo ""
    echo -e "  ${W}Usage:${N} ./install.sh [option]"
    echo ""
    echo "  (no args)           Full install"
    echo "  --update-llama      Pull + rebuild llama.cpp only"
    echo "  --only=NN           Run only module NN (e.g. --only=05)"
    echo "  --skip=NN           Skip module NN during full install"
    echo "  --help              Show this message"
    echo ""
    echo -e "  ${W}Env overrides:${N}"
    echo "  ENABLE_DEBUG=1      Enable verbose build output"
    echo "  ENABLE_BITNET=1     Enable BitNet support"
    echo ""
}

# Run a single numbered module by prefix (e.g. "05" → modules/05_llamacpp.sh)
run_only() {
    local prefix="$1"
    local matched=0
    for _f in "$SCRIPT_DIR"/modules/${prefix}_*.sh; do
        if [[ -f "$_f" ]]; then
            INFO "Running single module: $_f"
            # Functions already sourced — call the right one based on filename
            matched=1
        fi
    done
    [[ "$matched" -eq 1 ]] || ERR "No module found with prefix: $prefix"
}

print_summary() {
    echo ""
    echo -e "${W}${G}╔══════════════════════════════════════════════════╗"
    echo -e "║  🎉  Installation Complete!  (Intel Arc A770)    ║"
    echo -e "╚══════════════════════════════════════════════════╝${N}"
    echo ""
    echo -e "${W}  GPU backend:${N}    SYCL (level_zero:0) — full A770 16 GB VRAM"
    echo -e "${W}  Model:${N}          Llama-3.1-8B Q4_K_M (~5 GB on VRAM)"
    echo -e "${W}  API:${N}            http://localhost:${LLAMA_PORT}"
    echo ""
    echo -e "${W}  To start the stack:${N}"
    echo -e "  ${C}bash $INSTALL_DIR/start_ai_stack.sh${N}"
    echo ""
    echo -e "${W}  Test the API:${N}"
    echo -e "  ${C}curl http://localhost:${LLAMA_PORT}/v1/chat/completions \\"
    echo -e "    -H 'Content-Type: application/json' \\"
    echo -e "    -d '{\"model\":\"llama\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}'${N}"
    echo ""
    WARN "Re-login (or reboot) before first use — required for GPU group membership and oneAPI env."
    sleep 5
}

# ================================================================
#  Main install sequence
# ================================================================
SKIP_MODULE="${SKIP_MODULE:-}"

main() {
    clear
    echo -e "${W}${C}"
    echo "  ╔══════════════════════════════════════════════╗"
    echo "  ║   LOCAL AI STACK INSTALLER                   ║"
    echo "  ║   Ubuntu 24.04  ·  Intel Arc A770  (SYCL)    ║"
    echo "  ╚══════════════════════════════════════════════╝"
    echo -e "${N}"

    preflight                                            # 00
    install_system_deps                                  # 01
    configure_options                                    # 02
    install_intel_gpu_drivers                            # 03
    write_uninstall_script
    install_rust                                         # 04
    install_llamacpp_sycl                                # 05
    download_model                                       # 06
    install_memory_server                                # 07
    # install_anythingllm                                # 08 — uncomment to enable
    configure_shell
    write_startup_script
    print_summary
}

# ================================================================
#  Arg parser
# ================================================================
case "${1:-}" in
    --update-llama)
        update_llamacpp
        ;;
    --only=*)
        run_only "${1#--only=}"
        ;;
    --skip=*)
        SKIP_MODULE="${1#--skip=}"
        main
        ;;
    --help|-h)
        usage
        ;;
    "")
        main
        ;;
    *)
        ERR "Unknown argument: $1  (use --help for usage)"
        ;;
esac
