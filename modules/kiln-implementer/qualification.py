#!/usr/bin/env python3
"""Deployment bindings and qualification, never placement/effect authority.

Runtime materialization retains canonical owner outputs; it does not own tasks,
leases, provider admission, checks, or publication effects.
"""

from __future__ import annotations

import argparse
import fcntl
import json
import os
import pwd
import re
import shutil
import stat
import subprocess
import sys
import time
from pathlib import Path
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from collections.abc import Callable, Collection

    StrPath = str | os.PathLike[str]

MAX_DOCUMENT_BYTES = 4 * 1024 * 1024
LABEL = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,127}\Z")
DIGEST = re.compile(r"[0-9a-f]{64}\Z")
MAX_SOURCE_FILES = 4096
MAX_SOURCE_BYTES = 64 * 1024 * 1024
MAX_SOURCE_FILE_BYTES = 4 * 1024 * 1024
MAX_OUTPUT_BYTES = 16 * 1024 * 1024
MIN_DISK_MIB = 128
MAX_DISK_MIB = 65536
MIB_BYTES = 1024 * 1024
COHORT_EXECUTABLES = frozenset(
    {
        "coordinator",
        "verifier",
        "dispatch",
        "cairn_intake",
        "lattice",
        "cairn",
        "worker",
        "sandbox",
        "nix",
        "git",
    }
)


def document(path: StrPath) -> dict[str, Any]:
    with Path(path).open("rb") as source:
        data = source.read(MAX_DOCUMENT_BYTES + 1)
    if len(data) > MAX_DOCUMENT_BYTES:
        msg = "qualification document exceeds bound"
        raise ValueError(msg)
    result = json.loads(data)
    if not isinstance(result, dict):
        msg = "qualification document must be an object"
        raise TypeError(msg)
    return result


def digest(path: StrPath) -> str:
    value = subprocess.check_output(
        ["b3sum", "--no-names", str(path)], text=True, timeout=60
    ).strip()
    if not DIGEST.fullmatch(value):
        msg = "invalid digest tool output"
        raise ValueError(msg)
    return value


def immutable(path: StrPath) -> Path:
    resolved = Path(path).resolve(strict=True)
    if not str(resolved).startswith("/nix/store/") or not resolved.is_file():
        msg = "expected immutable store file"
        raise ValueError(msg)
    return resolved


def immutable_tree(path: StrPath) -> Path:
    resolved = Path(path).resolve(strict=True)
    if not str(resolved).startswith("/nix/store/") or not resolved.is_dir():
        msg = "expected immutable store directory"
        raise ValueError(msg)
    return resolved


def verify_manifest(path: StrPath) -> dict[str, Any]:
    manifest = document(path)
    if manifest.get("schema") != "onix.lattice.worker-guest.v1":
        msg = "unsupported guest manifest"
        raise ValueError(msg)
    if manifest.get("architecture") != "x86_64-linux":
        msg = "unsupported guest architecture"
        raise ValueError(msg)
    expected = {"vmlinux", "initrd", "root.raw", "launch.json", "cloud-hypervisor"}
    if set(manifest.get("entries", {})) != expected:
        msg = "guest manifest entries differ"
        raise ValueError(msg)
    for entry in manifest["entries"].values():
        if not DIGEST.fullmatch(entry.get("blake3", "")):
            msg = "malformed immutable identity"
            raise ValueError(msg)
        actual = immutable(entry["path"])
        if digest(actual) != entry["blake3"]:
            msg = "immutable guest/VMM identity differs"
            raise ValueError(msg)
    launch = document(manifest["entries"]["launch.json"]["path"])
    if launch != manifest.get("launch"):
        msg = "generated launch configuration differs"
        raise ValueError(msg)
    for field, entry_name in (
        ("kernel", "vmlinux"),
        ("initrd", "initrd"),
        ("root", "root.raw"),
    ):
        if immutable(launch[field]) != immutable(
            manifest["entries"][entry_name]["path"]
        ):
            msg = "launch points to a different actual guest artifact"
            raise ValueError(msg)
    if launch.get("disk_image_type") != "raw" or launch.get("network") != "none":
        msg = "unsupported disk or network profile"
        raise ValueError(msg)
    if (
        launch.get("memoryBacking") != "private"
        or launch.get("mergeable") is not False
        or launch.get("hugepages") is not False
        or launch.get("memory_source") != "anonymous"
    ):
        msg = "unsupported memory profile"
        raise ValueError(msg)
    if (
        launch.get("migration_mode") != "precopy"
        or launch.get("postcopy") is not False
        or launch.get("memfds") is not False
    ):
        msg = "unsupported migration mode"
        raise ValueError(msg)
    if (
        not 1 <= launch.get("cpus", 0) <= 8
        or not 512 <= launch.get("memoryMiB", 0) <= 16384
    ):
        msg = "guest resource bounds exceeded"
        raise ValueError(msg)
    cohort_path = immutable(manifest["cohort_manifest"])
    if digest(cohort_path) != manifest.get("cohort_blake3"):
        msg = "runtime/tool/workflow cohort differs"
        raise ValueError(msg)
    cohort = document(cohort_path)
    if cohort.get("schema") != "onix.kiln.implementation-cohort.v1":
        msg = "unsupported runtime cohort"
        raise ValueError(msg)
    if (
        set(cohort.get("entries", {})) != COHORT_EXECUTABLES
        or cohort.get("workerAdapter") != "omp"
    ):
        msg = "runtime/tool/worker cohort is incomplete or unsupported"
        raise ValueError(msg)
    if digest(immutable(cohort["workflow"])) != cohort.get("workflow_blake3"):
        msg = "workflow identity differs"
        raise ValueError(msg)
    for entry in cohort["entries"].values():
        if digest(immutable(entry["resolved_path"])) != entry["blake3"]:
            msg = "runtime/tool executable identity differs"
            raise ValueError(msg)
    vmm = manifest["entries"]["cloud-hypervisor"]["path"]
    with Path(vmm).open("rb") as stream:
        header = stream.read(20)
    if header[:6] != b"\x7fELF\x02\x01" or header[18:20] != b"\x3e\x00":
        msg = "actual CH identity cannot be a delegating wrapper"
        raise ValueError(msg)
    version = subprocess.check_output([vmm, "--version"], text=True, timeout=10).strip()
    if version != manifest.get("vmm_actual_version") or not re.fullmatch(
        r"cloud-hypervisor v54\.0(?:\.\d+)?(?:[-+ ].*)?", version
    ):
        msg = "actual VMM version differs or is unsupported"
        raise ValueError(msg)
    return manifest


def write_document(path: StrPath, value: object) -> None:
    target = Path(path)
    target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    # Qualification does not overwrite retained evidence, even on repeated runs.
    with target.open("x", encoding="utf-8") as output:
        json.dump(value, output, sort_keys=True, indent=2)
        output.write("\n")
        output.flush()
        os.fsync(output.fileno())


def observe(args: argparse.Namespace) -> dict[str, Any]:
    if not LABEL.fullmatch(args.host):
        msg = "invalid explicit host identity"
        raise ValueError(msg)
    manifest = verify_manifest(args.manifest)
    guest = Path(args.manifest).resolve().parent
    # Nix's store metadata verifies the staged transitive closure. A matching
    # wrapper name/version alone is never sufficient, nor is TCP reachability.
    closure = subprocess.check_output(
        ["nix-store", "--query", "--requisites", str(guest)], text=True, timeout=120
    ).splitlines()
    if not closure:
        msg = "guest closure is not registered"
        raise ValueError(msg)
    for path in closure:
        subprocess.run(
            ["nix-store", "--verify-path", path],
            check=True,
            stdout=subprocess.DEVNULL,
            timeout=120,
        )
    retention_root = Path(args.retention_root)
    if (
        not retention_root.is_absolute()
        or not retention_root.is_symlink()
        or retention_root.resolve(strict=True) != guest
    ):
        msg = "placement requires its exact live/checkpoint environment root"
        raise ValueError(msg)
    roots = subprocess.check_output(
        ["nix-store", "--query", "--roots", str(guest)], text=True, timeout=120
    ).splitlines()
    if not any(line.rpartition(" -> ")[0] == str(retention_root) for line in roots):
        msg = "staged closure has no observed registered retention root"
        raise ValueError(msg)
    kvm = Path("/dev/kvm").exists() and os.access("/dev/kvm", os.R_OK | os.W_OK)
    value = {
        "schema": "onix.lattice.placement-observation.v1",
        "host": args.host,
        "guest": str(guest),
        "manifest_blake3": digest(args.manifest),
        "vmm": manifest["entries"]["cloud-hypervisor"],
        "vmm_actual_version": manifest["vmm_actual_version"],
        "launch_blake3": manifest["entries"]["launch.json"]["blake3"],
        "closure": sorted(closure),
        "closure_verified": True,
        "retention_root": str(retention_root),
        "retention_observed": True,
        "kvm": "accessible-unqualified" if kvm else "unsupported",
        "qualification": "unqualified",
        "placement_authority": False,
        "non_claims": [
            "no boot/migration/restore executed",
            "no allocation or model admission granted",
            "observation is not current placement or effect fencing",
        ],
    }
    write_document(args.output, value)
    return value


def compare_placements(
    source: dict[str, Any], destination: dict[str, Any]
) -> dict[str, Any]:
    for item in (source, destination):
        if (
            item.get("schema") != "onix.lattice.placement-observation.v1"
            or item.get("closure_verified") is not True
            or item.get("retention_observed") is not True
        ):
            msg = "missing verified staging or retention observation"
            raise ValueError(msg)
        if item.get("kvm") != "accessible-unqualified":
            msg = "KVM unavailable: unsupported, not qualified"
            raise ValueError(msg)
    if source.get("host") == destination.get("host"):
        msg = "two distinct placement hosts are required"
        raise ValueError(msg)
    for field in (
        "guest",
        "manifest_blake3",
        "vmm",
        "vmm_actual_version",
        "launch_blake3",
        "closure",
    ):
        if source.get(field) != destination.get(field):
            raise ValueError("placement cohort mismatch: " + field)
    return {
        "schema": "onix.lattice.placement-preflight.v1",
        "compatible": True,
        "qualification": "unqualified",
        "dispatch_allowed": False,
        "remaining": [
            "fresh authoritative placement/disk/effect fences",
            "exact-profile boot/migration/restore/memory evidence",
            "qualified retained guest and host channels",
        ],
    }


def retain(args: argparse.Namespace) -> dict[str, str]:
    if not LABEL.fullmatch(args.reference):
        msg = "invalid attempt/checkpoint reference"
        raise ValueError(msg)
    guest = Path(args.guest).resolve(strict=True)
    if (
        not str(guest).startswith("/nix/store/")
        or not (guest / "manifest.json").is_file()
    ):
        msg = "only an immutable registered guest closure may be retained"
        raise ValueError(msg)
    verify_manifest(guest / "manifest.json")
    roots = Path(args.roots)
    if not roots.is_absolute() or roots.is_symlink():
        msg = "root directory must be an absolute real directory"
        raise ValueError(msg)
    roots.mkdir(mode=0o700, parents=True, exist_ok=True)
    root = roots / (args.kind + "-" + args.reference)
    with (roots / ".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if root.is_symlink():
            if root.resolve() != guest:
                msg = "retention reference already binds another environment"
                raise ValueError(msg)
        elif root.exists():
            msg = "retention reference is not a GC root"
            raise ValueError(msg)
        else:
            subprocess.run(
                [
                    "nix-store",
                    "--add-root",
                    str(root),
                    "--indirect",
                    "--realise",
                    str(guest),
                ],
                check=True,
                timeout=120,
            )
        if not root.is_symlink() or root.resolve(strict=True) != guest:
            msg = "Nix did not establish the requested GC root"
            raise ValueError(msg)
    return {
        "schema": "onix.lattice.environment-retention.v1",
        "kind": args.kind,
        "reference": args.reference,
        "root": str(root),
        "guest": str(guest),
        "release": "only after owner retires every live/checkpoint reference; never on process exit",
    }


def kiln_policy_check(
    cohort: dict[str, Any], policy_path: StrPath, enrollment_path: StrPath
) -> Any:
    """Kiln's own intake preflight: poll's parser and validation plus a dry admission probe."""
    entry = cohort["entries"]["coordinator"]
    program = immutable(entry["resolved_path"])
    if digest(program) != entry["blake3"]:
        msg = "canonical controller executable changed"
        raise ValueError(msg)
    result = subprocess.run(
        [
            str(program),
            "policy-check",
            "--policy",
            str(policy_path),
            "--enrollment",
            str(enrollment_path),
        ],
        capture_output=True,
        text=True,
        timeout=60,
    )
    if result.returncode != 0:
        raise ValueError(
            "Kiln refused the intake policy: " + result.stderr.strip()[:2048]
        )
    return json.loads(result.stdout)


def validate_policy(
    configuration: StrPath,
    repositories: Collection[str],
    classes: Collection[str],
    state_root: str,
    cohort: dict[str, Any],
    kiln_check: Callable[[dict[str, Any], Path, Path], object] = kiln_policy_check,
) -> dict[str, str]:
    config = Path(configuration)
    enrollment = document(config / "enrollment.json")
    if (
        set(enrollment) != {"repositories", "actors"}
        or sorted(enrollment["repositories"]) != sorted(repositories)
        or not enrollment["actors"]
    ):
        msg = "enrollment must exactly match admitted repositories and explicit actors"
        raise ValueError(msg)
    # Kiln owns the policy's shape and meaning; only deployment limits are checked here.
    kiln_check(cohort, config / "github-policy.json", config / "enrollment.json")
    policy = document(config / "github-policy.json")
    repo = policy["repository"]
    # GitHub matches repository names case-insensitively (Kiln EventPolicy).
    identity = (repo["owner"] + "/" + repo["repository"]).lower()
    if identity not in {repository.lower() for repository in repositories}:
        msg = "intake policy is not enrolled"
        raise ValueError(msg)
    if policy.get("terminal_policy") != "verified_pull_request":
        msg = "this deployment only admits verified-PR delivery"
        raise ValueError(msg)
    budget = policy["budget"]
    if (
        not 1 <= budget["attempts"] <= 8
        or not 1 <= budget["minutes_per_attempt"] <= 1440
    ):
        msg = "implementation budget exceeds deployment limits"
        raise ValueError(msg)
    scope = document(config / "work-class.json")
    if (
        scope.get("class") not in classes
        or str(scope.get("repository")).lower() != identity
    ):
        msg = "policy is not bound to an admitted work class/repository"
        raise ValueError(msg)
    if scope.get("policy_blake3") != digest(config / "github-policy.json"):
        msg = "work class does not bind the actual intake policy"
        raise ValueError(msg)
    transport = document(config / "worker-transport-profile.json")
    if transport.get("schema") != "kiln.lattice-implementation-cli.v2":
        msg = "unsupported actual worker transport profile"
        raise ValueError(msg)
    lattice = cohort["entries"]["lattice"]
    if (
        immutable(transport["lattice_program"]) != immutable(lattice["resolved_path"])
        or transport["executable_blake3"] != lattice["blake3"]
    ):
        msg = "worker transport must bind the actual immutable Lattice program"
        raise ValueError(msg)
    if (
        transport.get("state_directory") != state_root + "/lattice/implementation"
        or transport.get("output_directory") != state_root + "/lattice/observations"
    ):
        msg = "Lattice state/output must remain separate from the Kiln ledger and verifier"
        raise ValueError(msg)
    return {"policy": "admitted", "qualification": "unqualified"}


def _program_entry(value: object, cohort: dict[str, Any], name: str) -> None:
    entry = cohort["entries"][name]
    if (
        not isinstance(value, dict)
        or immutable(value["path"]) != immutable(entry["resolved_path"])
        or value.get("blake3") != entry["blake3"]
    ):
        msg = f"model broker {name} does not match the admitted cohort"
        raise ValueError(msg)


def _secret_reference(value: object) -> tuple[str, str, str | None] | None:
    """Parse Lattice's `SecretRef { provider, key, field: Option<String> }`.

    Lattice serializes the unset optional `field` as null (no
    skip_serializing_if), so its canonical form is `{"field": null, ...}`;
    absent and null both mean unset. Any other member is refused. An absent
    or null reference (no credential) parses to None.
    """
    if value is None:
        return None
    if not isinstance(value, dict) or not {"provider", "key"} <= set(value) <= {
        "provider",
        "key",
        "field",
    }:
        msg = "model credential reference has missing or unexpected members"
        raise ValueError(msg)
    field = value.get("field")
    if (
        not isinstance(value["provider"], str)
        or not isinstance(value["key"], str)
        or not (field is None or isinstance(field, str))
    ):
        msg = "model credential reference members have the wrong type"
        raise ValueError(msg)
    return (value["provider"], value["key"], field)


def validate_attempt(
    request: dict[str, Any],
    cohort: dict[str, Any],
    workspace_parent: StrPath,
    credential_env: str | None = None,
) -> Path:
    if request.get("schema") != "lattice.implementation-attempt-run.v3":
        msg = "unsupported actual Lattice implementation request schema"
        raise ValueError(msg)
    workspace_id = request["envelope"]["workspace_id"]
    if not LABEL.fullmatch(workspace_id):
        msg = "workspace identity is not a safe per-attempt label"
        raise ValueError(msg)
    parent = Path(workspace_parent).resolve(strict=True)
    workspace = parent / workspace_id
    if Path(request["workspace_root"]) != workspace or workspace.is_symlink():
        msg = "request must bind its independent exact workspace directory"
        raise ValueError(msg)
    # Lattice v3: the worker never has a network device; its only route is the
    # attempt-local model broker the trusted host dispatcher runs.
    if request.get("network") is not False or "network_namespace" in request:
        msg = "the worker must have no network grant; only the attempt-local model broker is admitted"
        raise ValueError(msg)
    host_local = {"kind": "host_local"}
    binding = request.get("execution_binding")
    if (
        request.get("worker_compute") != host_local
        or not isinstance(binding, dict)
        or binding.get("compute") != host_local
    ):
        msg = "this deployment admits only host-local worker compute"
        raise ValueError(msg)
    omp = request["omp"]
    broker = omp.get("model_broker")
    if (
        not isinstance(broker, dict)
        or broker.get("schema") != "lattice.candidate-model-broker.v1"
    ):
        msg = "the worker request must select Lattice's attempt-local model broker"
        raise ValueError(msg)
    endpoint = broker.get("endpoint")
    if not isinstance(endpoint, str) or not (
        endpoint.startswith(("https://", "http://127.0.0.1:"))
    ):
        msg = "model endpoint must be HTTPS or the dispatcher namespace's literal loopback"
        raise ValueError(msg)
    if omp.get("model") != "lattice/" + str(broker.get("model")):
        msg = "OMP must select exactly the broker's single wire model"
        raise ValueError(msg)
    expected_credential = (
        None if credential_env is None else ("env", credential_env, None)
    )
    if _secret_reference(broker.get("credential")) != expected_credential:
        msg = "model credential reference must match the dispatcher's configured runtime credential"
        raise ValueError(msg)
    _program_entry(broker.get("relay"), cohort, "relay")
    _program_entry(broker.get("shell"), cohort, "shell")
    if broker.get("sandbox_blake3") != cohort["entries"]["sandbox"]["blake3"]:
        msg = "model broker sandbox identity does not match the admitted cohort"
        raise ValueError(msg)
    if (
        type(request.get("output_limit_bytes")) is not int
        or not 1 <= request["output_limit_bytes"] <= MAX_OUTPUT_BYTES
    ):
        msg = "worker output limit exceeds the deployment bound"
        raise ValueError(msg)
    for field, entry_name in (("program", "worker"), ("sandbox_program", "sandbox")):
        entry = cohort["entries"][entry_name]
        actual = immutable(request[field])
        if (
            actual != immutable(entry["resolved_path"])
            or digest(actual) != entry["blake3"]
        ):
            msg = "worker/provider executable does not match the admitted cohort"
            raise ValueError(msg)
    if (
        request["omp"]["revision"] != cohort["revisions"]["worker"]
        or request["omp"]["executable_blake3"] != cohort["entries"]["worker"]["blake3"]
    ):
        msg = "OMP profile does not match actual selected worker bytes/revision"
        raise ValueError(msg)
    for field in ("read_paths", "write_paths"):
        if (
            not isinstance(request[field], list)
            or not request[field]
            or len(request[field]) > MAX_SOURCE_FILES
        ):
            msg = "explicit bounded workspace read/write grants are required"
            raise ValueError(msg)
        for item in request[field]:
            path = Path(item)
            if (
                not isinstance(item, str)
                or not path.parts
                or path.is_absolute()
                or ".." in path.parts
                or item.startswith("\\")
            ):
                msg = "workspace grants must use native canonical relative paths"
                raise ValueError(msg)
            if field == "write_paths" and path.parts[0] in (
                ".git",
                ".jj",
                ".omp",
                ".pi",
            ):
                msg = "worker cannot mutate VCS or harness/model configuration"
                raise ValueError(msg)
    for write in request["write_paths"]:
        if not any(
            write == read or write.startswith(read + "/")
            for read in request["read_paths"]
        ):
            msg = "native workspace write grant must be covered by a read grant"
            raise ValueError(msg)
    return workspace


def stage_tree(source: StrPath, workspace: Path) -> None:
    """Copy immutable input once; never overwrite possible worker effects."""
    if workspace.exists() or workspace.is_symlink():
        msg = "workspace already exists; recover durable intent instead of re-preparing"
        raise ValueError(msg)
    # Exclusive creation never replaces another preparation, even if empty.
    # Crashes retain partial input for owner retirement; retries never recopy it.
    workspace.mkdir(mode=0o700)
    files = 0
    total = 0
    entries = 0
    for directory, directories, names in os.walk(source, followlinks=False):
        entries += len(directories) + len(names)
        if entries > MAX_SOURCE_FILES:
            msg = "source tree entry bound exceeded"
            raise ValueError(msg)
        relative = Path(directory).relative_to(source)
        destination = workspace / relative
        destination.mkdir(mode=0o700, parents=True, exist_ok=True)
        for name in directories:
            item = Path(directory) / name
            if item.is_symlink() or (relative == Path() and name in (".git", ".jj")):
                msg = "source contains a symlink or root VCS metadata"
                raise ValueError(msg)
        for name in names:
            if relative == Path() and name in (".git", ".jj"):
                msg = "source contains root VCS metadata"
                raise ValueError(msg)
            item = Path(directory) / name
            metadata = item.lstat()
            files += 1
            total += metadata.st_size
            if (
                not stat.S_ISREG(metadata.st_mode)
                or files > MAX_SOURCE_FILES
                or metadata.st_size > MAX_SOURCE_FILE_BYTES
                or total > MAX_SOURCE_BYTES
            ):
                msg = "source file type/count/byte bound exceeded"
                raise ValueError(msg)
            target = destination / name
            shutil.copyfile(item, target)
            target.chmod(0o755 if metadata.st_mode & 0o111 else 0o644)
    # Normalize immutable-store transport permissions into this execution before
    # native Lattice recomputes/admit its base snapshot and records file modes.


def _protected_directory(path: StrPath, owner_uid: int = 0) -> Path:
    path = Path(path)
    metadata = path.lstat()
    if (
        not stat.S_ISDIR(metadata.st_mode)
        or metadata.st_uid != owner_uid
        or metadata.st_mode & 0o022
    ):
        msg = f"protected directory has unsafe type, owner or permissions: {path}"
        raise ValueError(msg)
    return path


def _regular_owned(path: StrPath, owner_uid: int, writable: bool = False) -> bytes:
    path = Path(path)
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(descriptor, "rb") as source:
        metadata = os.fstat(source.fileno())
        if (
            not stat.S_ISREG(metadata.st_mode)
            or metadata.st_uid != owner_uid
            or metadata.st_mode & 0o022
        ):
            msg = f"runtime binding file has unsafe type, owner or permissions: {path}"
            raise ValueError(msg)
        if not writable and metadata.st_mode & 0o200:
            msg = f"runtime binding file remains owner-writable: {path}"
            raise ValueError(msg)
        if metadata.st_size > MAX_DOCUMENT_BYTES:
            msg = "runtime binding document exceeds byte bound"
            raise ValueError(msg)
        return source.read(MAX_DOCUMENT_BYTES + 1)


def _owned_document(path: StrPath, owner_uid: int = 0) -> dict[str, Any]:
    value = json.loads(_regular_owned(path, owner_uid))
    if not isinstance(value, dict):
        msg = "runtime binding document must be an object"
        raise TypeError(msg)
    return value


def _controller(args: argparse.Namespace) -> Path:
    state = _protected_directory(Path(args.state_root))
    return _protected_directory(state / "controller")


def _operator(args: argparse.Namespace) -> list[str]:
    """Kiln's explicit local-operator authority, when the deployment names one."""
    operator = getattr(args, "local_operator", None)
    return ["--local-operator", operator] if operator else []


def _native(
    args: argparse.Namespace, command: str, *flags: object, raw: bool = False
) -> Any:
    cohort = document(immutable(Path(args.cohort) / "manifest.json"))
    entry = cohort["entries"]["coordinator"]
    program = immutable(entry["resolved_path"])
    if digest(program) != entry["blake3"]:
        msg = "canonical controller executable changed"
        raise ValueError(msg)
    # Kiln runs only as the coordinator (the unit's User=). Root phases never
    # switch accounts: NoNewPrivileges keeps them without CAP_SETUID.
    if os.geteuid() == 0:
        msg = "the canonical owner never runs as root"
        raise ValueError(msg)
    output = subprocess.check_output(
        [
            str(program),
            command,
            "--database",
            str(Path(args.state_root) / "kiln/work.sqlite"),
            "--enrollment",
            str(immutable(Path(args.configuration) / "enrollment.json")),
            *map(str, flags),
        ],
        timeout=60,
    )
    if len(output) > MAX_DOCUMENT_BYTES:
        msg = "canonical owner output exceeds byte bound"
        raise ValueError(msg)
    return output if raw else json.loads(output)


def _retained_claim(args: argparse.Namespace) -> dict[str, Any]:
    controller = _controller(args)
    reference = _owned_document(controller / "current.json")
    label = reference.get("claim")
    if not isinstance(label, str) or not re.fullmatch(
        r"[0-9a-f]{64}-[1-9][0-9]*\.json", label
    ):
        msg = "current claim reference is malformed"
        raise ValueError(msg)
    _protected_directory(controller / "claims")
    retained = _owned_document(controller / "claims" / label)
    attempt, fence = retained["identity"], retained["fence"]
    if not DIGEST.fullmatch(attempt) or type(fence) is not int or fence < 1:
        msg = "canonical claim identity or fence is malformed"
        raise ValueError(msg)
    return retained


def _current(
    args: argparse.Namespace, observation: dict[str, Any] | None = None
) -> dict[str, Any]:
    """The canonical owner's current view of the retained claim.

    Non-root phases ask Kiln directly. Root phases never run Kiln (they cannot
    switch to the coordinator under NoNewPrivileges); they take the observation
    a coordinator phase of the same unit just retrieved and check it the same way.
    """
    retained = _retained_claim(args)
    if observation is None:
        current = _native(
            args,
            "inspect-attempt",
            "--attempt",
            retained["identity"],
            "--fence",
            retained["fence"],
        )
    else:
        current = observation
    claim = current["attempt"]
    if any(
        claim.get(key) != retained.get(key)
        for key in (
            "identity",
            "fence",
            "work_identity",
            "work_revision",
            "claimed_at_ms",
        )
    ):
        msg = "current owner claim differs from retained claim reference"
        raise ValueError(msg)
    return current


def _seal(path: StrPath, value: object) -> None:
    write_document(path, value)
    Path(path).chmod(0o444)


# Hand-off between the phases of one controller unit: a coordinator phase (the
# unit's User=) runs Kiln and writes here; a root phase ("!" prefix: same
# sandbox, no User=) validates and seals into root-owned controller state.
# The spool is root-owned, sticky and ledger-group writable: each phase
# replaces only its own documents and every read checks the writer's UID.
def _spool(args: argparse.Namespace) -> Path:
    spool = Path(args.state_root) / "controller-spool"
    metadata = spool.lstat()
    if (
        not stat.S_ISDIR(metadata.st_mode)
        or metadata.st_uid != 0
        or metadata.st_mode & 0o007
    ):
        msg = "controller spool has unsafe type, owner or permissions"
        raise ValueError(msg)
    return spool


def _spool_write(args: argparse.Namespace, name: str, value: object) -> None:
    path = _spool(args) / name
    path.unlink(missing_ok=True)
    write_document(path, value)
    path.chmod(0o440 if os.geteuid() else 0o444)


def _spool_read(args: argparse.Namespace, name: str, owner_uid: int) -> dict[str, Any]:
    """Read a spool document written by exactly the expected phase account."""
    path = _spool(args) / name
    value = json.loads(_regular_owned(path, owner_uid, writable=False))
    if not isinstance(value, dict):
        msg = "controller spool document must be an object"
        raise TypeError(msg)
    return value


def _spool_clear(args: argparse.Namespace, *names: str) -> None:
    for name in names:
        (_spool(args) / name).unlink(missing_ok=True)


def _require_root(phase: str) -> None:
    if os.geteuid() != 0:
        msg = f"the {phase} phase belongs to the protected controller"
        raise ValueError(msg)
    # Sealed controller state is read by the other stage accounts.
    os.umask(0o022)


def claim_attempt(args: argparse.Namespace) -> dict[str, Any]:
    if args.phase == "native":
        # Coordinator: the canonical claim, retained for the root seal.
        claim = _native(args, "claim", "--lease-ms", args.lease_ms, *_operator(args))
        _spool_write(args, "claim.json", {"claim": claim})
        return {"phase": "native", "claimed": claim is not None}
    _require_root("seal")
    controller = _controller(args)
    claims = _protected_directory(controller / "claims")
    with (controller / "lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        claim = _spool_read(args, "claim.json", args.coordinator_uid)["claim"]
        _spool_clear(args, "claim.json")
        if claim is None:
            return {"claimed": False, "qualification": "unqualified"}
        if (
            claim.get("schema") != "kiln.implementation-attempt.v2"
            or not DIGEST.fullmatch(claim.get("identity", ""))
            or type(claim.get("fence")) is not int
            or claim["fence"] < 1
        ):
            msg = "canonical owner did not return an exact actual claim"
            raise ValueError(msg)
        leaf = f"{claim['identity']}-{claim['fence']}.json"
        _seal(claims / leaf, claim)
        temporary = controller / "current.new"
        _seal(temporary, {"claim": leaf})
        temporary.replace(controller / "current.json")
        return {
            "claimed": True,
            "claim": str(claims / leaf),
            "attempt": claim["identity"],
            "fence": claim["fence"],
        }


def prepare_fixture_intake(args: argparse.Namespace) -> dict[str, Any]:
    # Runs as the coordinator (the unit's User=); it only drives Kiln's
    # explicitly synthetic helper against the ledger, never root state.
    if os.geteuid() == 0:
        msg = "fixture intake runs as the coordinator, not root"
        raise ValueError(msg)
    spec = document(immutable(Path(args.bundle) / "runtime-template.json"))
    if (
        spec.get("schema") != "onix.kiln.runtime-template.v1"
        or spec.get("scope") != "synthetic-local-only"
    ):
        msg = "fixture-only intake cannot admit live provider authority"
        raise ValueError(msg)
    helper = spec["fixture_admission"]
    program = immutable(helper["path"])
    if digest(program) != helper["blake3"]:
        msg = "required synthetic intake helper executable changed"
        raise ValueError(msg)
    raw = subprocess.check_output(
        [
            str(program),
            "prepare-intake",
            "--database",
            str(Path(args.state_root) / "kiln/work.sqlite"),
            "--enrollment",
            str(immutable(Path(args.configuration) / "enrollment.json")),
        ],
        timeout=60,
        umask=0o007,
    )
    if len(raw) > MAX_DOCUMENT_BYTES:
        msg = "synthetic intake helper output exceeds bound"
        raise ValueError(msg)
    result = json.loads(raw)
    if (
        result.get("schema") != "kiln.scripted-intake-binding.v1"
        or result.get("scope") != "synthetic-local-only"
    ):
        msg = "helper did not return explicitly synthetic intake preparation"
        raise ValueError(msg)
    return result


def _expand_runtime(value: object, bindings: dict[str, Any]) -> Any:
    if isinstance(value, dict):
        if set(value) == {"runtime"}:
            key = value["runtime"]
            if key not in bindings:
                msg = f"unsupported runtime binding selector: {key}"
                raise ValueError(msg)
            return bindings[key]
        return {key: _expand_runtime(item, bindings) for key, item in value.items()}
    if isinstance(value, list):
        return [_expand_runtime(item, bindings) for item in value]
    return value


# Kiln's owner JSON spells WorkSourceKind in serde snake case; the Lattice
# request and Kiln's own dispatcher check (kiln-adapter-lattice worker.rs) use
# these wire names.
LATTICE_SOURCE_KINDS = {
    "git_hub_issue": "github_issue",
    "cairn_task": "cairn_task",
    "cairn_artifact": "cairn_artifact",
}


def _lattice_source_kind(kind: str) -> str:
    if kind not in LATTICE_SOURCE_KINDS:
        msg = f"unsupported canonical work source kind: {kind}"
        raise ValueError(msg)
    return LATTICE_SOURCE_KINDS[kind]


def _binding_context(
    args: argparse.Namespace, observation: dict[str, Any] | None = None
) -> tuple[Path, dict[str, Any], dict[str, Any], dict[str, Any]]:
    template = immutable(Path(args.bundle) / "runtime-template.json")
    spec = document(template)
    if spec.get("schema") != "onix.kiln.runtime-template.v1":
        msg = "immutable runtime template schema is unsupported"
        raise ValueError(msg)
    current = _current(args, observation)
    claim = current["attempt"]
    bindings = {
        "attempt": claim["identity"],
        "fence": claim["fence"],
        "work": claim["work_identity"],
        "work_revision": claim["work_revision"],
        "lease_until_ms": claim["lease_until_ms"],
        "claimed_at_ms": claim["claimed_at_ms"],
        "acceptance_digest": current["acceptance_digest"],
        "verification_profile": current["work"]["verification_profile"],
    }
    source = current["work"]["aliases"][0]
    # The scripted fixture keeps Kiln's fixed 3-minute window; a live template
    # may name its own bounded window, still capped by the current lease.
    window = spec.get("attempt_window_ms", 180_000)
    if type(window) is not int or not 60_000 <= window <= 3_600_000:
        msg = "attempt window must be 1..60 minutes"
        raise ValueError(msg)
    bindings.update(
        {
            "workspace": claim["identity"],
            "workspace_root": str(
                Path(args.state_root) / "workspaces" / claim["identity"]
            ),
            "base": claim["base"],
            "base_oid": claim["base"]["native_id"],
            "source_kind": _lattice_source_kind(source["kind"]),
            "source_id": source["native_id"],
            "readiness_snapshot": source["version"],
            "expires_at_ms": min(
                claim["lease_until_ms"], claim["claimed_at_ms"] + window
            ),
        }
    )
    bindings["verification_profile_document"] = document(
        immutable(Path(args.bundle) / "verification-profile.json")
    )
    if current.get("publication_branch") is not None:
        bindings["publication_branch"] = current["publication_branch"]
    return template, spec, current, bindings


def _fixture_execution(
    args: argparse.Namespace,
    spec: dict[str, Any],
    claim: dict[str, Any],
    prepared: StrPath,
    plan: object,
) -> tuple[Any, Any, Any]:
    """Kiln's explicit scripted helper binds needs/plan/owner grants natively (as the coordinator)."""
    if spec.get("scope") != "synthetic-local-only":
        msg = "fixture admission cannot grant live provider authority"
        raise ValueError(msg)
    helper = spec["fixture_admission"]
    program = immutable(helper["path"])
    if digest(program) != helper["blake3"]:
        msg = "required synthetic admission helper executable changed"
        raise ValueError(msg)
    plan_seed = _spool(args) / "dispatch-plan-seed.json"
    plan_seed.unlink(missing_ok=True)
    write_document(plan_seed, plan)
    try:
        raw = subprocess.check_output(
            [
                str(program),
                "bind-execution",
                "--database",
                str(Path(args.state_root) / "kiln/work.sqlite"),
                "--enrollment",
                str(immutable(Path(args.configuration) / "enrollment.json")),
                "--attempt",
                claim["identity"],
                "--fence",
                str(claim["fence"]),
                "--worker-request",
                str(prepared),
                "--dispatch-plan-template",
                str(plan_seed),
            ],
            timeout=60,
            umask=0o007,
        )
    finally:
        plan_seed.unlink(missing_ok=True)
    if len(raw) > MAX_DOCUMENT_BYTES:
        msg = "synthetic admission helper output exceeds bound"
        raise ValueError(msg)
    admitted = json.loads(raw)
    if (
        admitted.get("schema") != "kiln.scripted-execution-binding.v2"
        or admitted.get("scope") != "synthetic-local-only"
    ):
        msg = "helper did not return an explicitly synthetic typed execution binding"
        raise ValueError(msg)
    seed = admitted["worker_seed"]
    if seed.get("dispatch_plan") != admitted["dispatch_plan_identity"]:
        msg = "helper seed does not name its own admitted dispatch plan"
        raise ValueError(msg)
    return seed, admitted["dispatch_plan"], admitted["admission_observations"]


def _live_execution(
    args: argparse.Namespace,
    spec: dict[str, Any],
    claim: dict[str, Any],
    request: dict[str, Any],
    plan: dict[str, Any],
    bindings: dict[str, Any],
) -> tuple[Any, dict[str, Any], list[Any]]:
    """Bind the live route through the native owner (as the coordinator): needs, plan, current grants.

    The host-owner reservation is retained beforehand by `host-owner-reserve`;
    this never mints a grant.
    """
    live = spec.get("live_execution")
    if not isinstance(live, dict) or set(live) != {"needs", "attempt_binding"}:
        msg = "live dispatch template requires explicit work needs and provider fact references"
        raise ValueError(msg)
    scratch = _spool(args) / f"scratch-{claim['identity']}-{claim['fence']}"
    shutil.rmtree(scratch, ignore_errors=True)
    scratch.mkdir(mode=0o700)
    try:
        needs_seed = scratch / "needs-seed.json"
        write_document(needs_seed, _expand_runtime(live["needs"], bindings))
        needs = scratch / "needs.json"
        _native(
            args,
            "prepare-needs",
            "--work",
            claim["work_identity"],
            "--needs-file",
            needs_seed,
            "--output",
            needs,
            *_operator(args),
        )
        attachment = document(needs)
        _native(args, "attach-needs", "--needs-file", needs, *_operator(args), raw=True)
        bindings["route_identity"] = request["execution_binding"]["model_routes"][
            "routes"
        ][0]["route_identity"]
        plan["execution"] = {
            "requirements": attachment,
            "attempt": _expand_runtime(live["attempt_binding"], bindings),
            "native_request_profile": bindings["worker_profile"],
        }
        plan_path = scratch / "dispatch-plan.json"
        write_document(plan_path, plan)
        reservation = _native(
            args, "reserve-plan", "--plan-file", plan_path, *_operator(args)
        )
    finally:
        shutil.rmtree(scratch)
    if not DIGEST.fullmatch(str(reservation.get("plan"))):
        msg = "native reservation did not return the admitted plan identity"
        raise ValueError(msg)
    seed = json.loads(json.dumps(request))
    seed["envelope"]["policy_digest"] = attachment["policy_identity"]
    seed["dispatch_plan"] = reservation["plan"]
    seed["admitted_envelope"] = ""
    now = time.time_ns() // 1_000_000
    status = _native(args, "admission-status")
    observations = [
        item
        for item in status.get("eligibility", {}).values()
        if item["valid_until_ms"] >= now
    ]
    if not observations:
        msg = "no fresh owner eligibility observation is retained for this attempt"
        raise ValueError(msg)
    return seed, plan, observations


def _binding_summary(
    destination: StrPath, claim: dict[str, Any], manifest: dict[str, Any]
) -> dict[str, Any]:
    return {
        "path": str(destination),
        "attempt": claim["identity"],
        "fence": claim["fence"],
        "request_blake3": manifest["request_blake3"],
        "qualification": "scripted-unqualified",
    }


def _lattice(cohort: dict[str, Any]) -> Path:
    lattice = immutable(cohort["entries"]["lattice"]["resolved_path"])
    if digest(lattice) != cohort["entries"]["lattice"]["blake3"]:
        msg = "native Lattice preparation executable changed"
        raise ValueError(msg)
    return lattice


def materialize_binding(args: argparse.Namespace) -> dict[str, Any]:
    """Bind one stage's protected inputs in phases.

    observe (coordinator): Kiln's current view of the retained claim.
    stage   (root, dispatch): exclusive binding directory, isolated workspace
            owned by the worker, first native Lattice preparation.
    execute (coordinator, dispatch): Kiln needs/plan/owner-grant binding.
    seal    (root): validate the coordinator's results, final preparation,
            seal root-owned read-only bindings and their manifest.
    """
    observation_name = f"{args.stage}-observation.json"
    if args.phase == "observe":
        if os.geteuid() == 0:
            msg = "the observe phase runs as the coordinator"
            raise ValueError(msg)
        _spool_clear(args, observation_name, "dispatch-execution.json")
        current = _current(args)
        _spool_write(args, observation_name, current)
        return {
            "phase": "observe",
            "attempt": current["attempt"]["identity"],
            "fence": current["attempt"]["fence"],
        }
    if args.phase == "execute":
        if os.geteuid() == 0 or args.stage != "dispatch":
            msg = "the execute phase runs as the coordinator for dispatch"
            raise ValueError(msg)
        staged = _spool_read(args, "dispatch-stage.json", 0)
        if staged.get("bound"):
            _spool_write(args, "dispatch-execution.json", {"bound": True})
            return {"phase": "execute", "bound": True}
        spec = document(immutable(Path(args.bundle) / "runtime-template.json"))
        if "fixture_admission" in spec:
            seed_request, plan, observations = _fixture_execution(
                args, spec, staged["claim"], staged["prepared"], staged["plan"]
            )
        else:
            seed_request, plan, observations = _live_execution(
                args,
                spec,
                staged["claim"],
                staged["request"],
                staged["plan"],
                staged["bindings"],
            )
        _spool_write(
            args,
            "dispatch-execution.json",
            {"seed_request": seed_request, "plan": plan, "observations": observations},
        )
        return {"phase": "execute", "bound": False}
    _require_root(args.phase)
    observation = _spool_read(args, observation_name, args.coordinator_uid)
    template, spec, current, bindings = _binding_context(args, observation)
    claim = current["attempt"]
    controller = _controller(args)
    root = _protected_directory(controller / "bindings")
    operation = root / f"{claim['identity']}-{claim['fence']}"
    cohort = document(immutable(Path(args.cohort) / "manifest.json"))
    with (controller / "lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if not operation.exists():
            operation.mkdir(mode=0o755)
        _protected_directory(operation)
        destination = operation / args.stage
        if destination.exists() and (destination / "manifest.json").exists():
            # Already sealed for this exact claim: re-binding is a no-op.
            if args.phase == "stage":
                _spool_write(args, "dispatch-stage.json", {"bound": True})
            else:
                _spool_clear(
                    args,
                    observation_name,
                    "dispatch-stage.json",
                    "dispatch-execution.json",
                )
            return _binding_summary(
                destination, claim, _owned_document(destination / "manifest.json")
            )
        files = {}
        if args.stage == "dispatch" and args.phase == "stage":
            if (
                claim["phase"] != "claimed"
                or claim["lease_until_ms"] <= time.time_ns() // 1_000_000
            ):
                msg = "dispatch materialization requires an actual current unexpired claim"
                raise ValueError(msg)
            # Exclusive: a partial failure is retained; a workspace is never
            # recopied or rebound over possible worker effects.
            destination.mkdir(mode=0o755)
            request = _expand_runtime(spec["dispatch"]["attempt.json"], bindings)
            envelope = request["envelope"]
            for field, value in (
                ("work_id", claim["work_identity"]),
                ("work_version", claim["work_revision"]),
                ("attempt_id", claim["identity"]),
                ("fence", claim["fence"]),
            ):
                if envelope[field] != value:
                    msg = "immutable dispatch template failed to bind actual claim"
                    raise ValueError(msg)
            workspace = validate_attempt(
                request, cohort, args.workspace_parent, args.model_credential_env
            )
            stage_tree(immutable_tree(Path(args.bundle) / "base"), workspace)
            account = pwd.getpwuid(args.worker_uid)
            for directory, _, names in os.walk(workspace):
                os.chown(directory, account.pw_uid, account.pw_gid)
                for name in names:
                    os.chown(Path(directory) / name, account.pw_uid, account.pw_gid)
            # Lattice's native codec owns snapshot/profile/envelope identities.
            # Preparation runs before any worker, on immutable request input.
            seed = destination / "request-seed.json"
            _seal(seed, request)
            output = destination / "prepared-request.json"
            subprocess.run(
                [
                    str(_lattice(cohort)),
                    "implementation-attempt",
                    "prepare",
                    "--request",
                    str(seed),
                    "--output",
                    str(output),
                ],
                check=True,
                timeout=60,
            )
            output.chmod(0o444)
            request = json.loads(_regular_owned(output, 0))
            bindings["worker_profile"] = request["envelope"]["worker_profile"]
            plan = _expand_runtime(spec["dispatch"]["dispatch-plan.json"], bindings)
            _spool_write(
                args,
                "dispatch-stage.json",
                {
                    "claim": claim,
                    "request": request,
                    "plan": plan,
                    "prepared": str(output),
                    "bindings": {
                        key: value
                        for key, value in bindings.items()
                        if key != "verification_profile_document"
                    },
                },
            )
            return {
                "phase": "stage",
                "attempt": claim["identity"],
                "fence": claim["fence"],
            }
        if args.phase != "seal":
            msg = "unsupported binding phase for this stage"
            raise ValueError(msg)
        if args.stage == "dispatch":
            if not destination.is_dir():
                msg = "dispatch binding was not staged"
                raise ValueError(msg)
            output = destination / "prepared-request.json"
            request = json.loads(_regular_owned(output, 0))
            original_profile = request["envelope"]["worker_profile"]
            bindings["worker_profile"] = original_profile
            executed = _spool_read(
                args, "dispatch-execution.json", args.coordinator_uid
            )
            seed_request, plan, observations = (
                executed["seed_request"],
                executed["plan"],
                executed["observations"],
            )
            # Only the native policy association and the reserved plan identity
            # may change between preparations; every child execution grant
            # stays exactly as the immutable template bound it.
            previous = json.loads(json.dumps(request))
            previous["envelope"]["policy_digest"] = seed_request["envelope"][
                "policy_digest"
            ]
            previous["dispatch_plan"] = seed_request.get("dispatch_plan")
            previous["admitted_envelope"] = ""
            if seed_request != previous or not DIGEST.fullmatch(
                str(previous["dispatch_plan"])
            ):
                msg = "execution binding changed request grants or omitted the reserved plan"
                raise ValueError(msg)
            if (
                plan.get("attempt_identity") != claim["identity"]
                or plan.get("fence") != claim["fence"]
                or plan.get("work_identity") != claim["work_identity"]
            ):
                msg = "execution binding plan crosses the current claim"
                raise ValueError(msg)
            planned = destination / "planned-seed.json"
            _seal(planned, seed_request)
            final = destination / "final-request.json"
            subprocess.run(
                [
                    str(_lattice(cohort)),
                    "implementation-attempt",
                    "prepare",
                    "--request",
                    str(planned),
                    "--output",
                    str(final),
                ],
                check=True,
                timeout=60,
            )
            request = json.loads(_regular_owned(final, 0, writable=True))
            if (
                request["envelope"]["worker_profile"] != original_profile
                or request.get("dispatch_plan") != seed_request["dispatch_plan"]
            ):
                msg = "planned preparation changed the native worker profile or plan binding"
                raise ValueError(msg)
            files = {
                name: _expand_runtime(value, bindings)
                for name, value in spec["dispatch"].items()
                if name not in ("attempt.json", "dispatch-plan.json")
            }
            files["attempt.json"] = request
            files["dispatch-plan.json"] = plan
            files["admission-observations.json"] = observations
            for leftover in (planned, final, output, destination / "request-seed.json"):
                leftover.unlink()
        else:
            if (
                claim["phase"] != "verified"
                or current.get("handoff") is None
                or current.get("verification") is None
            ):
                msg = "publication materialization requires actual retained handoff and independent verification"
                raise ValueError(msg)
            if destination.exists():
                msg = "a partial publication binding is retained; it is never rebound"
                raise ValueError(msg)
            destination.mkdir(mode=0o755)
            handoff = current["handoff"]
            bindings.update(
                {
                    "candidate": handoff["candidate"],
                    "tree": handoff["tree"],
                    "handoff": current["handoff_identity"],
                    "verification": current["verification_identity"],
                }
            )
            files = _expand_runtime(spec["publication"], bindings)
            source = files["publication-source-profile.json"]
            if source["schema"] != "kiln.github-publication-source.v1":
                msg = "unsupported trusted publication source profile"
                raise ValueError(msg)
            if source["repository_path"] != str(
                Path(args.state_root) / "verifier/repository"
            ):
                msg = "publication source must bind the protected actual captured repository"
                raise ValueError(msg)
            source_root = _protected_directory(
                Path(args.state_root) / "publication-source"
            )
            export = source_root / f"{claim['identity']}-{claim['fence']}"
            export.mkdir(mode=0o755)
            repository = export / "candidate"
            git = immutable(cohort["entries"]["git"]["resolved_path"])
            if digest(git) != cohort["entries"]["git"]["blake3"]:
                msg = "publication export Git executable changed"
                raise ValueError(msg)
            acquisition = Path(args.state_root) / "verifier/repository"
            git_args = [str(git), "-c", "safe.directory=" + str(acquisition)]
            subprocess.run(
                [
                    *git_args,
                    "clone",
                    "--bare",
                    "--no-local",
                    "--no-hardlinks",
                    "--",
                    str(acquisition),
                    str(repository),
                ],
                check=True,
                timeout=60,
            )
            retained_ref = "refs/kiln/implementation-candidates/" + claim["identity"]
            subprocess.run(
                [
                    *git_args,
                    "-C",
                    str(repository),
                    "fetch",
                    "--no-tags",
                    "origin",
                    retained_ref + ":" + retained_ref,
                ],
                check=True,
                timeout=60,
            )
            subprocess.run(
                [
                    str(git),
                    "-C",
                    str(repository),
                    "cat-file",
                    "-e",
                    handoff["candidate"]["native_id"] + "^{commit}",
                ],
                check=True,
                timeout=30,
            )
            subprocess.run(
                [
                    str(git),
                    "-C",
                    str(repository),
                    "remote",
                    "set-url",
                    source["remote"]["remote_name"],
                    source["remote"]["remote_url"],
                ],
                check=True,
                timeout=30,
            )
            source["repository_path"] = str(repository)
            for directory, _, names in os.walk(repository):
                Path(directory).chmod(0o755)
                for name in names:
                    (Path(directory) / name).chmod(0o444)
        entries = {}
        for name, value in files.items():
            if name not in STAGE_ENTRIES[args.stage]:
                msg = "unexpected runtime stage entry"
                raise ValueError(msg)
            _seal(destination / name, value)
            entries[name] = digest(destination / name)
        request_blake3 = entries.get("attempt.json")
        if args.stage == "publication":
            dispatch_stage = _protected_directory(operation / "dispatch")
            dispatch_manifest = _owned_document(dispatch_stage / "manifest.json")
            request_blake3 = dispatch_manifest["request_blake3"]
            _regular_owned(dispatch_stage / "attempt.json", 0)
            if request_blake3 != digest(dispatch_stage / "attempt.json"):
                msg = "publication request lineage differs from sealed dispatch bytes"
                raise ValueError(msg)
        manifest = {
            "schema": "onix.kiln.runtime-binding.v1",
            "stage": args.stage,
            "attempt": claim["identity"],
            "fence": claim["fence"],
            "work": claim["work_identity"],
            "work_revision": claim["work_revision"],
            "template_blake3": digest(template),
            "cohort_manifest_blake3": digest(Path(args.cohort) / "manifest.json"),
            "request_blake3": request_blake3,
            "entries": entries,
        }
        _seal(destination / "manifest.json", manifest)
        destination.chmod(0o555)
        _spool_clear(
            args, observation_name, "dispatch-stage.json", "dispatch-execution.json"
        )
        return _binding_summary(destination, claim, manifest)


STAGE_ENTRIES = {
    "dispatch": {
        "attempt.json",
        "dispatch-plan.json",
        "admission-observations.json",
        "verification-profile.json",
        "verifier-authority.json",
    },
    "publication": {"publication.json", "publication-source-profile.json"},
}


def runtime_binding(args: argparse.Namespace) -> dict[str, Any]:
    """Resolve a protected stage artifact against fresh canonical owner state."""
    template, _, current, _ = _binding_context(args)
    claim = current["attempt"]
    root = _protected_directory(_controller(args) / "bindings")
    operation = _protected_directory(root / f"{claim['identity']}-{claim['fence']}")
    stage = _protected_directory(operation / args.stage)
    manifest = _owned_document(stage / "manifest.json")
    if (
        manifest.get("schema") != "onix.kiln.runtime-binding.v1"
        or manifest.get("stage") != args.stage
    ):
        msg = "runtime binding manifest schema/stage is unsupported"
        raise ValueError(msg)
    if any(
        manifest.get(key) != claim[field]
        for key, field in (
            ("attempt", "identity"),
            ("fence", "fence"),
            ("work", "work_identity"),
            ("work_revision", "work_revision"),
        )
    ):
        msg = "runtime binding belongs to another canonical claim"
        raise ValueError(msg)
    if manifest.get("cohort_manifest_blake3") != digest(
        Path(args.cohort) / "manifest.json"
    ) or manifest.get("template_blake3") != digest(template):
        msg = "runtime binding immutable template/cohort changed"
        raise ValueError(msg)
    entries = manifest.get("entries")
    if not isinstance(entries, dict) or set(entries) != STAGE_ENTRIES[args.stage]:
        msg = "runtime stage entry set is incomplete or unexpected"
        raise ValueError(msg)
    for name, expected in entries.items():
        raw = _regular_owned(stage / name, 0)
        if (
            not isinstance(expected, str)
            or not DIGEST.fullmatch(expected)
            or digest(stage / name) != expected
        ):
            msg = f"runtime binding bytes changed: {name}"
            raise ValueError(msg)
        json.loads(raw)
    if args.stage == "dispatch":
        request = _owned_document(stage / "attempt.json")
        plan = _owned_document(stage / "dispatch-plan.json")
        envelope = request["envelope"]
        if (
            envelope["attempt_id"] != claim["identity"]
            or envelope["fence"] != claim["fence"]
            or plan["attempt_identity"] != claim["identity"]
            or plan["fence"] != claim["fence"]
        ):
            msg = "runtime request/plan does not bind the current claim"
            raise ValueError(msg)
        if (
            envelope["work_id"] != claim["work_identity"]
            or envelope["work_version"] != claim["work_revision"]
            or plan["work_identity"] != claim["work_identity"]
            or plan["work_revision"] != claim["work_revision"]
        ):
            msg = "runtime request/plan crosses the current work version"
            raise ValueError(msg)
        if (
            envelope["workspace_id"] != plan["workspace"]["identity"]
            or manifest["request_blake3"] != entries["attempt.json"]
        ):
            msg = "runtime request workspace or exact byte binding differs"
            raise ValueError(msg)
    else:
        dispatch_stage = _protected_directory(operation / "dispatch")
        dispatch_manifest = _owned_document(dispatch_stage / "manifest.json")
        _regular_owned(dispatch_stage / "attempt.json", 0)
        if manifest["request_blake3"] != dispatch_manifest[
            "request_blake3"
        ] or manifest["request_blake3"] != digest(dispatch_stage / "attempt.json"):
            msg = "publication binding lost its exact native request lineage"
            raise ValueError(msg)
    return _binding_summary(stage, claim, manifest)


def attempt_inputs(
    args: argparse.Namespace,
) -> tuple[Path, dict[str, Any], dict[str, Any], dict[str, Any], Path]:
    bundle = immutable_tree(args.bundle)
    cohort = document(immutable(Path(args.cohort) / "manifest.json"))
    binding = runtime_binding(args)
    request = _owned_document(Path(binding["path"]) / "attempt.json")
    workspace = validate_attempt(
        request, cohort, args.workspace_parent, args.model_credential_env
    )
    return bundle, binding, cohort, request, workspace


def check_attempt(args: argparse.Namespace) -> dict[str, Any]:
    _, binding, _, _, workspace = attempt_inputs(args)
    if not workspace.is_dir() or workspace.is_symlink():
        msg = "controller-prepared actual claim workspace is absent or linked"
        raise ValueError(msg)
    return {
        "schema": "onix.kiln.workspace-preparation.v1",
        "workspace": str(workspace),
        "binding": binding["path"],
        "disposition": "request-checked",
        "qualification": "scripted-unqualified",
        "base_verification": "Lattice native snapshot admission required",
    }


SENT_REQUEST_FIELDS = {
    "schema",
    "attempt",
    "fence",
    "recorded",
    "request",
    "request_blake3",
    "state_directory",
}


def _sent_request(
    args: argparse.Namespace,
    cohort: dict[str, Any],
    operation: Path,
    claim: dict[str, Any],
) -> tuple[Path, dict[str, Any]]:
    """The request bytes Lattice actually ran for the canonical claim.

    Kiln's dispatcher may send the admitted request plus one budget `lineage`
    and records that file (kiln-adapter-lattice worker.rs `sent_request_path`);
    Lattice binds its persisted intent to those exact bytes, so every
    post-dispatch Lattice call (recover, cancel) must name it. Kiln's read-only
    `--sent-request` mode resolves and verifies it; this re-checks the result
    against the claim and the immutable worker transport profile.
    """
    entry = cohort["entries"]["dispatch"]
    program = immutable(entry["resolved_path"])
    if digest(program) != entry["blake3"]:
        msg = "canonical dispatcher executable changed"
        raise ValueError(msg)
    transport_path = immutable(
        Path(args.configuration) / "worker-transport-profile.json"
    )
    transport = document(transport_path)
    state_root = str(Path(args.state_root))
    output_directory = Path(transport.get("output_directory", ""))
    state_directory = transport.get("state_directory")
    if (
        output_directory != Path(state_root) / "lattice/observations"
        or state_directory != state_root + "/lattice/implementation"
        or args.state != state_directory
    ):
        msg = "worker transport output/state roots differ from the deployment's Lattice state"
        raise ValueError(msg)
    raw = subprocess.check_output(
        [
            str(program),
            "--database",
            str(Path(args.state_root) / "kiln/work.sqlite"),
            "--enrollment",
            str(immutable(Path(args.configuration) / "enrollment.json")),
            "--worker-request",
            str(operation / "attempt.json"),
            "--worker-transport-profile",
            str(transport_path),
            "--sent-request",
            "true",
        ],
        timeout=60,
    )
    if len(raw) > MAX_DOCUMENT_BYTES:
        msg = "sent-request resolution exceeds byte bound"
        raise ValueError(msg)
    sent = json.loads(raw)
    if (
        not isinstance(sent, dict)
        or set(sent) != SENT_REQUEST_FIELDS
        or sent["schema"] != "kiln.lattice-sent-request.v1"
    ):
        msg = "dispatcher did not return a typed sent-request resolution"
        raise ValueError(msg)
    if (
        sent["attempt"] != claim["attempt"]
        or type(sent["fence"]) is not int
        or sent["fence"] != claim["fence"]
        or type(sent["recorded"]) is not bool
    ):
        msg = "sent request belongs to another canonical claim"
        raise ValueError(msg)
    blake3 = sent["request_blake3"]
    request = Path(sent["request"])
    if (
        not isinstance(blake3, str)
        or not DIGEST.fullmatch(blake3)
        or request != output_directory / f"request-{blake3}.json"
    ):
        msg = "sent request is not the profile's frozen request file"
        raise ValueError(msg)
    if not stat.S_ISREG(request.lstat().st_mode) or digest(request) != blake3:
        msg = "sent request file is not the ordinary file Kiln verified"
        raise ValueError(msg)
    if not sent["recorded"] and blake3 != digest(operation / "attempt.json"):
        msg = "an unrecorded launch must have sent the admitted bytes"
        raise ValueError(msg)
    if sent["state_directory"] != state_directory:
        msg = "sent request names another Lattice state root"
        raise ValueError(msg)
    return request, sent


def _lattice_attempt(
    cohort: dict[str, Any],
    command: str,
    request: StrPath,
    state: str,
    timeout: float,
) -> bytes:
    program = immutable(cohort["entries"]["lattice"]["resolved_path"])
    if digest(program) != cohort["entries"]["lattice"]["blake3"]:
        msg = "native Lattice executable changed"
        raise ValueError(msg)
    raw = subprocess.check_output(
        [
            str(program),
            "implementation-attempt",
            command,
            "--request",
            str(request),
            "--state",
            state,
        ],
        timeout=timeout,
    )
    if len(raw) > MAX_DOCUMENT_BYTES:
        msg = f"native Lattice {command} output exceeds bound"
        raise ValueError(msg)
    return raw


def cancel_worker(args: argparse.Namespace) -> dict[str, Any]:
    """Persist cancellation for the exact request Lattice ran."""
    cohort = document(immutable(Path(args.cohort) / "manifest.json"))
    binding = runtime_binding(args)
    request, sent = _sent_request(args, cohort, Path(binding["path"]), binding)
    outcome = json.loads(
        _lattice_attempt(cohort, "cancel", request, sent["state_directory"], 30)
    )
    if not isinstance(outcome, dict):
        msg = "native Lattice cancellation output is not an object"
        raise TypeError(msg)
    return {
        "schema": "onix.kiln.worker-cancel.v1",
        "attempt": sent["attempt"],
        "fence": sent["fence"],
        "request": str(request),
        "request_blake3": sent["request_blake3"],
        "lattice": outcome,
    }


def export_candidate(args: argparse.Namespace) -> dict[str, Any]:
    _, binding, cohort, request, workspace = attempt_inputs(args)
    sent_request, sent = _sent_request(args, cohort, Path(binding["path"]), binding)
    raw = _lattice_attempt(cohort, "recover", sent_request, sent["state_directory"], 30)
    observation = json.loads(raw)
    if (
        observation.get("schema") != "lattice.implementation-attempt-observation.v1"
        or observation.get("envelope") != request["envelope"]
    ):
        msg = "native recovery substituted the installed attempt envelope"
        raise ValueError(msg)
    result = observation.get("result", {})
    receipt = result.get("receipt")
    if (
        result.get("disposition") != "produced"
        or result.get("blocker") is not None
        or not isinstance(receipt, dict)
    ):
        msg = "only a complete native produced candidate can be exported"
        raise ValueError(msg)
    envelope = request["envelope"]
    if (
        receipt.get("schema") != "lattice.candidate-receipt.v1"
        or receipt.get("disposition") != "produced"
        or receipt.get("blockers") != []
    ):
        msg = "native host candidate receipt is incomplete or blocked"
        raise ValueError(msg)
    if any(
        receipt.get(field) != envelope[field]
        for field in ("work_id", "attempt_id", "workspace_id")
    ) or receipt.get("fence") != str(envelope["fence"]):
        msg = "native candidate receipt crosses work, attempt, fence or workspace"
        raise ValueError(msg)
    if (
        not LABEL.fullmatch(envelope["attempt_id"])
        or type(envelope["fence"]) is not int
        or envelope["fence"] < 1
    ):
        msg = "candidate export requires an exact safe attempt/fence"
        raise ValueError(msg)
    parent = Path(args.output_parent).resolve(strict=True)
    exported = parent / (envelope["attempt_id"] + "-" + str(envelope["fence"]))
    exported.mkdir(mode=0o750)
    candidate = exported / "candidate"
    stage_tree(workspace, candidate)
    # Kiln's capture admits exactly Git's file modes (0644/0755) for its
    # byte-exact receipt. The 0750 capture-group directories keep the files
    # away from everyone outside that group.
    for directory, _, files in os.walk(candidate):
        Path(directory).chmod(0o750)
        for name in files:
            path = Path(directory) / name
            path.chmod(0o755 if path.stat().st_mode & 0o111 else 0o644)
    write_document(exported / "host-receipt.json", receipt)
    (exported / "host-receipt.json").chmod(0o640)
    with (exported / "native-observation.json").open("xb") as output:
        output.write(raw)
        output.flush()
        os.fsync(output.fileno())
    (exported / "native-observation.json").chmod(0o640)
    return {
        "schema": "onix.kiln.candidate-export.v1",
        "candidate_root": str(candidate),
        "host_receipt": str(exported / "host-receipt.json"),
        "accepted": False,
        "qualification": "unqualified",
        "next": "independent native capture-candidate and verify",
    }


def validate_verifier_authority(
    authority: dict[str, Any],
    root: StrPath,
    worker_uid: int,
    cohort: dict[str, Any],
) -> dict[str, str]:
    expected = Path(root) / "verifier"
    if authority.get("worker_uid") != worker_uid:
        msg = "verification authority must bind the actual editing worker UID"
        raise ValueError(msg)
    if (
        Path(authority["repository_root"]) != expected / "repository"
        or Path(authority["scratch_root"]) != expected / "scratch"
    ):
        msg = "trusted verification roots must remain separate from worker and ledger state"
        raise ValueError(msg)
    git = cohort["entries"]["git"]
    if (
        immutable(authority["git"]["path"]) != immutable(git["resolved_path"])
        or authority["git"]["blake3"] != git["blake3"]
    ):
        msg = "verification Git program must match the admitted actual toolchain"
        raise ValueError(msg)
    return {"authority": "deployment-bound", "qualification": "unqualified"}


def prepare_disks(args: argparse.Namespace) -> dict[str, Any]:
    if not LABEL.fullmatch(args.reference) or args.generation < 1:
        msg = (
            "mutable disks require an exact execution reference and positive generation"
        )
        raise ValueError(msg)
    if not all(
        MIN_DISK_MIB <= size <= MAX_DISK_MIB
        for size in (args.workspace_mib, args.state_mib)
    ):
        msg = "mutable disk size exceeds the declared bound"
        raise ValueError(msg)
    directory = Path(args.directory)
    if (
        not directory.is_absolute()
        or directory.parent.resolve(strict=True) != directory.parent
    ):
        msg = "mutable disk parent must be absolute and canonical"
        raise ValueError(msg)
    parent = directory.parent.stat()
    if parent.st_uid != os.geteuid() or parent.st_mode & 0o022:
        msg = "mutable disk parent must be owned and not group/world writable"
        raise ValueError(msg)
    # Exclusive directory creation prevents accidental workspace reuse or
    # replacement of unknown effects. Interrupted formatting is retained blocked.
    directory.mkdir(mode=0o700)
    disks = {}
    for name, size in (("workspace", args.workspace_mib), ("state", args.state_mib)):
        path = directory / (name + ".raw")
        fd = os.open(path, os.O_RDWR | os.O_CREAT | os.O_EXCL, 0o600)
        try:
            os.ftruncate(fd, size * MIB_BYTES)
            os.fsync(fd)
        finally:
            os.close(fd)
        subprocess.run(
            ["mkfs.ext4", "-F", "-q", "-U", "random", "-m", "0", str(path)],
            check=True,
            timeout=120,
        )
        filesystem_id = subprocess.check_output(
            ["blkid", "-p", "-s", "UUID", "-o", "value", str(path)],
            text=True,
            timeout=10,
        ).strip()
        if not re.fullmatch(
            r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}", filesystem_id
        ):
            msg = "filesystem identity was not observed"
            raise ValueError(msg)
        disks[name] = {
            "path": str(path),
            "image_type": "raw",
            "filesystem": "ext4",
            "filesystem_uuid": filesystem_id,
            "size_mib": size,
            "generation": args.generation,
        }
    if disks["workspace"]["filesystem_uuid"] == disks["state"]["filesystem_uuid"]:
        msg = "workspace and state must have independent filesystem identities"
        raise ValueError(msg)
    result = {
        "schema": "onix.lattice.mutable-disks.v1",
        "reference": args.reference,
        "disks": disks,
        "guest_identity": "generated-on-first-boot-not-observed",
        "credentials": "none-provisioned",
        "placement_authority": False,
        "qualification": "unqualified",
    }
    write_document(directory / "disks.json", result)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    observation = commands.add_parser("observe")
    for option in ("manifest", "host", "output", "retention-root"):
        observation.add_argument("--" + option, required=True)
    comparison = commands.add_parser("compare-placements")
    comparison.add_argument("--source", required=True)
    comparison.add_argument("--destination", required=True)
    retention = commands.add_parser("retain")
    for option in ("guest", "reference", "roots"):
        retention.add_argument("--" + option, required=True)
    retention.add_argument("--kind", choices=("live", "checkpoint"), required=True)
    policy = commands.add_parser("policy")
    policy.add_argument("--configuration", required=True)
    policy.add_argument("--repository", action="append", required=True)
    policy.add_argument("--work-class", action="append", required=True)
    policy.add_argument("--state-root", required=True)
    policy.add_argument("--cohort", required=True)
    for name in (
        "check-attempt",
        "export-candidate",
        "cancel-worker",
        "binding-path",
        "materialize-binding",
        "claim-attempt",
        "prepare-fixture-intake",
        "current-claim",
    ):
        attempt = commands.add_parser(name)
        for option in ("bundle", "cohort"):
            attempt.add_argument("--" + option, required=True)
        attempt.add_argument("--configuration", required=True)
        attempt.add_argument("--state-root", required=True)
        attempt.add_argument("--coordinator-uid", type=int, default=930)
        attempt.add_argument(
            "--stage", choices=tuple(STAGE_ENTRIES), default="dispatch"
        )
        attempt.add_argument(
            "--workspace-parent",
            required=name
            in ("check-attempt", "export-candidate", "materialize-binding"),
        )
        # The env-reference name the request's broker credential must use; set
        # only when the dispatcher loads a model credential.
        attempt.add_argument("--model-credential-env")
        # Kiln's local-operator authority for admission-bound owner commands.
        attempt.add_argument("--local-operator")
        if name == "materialize-binding":
            attempt.add_argument("--worker-uid", type=int, required=True)
            attempt.add_argument(
                "--phase",
                choices=("observe", "stage", "execute", "seal"),
                required=True,
            )
        if name == "claim-attempt":
            attempt.add_argument("--lease-ms", type=int, required=True)
            attempt.add_argument("--phase", choices=("native", "seal"), required=True)
        if name in ("export-candidate", "cancel-worker"):
            # The configured Lattice state root; the sent request must name it.
            attempt.add_argument("--state", required=True)
        if name == "export-candidate":
            attempt.add_argument("--output-parent", required=True)
    authority = commands.add_parser("verifier-authority")
    for option in ("authority", "root", "cohort"):
        authority.add_argument("--" + option, required=True)
    authority.add_argument("--worker-uid", type=int, required=True)
    disks = commands.add_parser("prepare-disks")
    for option in ("directory", "reference"):
        disks.add_argument("--" + option, required=True)
    for option in ("generation", "workspace-mib", "state-mib"):
        disks.add_argument("--" + option, required=True, type=int)
    args = parser.parse_args()
    try:
        if args.command == "observe":
            result = observe(args)
        elif args.command == "compare-placements":
            result = compare_placements(
                document(args.source), document(args.destination)
            )
        elif args.command == "retain":
            result = retain(args)
        elif args.command == "binding-path":
            result = runtime_binding(args)
        elif args.command == "current-claim":
            current = _current(args)["attempt"]
            result = {"attempt": current["identity"], "fence": current["fence"]}
        elif args.command == "claim-attempt":
            result = claim_attempt(args)
        elif args.command == "prepare-fixture-intake":
            result = prepare_fixture_intake(args)
        elif args.command == "materialize-binding":
            result = materialize_binding(args)
        elif args.command == "check-attempt":
            result = check_attempt(args)
        elif args.command == "export-candidate":
            result = export_candidate(args)
        elif args.command == "cancel-worker":
            result = cancel_worker(args)
        elif args.command == "verifier-authority":
            result = validate_verifier_authority(
                document(args.authority),
                args.root,
                args.worker_uid,
                document(Path(args.cohort) / "manifest.json"),
            )
        elif args.command == "prepare-disks":
            result = prepare_disks(args)
        else:
            result = validate_policy(
                args.configuration,
                args.repository,
                args.work_class,
                args.state_root,
                document(Path(args.cohort) / "manifest.json"),
            )
        print(json.dumps(result, sort_keys=True))
    except (
        ValueError,
        KeyError,
        TypeError,
        OSError,
        subprocess.SubprocessError,
    ) as error:
        print(
            json.dumps({"qualification": "failed", "error": str(error)}),
            file=sys.stderr,
        )
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
