"""Behavior of the Underclass Mesh-LLM gateway."""

from __future__ import annotations

import http.client
import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import ClassVar

import gateway
import pytest

KEY = "test-proxy-key"
CREATED = {
    "type": "response.created",
    "response": {"id": "resp_1", "created_at": 1700000000, "model": "gpt-5.5"},
}
USAGE = {
    "input_tokens": 11,
    "input_tokens_details": {"cached_tokens": 3},
    "output_tokens": 7,
    "output_tokens_details": {"reasoning_tokens": 5},
    "total_tokens": 18,
}
COMPLETED = {"type": "response.completed", "response": {"output": [], "usage": USAGE}}
TEXT_EVENTS = [
    CREATED,
    {"type": "response.output_item.added", "item": {"id": "rs_1", "type": "reasoning"}},
    {"type": "response.output_text.delta", "item_id": "msg_1", "delta": "po"},
    {"type": "response.output_text.delta", "item_id": "msg_1", "delta": "ng"},
    COMPLETED,
]


def call_item(item_id, call_id, arguments):
    return {
        "id": item_id,
        "type": "function_call",
        "call_id": call_id,
        "name": "get_weather",
        "arguments": arguments,
    }


# Codex streams Paris's arguments as deltas; Rome's arrive only when done.
TOOL_EVENTS = [
    CREATED,
    {"type": "response.output_item.added", "item": call_item("fc_1", "call_a", "")},
    {
        "type": "response.function_call_arguments.delta",
        "item_id": "fc_1",
        "delta": '{"city":',
    },
    {
        "type": "response.function_call_arguments.delta",
        "item_id": "fc_1",
        "delta": '"Paris"}',
    },
    {
        "type": "response.output_item.done",
        "item": call_item("fc_1", "call_a", '{"city":"Paris"}'),
    },
    {"type": "response.output_item.added", "item": call_item("fc_2", "call_b", "")},
    {
        "type": "response.output_item.done",
        "item": call_item("fc_2", "call_b", '{"city":"Rome"}'),
    },
    COMPLETED,
]


def feed_all(events, model="gpt-5.5"):
    stream = gateway.ChatStream(model)
    deltas = [delta for event in events for delta in stream.feed(event)]
    return stream, deltas


def merged_tool_calls(deltas):
    calls = {}
    for delta in deltas:
        for entry in delta.get("tool_calls", []):
            call = calls.setdefault(entry["index"], {"arguments": ""})
            call.update({key: entry[key] for key in ("id", "type") if key in entry})
            call.setdefault("name", entry["function"].get("name"))
            call["arguments"] += entry["function"]["arguments"]
    return calls


def test_conversation_with_tool_history_becomes_responses_input():
    request = gateway.responses_request(
        {
            "model": "gpt-5.5",
            "stream": False,
            "stream_options": {"include_usage": True},
            "max_completion_tokens": 256,
            "chat_template_kwargs": {"enable_thinking": True},
            "reasoning_effort": "low",
            "temperature": 0.2,
            "prompt_cache_key": "session-1",
            "messages": [
                {"role": "system", "content": "Be terse."},
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "Weather?"},
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": "data:image/png;base64,AA",
                                "detail": "low",
                            },
                        },
                    ],
                },
                {
                    "role": "assistant",
                    "content": None,
                    "tool_calls": [
                        {
                            "id": "call_a",
                            "type": "function",
                            "function": {
                                "name": "get_weather",
                                "arguments": '{"city":"Paris"}',
                            },
                        }
                    ],
                },
                {"role": "tool", "tool_call_id": "call_a", "content": "sunny"},
                {"role": "assistant", "content": "It is sunny."},
            ],
            "tools": [
                {
                    "type": "function",
                    "function": {
                        "name": "get_weather",
                        "parameters": {"type": "object"},
                    },
                }
            ],
            "tool_choice": {"type": "function", "function": {"name": "get_weather"}},
        }
    )
    assert request == {
        "model": "gpt-5.5",
        # Codex rejects these itself; they must not be silently dropped.
        "temperature": 0.2,
        "prompt_cache_key": "session-1",
        "input": [
            {
                "role": "system",
                "content": [{"type": "input_text", "text": "Be terse."}],
            },
            {
                "role": "user",
                "content": [
                    {"type": "input_text", "text": "Weather?"},
                    {
                        "type": "input_image",
                        "image_url": "data:image/png;base64,AA",
                        "detail": "low",
                    },
                ],
            },
            {
                "type": "function_call",
                "call_id": "call_a",
                "name": "get_weather",
                "arguments": '{"city":"Paris"}',
            },
            {"type": "function_call_output", "call_id": "call_a", "output": "sunny"},
            {
                "role": "assistant",
                "content": [{"type": "output_text", "text": "It is sunny."}],
            },
        ],
        "tools": [
            {
                "type": "function",
                "name": "get_weather",
                "parameters": {"type": "object"},
            }
        ],
        "tool_choice": {"type": "function", "name": "get_weather"},
        "reasoning": {"effort": "low"},
        "stream": True,
    }


def test_responses_shaped_tools_and_structured_output():
    tool = {"type": "function", "name": "lookup", "parameters": {"type": "object"}}
    request = gateway.responses_request(
        {
            "model": "gpt-5.5",
            "messages": [{"role": "user", "content": "hi"}],
            "tools": [tool],
            "tool_choice": "required",
            "response_format": {
                "type": "json_schema",
                "json_schema": {
                    "name": "answer",
                    "schema": {"type": "object"},
                    "strict": True,
                },
            },
            "verbosity": "low",
        }
    )
    assert request["tools"] == [tool]
    assert request["tool_choice"] == "required"
    assert request["text"] == {
        "format": {
            "type": "json_schema",
            "name": "answer",
            "schema": {"type": "object"},
            "strict": True,
        },
        "verbosity": "low",
    }


@pytest.mark.parametrize(
    "body",
    [
        {"model": "gpt-5.5", "messages": []},
        {"messages": [{"role": "user", "content": "hi"}]},
        {"model": "gpt-5.5", "messages": [{"role": "function", "content": "x"}]},
        {"model": "gpt-5.5", "messages": [{"role": "tool", "content": "x"}]},
        {
            "model": "gpt-5.5",
            "messages": [
                {
                    "role": "user",
                    "content": [{"type": "input_audio", "input_audio": {}}],
                }
            ],
        },
    ],
)
def test_rejects_messages_without_a_responses_equivalent(body):
    with pytest.raises(gateway.RequestError):
        gateway.responses_request(body)


def test_text_stream_reports_usage_and_stop():
    stream, deltas = feed_all(TEXT_EVENTS)
    assert deltas == [{"role": "assistant", "content": "po"}, {"content": "ng"}]
    assert stream.finish_reason == "stop"
    assert stream.id == "chatcmpl-resp_1"
    assert stream.usage == {
        "prompt_tokens": 11,
        "completion_tokens": 7,
        "total_tokens": 18,
        "prompt_tokens_details": {"cached_tokens": 3},
        "completion_tokens_details": {"reasoning_tokens": 5},
    }
    assert stream.completion()["choices"][0]["message"]["content"] == "pong"


def test_tool_calls_keep_indexes_and_complete_arguments():
    stream, deltas = feed_all(TOOL_EVENTS)
    assert merged_tool_calls(deltas) == {
        0: {
            "id": "call_a",
            "type": "function",
            "name": "get_weather",
            "arguments": '{"city":"Paris"}',
        },
        1: {
            "id": "call_b",
            "type": "function",
            "name": "get_weather",
            "arguments": '{"city":"Rome"}',
        },
    }
    assert stream.finish_reason == "tool_calls"
    message = stream.completion()["choices"][0]["message"]
    assert message["content"] is None
    assert [call["function"]["arguments"] for call in message["tool_calls"]] == [
        '{"city":"Paris"}',
        '{"city":"Rome"}',
    ]


def test_incomplete_and_failed_responses():
    incomplete = {
        "type": "response.incomplete",
        "response": {"incomplete_details": {"reason": "max_output_tokens"}},
    }
    stream, _ = feed_all([CREATED, incomplete])
    assert stream.finish_reason == "length"

    failed = {
        "type": "response.failed",
        "response": {"error": {"code": "server_error", "message": "boom"}},
    }
    stream, _ = feed_all([CREATED, failed])
    assert stream.finish_reason is None
    assert stream.error is not None
    assert stream.error["message"] == "boom"
    assert stream.error["code"] == "server_error"


class FakeUnderclass(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    requests: ClassVar[list[dict]] = []

    def log_message(self, fmt, *args):
        pass

    def reply(self, status, body, content_type="application/json"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def authorized(self):
        if self.headers.get("Authorization") == f"Bearer {KEY}":
            return True
        error = {"error": {"message": "invalid or missing proxy api key"}}
        self.reply(401, json.dumps(error).encode())
        return False

    def do_GET(self):
        if self.authorized() and self.path == "/v1/models":
            catalog = {
                "object": "list",
                "data": [
                    {"id": "gpt-5.5", "owned_by": "underclass-codex"},
                    {"id": "gpt-4.1", "owned_by": "underclass-copilot"},
                ],
            }
            self.reply(200, json.dumps(catalog).encode())

    def do_POST(self):
        length = int(self.headers["Content-Length"])
        body = json.loads(self.rfile.read(length))
        if not self.authorized():
            return
        FakeUnderclass.requests.append(body)
        if "temperature" in body:
            detail = {"detail": "Unsupported parameter: temperature"}
            self.reply(400, json.dumps(detail).encode())
            return
        events = {
            "gpt-tools": TOOL_EVENTS,
            "gpt-truncated": TEXT_EVENTS[:-1],
        }.get(body["model"], TEXT_EVENTS)
        stream = b"".join(
            b"event: %b\ndata: %b\n\n"
            % (event["type"].encode(), json.dumps(event).encode())
            for event in events
        )
        self.reply(200, stream, "text/event-stream")


def running(server):
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


@pytest.fixture(scope="module")
def servers():
    upstream = running(ThreadingHTTPServer(("127.0.0.1", 0), FakeUnderclass))
    url = f"http://127.0.0.1:{upstream.server_address[1]}/v1"
    current = running(gateway.Gateway(("127.0.0.1", 0), gateway.Upstream(url, KEY)))
    stale = running(gateway.Gateway(("127.0.0.1", 0), gateway.Upstream(url, "stale")))
    yield {"current": current, "stale": stale}
    for server in (current, stale, upstream):
        server.shutdown()
        server.server_close()


@pytest.fixture
def call(servers):
    FakeUnderclass.requests.clear()

    def request(method, path, body=None, server="current"):
        port = servers[server].server_address[1]
        connection = http.client.HTTPConnection("127.0.0.1", port, timeout=10)
        payload = None if body is None else json.dumps(body).encode()
        headers = {} if body is None else {"Content-Type": "application/json"}
        connection.request(method, path, body=payload, headers=headers)
        response = connection.getresponse()
        result = (response.status, response.getheader("Content-Type"), response.read())
        connection.close()
        return result

    return request


def chat(call, model, **extra):
    body = {"model": model, "messages": [{"role": "user", "content": "ping"}], **extra}
    return call("POST", "/v1/chat/completions", body)


def sse_chunks(body):
    events = [
        line.removeprefix("data: ") for line in body.decode().split("\n\n") if line
    ]
    assert events[-1] == "[DONE]"
    return [json.loads(event) for event in events[:-1]]


def test_models_lists_only_codex_backed_entries(call):
    status, _, body = call("GET", "/v1/models")
    assert status == 200
    assert [model["id"] for model in json.loads(body)["data"]] == ["gpt-5.5"]


def test_streaming_chat_is_translated(call):
    status, content_type, body = chat(
        call,
        "gpt-5.5",
        stream=True,
        stream_options={"include_usage": True},
        max_tokens=64,
    )
    assert status == 200
    assert content_type == "text/event-stream"
    chunks = sse_chunks(body)
    text = "".join(
        choice["delta"].get("content", "")
        for chunk in chunks
        for choice in chunk["choices"]
    )
    assert text == "pong"
    assert chunks[-2]["choices"][0]["finish_reason"] == "stop"
    assert chunks[-1]["choices"] == []
    assert chunks[-1]["usage"]["prompt_tokens"] == 11
    [upstream] = FakeUnderclass.requests
    assert upstream["stream"] is True
    assert "max_tokens" not in upstream
    assert upstream["input"] == [
        {"role": "user", "content": [{"type": "input_text", "text": "ping"}]}
    ]


def test_non_streaming_chat_returns_one_completion(call):
    status, _, body = chat(call, "gpt-5.5")
    assert status == 200
    completion = json.loads(body)
    assert completion["object"] == "chat.completion"
    assert completion["choices"][0]["message"]["content"] == "pong"
    assert completion["choices"][0]["finish_reason"] == "stop"
    assert completion["usage"]["completion_tokens"] == 7


def test_streaming_tool_calls(call):
    status, _, body = chat(call, "gpt-tools", stream=True)
    assert status == 200
    chunks = sse_chunks(body)
    deltas = [choice["delta"] for chunk in chunks for choice in chunk["choices"]]
    calls = merged_tool_calls(deltas)
    assert [entry["arguments"] for entry in calls.values()] == [
        '{"city":"Paris"}',
        '{"city":"Rome"}',
    ]
    assert chunks[-1]["choices"][0]["finish_reason"] == "tool_calls"


def test_upstream_rejection_is_relayed(call):
    status, _, body = chat(call, "gpt-5.5", temperature=0.2)
    assert status == 400
    assert json.loads(body) == {"detail": "Unsupported parameter: temperature"}


def test_wrong_key_surfaces_authentication_failure(call):
    status, _, _ = call("GET", "/v1/models", server="stale")
    assert status == 401


def test_truncated_stream_is_an_error(call):
    status, _, body = chat(call, "gpt-truncated")
    assert status == 502
    assert "ended before" in json.loads(body)["error"]["message"]


def test_conversation_turns_share_one_affinity_key(call):
    opening = [
        {"role": "system", "content": "Be terse."},
        {"role": "user", "content": "ping"},
    ]
    follow_up = [
        *opening,
        {"role": "assistant", "content": "pong"},
        {"role": "user", "content": "again"},
    ]
    for messages in (opening, follow_up):
        call("POST", "/v1/chat/completions", {"model": "gpt-5.5", "messages": messages})
    other = [{"role": "user", "content": "a different conversation"}]
    call("POST", "/v1/chat/completions", {"model": "gpt-5.5", "messages": other})
    explicit = {"model": "gpt-5.5", "messages": other, "prompt_cache_key": "client"}
    call("POST", "/v1/chat/completions", explicit)

    first, second, third, fourth = (
        request["prompt_cache_key"] for request in FakeUnderclass.requests
    )
    assert first == second
    assert first.startswith("mesh-")
    assert third not in {first, "client"}
    assert fourth == "client"


def test_other_paths_are_not_proxied(call):
    assert call("GET", "/admin/api/state")[0] == 404
    assert call("POST", "/v1/responses", {"model": "gpt-5.5"})[0] == 404
    assert FakeUnderclass.requests == []
