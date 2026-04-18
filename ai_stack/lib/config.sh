#!/bin/bash
# ================================================================
#  lib/config.sh — Single source of truth for all configuration.
#  Edit this file to change paths, model, or component versions.
#  Depends on: lib/common.sh (for ERR)
# ================================================================

# ── Base directories ─────────────────────────────────────────────
INSTALL_DIR="$HOME/ai_stack"
MODEL_DIR="$INSTALL_DIR/models"
APPS_DIR="$HOME/Applications"
LOG_DIR="$INSTALL_DIR/logs"

# ── llama.cpp ────────────────────────────────────────────────────
# Check https://github.com/ggerganov/llama.cpp/releases for updates
LLAMACPP_REPO="https://github.com/ggerganov/llama.cpp"
LLAMACPP_DIR="$INSTALL_DIR/llama.cpp"
LLAMACPP_BIN="$LLAMACPP_DIR/build/bin/llama-server"

# ── Model ────────────────────────────────────────────────────────
# A770 has 16 GB VRAM — Llama-3.1-8B Q4_K_M fits fully on-GPU (~5 GB)
# Check https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF for updates
MODEL_NAME="Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf"
MODEL_URL="https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf"
MODEL_SHA256="a9545e8f744c40880939f4e4db01d1ce4d06e64a3f4f6759165c9a0c59e8c20b"
MODEL_PATH="$MODEL_DIR/$MODEL_NAME"

# ── AnythingLLM ──────────────────────────────────────────────────
# Check https://github.com/Mintplex-Labs/anything-llm/releases for updates
ANYTHINGLLM_APPIMAGE_URL="https://cdn.anythingllm.com/latest/AnythingLLMDesktop-x86_64.AppImage"

# ── llama-server runtime settings ────────────────────────────────
LLAMA_PORT=8080
LLAMA_HOST="0.0.0.0"
LLAMA_CTX_SIZE=8192
LLAMA_GPU_LAYERS=99
LLAMA_API_KEY="local"

# ── Memory server ────────────────────────────────────────────────
MEMORY_SERVER_PORT=8090

# ── Search proxy ─────────────────────────────────────────────────
SEARCH_PROXY_PORT=8090
SEARXNG_URL="http://localhost:8081"

# ── Runtime feature flags ────────────────────────────────────────
# These start unset; configure_options() (module 02) sets them
# interactively. Override via environment to skip the prompts:
#   ENABLE_DEBUG=1 ENABLE_BITNET=1 ./install.sh
ENABLE_DEBUG="${ENABLE_DEBUG:-0}"
ENABLE_BITNET="${ENABLE_BITNET:-0}"

# ── Derived paths (do not edit) ───────────────────────────────────
MEM_DIR="$INSTALL_DIR/memory_server"
MEM_VENV="$MEM_DIR/.venv"
MEM_SCRIPT="$MEM_DIR/memory_server.py"
MEM_MARKER="$MEM_DIR/.installed"

PROXY_DIR="$INSTALL_DIR/search_proxy"
PROXY_VENV="$PROXY_DIR/.venv"
PROXY_SCRIPT="$PROXY_DIR/search_proxy.py"
PROXY_MARKER="$PROXY_DIR/.installed"

# ── Assets (bundled Python servers) ──────────────────────────────
# Resolved at runtime relative to install.sh location
ASSETS_DIR=""   # set by install.sh after SCRIPT_DIR is known

resolve_assets_dir() {
    local script_dir="$1"
    ASSETS_DIR="$script_dir/assets"
    if [[ ! -d "$ASSETS_DIR" ]]; then
        ERR "assets/ directory not found at $ASSETS_DIR"
    fi
}

# ── Validate critical paths exist at startup ──────────────────────
validate_assets() {
    local missing=0
    for f in memory_server.py search_proxy.py; do
        if [[ ! -f "$ASSETS_DIR/$f" ]]; then
            WARN "Missing required asset: $ASSETS_DIR/$f"
            (( missing++ )) || true
        fi
    done
    [[ "$missing" -eq 0 ]] || ERR "Missing $missing required asset(s) — cannot continue."
}
