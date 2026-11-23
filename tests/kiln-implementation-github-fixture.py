#!/usr/bin/env python3
"""Loopback-only stateful GitHub publication fixture for a disposable VM."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import socket
import subprocess
import threading
from urllib.parse import parse_qs, unquote, urlsplit

FIXTURE_TOKEN = "scripted-publisher-only"
MAX_BODY_BYTES = 64 * 1024


def read_plan(path):
    document = json.loads(Path(path).read_text())
    plan = document.get("plan", document)
    if not isinstance(plan, dict):
        raise ValueError("publication plan is not an object")
    candidate = plan.get("candidate")
    if not isinstance(candidate, dict):
        raise ValueError("publication plan has no exact candidate ref")
    values = {
        "repository": plan.get("repository"),
        "branch": plan.get("branch"),
        "base_branch": plan.get("base_branch"),
        "base": plan.get("base", {}).get("native_id"),
        "candidate": candidate.get("native_id"),
    }
    if any(not isinstance(value, str) or not value for value in values.values()):
        raise ValueError("publication plan lacks exact repository/branch/base/candidate")
    if len(values["repository"].split("/")) != 2:
        raise ValueError("publication plan repository identity is malformed")
    return values


class Fixture:
    def __init__(self, plan, state_dir, drop_pr_response_once, bare_repository):
        self.plan = plan
        self.bare_repository = Path(bare_repository).resolve(strict=True)
        self.git = ["git", "-c", "safe.directory=" + str(self.bare_repository), "-C", str(self.bare_repository)]
        if subprocess.check_output(self.git + ["rev-parse", "--is-bare-repository"], text=True).strip() != "true":
            raise ValueError("publication fixture requires an actual bare repository")
        self.state_dir = Path(state_dir)
        self.state_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
        self.state_file = self.state_dir / "state.json"
        self.events_file = self.state_dir / "events.jsonl"
        self.lock = threading.Lock()
        self.branch_sha = None
        self.pull = None
        self.drop_pr_response_once = drop_pr_response_once
        self.dropped_pr_response = False
        if self.state_file.exists():
            saved = json.loads(self.state_file.read_text())
            if any(saved.get(key) != plan[key] for key in ("repository", "branch", "base_branch", "base", "candidate")):
                raise ValueError("retained PR fixture belongs to another publication plan")
            self.pull = saved["pull_request"]
            self.dropped_pr_response = saved["dropped_pr_response"]
        self.refresh_branch()
        self._persist()

    def _persist(self):
        document = {
            "schema": "onix.kiln.scripted-github-fixture-state.v1",
            "repository": self.plan["repository"],
            "branch": self.plan["branch"],
            "base_branch": self.plan["base_branch"],
            "base": self.plan["base"],
            "candidate": self.plan["candidate"],
            "branch_sha": self.branch_sha,
            "pull_request": self.pull,
            "dropped_pr_response": self.dropped_pr_response,
        }
        temporary = self.state_file.with_suffix(".tmp")
        with temporary.open("w") as output:
            json.dump(document, output, sort_keys=True)
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, self.state_file)

    def refresh_branch(self):
        base = subprocess.check_output(self.git + ["rev-parse", "--verify", "refs/heads/" + self.plan["base_branch"]], text=True, timeout=10).strip()
        if base != self.plan["base"]:
            raise ValueError("actual publication target moved from the admitted base")
        ref = "refs/heads/" + self.plan["branch"]
        result = subprocess.run(self.git + ["rev-parse", "--verify", "--quiet", ref], capture_output=True, text=True, timeout=10)
        if result.returncode == 1:
            self.branch_sha = None
            return
        if result.returncode:
            raise ValueError("bare publication reference cannot be observed")
        self.branch_sha = result.stdout.strip()
        subprocess.run(self.git + ["cat-file", "-e", self.branch_sha + "^{commit}"], check=True, capture_output=True, timeout=10)
        if self.branch_sha != self.plan["candidate"]:
            raise ValueError("actual pushed branch differs from the exact candidate")
        self._persist()

    def record(self, method, path, status, body=None):
        event = {"method": method, "path": path, "status": status, "body": body}
        with self.events_file.open("a") as output:
            output.write(json.dumps(event, sort_keys=True) + "\n")
            output.flush()
            os.fsync(output.fileno())

    def handler(self):
        fixture = self

        class Handler(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"

            def log_message(self, *_args):
                return

            def _respond(self, status, body):
                payload = json.dumps(body, separators=(",", ":")).encode()
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(payload)))
                self.send_header("Connection", "close")
                self.end_headers()
                self.wfile.write(payload)
                self.close_connection = True

            def _authorized(self):
                return self.headers.get("Authorization") == f"Bearer {FIXTURE_TOKEN}"

            def _body(self):
                raw_length = self.headers.get("Content-Length")
                if raw_length is None:
                    raise ValueError("missing Content-Length")
                length = int(raw_length)
                if length < 0 or length > MAX_BODY_BYTES:
                    raise ValueError("request body exceeds fixture bound")
                value = json.loads(self.rfile.read(length))
                if not isinstance(value, dict):
                    raise ValueError("request body must be an object")
                return value

            def _repo_path(self, suffix):
                return f"/repos/{fixture.plan['repository']}/{suffix}"


            def do_GET(self):
                parsed = urlsplit(self.path)
                decoded_path = unquote(parsed.path)
                with fixture.lock:
                    if not self._authorized():
                        fixture.record("GET", self.path, 401)
                        self._respond(401, {"message": "fixture token rejected"})
                        return
                    try:
                        fixture.refresh_branch()
                    except (ValueError, subprocess.SubprocessError):
                        fixture.record("GET", self.path, 409)
                        self._respond(409, {"message": "actual Git object/ref conflicts with publication"})
                        return
                    branch_path = self._repo_path(
                        f"git/ref/heads/{fixture.plan['branch']}"
                    )
                    pull_path = self._repo_path("pulls")
                    if decoded_path == branch_path:
                        if fixture.branch_sha is None:
                            fixture.record("GET", self.path, 404)
                            self._respond(404, {"message": "Not Found"})
                        else:
                            fixture.record("GET", self.path, 200)
                            self._respond(200, {"object": {"sha": fixture.branch_sha}})
                        return
                    if decoded_path == pull_path:
                        query = parse_qs(parsed.query)
                        expected_head = f"{fixture.plan['repository'].split('/')[0]}:{fixture.plan['branch']}"
                        if (
                            query.get("state") != ["all"]
                            or query.get("head") != [expected_head]
                            or query.get("base") != [fixture.plan["base_branch"]]
                            or query.get("per_page") != ["100"]
                        ):
                            fixture.record("GET", self.path, 422)
                            self._respond(422, {"message": "fixture pull query is not exact"})
                            return
                        pulls = [] if fixture.pull is None else [fixture.pull]
                        fixture.record("GET", self.path, 200)
                        self._respond(200, pulls)
                        return
                    fixture.record("GET", self.path, 404)
                    self._respond(404, {"message": "fixture route not found"})

            def do_POST(self):
                with fixture.lock:
                    if not self._authorized():
                        fixture.record("POST", self.path, 401)
                        self._respond(401, {"message": "fixture token rejected"})
                        return
                    try:
                        body = self._body()
                    except (ValueError, json.JSONDecodeError):
                        fixture.record("POST", self.path, 400)
                        self._respond(400, {"message": "invalid fixture request"})
                        return
                    branch_path = self._repo_path("git/refs")
                    pull_path = self._repo_path("pulls")
                    decoded_path = unquote(urlsplit(self.path).path)
                    if decoded_path == branch_path:
                        fixture.record("POST", self.path, 405, body)
                        self._respond(405, {"message": "branch objects must arrive through guarded native Git push"})
                        return
                    if decoded_path == pull_path:
                        try:
                            fixture.refresh_branch()
                        except (ValueError, subprocess.SubprocessError):
                            fixture.record("POST", self.path, 409, body)
                            self._respond(409, {"message": "actual Git object/ref conflicts with publication"})
                            return
                        expected = {
                            "head": fixture.plan["branch"],
                            "base": fixture.plan["base_branch"],
                        }
                        if (
                            body.get("head") != expected["head"]
                            or body.get("base") != expected["base"]
                            or fixture.branch_sha != fixture.plan["candidate"]
                            or fixture.pull is not None
                        ):
                            fixture.record("POST", self.path, 422, body)
                            self._respond(422, {"message": "pull request does not match exact plan"})
                            return
                        number = 1
                        owner, repository = fixture.plan["repository"].split("/", 1)
                        fixture.pull = {
                            "number": number,
                            "state": "open",
                            "merged": False,
                            "html_url": f"https://github.com/{owner}/{repository}/pull/{number}",
                            "head": {
                                "ref": fixture.plan["branch"],
                                "sha": fixture.plan["candidate"],
                                "user": {"login": owner},
                            },
                            "base": {"ref": fixture.plan["base_branch"]},
                        }
                        fixture._persist()
                        fixture.record("POST", self.path, 201, body)
                        if fixture.drop_pr_response_once and not fixture.dropped_pr_response:
                            fixture.dropped_pr_response = True
                            fixture._persist()
                            self.close_connection = True
                            try:
                                self.connection.shutdown(socket.SHUT_RDWR)
                            except OSError:
                                pass
                            self.connection.close()
                            return
                        self._respond(201, fixture.pull)
                        return
                    fixture.record("POST", self.path, 404, body)
                    self._respond(404, {"message": "fixture route not found"})

        return Handler


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--publication-plan", required=True)
    parser.add_argument("--state-dir", required=True)
    parser.add_argument("--bare-repository", required=True)
    parser.add_argument("--port", required=True, type=int)
    parser.add_argument("--drop-pr-response-once", action="store_true")
    args = parser.parse_args()
    if args.port < 1 or args.port > 65535:
        raise SystemExit("fixture port must be nonzero and within range")
    fixture = Fixture(read_plan(args.publication_plan), args.state_dir, args.drop_pr_response_once, args.bare_repository)
    server = ThreadingHTTPServer(("127.0.0.1", args.port), fixture.handler())
    server.daemon_threads = True
    try:
        server.serve_forever(poll_interval=0.1)
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
