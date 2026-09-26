"""Expose the loopback Underclass Codex pool to Mesh-LLM.

Mesh-LLM 0.72.2 probes external endpoints with unauthenticated `/v1/models`
requests and forwards all inference to them as chat completions. Underclass
requires its proxy key, and its Codex backend accepts only streamed Responses
requests. This gateway listens on loopback, injects the key read from a systemd
credential, translates chat completions to Responses and translates the event
stream back. It never logs prompts, outputs or credentials.
"""

from __future__ import annotations

import argparse
import hashlib
import http.client
import ipaddress
import json
import sys
import time
import uuid
from collections.abc import Iterator
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, BinaryIO
from urllib.parse import urlsplit

JSON = dict[str, Any]

CODEX_OWNER = "underclass-codex"
MAX_BODY_BYTES = 64 * 1024 * 1024  # Underclass's own request-body limit.
MAX_ERROR_BYTES = 64 * 1024
MAX_LINE_BYTES = 64 * 1024
UPSTREAM_IDLE_TIMEOUT = 600.0

# r[impl onix.underclass.mesh.gateway]
# `stream` and `stream_options` are answered here. The Codex subscription
# backend rejects output-token caps, and Mesh-LLM inserts llama.cpp
# chat-template reasoning switches; neither is forwarded. Every other field
# reaches Underclass unchanged, so the real backend accepts or rejects it.
LOCAL_FIELDS = frozenset(
    {
        "stream",
        "stream_options",
        "max_tokens",
        "max_completion_tokens",
        "max_output_tokens",
        "chat_template_kwargs",
        "thinking_budget",
        "enable_thinking",
        "enableThinking",
        "enable_reasoning",
        "use_reasoning",
        "reasoning_enabled",
        "use_thinking",
        "thinking_enabled",
        "enable_think",
        "think_enabled",
    }
)

# Headers worth returning when Underclass itself answers with an error.
RELAYED_HEADERS = ("Retry-After", "x-request-id")

# Underclass pins a conversation to one pooled account by these body fields,
# then by the `session-id` header (its ADR 0003).
AFFINITY_FIELDS = ("prompt_cache_key", "promptCacheKey")


class RequestError(Exception):
    """A chat request that has no Responses equivalent."""


def input_content(content: object) -> list[JSON]:
    """Translate user, system or developer message content."""
    if isinstance(content, str):
        return [{"type": "input_text", "text": content}]
    if not isinstance(content, list):
        msg = "message content must be a string or an array of parts"
        raise RequestError(msg)
    parts: list[JSON] = []
    for part in content:
        kind = part.get("type") if isinstance(part, dict) else None
        if kind in {"text", "input_text"}:
            parts.append({"type": "input_text", "text": part.get("text", "")})
        elif kind == "image_url":
            image = part.get("image_url")
            url = image.get("url") if isinstance(image, dict) else image
            item: JSON = {"type": "input_image", "image_url": url}
            if isinstance(image, dict) and "detail" in image:
                item["detail"] = image["detail"]
            parts.append(item)
        elif kind == "input_image":
            parts.append(part)
        else:
            msg = f"unsupported message content part type {kind!r}"
            raise RequestError(msg)
    return parts


def plain_text(content: object) -> str:
    """Flatten assistant or tool message content into text."""
    if content is None:
        return ""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        texts = []
        for part in content:
            if not isinstance(part, dict) or part.get("type") not in {
                "text",
                "output_text",
            }:
                msg = "assistant and tool content parts must be text"
                raise RequestError(msg)
            texts.append(part.get("text", ""))
        return "".join(texts)
    msg = "message content must be a string or an array of parts"
    raise RequestError(msg)


def tool_call_items(calls: object) -> list[JSON]:
    """Translate assistant tool calls into Responses function calls."""
    if calls is None:
        return []
    if not isinstance(calls, list):
        msg = "tool_calls must be an array"
        raise RequestError(msg)
    items: list[JSON] = []
    for call in calls:
        function = call.get("function") if isinstance(call, dict) else None
        if not isinstance(function, dict) or not call.get("id"):
            msg = "assistant tool_calls need an id and a function"
            raise RequestError(msg)
        arguments = function.get("arguments", "")
        items.append(
            {
                "type": "function_call",
                "call_id": call["id"],
                "name": function.get("name"),
                "arguments": arguments
                if isinstance(arguments, str)
                else json.dumps(arguments),
            }
        )
    return items


def input_items(messages: object) -> list[JSON]:
    """Translate chat messages into Responses input items."""
    if not isinstance(messages, list) or not messages:
        msg = "messages must be a non-empty array"
        raise RequestError(msg)
    items: list[JSON] = []
    for message in messages:
        if not isinstance(message, dict):
            msg = "each message must be an object"
            raise RequestError(msg)
        role = message.get("role")
        if role in {"system", "developer", "user"}:
            content = input_content(message.get("content"))
            items.append({"role": role, "content": content})
        elif role == "assistant":
            text = plain_text(message.get("content"))
            if text:
                output = [{"type": "output_text", "text": text}]
                items.append({"role": "assistant", "content": output})
            items.extend(tool_call_items(message.get("tool_calls")))
        elif role == "tool":
            call_id = message.get("tool_call_id")
            if not call_id:
                msg = "tool messages need a tool_call_id"
                raise RequestError(msg)
            output = plain_text(message.get("content"))
            items.append(
                {"type": "function_call_output", "call_id": call_id, "output": output}
            )
        else:
            msg = f"unsupported message role {role!r}"
            raise RequestError(msg)
    return items


def flatten_tagged(value: object) -> object:
    """Turn chat's `{"type": T, T: {...}}` shape into Responses' flat shape.

    Responses-shaped values, which Mesh-LLM forwards unchanged from
    `/v1/responses` clients, are returned as they are.
    """
    if isinstance(value, dict):
        kind = value.get("type")
        nested = value.get(kind) if isinstance(kind, str) else None
        if isinstance(nested, dict):
            return {"type": kind, **nested}
    return value


def text_format(response_format: object) -> object:
    """Translate chat `response_format` into Responses `text.format`."""
    if (
        isinstance(response_format, dict)
        and response_format.get("type") == "json_schema"
    ):
        schema = response_format.get("json_schema")
        if isinstance(schema, dict):
            return {"type": "json_schema", **schema}
    return response_format


def responses_request(chat: object) -> JSON:
    """Translate a chat-completions request body into a Responses request."""
    if not isinstance(chat, dict):
        msg = "request body must be a JSON object"
        raise RequestError(msg)
    if not isinstance(chat.get("model"), str) or not chat["model"]:
        msg = "model is required"
        raise RequestError(msg)
    request = {key: value for key, value in chat.items() if key not in LOCAL_FIELDS}
    request["input"] = input_items(request.pop("messages", None))
    if "tools" in request:
        if not isinstance(request["tools"], list):
            msg = "tools must be an array"
            raise RequestError(msg)
        request["tools"] = [flatten_tagged(tool) for tool in request["tools"]]
    if "tool_choice" in request:
        request["tool_choice"] = flatten_tagged(request["tool_choice"])
    effort = request.pop("reasoning_effort", None)
    if effort is not None:
        reasoning = request.get("reasoning")
        reasoning = dict(reasoning) if isinstance(reasoning, dict) else {}
        reasoning.setdefault("effort", effort)
        request["reasoning"] = reasoning
    response_format = request.pop("response_format", None)
    verbosity = request.pop("verbosity", None)
    if response_format is not None or verbosity is not None:
        text = request.get("text")
        text = dict(text) if isinstance(text, dict) else {}
        if response_format is not None:
            text["format"] = text_format(response_format)
        if verbosity is not None:
            text["verbosity"] = verbosity
        request["text"] = text
    request["stream"] = True
    return request


def conversation_key(items: list[JSON]) -> str:
    """Derive a stable Underclass affinity key from a conversation's opening.

    Every turn of a chat repeats its opening messages, so hashing them through
    the first user message keeps the conversation on one pooled account, and
    its prompt cache warm, when the client sends no key of its own.
    """
    opening: list[JSON] = []
    for item in items:
        opening.append(item)
        if item.get("role") == "user":
            break
    digest = hashlib.sha256(json.dumps(opening, sort_keys=True).encode())
    return f"mesh-{digest.hexdigest()[:32]}"


def chat_usage(usage: object) -> JSON | None:
    """Translate Responses usage into chat-completions usage."""
    if not isinstance(usage, dict):
        return None
    prompt = usage.get("input_tokens") or 0
    completion = usage.get("output_tokens") or 0
    result: JSON = {
        "prompt_tokens": prompt,
        "completion_tokens": completion,
        "total_tokens": usage.get("total_tokens") or prompt + completion,
    }
    cached = (usage.get("input_tokens_details") or {}).get("cached_tokens")
    if cached is not None:
        result["prompt_tokens_details"] = {"cached_tokens": cached}
    reasoning = (usage.get("output_tokens_details") or {}).get("reasoning_tokens")
    if reasoning is not None:
        result["completion_tokens_details"] = {"reasoning_tokens": reasoning}
    return result


def upstream_error(event: JSON) -> JSON:
    """Build a chat error object from a Responses failure."""
    source = event
    if event.get("type") == "response.failed":
        source = (event.get("response") or {}).get("error") or {}
    return {
        "message": source.get("message") or "Underclass response failed",
        "type": "upstream_error",
        "code": source.get("code"),
        "param": source.get("param"),
    }


class ChatStream:
    """Translate one Responses event stream into chat-completion output."""

    def __init__(self, model: str) -> None:
        self.model = model
        self.id = f"chatcmpl-{uuid.uuid4().hex}"
        self.created = int(time.time())
        self.content: list[str] = []
        self.reasoning: list[str] = []
        self.refusal: list[str] = []
        self.calls: dict[str, JSON] = {}
        self.finish_reason: str | None = None
        self.usage: JSON | None = None
        self.error: JSON | None = None
        self.role_sent = False

    @property
    def done(self) -> bool:
        return self.finish_reason is not None or self.error is not None

    def interrupt(self, message: str) -> None:
        """Record that the stream ended without a terminal event."""
        if not self.done:
            self.error = {"message": message, "type": "upstream_error"}

    def feed(self, event: JSON) -> list[JSON]:
        """Consume one Responses event; return the chat deltas it yields."""
        kind = event.get("type")
        if kind == "response.created":
            response = event.get("response") or {}
            if response.get("id"):
                self.id = f"chatcmpl-{response['id']}"
            self.created = response.get("created_at") or self.created
            self.model = response.get("model") or self.model
            return []
        if kind == "response.output_text.delta":
            return self.text("content", self.content, event.get("delta"))
        if kind in {
            "response.reasoning_summary_text.delta",
            "response.reasoning_text.delta",
        }:
            return self.text("reasoning_content", self.reasoning, event.get("delta"))
        if kind == "response.refusal.delta":
            return self.text("refusal", self.refusal, event.get("delta"))
        if kind in {"response.output_item.added", "response.output_item.done"}:
            item = event.get("item") or {}
            if item.get("type") == "function_call":
                return self.function_call(item)
            return []
        if kind == "response.function_call_arguments.delta":
            call = self.calls.get(event.get("item_id", ""))
            delta = event.get("delta")
            if call is None or not isinstance(delta, str) or not delta:
                return []
            call["arguments"] += delta
            return [self.call_delta(call, delta, header=False)]
        if kind in {"response.completed", "response.incomplete"}:
            response = event.get("response") or {}
            self.usage = chat_usage(response.get("usage"))
            if kind == "response.incomplete":
                reason = (response.get("incomplete_details") or {}).get("reason")
                self.finish_reason = (
                    "content_filter" if reason == "content_filter" else "length"
                )
            else:
                self.finish_reason = "tool_calls" if self.calls else "stop"
            return []
        if kind in {"response.failed", "error"}:
            self.error = upstream_error(event)
        return []

    def emit(self, delta: JSON) -> JSON:
        if not self.role_sent:
            self.role_sent = True
            return {"role": "assistant", **delta}
        return delta

    def text(self, field: str, sink: list[str], delta: object) -> list[JSON]:
        if not isinstance(delta, str) or not delta:
            return []
        sink.append(delta)
        return [self.emit({field: delta})]

    def function_call(self, item: JSON) -> list[JSON]:
        """Start or finish a call; emit arguments not yet streamed."""
        item_id = item.get("id") or item.get("call_id") or str(len(self.calls))
        call = self.calls.get(item_id)
        header = call is None
        if call is None:
            call = {
                "index": len(self.calls),
                "id": item.get("call_id"),
                "name": item.get("name"),
                "arguments": "",
            }
            self.calls[item_id] = call
        final = item.get("arguments") or ""
        missing = (
            final[len(call["arguments"]) :]
            if final.startswith(call["arguments"])
            else ""
        )
        if not header and not missing:
            return []
        call["arguments"] += missing
        return [self.call_delta(call, missing, header=header)]

    def call_delta(self, call: JSON, arguments: str, *, header: bool) -> JSON:
        entry: JSON = {"index": call["index"], "function": {"arguments": arguments}}
        if header:
            entry["id"] = call["id"]
            entry["type"] = "function"
            entry["function"]["name"] = call["name"]
        return self.emit({"tool_calls": [entry]})

    def envelope(self, choices: list[JSON]) -> JSON:
        return {
            "id": self.id,
            "object": "chat.completion.chunk",
            "created": self.created,
            "model": self.model,
            "choices": choices,
        }

    def delta_chunk(self, delta: JSON) -> JSON:
        return self.envelope([{"index": 0, "delta": delta, "finish_reason": None}])

    def finish_chunk(self) -> JSON:
        delta = {} if self.role_sent else {"role": "assistant"}
        choice = {"index": 0, "delta": delta, "finish_reason": self.finish_reason}
        return self.envelope([choice])

    def usage_chunk(self) -> JSON:
        return {**self.envelope([]), "usage": self.usage}

    def completion(self) -> JSON:
        """Aggregate the consumed stream into one chat completion."""
        text = "".join(self.content)
        message: JSON = {
            "role": "assistant",
            "content": text if text or not self.calls else None,
        }
        if self.refusal:
            message["refusal"] = "".join(self.refusal)
        if self.reasoning:
            message["reasoning_content"] = "".join(self.reasoning)
        if self.calls:
            ordered = sorted(self.calls.values(), key=lambda call: call["index"])
            message["tool_calls"] = [
                {
                    "id": call["id"],
                    "type": "function",
                    "function": {"name": call["name"], "arguments": call["arguments"]},
                }
                for call in ordered
            ]
        result: JSON = {
            "id": self.id,
            "object": "chat.completion",
            "created": self.created,
            "model": self.model,
            "choices": [
                {"index": 0, "message": message, "finish_reason": self.finish_reason}
            ],
        }
        if self.usage is not None:
            result["usage"] = self.usage
        return result


def sse_events(stream: BinaryIO) -> Iterator[JSON]:
    """Yield the JSON payload of each server-sent event."""
    data: list[bytes] = []
    while True:
        line = stream.readline()
        stripped = line.rstrip(b"\r\n")
        if stripped.startswith(b"data:"):
            data.append(stripped[5:].removeprefix(b" "))
            continue
        if stripped:
            continue
        if data:
            payload = b"\n".join(data)
            data = []
            if payload != b"[DONE]":
                yield json.loads(payload)
        if not line:
            return


def is_loopback(host: str | None) -> bool:
    try:
        return host is not None and ipaddress.IPv4Address(host).is_loopback
    except ValueError:
        return False


class Upstream:
    """The authenticated loopback Underclass API."""

    def __init__(self, url: str, key: str) -> None:
        parts = urlsplit(url)
        if parts.scheme != "http" or not is_loopback(parts.hostname) or not parts.port:
            msg = "upstream must be an http:// IPv4 loopback URL with a port"
            raise ValueError(msg)
        self.host: str = parts.hostname or ""
        self.port: int = parts.port
        self.base = parts.path.rstrip("/")
        self.key = key

    def request(
        self,
        method: str,
        path: str,
        body: bytes | None = None,
        headers: dict[str, str] | None = None,
    ) -> tuple[http.client.HTTPConnection, http.client.HTTPResponse]:
        connection = http.client.HTTPConnection(
            self.host, self.port, timeout=UPSTREAM_IDLE_TIMEOUT
        )
        try:
            connection.request(
                method,
                self.base + path,
                body=body,
                headers={"Authorization": f"Bearer {self.key}", **(headers or {})},
            )
            return connection, connection.getresponse()
        except BaseException:
            connection.close()
            raise


class Gateway(ThreadingHTTPServer):
    daemon_threads = True
    request_queue_size = 64

    def __init__(self, address: tuple[str, int], upstream: Upstream) -> None:
        super().__init__(address, Handler)
        self.upstream = upstream


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "underclass-mesh-gateway"
    server: Gateway

    def do_GET(self) -> None:  # noqa: N802
        if urlsplit(self.path).path == "/v1/models":
            self.models()
        else:
            self.fail(404, "not found", "not_found_error")

    def do_POST(self) -> None:  # noqa: N802
        if urlsplit(self.path).path == "/v1/chat/completions":
            self.chat()
        else:
            self.fail(404, "not found", "not_found_error")

    def log_message(self, fmt: str, *args: object) -> None:
        # Mesh-LLM probes /v1/models every few seconds; chat() logs requests.
        pass

    def note(self, message: str) -> None:
        print(message, file=sys.stderr, flush=True)

    def models(self) -> None:
        """Advertise the Codex-backed Underclass models."""
        try:
            connection, response = self.server.upstream.request("GET", "/models")
        except OSError as error:
            self.note(f"models: underclass unreachable: {error}")
            self.fail(502, "Underclass is unreachable", "upstream_error")
            return
        try:
            body = response.read(MAX_BODY_BYTES)
            if response.status != 200:
                self.note(f"models: underclass status {response.status}")
                self.relay(response, body[:MAX_ERROR_BYTES])
                return
            try:
                catalog = json.loads(body)
            except ValueError:
                self.fail(
                    502, "Underclass returned an invalid catalog", "upstream_error"
                )
                return
            models = [
                model
                for model in catalog.get("data") or []
                if isinstance(model, dict) and model.get("owned_by") == CODEX_OWNER
            ]
            self.send_json(200, {"object": "list", "data": models})
        finally:
            connection.close()

    def chat(self) -> None:
        started = time.monotonic()
        try:
            chat = json.loads(self.read_body())
            request = responses_request(chat)
        except (RequestError, ValueError) as error:
            self.fail(400, str(error), "invalid_request_error")
            return
        stream = chat.get("stream") is True
        options = chat.get("stream_options")
        include_usage = (
            stream
            and isinstance(options, dict)
            and options.get("include_usage") is True
        )
        headers = {"Content-Type": "application/json", "Accept": "text/event-stream"}
        if session := self.headers.get("session-id"):
            headers["session-id"] = session
        elif not any(field in request for field in AFFINITY_FIELDS):
            request["prompt_cache_key"] = conversation_key(request["input"])
        outcome = "client disconnected"
        try:
            connection, response = self.server.upstream.request(
                "POST", "/responses", json.dumps(request).encode(), headers
            )
        except OSError as error:
            self.note(f"chat: underclass unreachable: {error}")
            self.fail(502, "Underclass is unreachable", "upstream_error")
            return
        try:
            if response.status != 200:
                outcome = f"underclass status {response.status}"
                self.relay(response, response.read(MAX_ERROR_BYTES))
                return
            translator = ChatStream(request["model"])
            if stream:
                self.stream_chat(response, translator, include_usage=include_usage)
            else:
                self.complete_chat(response, translator)
            outcome = (
                f"error {translator.error.get('code')}"
                if translator.error
                else f"finish {translator.finish_reason}"
            )
        except (BrokenPipeError, ConnectionResetError):
            pass
        finally:
            connection.close()
            elapsed = int((time.monotonic() - started) * 1000)
            self.note(
                f"chat model={request['model']} stream={stream} {outcome} ms={elapsed}"
            )

    def read_events(
        self, response: http.client.HTTPResponse, translator: ChatStream
    ) -> Iterator[list[JSON]]:
        """Feed upstream events to the translator until it finishes."""
        try:
            for event in sse_events(response):
                yield translator.feed(event)
                if translator.done:
                    return
        except (OSError, ValueError, http.client.HTTPException) as error:
            translator.interrupt(f"Underclass stream failed: {error}")
            return
        translator.interrupt("Underclass stream ended before the response completed")

    def stream_chat(
        self,
        response: http.client.HTTPResponse,
        translator: ChatStream,
        *,
        include_usage: bool,
    ) -> None:
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Transfer-Encoding", "chunked")
        self.send_header("Connection", "close")
        self.end_headers()
        self.close_connection = True
        for deltas in self.read_events(response, translator):
            for delta in deltas:
                self.write_event(translator.delta_chunk(delta))
        if translator.error:
            self.write_event({"error": translator.error})
        else:
            self.write_event(translator.finish_chunk())
            if include_usage and translator.usage is not None:
                self.write_event(translator.usage_chunk())
        self.write_chunk(b"data: [DONE]\n\n")
        self.write_chunk(b"")

    def complete_chat(
        self, response: http.client.HTTPResponse, translator: ChatStream
    ) -> None:
        for _ in self.read_events(response, translator):
            pass
        if translator.error:
            self.send_json(502, {"error": translator.error})
        else:
            self.send_json(200, translator.completion())

    def read_body(self) -> bytes:
        if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
            return self.read_chunked_body()
        length = int(self.headers.get("Content-Length") or 0)
        if not 0 <= length <= MAX_BODY_BYTES:
            msg = "request body length is invalid or too large"
            raise RequestError(msg)
        return self.rfile.read(length)

    def read_chunked_body(self) -> bytes:
        body = bytearray()
        while True:
            size = int(self.rfile.readline(MAX_LINE_BYTES).split(b";")[0].strip(), 16)
            if size == 0:
                while self.rfile.readline(MAX_LINE_BYTES).strip():
                    pass
                return bytes(body)
            if len(body) + size > MAX_BODY_BYTES:
                msg = "request body is too large"
                raise RequestError(msg)
            body += self.rfile.read(size)
            self.rfile.readline(MAX_LINE_BYTES)

    def write_chunk(self, data: bytes) -> None:
        self.wfile.write(b"%x\r\n%b\r\n" % (len(data), data))

    def write_event(self, payload: JSON) -> None:
        self.write_chunk(b"data: " + json.dumps(payload).encode() + b"\n\n")

    def send_json(self, status: int, payload: object) -> None:
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.close_connection = True
        self.wfile.write(body)

    def fail(self, status: int, message: str, kind: str) -> None:
        self.send_json(status, {"error": {"message": message, "type": kind}})

    def relay(self, response: http.client.HTTPResponse, body: bytes) -> None:
        """Return an Underclass error unchanged."""
        self.send_response(response.status)
        self.send_header(
            "Content-Type", response.getheader("Content-Type") or "application/json"
        )
        for name in RELAYED_HEADERS:
            if value := response.getheader(name):
                self.send_header(name, value)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.close_connection = True
        self.wfile.write(body)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--listen", required=True, help="loopback IPv4 HOST:PORT")
    parser.add_argument(
        "--upstream", required=True, help="Underclass base URL, http://HOST:PORT/v1"
    )
    parser.add_argument(
        "--key-file", required=True, type=Path, help="file holding the proxy key"
    )
    args = parser.parse_args(argv)
    host, _, port = args.listen.rpartition(":")
    if not is_loopback(host) or not port.isdigit():
        parser.error("--listen must be a loopback IPv4 HOST:PORT")
    key = args.key_file.read_text().strip()
    if not key or any(character.isspace() for character in key):
        parser.error("--key-file must contain exactly one proxy key")
    try:
        upstream = Upstream(args.upstream, key)
    except ValueError as error:
        parser.error(str(error))
    server = Gateway((host, int(port)), upstream)
    print(f"listening on http://{host}:{port}/v1", file=sys.stderr, flush=True)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main())
