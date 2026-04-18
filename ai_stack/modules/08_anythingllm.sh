#!/bin/bash
# ================================================================
#  modules/08_anythingllm.sh — AnythingLLM AppImage + search proxy.
#  Depends on: lib/common.sh, lib/config.sh
# ================================================================

_install_anythingllm_appimage() {
    mkdir -p "$APPS_DIR"
    local ai="$APPS_DIR/AnythingLLM.AppImage"

    if [[ -f "$ai" ]]; then
        OK "AnythingLLM already present."
        return
    fi

    ask "Download AnythingLLM AppImage?" || { WARN "Skipped AnythingLLM."; return; }

    wget -q --show-progress -O "$ai" "$ANYTHINGLLM_APPIMAGE_URL"
    chmod +x "$ai"

    mkdir -p "$HOME/.local/share/applications" "$HOME/.local/bin"

    cat > "$HOME/.local/share/applications/anythingllm.desktop" <<DESK
[Desktop Entry]
Name=AnythingLLM
Exec=$ai
Icon=utilities-terminal
Type=Application
Categories=Office;AI;
DESK

    ln -sf "$ai" "$HOME/.local/bin/anythingllm"
    OK "AnythingLLM installed → $ai"
}

_install_search_proxy() {
    mkdir -p "$PROXY_DIR"

    if [[ -f "$PROXY_MARKER" ]]; then
        OK "Search proxy already installed."
        return
    fi

    cp "$ASSETS_DIR/search_proxy.py" "$PROXY_SCRIPT"
    OK "Copied search_proxy.py"

    INFO "Creating search proxy venv…"
    python3 -m venv "$PROXY_VENV"
    "$PROXY_VENV/bin/pip" install --upgrade pip --quiet
    "$PROXY_VENV/bin/pip" install httpx fastapi "uvicorn[standard]"

    cat > "$PROXY_DIR/start_search_proxy.sh" <<PROXYSTART
#!/bin/bash
export LLAMA_URL="\${LLAMA_URL:-http://localhost:${LLAMA_PORT}}"
export LLAMA_API_KEY="\${LLAMA_API_KEY:-${LLAMA_API_KEY}}"
export SEARXNG_URL="\${SEARXNG_URL:-${SEARXNG_URL}}"
export PROXY_PORT="\${PROXY_PORT:-${SEARCH_PROXY_PORT}}"
exec "$PROXY_VENV/bin/python" "$PROXY_SCRIPT"
PROXYSTART
    chmod +x "$PROXY_DIR/start_search_proxy.sh"

    touch "$PROXY_MARKER"
    OK "Search proxy installed — listens on :${SEARCH_PROXY_PORT}, forwards to llama-server :${LLAMA_PORT}"
    INFO "Point AnythingLLM at http://localhost:${SEARCH_PROXY_PORT} (not ${LLAMA_PORT}) to enable web search."
}

install_anythingllm() {
    STEP "7/7  AnythingLLM + Search Proxy"
    _install_anythingllm_appimage
    _install_search_proxy
}
