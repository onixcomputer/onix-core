#!/usr/bin/env python3
"""Upload endpoint that adds owned EPUB and PDF books to Bookshelf and Calibre.

``PUT /<file name>`` with the book as the raw request body adds it, which is
what ``curl -T book.epub http://host:port/`` sends; ``GET /`` serves a page
that does the same from a browser.

Every request must come from an untagged Tailscale device owned by the same
Tailscale user as this server. tailscaled's local API resolves both the peer
and the server's own address, and a request that cannot be identified is
refused, so no identity is configured anywhere. Uploads are PUT-only and must
name this host, so a web page in the user's browser cannot forge one: a
cross-origin PUT needs a CORS preflight this server never grants, and a
DNS-rebound name fails the Host check.

Each upload is written into the Bookshelf source directory under its own
sanitised name, unless the same bytes are already there, and published with
bookshelf-sync while holding the lock that bookshelf-publish.service also
takes. It is then offered to the Calibre content server's add-book endpoint
from the loopback address Calibre trusts for writes, if a server is
configured. Uploads are added one at a time, and the JSON response reports
what each library did.
"""

from __future__ import annotations

import errno
import fcntl
import hashlib
import html
import http.client
import json
import os
import secrets
import socket
import socketserver
import subprocess
import sys
import tempfile
import threading
import unicodedata
import urllib.parse
import zipfile
from collections.abc import Callable, Iterator, Mapping
from dataclasses import dataclass
from email.message import Message
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, BinaryIO

BOOK_EXTENSIONS = (".epub", ".pdf")
PART_PREFIX = ".intake-"
PART_SUFFIX = ".part"
CHUNK_BYTES = 1024 * 1024
MAX_STEM_CHARS = 120
MAX_NAME_BYTES = 240
CONCURRENT_UPLOADS = 4
SOCKET_TIMEOUT_SECONDS = 120
# After refusing an upload, discard up to this much of its unread body (for at
# most LINGER_SECONDS per read) so the client sees the answer, not a reset.
DRAIN_LIMIT_BYTES = 2 * 1024 * 1024
LINGER_SECONDS = 5
TAILSCALE_LOCALAPI_HOST = "local-tailscaled.sock"
NAME_PUNCTUATION = frozenset(" -_.,()+&'")
MEBIBYTE = 1024 * 1024


class IntakeError(Exception):
    """A request the intake refuses, with the HTTP status that says why."""

    def __init__(self, status: HTTPStatus, message: str) -> None:
        super().__init__(message)
        self.status = status
        self.message = message


@dataclass(frozen=True)
class Config:
    bind: str
    port: int
    max_bytes: int
    tailscale_socket: str
    source_dir: Path
    library_dir: Path
    site_url: str
    sync: str
    sync_config_dir: Path
    sync_lock: Path
    calibre_url: str | None = None
    calibre_library_id: str | None = None
    calibre_source_address: str | None = None
    sync_timeout: float = 1800.0
    calibre_timeout: float = 300.0

    @classmethod
    def from_env(cls, env: Mapping[str, str]) -> Config:
        def need(key: str) -> str:
            value = env.get(key, "").strip()
            if not value:
                message = f"bookshelf-intake: {key} must be set"
                raise SystemExit(message)
            return value

        def optional(key: str) -> str | None:
            return env.get(key, "").strip() or None

        return cls(
            bind=need("BOOKSHELF_INTAKE_BIND"),
            port=int(need("BOOKSHELF_INTAKE_PORT")),
            max_bytes=int(need("BOOKSHELF_INTAKE_MAX_BYTES")),
            tailscale_socket=need("BOOKSHELF_INTAKE_TAILSCALE_SOCKET"),
            source_dir=Path(need("BOOKSHELF_SOURCE_DIR")),
            library_dir=Path(need("BOOKSHELF_LIBRARY_DIR")),
            site_url=need("BOOKSHELF_SITE_URL"),
            sync=need("BOOKSHELF_SYNC"),
            sync_config_dir=Path(need("BOOKSHELF_SYNC_CONFIG_DIR")),
            sync_lock=Path(need("BOOKSHELF_SYNC_LOCK")),
            calibre_url=optional("CALIBRE_URL"),
            calibre_library_id=optional("CALIBRE_LIBRARY_ID"),
            calibre_source_address=optional("CALIBRE_SOURCE_ADDRESS"),
        )


# --- Who is asking --------------------------------------------------------


@dataclass(frozen=True)
class Identity:
    user_id: int
    login: str
    node: str
    tags: tuple[str, ...]


WhoIs = Callable[[str, int], Identity]


class _UnixHTTPConnection(http.client.HTTPConnection):
    """HTTP over tailscaled's local API socket."""

    def __init__(self, path: str, timeout: float) -> None:
        super().__init__(TAILSCALE_LOCALAPI_HOST, timeout=timeout)
        self._socket_path = path

    def connect(self) -> None:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(self.timeout)
        sock.connect(self._socket_path)
        self.sock = sock


def tailscale_whois(socket_path: str) -> WhoIs:
    """Resolve a peer address to its Tailscale node and owner."""

    def whois(address: str, port: int) -> Identity:
        connection = _UnixHTTPConnection(socket_path, timeout=5)
        try:
            query = urllib.parse.urlencode({"addr": f"{address}:{port}"})
            connection.request("GET", f"/localapi/v0/whois?{query}")
            response = connection.getresponse()
            body = response.read()
        finally:
            connection.close()
        if response.status == HTTPStatus.NOT_FOUND:
            raise LookupError(address)
        if response.status != HTTPStatus.OK:
            message = f"tailscaled answered {response.status}"
            raise RuntimeError(message)
        answer = json.loads(body)
        node = answer.get("Node") or {}
        profile = answer.get("UserProfile") or {}
        return Identity(
            user_id=int(profile.get("ID") or node.get("User") or 0),
            login=str(profile.get("LoginName") or ""),
            node=str(node.get("ComputedName") or node.get("Name") or ""),
            tags=tuple(node.get("Tags") or ()),
        )

    return whois


def authorize(whois: WhoIs, peer: tuple[str, int], server: tuple[str, int]) -> Identity:
    """Admit an untagged peer owned by the Tailscale user who owns this server."""
    try:
        owner = whois(*server)
        identity = whois(*peer)
    except LookupError:
        raise IntakeError(
            HTTPStatus.FORBIDDEN, "this address is not a device on the tailnet"
        ) from None
    except Exception as error:  # noqa: BLE001 - any failure to identify the peer refuses it
        raise IntakeError(
            HTTPStatus.SERVICE_UNAVAILABLE, f"cannot identify the device: {error}"
        ) from None
    if owner.tags or not owner.user_id:
        raise IntakeError(
            HTTPStatus.SERVICE_UNAVAILABLE,
            "this server is a tagged device, so no Tailscale user owns it",
        )
    if identity.tags:
        raise IntakeError(HTTPStatus.FORBIDDEN, "tagged devices may not upload books")
    if identity.user_id != owner.user_id:
        raise IntakeError(
            HTTPStatus.FORBIDDEN,
            f"only devices of this server's Tailscale owner may upload books, not {identity.login or 'this device'}",
        )
    return identity


def allowed_host(host_header: str | None, bind: str) -> bool:
    """Whether a Host header names this server rather than a rebound domain."""
    if not host_header:
        return False
    host = urllib.parse.urlsplit(f"//{host_header.strip()}").hostname or ""
    host = host.rstrip(".").lower()
    if host == bind.lower():
        return True
    # MagicDNS names: the short machine name, or one under the tailnet's
    # ts.net domain. Neither can be pointed elsewhere by a web page.
    return bool(host) and ("." not in host or host.endswith(".ts.net"))


# --- What is being sent ---------------------------------------------------


def book_name(request_path: str) -> str:
    """The sanitised file name an upload is stored under."""
    raw = urllib.parse.unquote(
        urllib.parse.urlsplit(request_path).path.removeprefix("/")
    )
    if not raw:
        raise IntakeError(
            HTTPStatus.BAD_REQUEST, "put the file name in the URL, as in PUT /book.epub"
        )
    if "/" in raw or "\\" in raw or "\x00" in raw:
        raise IntakeError(
            HTTPStatus.BAD_REQUEST, "the file name must not contain a path"
        )
    requested = Path(unicodedata.normalize("NFC", raw).strip())
    stem, extension = requested.stem, requested.suffix.lower()
    if extension not in BOOK_EXTENSIONS:
        raise IntakeError(
            HTTPStatus.UNSUPPORTED_MEDIA_TYPE, "only .epub and .pdf files are accepted"
        )

    kept: list[str] = []
    for character in stem:
        if character.isalnum() or character in NAME_PUNCTUATION:
            kept.append(character)
        elif not kept or kept[-1] != "-":
            kept.append("-")
    # Leading dots would hide the file, and intake's own partial files start with one.
    cleaned = " ".join("".join(kept).split()).strip(" .-")[:MAX_STEM_CHARS]
    while len((cleaned + extension).encode()) > MAX_NAME_BYTES:
        cleaned = cleaned[:-1]
    return (cleaned.strip(" .-") or "book") + extension


def upload_request(
    request_path: str, headers: Message, max_bytes: int
) -> tuple[str, int]:
    """Validate an upload's name and declared size before its body is read."""
    name = book_name(request_path)
    if headers.get("Transfer-Encoding"):
        raise IntakeError(
            HTTPStatus.LENGTH_REQUIRED,
            "send the book with a Content-Length; chunked uploads are not accepted",
        )
    declared = headers.get("Content-Length")
    if declared is None:
        raise IntakeError(HTTPStatus.LENGTH_REQUIRED, "Content-Length is required")
    try:
        length = int(declared)
    except ValueError:
        raise IntakeError(
            HTTPStatus.BAD_REQUEST, "Content-Length is not a number"
        ) from None
    if length <= 0:
        raise IntakeError(HTTPStatus.BAD_REQUEST, "the upload is empty")
    if length > max_bytes:
        raise IntakeError(
            HTTPStatus(413),
            f"books are limited to {max_bytes // MEBIBYTE} MiB",
        )
    return name, length


def check_content(path: Path, extension: str) -> None:
    """Refuse a file whose bytes are not the format its name claims."""
    if extension == ".pdf":
        with path.open("rb") as handle:
            head = handle.read(1024)
        if b"%PDF-" not in head:
            raise IntakeError(
                HTTPStatus.UNSUPPORTED_MEDIA_TYPE, "this .pdf file is not a PDF"
            )
        return
    try:
        with zipfile.ZipFile(path) as archive:
            names = set(archive.namelist())
    except Exception:  # noqa: BLE001 - any unreadable archive is not an EPUB
        raise IntakeError(
            HTTPStatus.UNSUPPORTED_MEDIA_TYPE,
            "this .epub file is not an EPUB (not a ZIP archive)",
        ) from None
    if "META-INF/container.xml" not in names:
        raise IntakeError(
            HTTPStatus.UNSUPPORTED_MEDIA_TYPE,
            "this .epub file is not an EPUB (no META-INF/container.xml)",
        )


# --- Bookshelf ------------------------------------------------------------


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(CHUNK_BYTES):
            digest.update(chunk)
    return digest.hexdigest()


def source_books(directory: Path) -> Iterator[Path]:
    """The files bookshelf-sync would read as books."""
    for root, _directories, files in os.walk(directory):
        for name in files:
            if name.startswith(("._", PART_PREFIX)):
                continue
            if Path(name).suffix.lower() in BOOK_EXTENSIONS:
                yield Path(root, name)


def find_identical(directory: Path, size: int, digest: str) -> Path | None:
    for candidate in source_books(directory):
        try:
            if candidate.stat().st_size == size and sha256_file(candidate) == digest:
                return candidate
        except FileNotFoundError:
            continue
    return None


def place(part: Path, directory: Path, name: str) -> Path:
    """Link the upload into the source directory without replacing anything."""
    stem, extension = Path(name).stem, Path(name).suffix
    number = 1
    while True:
        target = directory / (name if number == 1 else f"{stem}-{number}{extension}")
        try:
            os.link(part, target)
        except FileExistsError:
            number += 1
            continue
        return target


def find_published(library_dir: Path, size: int, digest: str) -> dict[str, Any] | None:
    """The catalog entry whose published file holds exactly these bytes."""
    try:
        catalog = json.loads((library_dir / "catalog.json").read_text())
    except (FileNotFoundError, ValueError):
        return None
    for book in catalog.get("books") or []:
        for book_format in book.get("formats") or []:
            if book_format.get("size") != size:
                continue
            try:
                if (
                    sha256_file(library_dir / book["id"] / book_format["file"])
                    == digest
                ):
                    return {
                        "id": book["id"],
                        "title": book.get("title"),
                        "authors": book.get("authors") or [],
                    }
            except (KeyError, OSError):
                continue
    return None


def publish(config: Config) -> subprocess.CompletedProcess[str]:
    with config.sync_lock.open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        return subprocess.run(
            [config.sync],
            cwd=config.sync_config_dir,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=config.sync_timeout,
            check=False,
        )


def tail(output: str, lines: int = 12) -> list[str]:
    return [line for line in output.splitlines() if line.strip()][-lines:]


def build_failure(output: str, file_name: str) -> str | None:
    """bookshelf-sync's own reason for skipping a file, if it printed one."""
    for line in output.splitlines():
        stripped = line.strip()
        if stripped.startswith("fail") and file_name in stripped:
            return stripped
    return None


# --- Calibre --------------------------------------------------------------


def calibre_add(config: Config, path: Path, name: str) -> dict[str, Any]:
    """Offer a book to the Calibre content server's add-book endpoint."""
    assert config.calibre_url is not None
    url = urllib.parse.urlsplit(config.calibre_url)
    segments = ["cdb", "add-book", secrets.token_hex(4), "n", name]
    if config.calibre_library_id:
        segments.append(config.calibre_library_id)
    target = (
        url.path.rstrip("/")
        + "/"
        + "/".join(urllib.parse.quote(part, safe="") for part in segments)
    )
    source = (
        (config.calibre_source_address, 0) if config.calibre_source_address else None
    )
    connection = http.client.HTTPConnection(
        url.hostname or "127.0.0.1",
        url.port or 80,
        timeout=config.calibre_timeout,
        source_address=source,
    )
    try:
        with path.open("rb") as body:
            connection.request(
                "POST",
                target,
                body=body,
                headers={
                    "Content-Type": "application/octet-stream",
                    "Content-Length": str(path.stat().st_size),
                },
            )
            response = connection.getresponse()
            payload = response.read()
    except OSError as error:
        return {"status": "failed", "error": f"cannot reach Calibre: {error}"}
    finally:
        connection.close()

    if response.status != HTTPStatus.OK:
        detail = payload.decode(errors="replace").strip()[:300]
        return {
            "status": "failed",
            "error": f"Calibre answered {response.status}: {detail}",
        }
    try:
        answer = json.loads(payload)
    except ValueError:
        return {
            "status": "failed",
            "error": "Calibre returned a response that is not JSON",
        }
    described = {"title": answer.get("title"), "authors": answer.get("authors") or []}
    if "book_id" in answer:
        return {"status": "added", "book_id": answer["book_id"], **described}
    return {
        "status": "already-present",
        "matches": answer.get("duplicates") or [],
        **described,
    }


# --- Intake ---------------------------------------------------------------


class Intake:
    def __init__(self, config: Config, whois: WhoIs) -> None:
        self.config = config
        self.whois = whois
        self.ingest_lock = threading.Lock()
        self.uploads = threading.BoundedSemaphore(CONCURRENT_UPLOADS)

    def remove_stale_parts(self) -> None:
        for leftover in self.config.source_dir.glob(f"{PART_PREFIX}*{PART_SUFFIX}"):
            leftover.unlink(missing_ok=True)

    def receive(self, stream: BinaryIO, length: int) -> tuple[Path, str]:
        """Write the body to a hidden partial file beside the source books."""
        descriptor, raw_path = tempfile.mkstemp(
            prefix=PART_PREFIX, suffix=PART_SUFFIX, dir=self.config.source_dir
        )
        part = Path(raw_path)
        digest = hashlib.sha256()
        remaining = length
        try:
            with os.fdopen(descriptor, "wb") as handle:
                while remaining:
                    chunk = stream.read(min(CHUNK_BYTES, remaining))
                    if not chunk:
                        raise IntakeError(
                            HTTPStatus.BAD_REQUEST,
                            "the upload ended before Content-Length bytes arrived",
                        )
                    handle.write(chunk)
                    digest.update(chunk)
                    remaining -= len(chunk)
        except BaseException:
            part.unlink(missing_ok=True)
            raise
        return part, digest.hexdigest()

    def add(
        self, part: Path, name: str, size: int, digest: str
    ) -> tuple[HTTPStatus, dict[str, Any]]:
        check_content(part, Path(name).suffix)
        with self.ingest_lock:
            bookshelf = self.add_to_bookshelf(part, name, size, digest)
            calibre = (
                calibre_add(self.config, part, name)
                if self.config.calibre_url
                else None
            )

        result: dict[str, Any] = {
            "file": name,
            "bytes": size,
            "sha256": digest,
            "bookshelf": bookshelf,
        }
        if calibre is not None:
            result["calibre"] = calibre
        outcomes = [
            target["status"] for target in (bookshelf, calibre) if target is not None
        ]
        if "failed" in outcomes:
            return HTTPStatus.BAD_GATEWAY, result
        if "added" in outcomes:
            return HTTPStatus.CREATED, result
        return HTTPStatus.OK, result

    def add_to_bookshelf(
        self, part: Path, name: str, size: int, digest: str
    ) -> dict[str, Any]:
        config = self.config
        existing = find_identical(config.source_dir, size, digest)
        if existing is not None:
            published = find_published(config.library_dir, size, digest)
            if published is not None:
                return {
                    "status": "already-present",
                    "source": existing.name,
                    **published,
                }
            placed = None
            source = existing
        else:
            placed = place(part, config.source_dir, name)
            source = placed

        try:
            run = publish(config)
        except subprocess.TimeoutExpired:
            return {
                "status": "failed",
                "source": source.name,
                "error": "publishing timed out",
            }

        published = find_published(config.library_dir, size, digest)
        if published is not None:
            return {"status": "added", "source": source.name, **published}
        if run.returncode != 0:
            # Leave the book in place; the next publish retries it.
            return {
                "status": "failed",
                "source": source.name,
                "error": f"bookshelf-sync exited with status {run.returncode}",
                "log": tail(run.stdout),
            }
        # bookshelf-sync skipped the book. Keep the source directory equal to
        # what is published rather than retrying an unreadable file forever.
        if placed is not None:
            placed.unlink(missing_ok=True)
        return {
            "status": "failed",
            "error": build_failure(run.stdout, source.name)
            or "Bookshelf could not read this book",
        }


# --- HTTP -----------------------------------------------------------------


PAGE = """<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Send books</title>
<style>
  :root { color-scheme: light dark; font-family: system-ui, sans-serif; line-height: 1.5; }
  body { max-width: 40rem; margin: 2rem auto; padding: 0 1rem; }
  label.drop { display: block; border: 2px dashed currentColor; border-radius: .75rem;
               padding: 2.5rem 1rem; text-align: center; cursor: pointer; }
  label.drop.over { border-style: solid; }
  input[type=file] { position: absolute; width: 1px; height: 1px; opacity: 0; }
  ol { padding-left: 1.25rem; }
  li { margin: .5rem 0; overflow-wrap: anywhere; }
  .added { color: #2e7d32; } .present { color: #8a6d00; } .failed { color: #c62828; }
  @media (prefers-color-scheme: dark) {
    .added { color: #81c784; } .present { color: #e0c060; } .failed { color: #ef9a9a; }
  }
</style>
<h1>Send books</h1>
<p>EPUB or PDF, up to @MAX_MIB@ MiB each. Every book goes to
<a href="@SITE_URL@">Bookshelf</a>@CALIBRE_CLAUSE@.</p>
<label class="drop" id="drop">Choose books, or drop them here
  <input type="file" id="files" multiple accept=".epub,.pdf,application/epub+zip,application/pdf">
</label>
<ol id="results" aria-live="polite"></ol>
<p>From a terminal: <code>curl -T book.epub @UPLOAD_URL@</code></p>
<script>
const maxBytes = @MAX_BYTES@;
const results = document.getElementById("results");
const input = document.getElementById("files");
const drop = document.getElementById("drop");
let queue = Promise.resolve();

function outcome(name, target) {
  if (!target) return null;
  if (target.status === "added") return name + " added";
  if (target.status === "already-present") return name + " already had it";
  return name + " failed: " + (target.error || target.status);
}

function describe(file, status, body) {
  if (body.error) return [file.name + ": " + body.error, "failed"];
  const title = (body.bookshelf && body.bookshelf.title) || (body.calibre && body.calibre.title) || file.name;
  const parts = [outcome("Bookshelf", body.bookshelf), outcome("Calibre", body.calibre)].filter(Boolean);
  const kind = status >= 400 ? "failed" : status === 201 ? "added" : "present";
  return [title + " \u2014 " + parts.join(", "), kind];
}

function send(file) {
  const item = document.createElement("li");
  results.append(item);
  const lower = file.name.toLowerCase();
  if (!lower.endsWith(".epub") && !lower.endsWith(".pdf")) {
    item.textContent = file.name + ": only .epub and .pdf files are accepted";
    item.className = "failed";
    return;
  }
  if (file.size > maxBytes) {
    item.textContent = file.name + ": larger than the " + Math.floor(maxBytes / 1048576) + " MiB limit";
    item.className = "failed";
    return;
  }
  item.textContent = file.name + ": waiting\u2026";
  queue = queue.then(async () => {
    item.textContent = file.name + ": sending\u2026";
    try {
      const response = await fetch("/" + encodeURIComponent(file.name), { method: "PUT", body: file });
      const body = await response.json().catch(() => ({ error: response.status + " " + response.statusText }));
      const [text, kind] = describe(file, response.status, body);
      item.textContent = text;
      item.className = kind;
    } catch (error) {
      item.textContent = file.name + ": " + error;
      item.className = "failed";
    }
  });
}

input.addEventListener("change", () => { for (const file of input.files) send(file); input.value = ""; });
for (const name of ["dragenter", "dragover"]) {
  drop.addEventListener(name, (event) => { event.preventDefault(); drop.classList.add("over"); });
}
for (const name of ["dragleave", "drop"]) {
  drop.addEventListener(name, (event) => { event.preventDefault(); drop.classList.remove("over"); });
}
drop.addEventListener("drop", (event) => { for (const file of event.dataTransfer.files) send(file); });
</script>
</html>
"""


def render_page(config: Config, port: int) -> str:
    upload_url = f"http://{config.bind}:{port}/"
    return (
        PAGE.replace("@MAX_MIB@", str(config.max_bytes // MEBIBYTE))
        .replace("@MAX_BYTES@", str(config.max_bytes))
        .replace("@SITE_URL@", html.escape(config.site_url, quote=True))
        .replace("@CALIBRE_CLAUSE@", " and Calibre" if config.calibre_url else "")
        .replace("@UPLOAD_URL@", html.escape(upload_url))
    )


class IntakeServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, intake: Intake) -> None:
        self.intake = intake
        if ":" in intake.config.bind:
            self.address_family = socket.AF_INET6
        super().__init__((intake.config.bind, intake.config.port), Handler)

    def server_bind(self) -> None:
        # Bind the Tailnet address even if tailscaled has not assigned it yet.
        if self.address_family == socket.AF_INET:
            self.socket.setsockopt(
                socket.IPPROTO_IP, getattr(socket, "IP_FREEBIND", 15), 1
            )
        # HTTPServer.server_bind would reverse-resolve the address; skip that.
        socketserver.TCPServer.server_bind(self)
        self.server_name = str(self.server_address[0])
        self.server_port = int(self.server_address[1])


class Handler(BaseHTTPRequestHandler):
    server: IntakeServer
    protocol_version = "HTTP/1.1"
    server_version = "bookshelf-intake"
    timeout = SOCKET_TIMEOUT_SECONDS

    def setup(self) -> None:
        super().setup()
        self.checked = False
        self.body_consumed = False
        self.refusal: IntakeError | None = None
        self.identity: Identity | None = None
        self.upload: tuple[str, int] | None = None

    def precheck(self) -> bool:
        """Authorize the request once; on refusal, answer it and return False."""
        if not self.checked:
            self.checked = True
            config = self.server.intake.config
            try:
                if not allowed_host(self.headers.get("Host"), config.bind):
                    raise IntakeError(
                        HTTPStatus.MISDIRECTED_REQUEST,
                        "this server only answers to its own address",
                    )
                origin = self.headers.get("Origin")
                if origin is not None and urllib.parse.urlsplit(
                    origin
                ).netloc != self.headers.get("Host"):
                    raise IntakeError(
                        HTTPStatus.FORBIDDEN,
                        "uploads from other sites are not accepted",
                    )
                server_address, server_port = self.server.server_address[:2]
                self.identity = authorize(
                    self.server.intake.whois,
                    (self.client_address[0], self.client_address[1]),
                    (str(server_address), int(server_port)),
                )
                if self.command == "PUT":
                    self.upload = upload_request(
                        self.path, self.headers, config.max_bytes
                    )
            except IntakeError as error:
                self.refusal = error
        if self.refusal is not None:
            self.send_json(self.refusal.status, {"error": self.refusal.message})
            return False
        return True

    def handle_expect_100(self) -> bool:
        # Refuse before the client sends a body it would only waste.
        return self.precheck() and super().handle_expect_100()

    def do_GET(self) -> None:  # noqa: N802 - http.server's naming
        if not self.precheck():
            return
        if urllib.parse.urlsplit(self.path).path != "/":
            self.send_json(
                HTTPStatus.NOT_FOUND, {"error": "not found; PUT a book to /<file name>"}
            )
            return
        page = render_page(self.server.intake.config, self.server.server_port)
        self.send_body(HTTPStatus.OK, "text/html; charset=utf-8", page.encode())

    def do_POST(self) -> None:  # noqa: N802 - http.server's naming
        # A cross-site form can POST without a CORS preflight; only PUT uploads.
        if not self.precheck():
            return
        self.send_json(
            HTTPStatus.METHOD_NOT_ALLOWED, {"error": "upload with PUT /<file name>"}
        )

    def do_PUT(self) -> None:  # noqa: N802 - http.server's naming
        if not self.precheck():
            return
        assert self.upload is not None
        assert self.identity is not None
        name, length = self.upload
        intake = self.server.intake
        if not intake.uploads.acquire(blocking=False):
            self.send_json(
                HTTPStatus.SERVICE_UNAVAILABLE,
                {"error": "too many uploads at once; try again shortly"},
            )
            return
        self.body_consumed = True
        try:
            part, digest = intake.receive(self.rfile, length)
            try:
                status, result = intake.add(part, name, length, digest)
            finally:
                part.unlink(missing_ok=True)
        except IntakeError as error:
            self.send_json(error.status, {"error": error.message})
            return
        except TimeoutError:
            self.send_json(HTTPStatus.REQUEST_TIMEOUT, {"error": "the upload stalled"})
            return
        except OSError as error:
            status = (
                HTTPStatus.INSUFFICIENT_STORAGE
                if error.errno == errno.ENOSPC
                else HTTPStatus.INTERNAL_SERVER_ERROR
            )
            self.send_json(
                status,
                {"error": f"could not store the book: {error.strerror or error}"},
            )
            return
        finally:
            intake.uploads.release()

        self.log_message(
            "%s from %s (%s): bookshelf %s, calibre %s",
            name,
            self.identity.node,
            self.identity.login,
            result["bookshelf"]["status"],
            result.get("calibre", {}).get("status", "not configured"),
        )
        self.send_json(status, result)

    def send_json(self, status: HTTPStatus, payload: Mapping[str, Any]) -> None:
        body = (json.dumps(payload, indent=2, ensure_ascii=False) + "\n").encode()
        self.send_body(status, "application/json; charset=utf-8", body)

    def send_body(self, status: HTTPStatus, content_type: str, body: bytes) -> None:
        # Bodies of refused uploads are never read, so never reuse the connection.
        self.close_connection = True
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Security-Policy", "frame-ancestors 'none'")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)
        if self.command in ("PUT", "POST") and not self.body_consumed:
            self.linger()

    def linger(self) -> None:
        """Let the client read a refusal before the connection closes.

        Closing a socket that still holds unread request bytes sends a reset,
        which can destroy the answer before the client reads it. So stop
        writing, then discard whatever still arrives, within bounds.
        """
        self.body_consumed = True
        try:
            self.connection.shutdown(socket.SHUT_WR)
            self.connection.settimeout(LINGER_SECONDS)
            discarded = 0
            while discarded < DRAIN_LIMIT_BYTES:
                chunk = self.connection.recv(CHUNK_BYTES)
                if not chunk:
                    return
                discarded += len(chunk)
        except OSError:
            return


def main() -> int:
    config = Config.from_env(os.environ)
    intake = Intake(config, tailscale_whois(config.tailscale_socket))
    intake.remove_stale_parts()
    server = IntakeServer(intake)
    print(
        f"bookshelf-intake listening on http://{config.bind}:{server.server_port}/",
        flush=True,
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
