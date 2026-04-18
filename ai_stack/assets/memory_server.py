"""
memory_server.py — Local memory API for the AI stack.

Wraps mem0ai (vector store: ChromaDB, embedder: sentence-transformers)
behind a small FastAPI service so AnythingLLM / any OpenAI-compatible
client can do stateful, long-term memory without a cloud dependency.

Endpoints
---------
POST /memory               Store a memory for a user
GET  /memory/{user_id}     Retrieve all memories for a user
POST /memory/search        Semantic search across memories
DELETE /memory/{memory_id} Delete a single memory

Configuration (environment variables)
--------------------------------------
LLAMA_BASE_URL   Base URL of the llama-server  (default: http://localhost:8080/v1)
LLAMA_API_KEY    API key for llama-server       (default: local)
LLAMA_MODEL      Model name to pass to mem0      (default: llama)
MEMORY_HOST      Bind host                       (default: 0.0.0.0)
MEMORY_PORT      Bind port                       (default: 8090)
"""

from __future__ import annotations

import logging
import os
from typing import Any

import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# ── Logging ──────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(name)s  %(message)s",
)
log = logging.getLogger("memory_server")

# ── Config ────────────────────────────────────────────────────────
LLAMA_BASE_URL = os.getenv("LLAMA_BASE_URL", "http://localhost:8080/v1")
LLAMA_API_KEY  = os.getenv("LLAMA_API_KEY",  "local")
LLAMA_MODEL    = os.getenv("LLAMA_MODEL",    "llama")
HOST           = os.getenv("MEMORY_HOST",    "0.0.0.0")
PORT           = int(os.getenv("MEMORY_PORT", "8090"))

# ── mem0 setup ────────────────────────────────────────────────────
try:
    from mem0 import Memory  # type: ignore
except ImportError as exc:
    raise SystemExit(
        "mem0ai not installed. Run: pip install mem0ai chromadb"
    ) from exc

_MEM0_CONFIG: dict[str, Any] = {
    "llm": {
        "provider": "openai",           # mem0 uses the OpenAI-compatible API
        "config": {
            "model":    LLAMA_MODEL,
            "base_url": LLAMA_BASE_URL,
            "api_key":  LLAMA_API_KEY,
        },
    },
    "embedder": {
        "provider": "huggingface",
        "config": {
            "model": "sentence-transformers/all-MiniLM-L6-v2",
        },
    },
    "vector_store": {
        "provider": "chroma",
        "config": {
            "collection_name": "ai_stack_memory",
            "path":            os.path.expanduser("~/ai_stack/memory_server/chroma_db"),
        },
    },
}

log.info("Initialising mem0 (first run downloads embedder model ~22 MB)…")
memory = Memory.from_config(_MEM0_CONFIG)
log.info("mem0 ready.")

# ── FastAPI app ───────────────────────────────────────────────────
app = FastAPI(
    title="AI Stack Memory Server",
    description="Local mem0 memory API — no cloud required.",
    version="1.0.0",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Schemas ───────────────────────────────────────────────────────
class StoreRequest(BaseModel):
    user_id: str
    content: str
    metadata: dict[str, Any] = {}

class SearchRequest(BaseModel):
    user_id: str
    query: str
    limit: int = 5

# ── Routes ────────────────────────────────────────────────────────
@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/memory", summary="Store a memory")
def store_memory(req: StoreRequest) -> dict[str, Any]:
    try:
        result = memory.add(
            req.content,
            user_id=req.user_id,
            metadata=req.metadata,
        )
        log.info("Stored memory for user=%s", req.user_id)
        return {"status": "stored", "result": result}
    except Exception as exc:
        log.exception("store_memory failed")
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.get("/memory/{user_id}", summary="Get all memories for a user")
def get_memories(user_id: str) -> dict[str, Any]:
    try:
        results = memory.get_all(user_id=user_id)
        return {"user_id": user_id, "memories": results}
    except Exception as exc:
        log.exception("get_memories failed")
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.post("/memory/search", summary="Semantic search across memories")
def search_memories(req: SearchRequest) -> dict[str, Any]:
    try:
        results = memory.search(
            req.query,
            user_id=req.user_id,
            limit=req.limit,
        )
        return {"user_id": req.user_id, "query": req.query, "results": results}
    except Exception as exc:
        log.exception("search_memories failed")
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.delete("/memory/{memory_id}", summary="Delete a single memory")
def delete_memory(memory_id: str) -> dict[str, str]:
    try:
        memory.delete(memory_id=memory_id)
        log.info("Deleted memory id=%s", memory_id)
        return {"status": "deleted", "memory_id": memory_id}
    except Exception as exc:
        log.exception("delete_memory failed")
        raise HTTPException(status_code=500, detail=str(exc)) from exc


# ── Entry point ───────────────────────────────────────────────────
if __name__ == "__main__":
    log.info("Memory server starting on %s:%d", HOST, PORT)
    uvicorn.run(app, host=HOST, port=PORT, log_level="info")
