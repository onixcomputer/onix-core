#!/usr/bin/env python3
"""A single OpenCode repair session, not a benchmark or adversarial harness."""

import argparse
import hashlib
import json
import os
import re
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import urlsplit

LEMMA = "count_matching_all_from"
MODEL = "nemotron-3.5-super-vl"
MAX_SECONDS = 1800
VERIFIER_SECONDS = 120


def require(condition: object, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n")


def tokens(text: str) -> list[str]:
    """Lex the restricted repair language; nested Rust comments are supported."""
    result = []
    i = 0
    while i < len(text):
        if text[i].isspace():
            i += 1
        elif text.startswith("//", i):
            end = text.find("\n", i)
            i = len(text) if end < 0 else end
        elif text.startswith("/*", i):
            depth = 1
            i += 2
            while depth and i < len(text):
                if text.startswith("/*", i):
                    depth += 1
                    i += 2
                elif text.startswith("*/", i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
            require(depth == 0, "Unterminated proof comment")
        else:
            match = re.match(r"[A-Za-z_][A-Za-z_0-9]*|[0-9]+|::|[^\s]", text[i:])
            token = match.group()
            result.append(token)
            i += len(token)
    return result


def split_proof(source: str) -> tuple[str, str, str]:
    # The selected corpus proof has no strings or braces in its signature.
    match = re.search(r"(?m)^proof fn " + LEMMA + r"\(", source)
    require(match is not None, f"Missing selected Trellis lemma: {LEMMA}")
    opening = source.index("{", match.end())
    depth = 1
    i = opening + 1
    while depth and i < len(source):
        if source.startswith("//", i):
            end = source.find("\n", i)
            i = len(source) if end < 0 else end
            continue
        if source[i] == "{":
            depth += 1
        elif source[i] == "}":
            depth -= 1
        i += 1
    require(depth == 0, "Unbalanced selected Trellis proof")
    return source[: opening + 1], source[opening + 1 : i - 1], source[i - 1 :]


def checked_candidate(original: str, candidate: str) -> str:
    prefix, _, suffix = split_proof(original)
    require(
        candidate.startswith(prefix) and candidate.endswith(suffix),
        "Frozen scaffold changed: only the selected proof body may change",
    )
    body = candidate[len(prefix) : len(candidate) - len(suffix)]
    ts = tokens(body)
    require(ts, "Empty proof body")
    # This is deliberately a small proof-language policy, not Reasonable's harness.
    # No attributes, macros, paths, declarations, strings or indirect calls.
    banned = {
        "assume",
        "admit",
        "axiom",
        "unsafe",
        "external_body",
        "external",
        "verifier",
        "trusted",
        "fn",
        "use",
        "mod",
        "extern",
        "exec",
        "spec",
        "const",
        "static",
        "trait",
        "impl",
        "struct",
        "enum",
        "type",
        "macro_rules",
        "include",
        "include_str",
        "include_bytes",
    }
    require(not banned.intersection(ts), "Disallowed trust escape or declaration")
    require(
        not {"#", "::", '"', "'", "\\", "`"}.intersection(ts),
        "Attributes, paths, strings and escaped identifiers are not allowed",
    )
    calls = {
        "assert",
        "reveal",
        "reveal_with_fuel",
        "count_matching_from_spec",
        "count_matching_spec",
        LEMMA,
        "p",
        "len",
    }
    stack = []
    pairs = {"}": "{", ")": "(", "]": "["}
    for i, token in enumerate(ts):
        if token in ("{", "(", "["):
            stack.append(token)
        elif token in pairs:
            require(
                stack and stack.pop() == pairs[token], "Unbalanced proof delimiters"
            )
        if re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", token):
            require(
                not (i + 1 < len(ts) and ts[i + 1] == "!"), "Macros are not allowed"
            )
            if i + 1 < len(ts) and ts[i + 1] == "(":
                require(
                    token in calls or token in {"if", "while", "match"},
                    f"Call outside the proof allowlist: {token}",
                )
        require(
            not (token == "(" and i and ts[i - 1] in (")", "]", "}")),
            "Indirect calls are not allowed",
        )
    require(not stack, "Unbalanced proof delimiters")
    return body


def run_logged(
    command: list[str],
    log: Path,
    *,
    cwd: Path,
    env: dict[str, str] | None = None,
    seconds: int = VERIFIER_SECONDS,
) -> int:
    with log.open("wb") as stream:
        process = subprocess.Popen(
            command,
            cwd=cwd,
            env=env,
            stdout=stream,
            stderr=subprocess.STDOUT,
            start_new_session=True,
            stdin=subprocess.DEVNULL,
        )
        try:
            return process.wait(timeout=seconds)
        except BaseException:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
            raise


def verify_command(trellis: Path, root: Path, candidate: Path) -> list[str]:
    return ["bash", str(trellis / "scripts/verus.sh"), str(candidate)]


def verify(trellis: Path, root: Path, candidate: Path, log: Path) -> bool:
    env = os.environ.copy()
    env["VERUS_ROOT"] = str(root)
    # The package supplies its own exact Rust runtime, not the caller's toolchain.
    env.pop("RUST_TOOLCHAIN", None)
    status = run_logged(
        verify_command(trellis, root, candidate), log, cwd=trellis, env=env
    )
    text = log.read_text(errors="replace")
    summary = re.search(r"verification results::\s*(\d+) verified,\s*0 errors", text)
    return status == 0 and summary is not None and int(summary[1]) > 0


def verifier_tool(args: list[str]) -> int:
    original, candidate, trellis, root = map(Path, args)
    checked_candidate(original.read_text(), candidate.read_text())
    env = os.environ.copy()
    env["VERUS_ROOT"] = str(root)
    env.pop("RUST_TOOLCHAIN", None)
    # The shell permission permits exactly this no-argument wrapper, not arbitrary flags.
    completed = subprocess.run(
        verify_command(trellis, root, candidate),
        cwd=trellis,
        env=env,
        timeout=VERIFIER_SECONDS,
    )
    return completed.returncode


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--trellis",
        type=Path,
        default=Path(__file__).resolve().parents[3] / "OnixResearch/trellis",
    )
    parser.add_argument("--endpoint", default="http://127.0.0.1:18000/v1")
    parser.add_argument(
        "--output",
        type=Path,
        help="New or empty artifact directory; default: a temporary directory",
    )
    args = parser.parse_args()
    trellis = args.trellis.resolve()
    require(
        (trellis / "scripts/verus.sh").is_file(), "Missing Trellis scripts/verus.sh"
    )
    require(
        (trellis / "flake.lock").is_file(), "Missing Trellis production toolchain lock"
    )
    endpoint = urlsplit(args.endpoint)
    require(
        endpoint.scheme == "http"
        and endpoint.hostname in {"localhost", "127.0.0.1", "::1"}
        and endpoint.path.rstrip("/") == "/v1"
        and not endpoint.username
        and not endpoint.password
        and not endpoint.query
        and not endpoint.fragment,
        "Endpoint must be a credential-free loopback HTTP /v1 URL (use an SSH tunnel)",
    )
    for executable in ("nix", "opencode", "git", "bash"):
        require(
            shutil.which(executable), f"Required executable not found: {executable}"
        )
    out = (
        args.output.resolve()
        if args.output
        else Path(tempfile.mkdtemp(prefix="nemotron-verus-"))
    )
    require(not out.is_relative_to(trellis), "Output must not be inside Trellis")
    if out.exists():
        require(
            out.is_dir() and not any(out.iterdir()),
            "Output must be a new or empty directory",
        )
    out.mkdir(parents=True, exist_ok=True)
    print(f"Artifacts: {out}", flush=True)
    result = {
        "verified": False,
        "lemma": LEMMA,
        "source": str(trellis / "src/seq_fold.rs"),
    }
    try:
        work = out / "work"
        work.mkdir()
        state = out / "state"
        state.mkdir()
        # OpenCode matches file permissions relative to the Git worktree, or /
        # outside Git. Give this isolated task its own root for exact allowlists.
        initialized = subprocess.run(
            ["git", "init", "--quiet", str(work)], capture_output=True, text=True
        )
        require(
            initialized.returncode == 0,
            f"Worktree initialization failed: {initialized.stderr}",
        )
        source = (trellis / "src/seq_fold.rs").read_text()
        prefix, body, suffix = split_proof(source)
        require(tokens(body), "Original selected proof body is empty")
        original = out / "original.rs"
        original.write_text(source)
        candidate = work / "proof.rs"
        unsolved = (
            prefix
            + "\n    // Repair only this body. Prove the unchanged postcondition.\n"
            + suffix
        )
        candidate.write_text(unsolved)
        (out / "unsolved.rs").write_text(unsolved)
        result["source_sha256"] = hashlib.sha256(source.encode()).hexdigest()
        result["trellis_lock_sha256"] = hashlib.sha256(
            (trellis / "flake.lock").read_bytes()
        ).hexdigest()
        # Resolve the existing Trellis package, never another Verus derivation.
        built = subprocess.run(
            [
                "nix",
                "build",
                ".#verus",
                "--no-link",
                "--print-out-paths",
                "--no-write-lock-file",
            ],
            cwd=trellis,
            text=True,
            capture_output=True,
        )
        (out / "nix.log").write_text(built.stderr)
        require(built.returncode == 0, "Trellis .#verus build failed; inspect nix.log")
        roots = built.stdout.splitlines()
        require(
            len(roots) == 1 and Path(roots[0]).is_dir(),
            "Unexpected Verus package output",
        )
        root = Path(roots[0])
        result["verus_root"] = str(root)
        require(
            verify(trellis, root, original, out / "original-verifier.log"),
            "Unmodified corpus proof failed; inspect original-verifier.log",
        )
        require(
            not verify(trellis, root, candidate, out / "unsolved-verifier.log"),
            "Removed proof body still verifies; refusing an already-solved task",
        )
        require(
            "postcondition not satisfied"
            in (out / "unsolved-verifier.log").read_text(),
            "Unsolved task did not fail its postcondition; inspect unsolved-verifier.log",
        )
        tool = work / "verify"
        tool.write_text(
            "#!/usr/bin/env bash\nset -euo pipefail\nexec "
            + shlex.join(
                [
                    sys.executable,
                    str(Path(__file__).resolve()),
                    "--verify",
                    str(original),
                    str(candidate),
                    str(trellis),
                    str(root),
                ]
            )
            + "\n"
        )
        tool.chmod(0o500)
        permission = {
            "*": "deny",
            "read": {"*": "deny", "proof.rs": "allow"},
            "edit": {"*": "deny", "proof.rs": "allow"},
            "bash": {"*": "deny", "./verify": "allow", "bash ./verify": "allow"},
            "external_directory": "deny",
        }
        system = (
            f"Repair only the body of {LEMMA} in proof.rs. "
            "The entire remaining file is frozen. Use read/edit tools and bash ./verify; "
            "no other command is permitted. Do not copy a reference solution. "
            "Use ordinary Verus proof statements, recursive induction and existing helpers. "
            "No assumptions, admissions, attributes, macros, imports, strings, qualified paths, "
            "new declarations or indirect calls. Allowed calls: assert, reveal, reveal_with_fuel, "
            f"count_matching_from_spec, count_matching_spec, {LEMMA}, "
            "the supplied spec predicate p, and sequence method len. "
            "Run ./verify and repair verifier errors before finishing."
        )
        config = {
            "$schema": "https://opencode.ai/config.json",
            "share": "disabled",
            "autoupdate": False,
            "snapshot": False,
            "plugin": [],
            "mcp": {},
            "lsp": False,
            "formatter": False,
            "instructions": [],
            "enabled_providers": ["nemotron"],
            "model": f"nemotron/{MODEL}",
            "small_model": f"nemotron/{MODEL}",
            "default_agent": "proof",
            "permission": permission,
            "compaction": {"auto": False},
            "provider": {
                "nemotron": {
                    "npm": "@ai-sdk/openai-compatible",
                    "env": [],
                    "name": "Local Nemotron",
                    "options": {
                        "baseURL": args.endpoint.rstrip("/"),
                        "timeout": 300000,
                    },
                    "models": {
                        MODEL: {
                            "name": MODEL,
                            "reasoning": True,
                            "interleaved": {"field": "reasoning_content"},
                            "temperature": True,
                            "tool_call": True,
                            "modalities": {"input": ["text"], "output": ["text"]},
                            "limit": {"context": 65536, "output": 8192},
                            "options": {
                                "chat_template_kwargs": {"enable_thinking": True}
                            },
                        }
                    },
                }
            },
            "agent": {
                "proof": {
                    "mode": "primary",
                    "prompt": system,
                    "temperature": 1.0,
                    "top_p": 0.95,
                    "steps": 24,
                    "permission": permission,
                }
            },
        }
        config_path = out / "opencode.json"
        write_json(config_path, config)
        env = {
            "PATH": os.environ["PATH"],
            "HOME": str(state),
            "XDG_CONFIG_HOME": str(state / "config"),
            "XDG_DATA_HOME": str(state / "data"),
            "XDG_CACHE_HOME": str(state / "cache"),
            "XDG_STATE_HOME": str(state / "state"),
            "OPENCODE_CONFIG": str(config_path),
            "OPENCODE_DISABLE_AUTOUPDATE": "true",
            "OPENCODE_DISABLE_PROJECT_CONFIG": "true",
            "OPENCODE_DISABLE_DEFAULT_PLUGINS": "true",
            "OPENCODE_DISABLE_MODELS_FETCH": "true",
            "OPENCODE_DISABLE_CLAUDE_CODE": "true",
            "OPENCODE_DISABLE_LSP_DOWNLOAD": "true",
            "OPENCODE_DISABLE_AUTOCOMPACT": "true",
            "OPENCODE_DISABLE_PRUNE": "true",
            "OPENCODE_EXPERIMENTAL_DISABLE_FILEWATCHER": "true",
            "OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX": "8192",
            "DO_NOT_TRACK": "1",
            "OTEL_SDK_DISABLED": "true",
            "LANG": "C.UTF-8",
            "NO_COLOR": "1",
        }
        prompt = (
            "Read proof.rs and repair its missing sequence-fold induction proof: "
            "when every remaining element satisfies p, the count equals the suffix length. "
            "Preserve all frozen code; run ./verify to check. "
            "The final response must summarize the actual verification result."
        )
        (out / "prompt.txt").write_text(prompt + "\n")
        command = [
            shutil.which("opencode"),
            "run",
            "--pure",
            "--dir",
            str(work),
            "--model",
            f"nemotron/{MODEL}",
            "--agent",
            "proof",
            "--format",
            "json",
            prompt,
        ]
        write_json(out / "invocation.json", {"argv": command, "seconds": MAX_SECONDS})
        status = run_logged(
            command, out / "transcript.jsonl", cwd=work, env=env, seconds=MAX_SECONDS
        )
        result["opencode_status"] = status
        require(status == 0, "OpenCode repair failed; inspect transcript.jsonl")
        require(
            (out / "transcript.jsonl").stat().st_size > 0,
            "OpenCode produced no transcript",
        )
        require(
            candidate.is_file() and not candidate.is_symlink(),
            "Missing or symlinked candidate",
        )
        repaired = candidate.read_text()
        require(repaired != unsolved, "OpenCode did not change the missing proof")
        checked_candidate(source, repaired)
        require(
            verify(trellis, root, candidate, out / "final-verifier.log"),
            "Independent final verification failed; inspect final-verifier.log",
        )
        result["candidate_sha256"] = hashlib.sha256(candidate.read_bytes()).hexdigest()
        result["verified"] = True
        print("Verified repaired sequence-fold induction proof; see final-verifier.log")
        return 0
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        result["error"] = str(error)
        print(f"Proof loop failed: {error}", file=sys.stderr)
        return 1
    finally:
        write_json(out / "result.json", result)


if __name__ == "__main__":
    try:
        if len(sys.argv) > 1 and sys.argv[1] == "--verify":
            require(len(sys.argv) == 6, "Verifier wrapper accepts no extra arguments")
            sys.exit(verifier_tool(sys.argv[2:]))
        sys.exit(main())
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"Proof loop failed: {error}", file=sys.stderr)
        sys.exit(1)
