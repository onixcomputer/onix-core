#!/usr/bin/env python3
"""Bounded local OpenAI Chat Completions fixture for the scripted OMP VM path.

This deterministic fixture is not a model and makes no claim about Luna weights.
It emits one native OMP `write` call only for the exact task marker in its
scenario; the OMP process performs the actual tool execution.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any

SCHEMA = "kiln.scripted-model-scenario.v1"
MODEL = "scripted-v1"
PROVIDER = "kiln-scripted"
BIND = "127.0.0.1"
MAX_BODY_BYTES = 1_048_576
MAX_REQUESTS = 2
MAX_SECONDS = 120
MAX_RESPONSE_BYTES = 16_384
MAX_RESPONSE_DELAY_SECONDS = 115
WORKER_DEADLINE_SECONDS = 90
DELAY_HEARTBEAT = b": scripted fixture delay\n\n"
WRITE_TOOL_NAME = "write"


class FixtureError(Exception):
    pass


def digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def compact_json(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def load_scenario(path: Path) -> dict[str, Any]:
    raw = path.read_bytes()
    if len(raw) > 16_384:
        raise FixtureError("scenario exceeds 16384 bytes")
    value = json.loads(raw)
    required = {
        "schema", "id", "model", "task_marker", "target_path", "content",
        "completion_text", "tool_call_id",
    }
    if not isinstance(value, dict) or set(value) != required:
        raise FixtureError("scenario fields do not match the fixture schema")
    if value["schema"] != SCHEMA or value["model"] != f"{PROVIDER}/{MODEL}":
        raise FixtureError("unsupported scenario schema or model selector")
    for field in ("id", "task_marker", "target_path", "content", "completion_text", "tool_call_id"):
        if not isinstance(value[field], str) or not value[field] or "\x00" in value[field]:
            raise FixtureError(f"scenario {field} must be a nonempty string")
    if len(value["id"]) > 64 or len(value["task_marker"]) > 512:
        raise FixtureError("scenario identity or task marker exceeds bounds")
    relative = Path(value["target_path"])
    if relative.is_absolute() or ".." in relative.parts or not relative.parts:
        raise FixtureError("target_path must be a safe relative path")
    if len(value["content"].encode("utf-8")) > 16_384:
        raise FixtureError("scripted content exceeds 16384 bytes")
    if len(value["completion_text"]) > 512:
        raise FixtureError("completion text exceeds 512 characters")
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", value["tool_call_id"]):
        raise FixtureError("tool_call_id has invalid syntax")
    return value


def message_contains_marker(message: Any, marker: str) -> bool:
    if isinstance(message, str):
        return marker in message
    if isinstance(message, list):
        return any(message_contains_marker(item, marker) for item in message)
    if isinstance(message, dict):
        return any(message_contains_marker(item, marker) for item in message.values())
    return False


def session_marker(messages: list[Any], marker: str) -> tuple[dict[str, Any], str]:
    found = [m for m in messages if isinstance(m, dict) and message_contains_marker(m, marker)]
    if len(found) != 1 or found[0].get("role") != "user":
        raise FixtureError("request must carry exactly one user task marker")
    encoded = compact_json(found[0])
    return found[0], digest(encoded)


def validate_tools(request: dict[str, Any]) -> None:
    tools = request.get("tools")
    if not isinstance(tools, list):
        raise FixtureError("OMP request omitted tools")
    matches = []
    for tool in tools:
        if not isinstance(tool, dict):
            continue
        function = tool.get("function")
        if tool.get("type") == "function" and isinstance(function, dict) and function.get("name") == WRITE_TOOL_NAME:
            matches.append(function)
    if len(matches) != 1:
        raise FixtureError("OMP request must expose exactly one native write function")
    parameters = matches[0].get("parameters")
    if not isinstance(parameters, dict) or parameters.get("type") != "object":
        raise FixtureError("OMP write function parameters are not an object schema")
    properties = parameters.get("properties")
    if not isinstance(properties, dict) or not {"path", "content"} <= set(properties):
        raise FixtureError("OMP write function schema lacks path/content")


def sse_chunks(response_id: str, model: str, content: str | None = None, tool: dict[str, Any] | None = None) -> bytes:
    now = int(time.time())
    chunks: list[dict[str, Any]] = []
    delta: dict[str, Any]
    finish: str
    if tool is not None:
        delta = {"tool_calls": [{
            "index": 0,
            "id": tool["id"],
            "type": "function",
            "function": {"name": WRITE_TOOL_NAME, "arguments": json.dumps(tool["arguments"], ensure_ascii=False, separators=(",", ":"))},
        }]}
        chunks.append({"id": response_id, "object": "chat.completion.chunk", "created": now, "model": model,
                       "choices": [{"index": 0, "delta": delta, "finish_reason": None}]})
        finish = "tool_calls"
    else:
        delta = {"content": content or ""}
        chunks.append({"id": response_id, "object": "chat.completion.chunk", "created": now, "model": model,
                       "choices": [{"index": 0, "delta": delta, "finish_reason": None}]})
        finish = "stop"
    chunks.append({"id": response_id, "object": "chat.completion.chunk", "created": now, "model": model,
                   "choices": [{"index": 0, "delta": {}, "finish_reason": finish}]})
    body = b"".join(b"data: " + compact_json(chunk) + b"\n\n" for chunk in chunks) + b"data: [DONE]\n\n"
    if len(body) > MAX_RESPONSE_BYTES:
        raise FixtureError("scripted response exceeds bound")
    return body
def json_completion(response_id: str, model: str, content: str | None = None, tool: dict[str, Any] | None = None) -> bytes:
    message: dict[str, Any] = {"role": "assistant", "content": content}
    finish = "stop"
    if tool is not None:
        message["tool_calls"] = [{
            "id": tool["id"],
            "type": "function",
            "function": {"name": WRITE_TOOL_NAME, "arguments": json.dumps(tool["arguments"], ensure_ascii=False, separators=(",", ":"))},
        }]
        message["content"] = None
        finish = "tool_calls"
    body = compact_json({
        "id": response_id,
        "object": "chat.completion",
        "created": int(time.time()),
        "model": model,
        "choices": [{"index": 0, "message": message, "finish_reason": finish}],
    })
    if len(body) > MAX_RESPONSE_BYTES:
        raise FixtureError("scripted response exceeds bound")
    return body



class FixtureServer(HTTPServer):
    allow_reuse_address = False

    def get_request(self) -> tuple[Any, Any]:
        connection, client_address = super().get_request()
        connection.settimeout(10)
        return connection, client_address

    def __init__(self, scenario: dict[str, Any], evidence: Path, response_delay_seconds: int = 0):
        super().__init__((BIND, 18700), Handler)
        self.scenario = scenario
        self.evidence = evidence
        self.response_delay_seconds = response_delay_seconds
        self.started = time.monotonic()
        self.lock = threading.Lock()
        self.requests_seen = 0
        self.marker_digest: str | None = None
        self.outcome = "running"

    def record(self, event: dict[str, Any]) -> None:
        self.evidence.parent.mkdir(parents=True, exist_ok=True)
        with self.lock:
            existing: dict[str, Any] = {"schema": "kiln.scripted-model-evidence.v1", "scenario_id": self.scenario["id"], "events": []}
            if self.evidence.exists():
                try:
                    candidate = json.loads(self.evidence.read_text(encoding="utf-8"))
                    if candidate.get("schema") == existing["schema"] and candidate.get("scenario_id") == self.scenario["id"]:
                        existing = candidate
                except (OSError, json.JSONDecodeError):
                    pass
            existing["events"].append(event)
            temp = self.evidence.with_name(self.evidence.name + ".tmp")
            temp.write_bytes(compact_json(existing) + b"\n")
            os.replace(temp, self.evidence)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server: FixtureServer

    def log_message(self, _format: str, *_args: Any) -> None:
        # Never log request headers, prompts, or model payloads.
        return

    def reject(self, status: int, message: str) -> None:
        body = compact_json({"error": {"message": message, "type": "invalid_request_error"}})
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)
        self.close_connection = True

    def do_POST(self) -> None:
        srv = self.server
        if self.path != "/v1/chat/completions":
            self.reject(404, "unsupported fixture endpoint")
            return
        if self.headers.get("Authorization") is not None:
            self.reject(401, "fixture provider is authless")
            return
        if self.headers.get("Transfer-Encoding") is not None:
            self.reject(400, "transfer encoding is not supported")
            return
        length_value = self.headers.get("Content-Length", "")
        if len(length_value) > 10 or not length_value.isascii() or not length_value.isdecimal():
            self.reject(411, "a bounded Content-Length is required")
            return
        length = int(length_value)
        if length <= 0 or length > MAX_BODY_BYTES:
            self.reject(413, "request body exceeds fixture bounds")
            return
        if time.monotonic() - srv.started > MAX_SECONDS:
            self.reject(408, "fixture deadline exceeded")
            return
        try:
            raw = self.rfile.read(length)
            if len(raw) != length:
                raise FixtureError("truncated request body")
            request = json.loads(raw)
            if not isinstance(request, dict) or request.get("model") != MODEL:
                raise FixtureError("unexpected model or request shape")
            messages = request.get("messages")
            if not isinstance(messages, list) or not messages:
                raise FixtureError("messages must be a nonempty array")
            _, marker_digest = session_marker(messages, srv.scenario["task_marker"])
            validate_tools(request)
            with srv.lock:
                if srv.requests_seen >= MAX_REQUESTS:
                    raise FixtureError("request limit exceeded")
                index = srv.requests_seen
                if index == 0:
                    srv.marker_digest = marker_digest
                elif marker_digest != srv.marker_digest:
                    raise FixtureError("crossed task session")
                srv.requests_seen += 1
            if index == 0:
                response_id = "chatcmpl-kiln-scripted-tool"
                tool = {
                    "id": srv.scenario["tool_call_id"],
                    "arguments": {"path": srv.scenario["target_path"], "content": srv.scenario["content"]},
                }
                if request.get("stream") is True:
                    body = sse_chunks(response_id, MODEL, tool=tool)
                else:
                    body = json_completion(response_id, MODEL, tool=tool)
                event_type = "tool_call"
            else:
                tool_results = [m for m in messages if isinstance(m, dict) and m.get("role") == "tool"
                                and m.get("tool_call_id") == srv.scenario["tool_call_id"]]
                assistant_calls = [call for m in messages if isinstance(m, dict) and m.get("role") == "assistant"
                                   for call in m.get("tool_calls", []) if isinstance(call, dict)
                                   and call.get("id") == srv.scenario["tool_call_id"]]
                if len(tool_results) != 1 or len(assistant_calls) != 1:
                    raise FixtureError("second request does not contain the matching native write result")
                result_content = tool_results[0].get("content")
                if isinstance(result_content, str):
                    result_text = result_content
                elif isinstance(result_content, list):
                    result_text = "".join(
                        part.get("text", "") for part in result_content
                        if isinstance(part, dict) and part.get("type") == "text" and isinstance(part.get("text"), str)
                    )
                else:
                    result_text = ""
                if "Successfully wrote " not in result_text or srv.scenario["target_path"] not in result_text:
                    raise FixtureError("native write tool result does not confirm the scenario path was written")
                call_function = assistant_calls[0].get("function")
                if not isinstance(call_function, dict) or call_function.get("name") != WRITE_TOOL_NAME:
                    raise FixtureError("tool history does not match native write")
                args = json.loads(call_function.get("arguments", "{}"))
                if args != {"path": srv.scenario["target_path"], "content": srv.scenario["content"]}:
                    raise FixtureError("tool history arguments differ from scenario")
                if request.get("stream") is True:
                    body = sse_chunks("chatcmpl-kiln-scripted-final", MODEL, content=srv.scenario["completion_text"])
                else:
                    body = json_completion("chatcmpl-kiln-scripted-final", MODEL, content=srv.scenario["completion_text"])
                event_type = "completed"
            if len(body) > MAX_RESPONSE_BYTES:
                raise FixtureError("response body exceeds fixture bound")
            heartbeat_delay = request.get("stream") is True and srv.response_delay_seconds > WORKER_DEADLINE_SECONDS
            if heartbeat_delay and len(body) + srv.response_delay_seconds * (len(DELAY_HEARTBEAT) + 8) > MAX_RESPONSE_BYTES:
                raise FixtureError("delayed response body exceeds fixture bound")
            srv.record({
                "request": index + 1,
                "request_sha256": digest(raw),
                "task_message_sha256": marker_digest,
                "body_bytes": length,
                "model": MODEL,
                "stream": request.get("stream") is True,
                "authorization_present": False,
                "response": event_type,
                "response_bytes": len(body),
                "response_delay_seconds": srv.response_delay_seconds,
            })
            self.send_response(200)
            content_type = "text/event-stream; charset=utf-8" if request.get("stream") is True else "application/json"
            self.send_header("Content-Type", content_type)
            self.send_header("Cache-Control", "no-cache")
            if heartbeat_delay:
                self.send_header("Transfer-Encoding", "chunked")
            else:
                self.send_header("Content-Length", str(len(body)))
            self.send_header("Connection", "close")
            self.end_headers()
            if heartbeat_delay:
                # Keep the HTTP stream active without producing a model event;
                # the real caller deadline/cancellation must terminate the child.
                heartbeat = DELAY_HEARTBEAT
                chunk = f"{len(heartbeat):x}\r\n".encode() + heartbeat + b"\r\n"
                for _ in range(srv.response_delay_seconds):
                    self.wfile.write(chunk)
                    self.wfile.flush()
                    time.sleep(1)
                self.wfile.write(f"{len(body):x}\r\n".encode() + body + b"\r\n0\r\n\r\n")
            else:
                if srv.response_delay_seconds:
                    time.sleep(srv.response_delay_seconds)
                self.wfile.write(body)
            self.wfile.flush()
            self.close_connection = True
            if index == MAX_REQUESTS - 1:
                srv.outcome = "completed"
        except (FixtureError, json.JSONDecodeError, UnicodeDecodeError, TypeError, ValueError) as exc:
            srv.record({"request": min(srv.requests_seen + 1, MAX_REQUESTS), "rejected": True, "reason": str(exc)[:160]})
            self.reject(400, "fixture request rejected")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scenario", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--host", default=BIND)
    parser.add_argument("--port", type=int, default=18700)
    parser.add_argument("--response-delay-seconds", type=int, default=0)
    args = parser.parse_args()
    if args.host != BIND or args.port != 18700:
        parser.error("fixture binds only 127.0.0.1:18700")
    if not 0 <= args.response_delay_seconds <= MAX_RESPONSE_DELAY_SECONDS:
        parser.error("response delay must be bounded to 0..115 seconds")
    try:
        scenario = load_scenario(args.scenario)
        if args.evidence.exists():
            raise FixtureError("evidence path already exists; each fixture run needs fresh evidence")
        server = FixtureServer(scenario, args.evidence, args.response_delay_seconds)
    except (FixtureError, OSError, json.JSONDecodeError) as exc:
        print(f"scripted model fixture: {exc}", file=sys.stderr)
        return 2
    server.timeout = 1
    try:
        while server.requests_seen < MAX_REQUESTS and time.monotonic() - server.started <= MAX_SECONDS:
            server.handle_request()
        if server.outcome != "completed" or server.requests_seen != MAX_REQUESTS:
            server.record({"outcome": "incomplete", "requests": server.requests_seen})
            print("scripted model fixture: expected one tool turn and one final turn", file=sys.stderr)
            return 1
        server.record({"outcome": "completed", "requests": server.requests_seen})
        return 0
    finally:
        server.server_close()


if __name__ == "__main__":
    raise SystemExit(main())
