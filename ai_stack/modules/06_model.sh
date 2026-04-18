#!/bin/bash
# ================================================================
#  modules/06_model.sh — LLM model download + checksum verify.
#  Depends on: lib/common.sh, lib/config.sh
# ================================================================

_verify_model_checksum() {
    if [[ -z "${MODEL_SHA256:-}" ]]; then
        WARN "No SHA256 checksum configured — skipping verification."
        WARN "Set MODEL_SHA256 in lib/config.sh for integrity checking."
        return 0
    fi

    INFO "Verifying model checksum…"
    local actual
    actual=$(sha256sum "$MODEL_PATH" | awk '{print $1}')

    if [[ "$actual" == "$MODEL_SHA256" ]]; then
        OK "Checksum verified ✓"
    else
        WARN "Checksum MISMATCH — removing corrupted file."
        WARN "  Expected: $MODEL_SHA256"
        WARN "  Got:      $actual"
        rm -f "$MODEL_PATH"
        ERR "Model download appears corrupted. Re-run to retry."
    fi
}

download_model() {
    STEP "5/7  LLM model (Llama-3.1-8B Q4_K_M, ~5 GB)"
    INFO "The A770's 16 GB VRAM fits this model fully on-GPU."

    mkdir -p "$MODEL_DIR"

    if [[ -f "$MODEL_PATH" ]]; then
        OK "Model file present — verifying checksum…"
        _verify_model_checksum
        return
    fi

    INFO "Downloading from Hugging Face — this will take a while ☕"
    wget \
        --continue \
        --tries=5 \
        --timeout=30 \
        --show-progress \
        -O "$MODEL_PATH" \
        "$MODEL_URL" \
        || { rm -f "$MODEL_PATH"; ERR "Download failed — partial file removed."; }

    _verify_model_checksum
    OK "Model saved → $MODEL_PATH"
}
