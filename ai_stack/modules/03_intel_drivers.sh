#!/bin/bash
# ================================================================
#  modules/03_intel_drivers.sh — Intel Arc GPU drivers + oneAPI.
#  Installs OpenCL ICD, level-zero, and the icx/icpx compilers.
#  Depends on: lib/common.sh
# ================================================================

#!/usr/bin/env bash
# Intel Arc 2026 Smart Installer — resilient, interactive, resumable
# Supports: Ubuntu 22.04/24.04

set -Eeuo pipefail

STATE_FILE="/var/tmp/intel_arc_install.state"
LOG_FILE="/var/tmp/intel_arc_install.log"

# ---------- logging ----------
log(){ echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG_FILE"; }
err(){ log "ERROR: $*"; }
ok(){ log "OK: $*"; }
warn(){ log "WARN: $*"; }

# ---------- state ----------
save_state(){ echo "$1" > "$STATE_FILE"; }
load_state(){ [[ -f "$STATE_FILE" ]] && cat "$STATE_FILE" || echo ""; }

# ---------- detection ----------
detect(){
  KERNEL=$(uname -r)
  UBUNTU=$(lsb_release -rs 2>/dev/null || echo unknown)
  GPU=$(lspci | grep -i 'intel.*vga' || true)
  DRIVER=$(lsmod | grep -E 'i915|xe' | awk '{print $1}' | head -1)
}

# ---------- diagnostics ----------
diagnose(){
  detect
  echo "\n=== SYSTEM ==="
  echo "Kernel: $KERNEL"
  echo "Ubuntu: $UBUNTU"
  echo "GPU: ${GPU:-not detected}"
  echo "Driver: ${DRIVER:-none}"

  echo "\n=== RUNTIME ==="
  clinfo -l 2>/dev/null | grep -i intel || echo "OpenCL: FAIL"
  sycl-ls 2>/dev/null | grep -i gpu || echo "SYCL: FAIL"
  vainfo 2>/dev/null | grep -i intel || echo "VAAPI: FAIL"
  vulkaninfo 2>/dev/null | grep -i intel || echo "Vulkan: FAIL"
  xpu-smi discovery 2>/dev/null || echo "xpu-smi: FAIL"
}

# ---------- fixes ----------
fix_kernel(){
  log "Ensuring HWE kernel"
  sudo apt-get install -y linux-generic-hwe-24.04
}

fix_graphics(){
  log "Installing graphics stack"
  sudo apt-get install -y \
    mesa-vulkan-drivers \
    mesa-opencl-icd \
    intel-media-va-driver-non-free \
    vainfo libvpl2 intel-gsc xpu-smi
}

fix_compute(){
  log "Installing compute runtime"
  sudo apt-get install -y intel-opencl-icd intel-level-zero-gpu libze1 libze-dev clinfo
}

fix_oneapi(){
  if ! command -v icx >/dev/null; then
    log "Installing oneAPI compiler"
    sudo apt-get install -y intel-oneapi-compiler-dpcpp-cpp || true
  else
    ok "icx already present"
  fi
}

fix_permissions(){
  sudo usermod -aG render,video "$USER" || true
  warn "Re-login required for GPU access"
}

# ---------- intelligent repair ----------
repair_loop(){
  for i in {1..3}; do
    log "Repair pass $i"

    clinfo >/dev/null 2>&1 || fix_compute
    sycl-ls >/dev/null 2>&1 || fix_oneapi
    vainfo >/dev/null 2>&1 || fix_graphics

    if clinfo >/dev/null 2>&1 && sycl-ls >/dev/null 2>&1; then
      ok "Core compute stack working"
      return
    fi
  done

  err "Unable to fully repair automatically"
}

# ---------- install modes ----------
install_stable(){
  save_state "stable"
  fix_kernel
  fix_graphics
  fix_compute
  fix_oneapi
  fix_permissions
  repair_loop
}

install_performance(){
  save_state "performance"
  fix_kernel
  fix_graphics
  fix_compute
  fix_oneapi
  repair_loop
}

install_bleeding(){
  save_state "bleeding"
  log "Enabling experimental stack"
  sudo add-apt-repository -y ppa:kobuk-team/intel-graphics || true
  sudo apt-get update
  install_performance
}

# ---------- resume ----------
resume(){
  state=$(load_state)
  [[ -z "$state" ]] && { warn "No previous state"; return; }
  log "Resuming from $state"
  case $state in
    stable) install_stable ;;
    performance) install_performance ;;
    bleeding) install_bleeding ;;
  esac
}

# ---------- menu ----------
menu(){
  PS3="Select option: "
  select opt in \
    "Smart Install (auto)" \
    "Stable" \
    "Performance" \
    "Bleeding Edge" \
    "Diagnose" \
    "Repair" \
    "Resume" \
    "Exit"; do

    case $REPLY in
      1) install_stable ;;
      2) install_stable ;;
      3) install_performance ;;
      4) install_bleeding ;;
      5) diagnose ;;
      6) repair_loop ;;
      7) resume ;;
      8) break ;;
      *) echo "Invalid" ;;
    esac
  done
}

# ---------- entry ----------
detect
menu
