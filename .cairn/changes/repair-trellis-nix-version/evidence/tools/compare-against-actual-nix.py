#!/usr/bin/env python3
"""Bounded differential acceptance against native libnix and the Nix evaluator.

No Python version-order implementation is used. Exit 0 requires complete,
nonempty output and exact agreement. This is a campaign-local throwaway harness.
"""

import argparse
import hashlib
import itertools
import json
import os
from pathlib import Path
import platform
import random
import re
import shlex
import shutil
import signal
import subprocess
import sys
import time
from collections import Counter

SEED = 0x4E4958323336
BATCH_SIZE = 256
PROCESS_SECONDS = 10
TOTAL_SECONDS = 180
EVAL_EXPRESSION_BYTES = 24000


def identity(path):
    path = Path(path)
    resolved = path.resolve(strict=True)
    digest = hashlib.sha256()
    with resolved.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    stat = resolved.stat()
    return {"requested_path": str(path), "resolved_path": str(resolved),
            "bytes": stat.st_size, "sha256": digest.hexdigest()}


def corpus():
    cases = []
    seen = set()

    def add(tag, left, right, reverse=False):
        for a, b in ((left, right), (right, left)) if reverse else ((left, right),):
            if (a, b) not in seen:
                seen.add((a, b))
                cases.append({"category": tag, "left_hex": a.hex(), "right_hex": b.hex()})

    special = [
        (b"1.0pre", b"1.0"), (b"pre", b""), (b"pre!", b""),
        (b"pre!", b"pre"), (b"1.0pre!", b"1.0"), (b"", b"_"),
        (b"_", b"_"), (b"1_2", b"1.2"), (b"1+2", b"1.2"),
        (b"1 2", b"1.2"), (b"1\t2", b"1.2"), (b"1\n2", b"1.2"),
        (b"1\x002", b"1"), (b"\x00a", b"\x00b"), (b"a\x00b", b"a\x00c"),
        (b"2147483647", b"2147483646"), (b"2147483648", b"3"),
        (b"2147483647", b"2147483648"), (b"9999999999", b"10000000000"),
        (b"18446744073709551616", b"18446744073709551617"),
        (b"02147483648", b"2147483648"), (b"0002147483647", b"2147483647"),
        (b"00000000000000000000000001", b"1"),
        (b"${x}", b"${y}"), (b'"\\\r\n', b'"\\\r\t'),
        (b"a/b:c@d", b"a/b:c@e"), (b"\x7f", b"\x80"), (b"\xfe", b"\xff"),
    ]
    for left, right in special:
        add("discriminating-boundary", left, right, True)

    components = [b"", b"pre", b"pre!", b"a", b"!", b"_", b"0", b"00", b"2", b"10",
                  b"2147483647", b"2147483648"]
    for left, right in itertools.product(components, repeat=2):
        for prefix, suffix in [(b"", b""), (b"1.", b""), (b"2-", b".3")]:
            add("exhaustive-component-cross-product", prefix + left + suffix, prefix + right + suffix)

    vectors = [()]
    for length in (1, 2):
        vectors.extend(itertools.product([b"0", b"pre", b"!", b"a"], repeat=length))
    for left, right in itertools.product(vectors, repeat=2):
        for sep in (b".", b"-"):
            add("exhaustive-short-component-vectors", sep.join(left), sep.join(right))

    separators = [b"", b".", b"-", b"..", b"--", b".-.-", b"---...---"]
    for left, right in itertools.product(separators, repeat=2):
        for tail in (b"", b"pre", b"pre!", b"0"):
            add("separator-runs", b"1" + left + tail, b"1" + right + tail)
    for byte in range(256):
        value = bytes([byte])
        for anchor in (b"", b"_", b"0", b"pre"):
            add("all-byte-probes", value, anchor, True)
        add("all-byte-token-boundaries", b"1" + value + b"2", b"1.2", True)
        add("all-byte-reflexivity", value, value)

    for size in (32, 256, 4096, 16384):
        zeros = b"0" * size
        for tail in (b"0", b"1", b"2147483647", b"2147483648"):
            add("arbitrary-leading-zero-runs", zeros + tail, tail, True)
        add("long-text-component", b"a" * size + b"!", b"a" * size + b"_", True)
        add("long-overflow-component", b"9" * size, b"1" + b"0" * size, True)
    for count in (32, 256, 2048):
        base = b"1." * count
        add("many-components", base + b"pre", base, True)
        add("many-components", base + b"pre!", base, True)
        add("many-components", base + b"1", base + b"2", True)

    rng = random.Random(SEED)
    for index in range(1000):
        a = bytes(rng.randrange(256) for _ in range(rng.randrange(65)))
        b = bytes(rng.randrange(256) for _ in range(rng.randrange(65)))
        add("seeded-byte-vectors", a, b)
    alphabet = b"0123456789prePREab_.-!+ /:\t\n\r\x00${}\\\""
    for index in range(750):
        a = bytes(rng.choice(alphabet) for _ in range(rng.randrange(65)))
        b = bytes(rng.choice(alphabet) for _ in range(rng.randrange(65)))
        add("seeded-ascii-vectors", a, b)
    unicode_tokens = ["0", "1", "pre", "pre!", ".", "-", "_", "\t", "\n", "é", "λ", "中", "😀", "\u0080", "${x}", "\\", '"']
    for index in range(256):
        a = "".join(rng.choice(unicode_tokens) for _ in range(rng.randrange(12))).encode("utf-8")
        b = "".join(rng.choice(unicode_tokens) for _ in range(rng.randrange(12))).encode("utf-8")
        add("seeded-valid-utf8-vectors", a, b)
    return cases


class Runner:
    def __init__(self, report):
        self.report = report
        self.deadline = time.monotonic() + TOTAL_SECONDS
        self.environment = dict(os.environ, LC_ALL="C", LANG="C")

    def run(self, argv, stdin=b"", purpose=""):
        remaining = self.deadline - time.monotonic()
        if remaining <= 0:
            raise RuntimeError("total campaign process deadline exceeded")
        timeout = min(PROCESS_SECONDS, remaining)
        record = {"purpose": purpose, "argv": list(argv), "shell_display": shlex.join(argv),
                  "environment_overrides": {"LC_ALL": "C", "LANG": "C"},
                  "stdin_bytes": len(stdin), "stdin_sha256": hashlib.sha256(stdin).hexdigest(),
                  "timeout_seconds": timeout}
        self.report["commands"].append(record)
        started = time.monotonic()
        with subprocess.Popen(argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, env=self.environment, start_new_session=True) as process:
            try:
                stdout, stderr = process.communicate(stdin, timeout=timeout)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                stdout, stderr = process.communicate()
                record.update(timed_out=True, returncode=process.returncode,
                              stdout=stdout.decode("utf-8", "backslashreplace"),
                              stderr=stderr.decode("utf-8", "backslashreplace"))
                raise RuntimeError(f"process timeout: {purpose}")
            finally:
                record["elapsed_seconds"] = round(time.monotonic() - started, 6)
        record.update(returncode=process.returncode, stdout=stdout.decode("utf-8", "backslashreplace"),
                      stderr=stderr.decode("utf-8", "backslashreplace"))
        if process.returncode != 0:
            raise RuntimeError(f"nonzero process exit ({process.returncode}): {purpose}")
        return stdout


def driver_results(runner, executable, pairs, purpose):
    payload = b"".join((p["left_hex"] + " " + p["right_hex"] + "\n").encode("ascii") for p in pairs)
    stdout = runner.run([executable], payload, purpose)
    rows = stdout.splitlines()
    if len(rows) != len(pairs) or not rows or any(row not in (b"-1", b"0", b"1") for row in rows):
        raise RuntimeError(f"invalid/missing driver output: {purpose}; expected {len(pairs)}, received {len(rows)}")
    return [int(row) for row in rows]


def evaluator_expression(pairs):
    # JSON is parsed by Nix, not treated as Nix syntax. Escape Nix interpolation
    # after quoting the JSON text as a double-quoted Nix string literal.
    json_text = json.dumps(pairs, ensure_ascii=True, separators=(",", ":"))
    literal = json.dumps(json_text, ensure_ascii=True).replace("${", "\\${")
    return ("let pairs = builtins.fromJSON " + literal + "; in { "
            'inputHashes = builtins.map (p: builtins.map (s: builtins.hashString "sha256" s) p) pairs; '
            "results = builtins.map (p: builtins.compareVersions (builtins.elemAt p 0) (builtins.elemAt p 1)) pairs; }")


def evaluate(runner, nix, cases, report):
    candidates = []
    excluded = Counter()
    for index, case in enumerate(cases):
        raw = [bytes.fromhex(case["left_hex"]), bytes.fromhex(case["right_hex"])]
        has_nul = any(b"\x00" in value for value in raw)
        try:
            texts = [value.decode("utf-8", "strict") for value in raw]
        except UnicodeDecodeError:
            texts = None
        if has_nul:
            excluded["contains_nul"] += 1
        if texts is None:
            excluded["invalid_utf8"] += 1
        if has_nul or texts is None:
            excluded["excluded_unique_pairs"] += 1
        else:
            candidates.append((index, texts, [hashlib.sha256(v).hexdigest() for v in raw]))
    report["evaluator"].update(eligible_pairs=len(candidates), exclusions=dict(excluded),
        exclusion_counts_may_overlap=True,
        limits="NUL-containing and non-UTF8 byte strings are deliberately excluded from the ordinary JSON evaluator channel, not from native/runtime comparison. No byte-wide evaluator equivalence is claimed.")
    if not candidates:
        raise RuntimeError("empty evaluator corpus")
    batch = []

    def flush():
        expression = evaluator_expression([item[1] for item in batch])
        argv = [nix, "--extra-experimental-features", "nix-command", "eval", "--offline", "--json", "--expr", expression]
        response = json.loads(runner.run(argv, purpose=f"nix-evaluator batch beginning pair {batch[0][0]}"))
        if not isinstance(response, dict) or set(response) != {"inputHashes", "results"}:
            raise RuntimeError("invalid evaluator output object")
        hashes, results = response["inputHashes"], response["results"]
        if not isinstance(results, list) or len(results) != len(batch) or not isinstance(hashes, list) or len(hashes) != len(batch):
            raise RuntimeError("missing/extra evaluator output rows")
        for (index, texts, expected_hashes), actual_hashes, actual in zip(batch, hashes, results):
            case = cases[index]
            if type(actual) is not int or actual not in (-1, 0, 1):
                raise RuntimeError(f"invalid evaluator ordering at pair {index}: {actual!r}")
            case["evaluator"] = actual
            report["evaluator"]["checked_pairs"] += 1
            if actual_hashes != expected_hashes:
                report["mismatches"].append(dict(index=index, kind="evaluator-input-byte-fidelity",
                    left_hex=case["left_hex"], right_hex=case["right_hex"],
                    expected_hashes=expected_hashes, actual_hashes=actual_hashes))
            if actual != case["runtime"] or actual != case["native"]:
                report["mismatches"].append(dict(index=index, kind="evaluator-vs-drivers", **case))
        batch.clear()

    for item in candidates:
        # Keep expressions safely below Linux's per-argument size limit, also
        # allowing individual long-component pairs without silently dropping any.
        proposed = batch + [item]
        if batch and (len(proposed) > 64 or len(evaluator_expression([x[1] for x in proposed]).encode()) > EVAL_EXPRESSION_BYTES):
            flush()
        batch.append(item)
    if batch:
        flush()


def collect_identities(args, runner, report):
    scratch = Path(__file__).resolve().parent
    driver = scratch / "runtime-smoke/src/main.rs"
    match = re.search(r'#\[path\s*=\s*"([^"]+)"\]', driver.read_text())
    if match is None:
        raise RuntimeError("runtime driver's actual-source path is missing")
    sources = [Path(__file__).resolve(), driver, scratch / "native-oracle/main.cpp", Path(match.group(1))]
    report["sources"] = [identity(source) for source in sources]
    for name in ("runtime", "native_oracle", "nix"):
        path = getattr(args, name)
        if not os.path.isabs(path) or not os.access(path, os.X_OK):
            raise RuntimeError(f"{name} must name an absolute executable path: {path}")
        report["executables"][name] = identity(path)
    runner.run([args.nix, "--version"], purpose="actual Nix version")
    ldd = shutil.which("ldd")
    getconf = shutil.which("getconf")
    if not ldd or not getconf:
        raise RuntimeError("required host-profile tools ldd/getconf not found")
    report["profile_tools"] = [identity(ldd), identity(getconf)]
    runner.run([getconf, "GNU_LIBC_VERSION"], purpose="host getconf libc identity (not necessarily oracle-linked libc)")
    for name in ("native_oracle", "nix"):
        trace = runner.run([ldd, getattr(args, name)], purpose=f"{name} dynamic loader library trace").decode("utf-8", "strict")
        if "not found" in trace:
            raise RuntimeError(f"missing dynamic library in {name}")
        libraries = []
        for line in trace.splitlines():
            resolved = re.search(r"=>\s+(/\S+)", line)
            direct = re.match(r"\s*(/\S+)", line)
            path = (resolved or direct)
            if path:
                value = path.group(1)
                # Pin comparator, supporting Nix utility library, C runtime and
                # loader; retain the complete trace for every other dependency.
                if any(key in Path(value).name for key in ("libnix", "libc.so", "ld-linux")):
                    libraries.append(identity(value))
        if not any("libc.so" in Path(item["resolved_path"]).name for item in libraries):
            raise RuntimeError(f"unable to identify linked libc for {name}")
        if name == "native_oracle" and not any("libnixstore" in Path(item["resolved_path"]).name for item in libraries):
            raise RuntimeError("native oracle does not resolve the required libnixstore comparator")
        report["libraries"][name] = libraries
    report["host"] = {"platform": platform.platform(), "machine": platform.machine(),
        "python": sys.version, "libc_python_reports": list(platform.libc_ver()),
        "locale": "C enforced for every child; native driver additionally calls setlocale(LC_ALL, C)",
        "high_byte_scope": "All 256 byte values are probed, including equal high bytes and bytes adjacent to digits. This is empirical evidence for these exact binaries/libraries in the C locale, not portable C++ signed-char equivalence. Passing a negative signed char other than EOF to isdigit is undefined by the C standard unless converted to unsigned char; this harness does not establish the upstream cast/compiler details or all libc behavior. ldd identifies resolved dependencies, not a captured live process map. Host getconf libc and native-linked libc can differ; inspect both recorded identities."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", required=True)
    parser.add_argument("--native-oracle", required=True)
    parser.add_argument("--nix", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    report = {"schema": 1, "status": "failed", "invocation": [sys.executable, *sys.argv],
              "working_directory": os.getcwd(), "python_executable": identity(sys.executable),
              "seed": SEED, "batch_size": BATCH_SIZE,
              "deadlines_seconds": {"per_process": PROCESS_SECONDS, "total_process_campaign": TOTAL_SECONDS},
              "protocol": "lowercase HEX SPACE HEX NEWLINE; empty sides are allowed; one exact -1/0/1 row per pair",
              "commands": [], "executables": {}, "libraries": {}, "sources": [],
              "pair_count": 0, "checked_driver_pairs": 0, "mismatches": [], "errors": [],
              "evaluator": {"checked_pairs": 0}, "cases": []}
    try:
        runner = Runner(report)
        collect_identities(args, runner, report)
        cases = corpus()
        report["cases"] = cases
        report["pair_count"] = len(cases)
        report["category_counts"] = dict(Counter(case["category"] for case in cases))
        report["corpus_sha256"] = hashlib.sha256(b"".join(
            (case["left_hex"] + " " + case["right_hex"] + "\n").encode("ascii") for case in cases)).hexdigest()
        if not cases:
            raise RuntimeError("empty driver corpus")
        for start in range(0, len(cases), BATCH_SIZE):
            batch = cases[start:start + BATCH_SIZE]
            runtime = driver_results(runner, args.runtime, batch, f"runtime pairs {start}:{start + len(batch)}")
            native = driver_results(runner, args.native_oracle, batch, f"native pairs {start}:{start + len(batch)}")
            for offset, (case, actual, expected) in enumerate(zip(batch, runtime, native)):
                case.update(runtime=actual, native=expected)
                if actual != expected:
                    report["mismatches"].append(dict(index=start + offset, kind="runtime-vs-native", **case))
            report["checked_driver_pairs"] += len(batch)
        evaluate(runner, args.nix, cases, report)
        if report["checked_driver_pairs"] != len(cases) or report["evaluator"]["checked_pairs"] != report["evaluator"]["eligible_pairs"]:
            raise RuntimeError("incomplete campaign coverage")
        if not report["mismatches"]:
            report["status"] = "passed"
    except Exception as error:
        report["errors"].append(f"{type(error).__name__}: {error}")
    finally:
        output = Path(args.output)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(report, indent=2, ensure_ascii=True) + "\n")
    summary = {"status": report["status"], "pair_count": report["pair_count"],
               "checked_driver_pairs": report["checked_driver_pairs"],
               "evaluator_checked_pairs": report["evaluator"]["checked_pairs"],
               "mismatch_count": len(report["mismatches"]), "errors": report["errors"], "output": str(output)}
    print(json.dumps(summary, sort_keys=True))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
