"""
search_proxy.py — Web-search-augmented OpenAI-compatible proxy.

Sits between AnythingLLM (or any client) and llama-server.
When a chat-completion request arrives, the proxy:
  1. Extracts the latest user message.
  2. Sends it as a search query to SearXNG.
  3. Prepends a concise context block of search results to the message.
  4. Forwards the augmented request to llama-server.
  5. Streams the response back unchanged.

Non-chat endpoints (e.g. /v1/models) are forwarded as-is.

Configuration (environment variables)
--------------------------------------
LLAMA_URL      Base URL of llama-server         (default: http://localhost:8080)
LLAMA_API_KEY  API key for llama-server          (default: local)
SEARXNG_URL    Base URL of SearXNG instance      (default: http://localhost:8081)
PROXY_HOST     Bind host                         (default: 0.0.0.0)
PROXY_PORT     Bind port                         (default: 8090)
SEARCH_RESULTS Number of SearXNG hits to inject  (default: 3)
"""

from __future__ import annotations

import json
import logging
import os
from typing import AsyncIterator

import httpx
import uvicorn
from fastapi import FastAPI, Request, Response
from fastapi.responses import StreamingResponse

# ── Logging ──────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(name)s  %(message)s",
)
log = logging.getLogger("search_proxy")

# ── Config ────────────────────────────────────────────────────────
LLAMA_URL      = os.getenv("LLAMA_URL",      "http://localhost:8080")
LLAMA_API_KEY  = os.getenv("LLAMA_API_KEY",  "local")
SEARXNG_URL    = os.getenv("SEARXNG_URL",    "http://localhost:8081")
PROXY_HOST     = os.getenv("PROXY_HOST",     "0.0.0.0")
PROXY_PORT     = int(os.getenv("PROXY_PORT", "8090"))
SEARCH_RESULTS = int(os.getenv("SEARCH_RESULTS", "3"))

# ── FastAPI app ───────────────────────────────────────────────────
app = FastAPI(
    title="AI Stack Search Proxy",
    description="Augments chat completions with live SearXNG results.",
    version="1.0.0",
)

# ── Helpers ───────────────────────────────────────────────────────
async def _searxng_search(query: str, client: httpx.AsyncClient) -> str:
    """Return a formatted block of SearXNG results for *query*."""
    try:
        resp = await client.get(
            f"{SEARXNG_URL}/search",
            params={"q": query, "format": "json", "categories": "general"},
            timeout=8.0,
        )
        resp.raise_for_status()
        data = resp.json()
        results = data.get("results", [])[:SEARCH_RESULTS]
        if not results:
            return ""
        lines = ["[Web search results]"]
        for i, r in enumerate(results, 1):
            title   = r.get("title", "").strip()
            url     = r.get("url", "").strip()
            snippet = r.get("content", "").strip()
            lines.append(f"{i}. {title}\n   {url}\n   {snippet}")
        lines.append("[End of search results]\n")
        return "\n".join(lines)
    except Exception as exc:
        log.warning("SearXNG search failed: %s", exc)
        return ""


def _inject_search_context(messages: list[dict], context: str) -> list[dict]:
    """Prepend *context* to the last user message in *messages*."""
    if not context:
        return messages
    patched = list(messages)
    for i in range(len(patched) - 1, -1, -1):
        if patched[i].get("role") == "user":
            original = patched[i].get("content", "")
            patched[i] = {
                **patched[i],
                "content": f"{context}\n{original}",
            }
            break
    return patched


def _llama_headers() -> dict[str, str]:
    return {
        "Authorization": f"Bearer {LLAMA_API_KEY}",
        "Content-Type":  "application/json",
    }


async def _stream_response(
    client: httpx.AsyncClient,
    url: str,
    payload: dict,
) -> AsyncIterator[bytes]:
    async with client.stream(
        "POST", url, json=payload, headers=_llama_headers(), timeout=120.0
    ) as resp:
        async for chunk in resp.aiter_bytes():
            yield chunk


# ── Routes ────────────────────────────────────────────────────────
@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.api_route(
    "/v1/chat/completions",
    methods=["POST"],
    summary="Search-augmented chat completions",
)
async def chat_completions(request: Request) -> Response:
    body: dict = await request.json()
    messages: list[dict] = body.get("messages", [])

    # Extract last user turn as the search query
    query = ""
    for msg in reversed(messages):
        if msg.get("role") == "user":
            query = msg.get("content", "")
            break

    async with httpx.AsyncClient() as client:
        if query:
            log.info("Searching SearXNG for: %r", query[:80])
            context = await _searxng_search(query, client)
            if context:
                log.info("Injecting %d search result(s)", SEARCH_RESULTS)
                body["messages"] = _inject_search_context(messages, context)

        target_url = f"{LLAMA_URL}/v1/chat/completions"
        streaming   = body.get("stream", False)

        if streaming:
            return StreamingResponse(
                _stream_response(client, target_url, body),
                media_type="text/event-stream",
            )

        resp = await client.post(
            target_url,
            json=body,
            headers=_llama_headers(),
            timeout=120.0,
        )
        return Response(
            content=resp.content,
            status_code=resp.status_code,
            media_type="application/json",
        )


@app.api_route(
    "/v1/{path:path}",
    methods=["GET", "POST", "PUT", "DELETE"],
    summary="Transparent passthrough for all other /v1 endpoints",
)
async def passthrough(path: str, request: Request) -> Response:
    target_url = f"{LLAMA_URL}/v1/{path}"
    async with httpx.AsyncClient() as client:
        resp = await client.request(
            method=request.method,
            url=target_url,
            headers=_llama_headers(),
            content=await request.body(),
            timeout=30.0,
        )
    return Response(
        content=resp.content,
        status_code=resp.status_code,
        media_type=resp.headers.get("content-type", "application/json"),
    )


# ── Entry point ───────────────────────────────────────────────────
if __name__ == "__main__":
    log.info(
        "Search proxy starting on %s:%d  →  llama: %s  searxng: %s",
        PROXY_HOST, PROXY_PORT, LLAMA_URL, SEARXNG_URL,
    )
    uvicorn.run(app, host=PROXY_HOST, port=PROXY_PORT, log_level="info")
