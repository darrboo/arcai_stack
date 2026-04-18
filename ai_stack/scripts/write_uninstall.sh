#!/bin/bash
# ================================================================
#  scripts/write_uninstall.sh — Generates uninstall_ai_stack.sh
#  from templates/uninstall.sh.tpl.
#  Depends on: lib/common.sh, lib/config.sh
# ================================================================

write_uninstall_script() {
    STEP "Writing uninstall script"

    local tpl="$SCRIPT_DIR/templates/uninstall.sh.tpl"
    local out="$HOME/uninstall_ai_stack.sh"

    [[ -f "$tpl" ]] || ERR "Template not found: $tpl"

    sed \
        -e "s|{{INSTALL_DIR}}|$INSTALL_DIR|g" \
        -e "s|{{MODEL_DIR}}|$MODEL_DIR|g" \
        "$tpl" > "$out"

    chmod +x "$out"
    OK "Uninstall script written → $out"
}
