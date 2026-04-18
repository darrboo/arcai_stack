#!/bin/bash
# ================================================================
#  modules/01_system_deps.sh — Base system packages.
#  Depends on: lib/common.sh
# ================================================================

install_system_deps() {
    STEP "1/7  System packages"

    sudo apt-get update -qq
    sudo apt-get install -y --no-install-recommends \
        curl wget git build-essential cmake pkg-config \
        libssl-dev ca-certificates unzip file libfuse2 \
        libwebkit2gtk-4.1-dev libgtk-3-dev \
        gpg-agent software-properties-common \
        ocl-icd-libopencl1

    OK "System packages installed."
}
