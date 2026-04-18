#!/bin/bash
# ================================================================
#  scripts/write_startup.sh — Generates start_ai_stack.sh from
#  templates/start_ai_stack.sh.tpl, substituting config values
#  at write time so the generated script is self-contained.
#  Depends on: lib/common.sh, lib/config.sh
# ================================================================

write_startup_script() {
    STEP "Writing startup script"

    local tpl="$SCRIPT_DIR/templates/start_ai_stack.sh.tpl"
    local out="$INSTALL_DIR/start_ai_stack.sh"

    [[ -f "$tpl" ]] || ERR "Template not found: $tpl"

    sed \
        -e "s|{{LLAMACPP_BIN}}|$LLAMACPP_BIN|g" \
        -e "s|{{MODEL_PATH}}|$MODEL_PATH|g" \
        -e "s|{{INSTALL_DIR}}|$INSTALL_DIR|g" \
        -e "s|{{LOG_DIR}}|$LOG_DIR|g" \
        -e "s|{{LLAMA_PORT}}|$LLAMA_PORT|g" \
        -e "s|{{LLAMA_HOST}}|$LLAMA_HOST|g" \
        -e "s|{{LLAMA_CTX_SIZE}}|$LLAMA_CTX_SIZE|g" \
        -e "s|{{LLAMA_GPU_LAYERS}}|$LLAMA_GPU_LAYERS|g" \
        -e "s|{{LLAMA_API_KEY}}|$LLAMA_API_KEY|g" \
        "$tpl" > "$out"

    chmod +x "$out"
    OK "Startup script written → $out"
}
