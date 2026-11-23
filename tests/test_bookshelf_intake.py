"""Behavioral regressions for the Bookshelf upload intake."""

from __future__ import annotations

import hashlib
import http.client
import importlib.util
import io
import json
import os
import socket
import stat
import sys
import threading
import zipfile
from collections.abc import Iterator
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from types import ModuleType
from typing import Any

import pytest

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = Path(
    os.environ.get("BOOKSHELF_INTAKE_SCRIPT", ROOT / "modules/bookshelf/intake.py")
)
OWNER_ID = 4242
MAX_BYTES = 1024 * 1024
TRUSTED_SOURCE = "127.0.0.2"

FAKE_SYNC = """#!{python}
import fcntl, json, re, shutil, sys
from pathlib import Path

config = json.loads(Path("bookshelf.config.json").read_text())
source = Path(config["input"])
library = Path(config["storage"]["directory"])
with open(config["lock"], "a") as lock:
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        held = False
    except BlockingIOError:
        held = True
books = []
for path in sorted(source.rglob("*")):
    if not path.is_file() or path.name.startswith(".") or path.suffix.lower() not in (".epub", ".pdf"):
        continue
    if b"UNREADABLE" in path.read_bytes():
        print(f"  fail   {{path.name}} (cannot read)")
        continue
    if config.get("crash"):
        continue
    book_id = re.sub(r"[^a-z0-9]+", "-", path.stem.lower()).strip("-") or "book"
    folder = library / book_id
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / (book_id + path.suffix.lower())
    shutil.copyfile(path, target)
    books.append({{
        "id": book_id,
        "title": path.stem,
        "authors": ["Test Author"],
        "formats": [{{"format": path.suffix[1:].lower(), "file": target.name, "size": path.stat().st_size}}],
    }})
with open(config["runs"], "a") as runs:
    runs.write(json.dumps({{"lock_held": held, "crashed": bool(config.get("crash"))}}) + "\\n")
if config.get("crash"):
    print("upload failed: storage unavailable")
    sys.exit(3)
(library / "catalog.json").write_text(json.dumps({{"version": 1, "books": books}}))
print(f"{{len(books)}} books built")
"""


@pytest.fixture(scope="module")
def intake() -> ModuleType:
    spec = importlib.util.spec_from_file_location("bookshelf_intake", SCRIPT)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def epub(marker: str) -> bytes:
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        archive.writestr(zipfile.ZipInfo("mimetype"), "application/epub+zip")
        archive.writestr("META-INF/container.xml", "<container/>")
        archive.writestr("OEBPS/text.xhtml", f"<p>{marker}</p>")
    return buffer.getvalue()


class FakeCalibre:
    """Records what reaches Calibre's add-book endpoint, and from where."""

    def __init__(self) -> None:
        self.requests: list[dict[str, Any]] = []
        self.refuse = False
        self.added: dict[str, int] = {}
        fake = self

        class Handler(BaseHTTPRequestHandler):
            def do_POST(self) -> None:  # noqa: N802
                body = self.rfile.read(int(self.headers["Content-Length"]))
                digest = hashlib.sha256(body).hexdigest()
                fake.requests.append(
                    {
                        "client": self.client_address[0],
                        "path": self.path,
                        "sha256": digest,
                    }
                )
                if fake.refuse:
                    self.answer(403, b"Anonymous users are not allowed to make changes")
                    return
                if digest in fake.added:
                    payload = {
                        "title": "T",
                        "authors": ["A"],
                        "duplicates": [{"title": "T", "authors": ["A"]}],
                    }
                else:
                    fake.added[digest] = len(fake.added) + 100
                    payload = {
                        "title": "T",
                        "authors": ["A"],
                        "book_id": fake.added[digest],
                    }
                self.answer(200, json.dumps(payload).encode())

            def answer(self, status: int, body: bytes) -> None:
                self.send_response(status)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, *_args: Any) -> None:
                pass

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    @property
    def url(self) -> str:
        return f"http://127.0.0.1:{self.server.server_address[1]}"

    def close(self) -> None:
        self.server.shutdown()
        self.server.server_close()


class Harness:
    def __init__(self, intake: ModuleType, tmp_path: Path) -> None:
        self.source = tmp_path / "source"
        self.library = tmp_path / "library"
        self.config_dir = tmp_path / "sync-config"
        self.runs = tmp_path / "sync-runs.jsonl"
        for directory in (self.source, self.library, self.config_dir):
            directory.mkdir()
        self.lock = tmp_path / "publish.lock"
        self.sync_config: dict[str, Any] = {
            "input": str(self.source),
            "output": str(tmp_path / "build"),
            "storage": {"provider": "fs", "directory": str(self.library)},
            "lock": str(self.lock),
            "runs": str(self.runs),
        }
        self.write_sync_config()
        sync = tmp_path / "fake-bookshelf-sync"
        sync.write_text(FAKE_SYNC.format(python=sys.executable))
        sync.chmod(0o755)

        self.calibre = FakeCalibre()
        self.owner = intake.Identity(
            user_id=OWNER_ID, login="me@example.com", node="server", tags=()
        )
        self.peer = intake.Identity(
            user_id=OWNER_ID, login="me@example.com", node="phone", tags=()
        )
        self.whois_failure: Exception | None = None
        config = intake.Config(
            bind="127.0.0.1",
            port=0,
            max_bytes=MAX_BYTES,
            tailscale_socket="/nonexistent",
            source_dir=self.source,
            library_dir=self.library,
            site_url="http://127.0.0.1:9/",
            sync=str(sync),
            sync_config_dir=self.config_dir,
            sync_lock=self.lock,
            calibre_url=self.calibre.url,
            calibre_library_id="Test_Library",
            calibre_source_address=TRUSTED_SOURCE,
        )
        self.server = intake.IntakeServer(intake.Intake(config, self.whois))
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def whois(self, address: str, port: int) -> Any:
        if self.whois_failure is not None:
            raise self.whois_failure
        if (address, port) == ("127.0.0.1", self.port):
            return self.owner
        return self.peer

    def write_sync_config(self) -> None:
        (self.config_dir / "bookshelf.config.json").write_text(
            json.dumps(self.sync_config)
        )

    @property
    def port(self) -> int:
        return self.server.server_port

    def request(
        self,
        method: str,
        path: str,
        body: bytes | None = None,
        headers: dict[str, str] | None = None,
    ) -> tuple[int, Any]:
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=30)
        try:
            connection.request(method, path, body=body, headers=headers or {})
            response = connection.getresponse()
            payload = response.read()
        finally:
            connection.close()
        if response.getheader("Content-Type", "").startswith("application/json"):
            return response.status, json.loads(payload)
        return response.status, payload.decode()

    def put(
        self, name: str, body: bytes, headers: dict[str, str] | None = None
    ) -> tuple[int, Any]:
        return self.request("PUT", "/" + name, body, headers)

    def source_files(self) -> list[str]:
        return sorted(path.name for path in self.source.iterdir())

    def sync_runs(self) -> list[dict[str, Any]]:
        if not self.runs.exists():
            return []
        return [json.loads(line) for line in self.runs.read_text().splitlines()]

    def close(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.calibre.close()


@pytest.fixture
def harness(intake: ModuleType, tmp_path: Path) -> Iterator[Harness]:
    instance = Harness(intake, tmp_path)
    try:
        yield instance
    finally:
        instance.close()


@pytest.mark.parametrize(
    ("path", "expected"),
    [
        ("/The%20Hedgehog%20and%20the%20Fox.EPUB", "The Hedgehog and the Fox.epub"),
        ("/.hidden.epub", "hidden.epub"),
        ("/%3A%3F%2A.pdf", "book.pdf"),
        ("/Caf%C3%A9%20%E2%80%94%20notes.pdf", "Café - notes.pdf"),
        ("/report.pdf?ignored=1", "report.pdf"),
    ],
)
def test_book_name_is_sanitised(intake: ModuleType, path: str, expected: str) -> None:
    assert intake.book_name(path) == expected


@pytest.mark.parametrize(
    ("path", "status"),
    [
        ("/..%2F..%2Fetc%2Fpasswd.epub", 400),
        ("/a%5Cb.epub", 400),
        ("/a%00b.epub", 400),
        ("/", 400),
        ("/notes.docx", 415),
        ("/.epub", 415),
    ],
)
def test_book_name_refuses_paths_and_other_types(
    intake: ModuleType, path: str, status: int
) -> None:
    with pytest.raises(intake.IntakeError) as refused:
        intake.book_name(path)
    assert refused.value.status == status


def test_long_book_name_fits_the_filesystem(intake: ModuleType) -> None:
    name = intake.book_name("/" + "é" * 400 + ".epub")
    assert name.endswith(".epub")
    assert len(name.encode()) <= 240


@pytest.mark.parametrize(
    ("host", "allowed"),
    [
        ("100.110.43.11:39301", True),
        ("britton-desktop:39301", True),
        ("britton-desktop.bison-tailor.ts.net", True),
        ("rebound.example.com:39301", False),
        ("100.110.43.12:39301", False),
        (None, False),
    ],
)
def test_host_header_must_name_this_server(
    intake: ModuleType, host: str | None, allowed: bool
) -> None:
    assert intake.allowed_host(host, "100.110.43.11") is allowed


SERVER = ("100.64.0.1", 39301)
PEER = ("100.64.0.2", 50000)


def test_authorize_admits_only_untagged_devices_of_the_server_owner(
    intake: ModuleType,
) -> None:
    def answer(owner: Any, peer: Any = None, failure: Exception | None = None) -> Any:
        def whois(address: str, port: int) -> Any:
            if (address, port) == SERVER:
                return owner
            if failure is not None:
                raise failure
            return peer

        return whois

    owner = intake.Identity(OWNER_ID, "me@example.com", "server", ())
    mine = intake.Identity(OWNER_ID, "me@example.com", "phone", ())
    assert intake.authorize(answer(owner, mine), PEER, SERVER) == mine

    refusals = [
        (answer(owner, intake.Identity(7, "someone@example.com", "laptop", ())), 403),
        (
            answer(
                owner, intake.Identity(OWNER_ID, "me@example.com", "ci", ("tag:ci",))
            ),
            403,
        ),
        (
            answer(owner, intake.Identity(9, "tagged-devices", "exit", ("tag:exit",))),
            403,
        ),
        (answer(owner, failure=LookupError("100.64.0.2")), 403),
        (answer(owner, failure=ConnectionRefusedError("tailscaled is down")), 503),
        # A tagged server has no owner whose devices could be admitted.
        (
            answer(
                intake.Identity(9, "tagged-devices", "server", ("tag:server",)), mine
            ),
            503,
        ),
    ]
    for whois, status in refusals:
        with pytest.raises(intake.IntakeError) as refused:
            intake.authorize(whois, PEER, SERVER)
        assert refused.value.status == status


def test_upload_adds_the_book_to_both_libraries(harness: Harness) -> None:
    book = epub("one")
    status, result = harness.put("First%20Book.epub", book)

    assert status == 201, result
    assert result["bookshelf"]["status"] == "added"
    assert result["bookshelf"]["id"] == "first-book"
    assert result["calibre"] == {
        "status": "added",
        "book_id": 100,
        "title": "T",
        "authors": ["A"],
    }

    stored = harness.source / "First Book.epub"
    assert harness.source_files() == ["First Book.epub"]
    assert stored.read_bytes() == book
    assert stat.S_IMODE(stored.stat().st_mode) == 0o600
    assert (harness.library / "first-book" / "first-book.epub").read_bytes() == book

    # bookshelf-sync ran once, while intake held the lock bookshelf-publish.service takes.
    assert harness.sync_runs() == [{"lock_held": True, "crashed": False}]

    # Calibre saw the same bytes, from the loopback address it trusts for writes.
    [calibre] = harness.calibre.requests
    assert calibre["client"] == TRUSTED_SOURCE
    assert calibre["sha256"] == hashlib.sha256(book).hexdigest()
    assert calibre["path"].startswith("/cdb/add-book/")
    assert calibre["path"].endswith("/n/First%20Book.epub/Test_Library")


def test_same_bytes_again_are_reported_not_duplicated(harness: Harness) -> None:
    book = epub("one")
    assert harness.put("first.epub", book)[0] == 201

    status, result = harness.put("renamed%20copy.epub", book)

    assert status == 200, result
    assert result["bookshelf"]["status"] == "already-present"
    assert result["bookshelf"]["source"] == "first.epub"
    assert result["calibre"]["status"] == "already-present"
    assert harness.source_files() == ["first.epub"]
    assert len(harness.sync_runs()) == 1


def test_a_different_book_with_the_same_name_does_not_replace_it(
    harness: Harness,
) -> None:
    first, second = epub("one"), epub("two")
    assert harness.put("book.epub", first)[0] == 201

    status, result = harness.put("book.epub", second)

    assert status == 201, result
    assert result["bookshelf"]["source"] == "book-2.epub"
    assert (harness.source / "book.epub").read_bytes() == first
    assert (harness.source / "book-2.epub").read_bytes() == second


@pytest.mark.parametrize(
    ("name", "body", "headers", "status"),
    [
        ("book.epub", epub("x"), {"Host": "rebound.example.com"}, 421),
        ("book.epub", epub("x"), {"Origin": "http://elsewhere.example.com"}, 403),
        ("book.epub", b"x" * (MAX_BYTES + 1), {}, 413),
        ("book.mobi", b"x", {}, 415),
        ("book.epub", b"PK but not really an archive", {}, 415),
        ("book.pdf", b"<html>not a pdf</html>", {}, 415),
    ],
    ids=[
        "rebound-host",
        "foreign-origin",
        "too-large",
        "other-type",
        "fake-epub",
        "fake-pdf",
    ],
)
def test_refused_uploads_leave_nothing_behind(
    harness: Harness, name: str, body: bytes, headers: dict[str, str], status: int
) -> None:
    answer, result = harness.put(name, body, headers)

    assert answer == status, result
    assert "error" in result
    assert harness.source_files() == []
    assert harness.sync_runs() == []
    assert harness.calibre.requests == []


def test_other_owners_and_unidentified_peers_are_refused(
    intake: ModuleType, harness: Harness
) -> None:
    harness.peer = intake.Identity(7, "someone@example.com", "laptop", ())
    assert harness.put("book.epub", epub("x"))[0] == 403
    assert harness.request("GET", "/")[0] == 403

    harness.whois_failure = ConnectionRefusedError("tailscaled is down")
    assert harness.put("book.epub", epub("x"))[0] == 503

    assert harness.source_files() == []
    assert harness.calibre.requests == []


def test_post_and_chunked_uploads_are_refused(harness: Harness) -> None:
    assert harness.request("POST", "/book.epub", epub("x"))[0] == 405

    connection = http.client.HTTPConnection("127.0.0.1", harness.port, timeout=30)
    try:
        connection.request(
            "PUT", "/book.epub", body=iter([epub("x")]), encode_chunked=True
        )
        assert connection.getresponse().status == 411
    finally:
        connection.close()
    assert harness.source_files() == []


def raw_exchange(port: int, head: str) -> socket.socket:
    client = socket.create_connection(("127.0.0.1", port), timeout=30)
    client.sendall(head.encode())
    return client


def status_line(client: socket.socket) -> str:
    received = b""
    while b"\r\n" not in received:
        chunk = client.recv(4096)
        if not chunk:
            break
        received += chunk
    return received.split(b"\r\n", 1)[0].decode()


def test_expect_continue_refuses_before_the_body_is_sent(harness: Harness) -> None:
    client = raw_exchange(
        harness.port,
        f"PUT /big.epub HTTP/1.1\r\nHost: 127.0.0.1:{harness.port}\r\n"
        f"Content-Length: {MAX_BYTES + 1}\r\nExpect: 100-continue\r\n\r\n",
    )
    try:
        assert status_line(client).startswith("HTTP/1.1 413")
    finally:
        client.close()


def test_expect_continue_accepts_a_valid_upload(harness: Harness) -> None:
    book = epub("continued")
    client = raw_exchange(
        harness.port,
        f"PUT /continued.epub HTTP/1.1\r\nHost: 127.0.0.1:{harness.port}\r\n"
        f"Content-Length: {len(book)}\r\nExpect: 100-continue\r\n\r\n",
    )
    try:
        interim = b""
        while b"\r\n\r\n" not in interim:
            chunk = client.recv(4096)
            assert chunk, "connection closed before 100 Continue"
            interim += chunk
        assert interim.startswith(b"HTTP/1.1 100 Continue\r\n")
        client.sendall(book)
        response = interim.split(b"\r\n\r\n", 1)[1]
        while chunk := client.recv(65536):
            response += chunk
    finally:
        client.close()
    assert response.startswith(b"HTTP/1.1 201")
    assert harness.source_files() == ["continued.epub"]


def test_unreadable_book_is_reported_and_removed_from_the_source(
    harness: Harness,
) -> None:
    book = epub("UNREADABLE")
    status, result = harness.put("broken.epub", book)

    assert status == 502, result
    assert result["bookshelf"]["status"] == "failed"
    assert "fail" in result["bookshelf"]["error"]
    assert "broken.epub" in result["bookshelf"]["error"]
    assert harness.source_files() == []
    # Calibre is a separate library and still gets its own answer.
    assert result["calibre"]["status"] == "added"


def test_failed_publish_keeps_the_book_for_the_next_run(harness: Harness) -> None:
    book = epub("kept")
    harness.sync_config["crash"] = True
    harness.write_sync_config()

    status, result = harness.put("kept.epub", book)

    assert status == 502, result
    assert result["bookshelf"]["status"] == "failed"
    assert result["bookshelf"]["error"] == "bookshelf-sync exited with status 3"
    assert result["bookshelf"]["log"][-1] == "upload failed: storage unavailable"
    assert harness.source_files() == ["kept.epub"]

    # Sending the same book again once publishing works puts it on the shelf.
    harness.sync_config["crash"] = False
    harness.write_sync_config()
    status, result = harness.put("kept.epub", book)

    assert status == 201, result
    assert result["bookshelf"]["status"] == "added"
    assert result["bookshelf"]["source"] == "kept.epub"
    assert result["calibre"]["status"] == "already-present"
    assert harness.source_files() == ["kept.epub"]


def test_calibre_refusal_is_reported_without_losing_bookshelf(harness: Harness) -> None:
    harness.calibre.refuse = True

    status, result = harness.put("solo.epub", epub("solo"))

    assert status == 502, result
    assert result["bookshelf"]["status"] == "added"
    assert result["calibre"]["status"] == "failed"
    assert "403" in result["calibre"]["error"]
    assert harness.source_files() == ["solo.epub"]


def test_page_is_served_to_allowed_devices(harness: Harness) -> None:
    status, page = harness.request("GET", "/")

    assert status == 200
    assert f"curl -T book.epub http://127.0.0.1:{harness.port}/" in page
    assert "const maxBytes = 1048576;" in page
    assert harness.request("GET", "/elsewhere")[0] == 404
