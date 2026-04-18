#!/bin/bash
# ================================================================
#  modules/07_memory_server.sh — mem0 + ChromaDB memory server.
#  Depends on: lib/common.sh, lib/config.sh
# ================================================================

install_memory_server() {
    STEP "6/7  Memory server (mem0 · ChromaDB · sentence-transformers)"

    mkdir -p "$MEM_DIR"

    if [[ -f "$MEM_MARKER" && -f "$MEM_SCRIPT" ]]; then
        OK "Memory server already installed."
        return
    fi

    # Copy the bundled server script
    cp "$ASSETS_DIR/memory_server.py" "$MEM_SCRIPT"
    OK "Copied memory_server.py"

    INFO "Creating Python venv…"
    python3 -m venv "$MEM_VENV"
    "$MEM_VENV/bin/pip" install --upgrade pip --quiet

    INFO "Step 1/3 — web framework…"
    "$MEM_VENV/bin/pip" install fastapi "uvicorn[standard]"

    INFO "Step 2/3 — mem0ai + ChromaDB (~200 MB)…"
    "$MEM_VENV/bin/pip" install mem0ai chromadb

    INFO "Step 3/3 — sentence-transformers + huggingface-hub (~300 MB)…"
    "$MEM_VENV/bin/pip" install sentence-transformers huggingface-hub

    cat > "$MEM_DIR/start_memory_server.sh" <<MEMSTART
#!/bin/bash
source "$MEM_VENV/bin/activate"
export LLAMA_BASE_URL="\${LLAMA_BASE_URL:-http://localhost:${LLAMA_PORT}/v1}"
export LLAMA_API_KEY="\${LLAMA_API_KEY:-${LLAMA_API_KEY}}"
export LLAMA_MODEL="\${LLAMA_MODEL:-llama}"
exec python3 "$MEM_SCRIPT"
MEMSTART
    chmod +x "$MEM_DIR/start_memory_server.sh"

    touch "$MEM_MARKER"
    OK "Memory server installed → $MEM_DIR"
    INFO "First launch will download the sentence-transformer model (~22 MB)."
}
