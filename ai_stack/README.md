# Local AI Stack — Intel Arc A770

A fully local LLM stack for Ubuntu 24.04, built around **llama.cpp**'s SYCL backend for Intel Arc GPUs. No cloud. No API keys. 16 GB of VRAM put to work.

## Components

| Component | Purpose |
|---|---|
| llama.cpp (SYCL) | LLM inference engine — uses Arc A770 via level-zero |
| Llama-3.1-8B Q4_K_M | Default model (~5 GB VRAM) |
| memory\_server.py | Long-term memory via mem0 + ChromaDB |
| search\_proxy.py | Injects SearXNG results into chat completions |
| AnythingLLM | Optional desktop chat UI |

---

## Installation

```bash
git clone <this-repo>
cd ai_stack
chmod +x install.sh
./install.sh
```

Re-login (or reboot) after installation — required for Intel GPU group membership and the oneAPI environment to take effect.

### Options

```bash
./install.sh                   # Full install (interactive)
./install.sh --update-llama    # Pull + rebuild llama.cpp only
./install.sh --only=05         # Run one module by number
./install.sh --skip=08         # Full install, skip one module
./install.sh --help
```

### Environment overrides (skip interactive prompts)

```bash
ENABLE_DEBUG=1 ENABLE_BITNET=1 ./install.sh
```

---

## File Structure

```
ai_stack/
├── install.sh                  # Entry point
├── lib/
│   ├── common.sh               # Colours, OK/ERR/WARN/INFO/STEP, ask(), PAUSE()
│   ├── config.sh               # All paths, URLs, versions, flags
│   └── cmake_guard.sh          # CMake generator mismatch guard
├── modules/
│   ├── 00_preflight.sh         # System + asset checks
│   ├── 01_system_deps.sh       # apt packages
│   ├── 02_configure_options.sh # Interactive feature flags
│   ├── 03_intel_drivers.sh     # Intel GPU drivers + oneAPI compiler
│   ├── 04_rust.sh              # Rust toolchain
│   ├── 05_llamacpp.sh          # llama.cpp SYCL build
│   ├── 06_model.sh             # Model download + SHA256 verify
│   ├── 07_memory_server.sh     # mem0 + ChromaDB memory server
│   └── 08_anythingllm.sh       # AnythingLLM + search proxy
├── scripts/
│   ├── configure_shell.sh      # Writes oneAPI env vars to .bashrc/.zshrc
│   ├── write_startup.sh        # Generates start_ai_stack.sh from template
│   └── write_uninstall.sh      # Generates uninstall_ai_stack.sh from template
├── templates/
│   ├── start_ai_stack.sh.tpl   # Startup script template
│   └── uninstall.sh.tpl        # Uninstaller template
└── assets/
    ├── memory_server.py        # FastAPI memory server (mem0 + ChromaDB)
    └── search_proxy.py         # FastAPI search-augmented proxy
```

---

## Starting the Stack

After installation:

```bash
bash ~/ai_stack/start_ai_stack.sh
```

Test the API:

```bash
curl http://localhost:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"llama","messages":[{"role":"user","content":"Hello"}]}'
```

### Memory server

```bash
bash ~/ai_stack/memory_server/start_memory_server.sh
```

Stores and retrieves memories at `http://localhost:8090/memory`.

### Search proxy

```bash
bash ~/ai_stack/search_proxy/start_search_proxy.sh
```

Point AnythingLLM at `http://localhost:8090` (not 8080) to get SearXNG results injected into every chat completion.

---

## Configuration

All paths, ports, model URLs, and flags are in **`lib/config.sh`**. Edit that file — nothing else needs changing for common adjustments.

| Variable | Default | Purpose |
|---|---|---|
| `MODEL_URL` | Llama-3.1-8B Q4_K_M | HuggingFace model URL |
| `MODEL_SHA256` | set in config | SHA256 for download verification |
| `LLAMA_PORT` | 8080 | llama-server port |
| `LLAMA_HOST` | 0.0.0.0 | llama-server bind address |
| `LLAMA_CTX_SIZE` | 8192 | Context window size |
| `LLAMA_GPU_LAYERS` | 99 | GPU offload layers (99 = all) |
| `ENABLE_BITNET` | 0 | Build with BitNet support |

After changing config, regenerate the startup script:

```bash
source lib/common.sh
source lib/config.sh
source scripts/write_startup.sh
write_startup_script
```

---

## Uninstalling

```bash
bash ~/uninstall_ai_stack.sh
```

Prompts whether to remove downloaded models (kept separately from the rest of the stack by default).
