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
from pathlib import Path
import pwd
import re
import shutil
import stat
import subprocess
import sys
import time

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
COHORT_EXECUTABLES = frozenset({"coordinator", "verifier", "dispatch", "cairn_intake", "lattice", "cairn", "worker", "sandbox", "nix", "git"})


def document(path):
    with Path(path).open("rb") as source:
        data = source.read(MAX_DOCUMENT_BYTES + 1)
    if len(data) > MAX_DOCUMENT_BYTES:
        raise ValueError("qualification document exceeds bound")
    result = json.loads(data)
    if not isinstance(result, dict):
        raise ValueError("qualification document must be an object")
    return result


def digest(path):
    value = subprocess.check_output(["b3sum", "--no-names", str(path)], text=True, timeout=60).strip()
    if not DIGEST.fullmatch(value):
        raise ValueError("invalid digest tool output")
    return value


def immutable(path):
    resolved = Path(path).resolve(strict=True)
    if not str(resolved).startswith("/nix/store/") or not resolved.is_file():
        raise ValueError("expected immutable store file")
    return resolved


def immutable_tree(path):
    resolved = Path(path).resolve(strict=True)
    if not str(resolved).startswith("/nix/store/") or not resolved.is_dir():
        raise ValueError("expected immutable store directory")
    return resolved


def verify_manifest(path):
    manifest = document(path)
    if manifest.get("schema") != "onix.lattice.worker-guest.v1":
        raise ValueError("unsupported guest manifest")
    if manifest.get("architecture") != "x86_64-linux":
        raise ValueError("unsupported guest architecture")
    expected = {"vmlinux", "initrd", "root.raw", "launch.json", "cloud-hypervisor"}
    if set(manifest.get("entries", {})) != expected:
        raise ValueError("guest manifest entries differ")
    for entry in manifest["entries"].values():
        if not DIGEST.fullmatch(entry.get("blake3", "")):
            raise ValueError("malformed immutable identity")
        actual = immutable(entry["path"])
        if digest(actual) != entry["blake3"]:
            raise ValueError("immutable guest/VMM identity differs")
    launch = document(manifest["entries"]["launch.json"]["path"])
    if launch != manifest.get("launch"):
        raise ValueError("generated launch configuration differs")
    for field, entry_name in (("kernel", "vmlinux"), ("initrd", "initrd"), ("root", "root.raw")):
        if immutable(launch[field]) != immutable(manifest["entries"][entry_name]["path"]):
            raise ValueError("launch points to a different actual guest artifact")
    if launch.get("disk_image_type") != "raw" or launch.get("network") != "none":
        raise ValueError("unsupported disk or network profile")
    if launch.get("memoryBacking") != "private" or launch.get("mergeable") is not False or launch.get("hugepages") is not False or launch.get("memory_source") != "anonymous":
        raise ValueError("unsupported memory profile")
    if launch.get("migration_mode") != "precopy" or launch.get("postcopy") is not False or launch.get("memfds") is not False:
        raise ValueError("unsupported migration mode")
    if not 1 <= launch.get("cpus", 0) <= 8 or not 512 <= launch.get("memoryMiB", 0) <= 16384:
        raise ValueError("guest resource bounds exceeded")
    cohort_path = immutable(manifest["cohort_manifest"])
    if digest(cohort_path) != manifest.get("cohort_blake3"):
        raise ValueError("runtime/tool/workflow cohort differs")
    cohort = document(cohort_path)
    if cohort.get("schema") != "onix.kiln.implementation-cohort.v1":
        raise ValueError("unsupported runtime cohort")
    if set(cohort.get("entries", {})) != COHORT_EXECUTABLES or cohort.get("workerAdapter") != "omp":
        raise ValueError("runtime/tool/worker cohort is incomplete or unsupported")
    if digest(immutable(cohort["workflow"])) != cohort.get("workflow_blake3"):
        raise ValueError("workflow identity differs")
    for entry in cohort["entries"].values():
        if digest(immutable(entry["resolved_path"])) != entry["blake3"]:
            raise ValueError("runtime/tool executable identity differs")
    vmm = manifest["entries"]["cloud-hypervisor"]["path"]
    with Path(vmm).open("rb") as stream:
        header = stream.read(20)
    if header[:6] != b"\x7fELF\x02\x01" or header[18:20] != b"\x3e\x00":
        raise ValueError("actual CH identity cannot be a delegating wrapper")
    version = subprocess.check_output([vmm, "--version"], text=True, timeout=10).strip()
    if version != manifest.get("vmm_actual_version") or not re.fullmatch(r"cloud-hypervisor v54\.0(?:\.\d+)?(?:[-+ ].*)?", version):
        raise ValueError("actual VMM version differs or is unsupported")
    return manifest


def write_document(path, value):
    target = Path(path)
    target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    # Qualification does not overwrite retained evidence, even on repeated runs.
    with target.open("x", encoding="utf-8") as output:
        json.dump(value, output, sort_keys=True, indent=2)
        output.write("\n")
        output.flush()
        os.fsync(output.fileno())


def observe(args):
    if not LABEL.fullmatch(args.host):
        raise ValueError("invalid explicit host identity")
    manifest = verify_manifest(args.manifest)
    guest = Path(args.manifest).resolve().parent
    # Nix's store metadata verifies the staged transitive closure. A matching
    # wrapper name/version alone is never sufficient, nor is TCP reachability.
    closure = subprocess.check_output(["nix-store", "--query", "--requisites", str(guest)], text=True, timeout=120).splitlines()
    if not closure:
        raise ValueError("guest closure is not registered")
    for path in closure:
        subprocess.run(["nix-store", "--verify-path", path], check=True, stdout=subprocess.DEVNULL, timeout=120)
    retention_root = Path(args.retention_root)
    if not retention_root.is_absolute() or not retention_root.is_symlink() or retention_root.resolve(strict=True) != guest:
        raise ValueError("placement requires its exact live/checkpoint environment root")
    roots = subprocess.check_output(["nix-store", "--query", "--roots", str(guest)], text=True, timeout=120).splitlines()
    if not any(line.rpartition(" -> ")[0] == str(retention_root) for line in roots):
        raise ValueError("staged closure has no observed registered retention root")
    kvm = Path("/dev/kvm").exists() and os.access("/dev/kvm", os.R_OK | os.W_OK)
    value = {
        "schema": "onix.lattice.placement-observation.v1", "host": args.host,
        "guest": str(guest), "manifest_blake3": digest(args.manifest),
        "vmm": manifest["entries"]["cloud-hypervisor"],
        "vmm_actual_version": manifest["vmm_actual_version"],
        "launch_blake3": manifest["entries"]["launch.json"]["blake3"],
        "closure": sorted(closure), "closure_verified": True,
        "retention_root": str(retention_root), "retention_observed": True,
        "kvm": "accessible-unqualified" if kvm else "unsupported",
        "qualification": "unqualified", "placement_authority": False,
        "non_claims": ["no boot/migration/restore executed", "no allocation or model admission granted", "observation is not current placement or effect fencing"],
    }
    write_document(args.output, value)
    return value


def compare_placements(source, destination):
    for item in (source, destination):
        if item.get("schema") != "onix.lattice.placement-observation.v1" or item.get("closure_verified") is not True or item.get("retention_observed") is not True:
            raise ValueError("missing verified staging or retention observation")
        if item.get("kvm") != "accessible-unqualified":
            raise ValueError("KVM unavailable: unsupported, not qualified")
    if source.get("host") == destination.get("host"):
        raise ValueError("two distinct placement hosts are required")
    for field in ("guest", "manifest_blake3", "vmm", "vmm_actual_version", "launch_blake3", "closure"):
        if source.get(field) != destination.get(field):
            raise ValueError("placement cohort mismatch: " + field)
    return {"schema": "onix.lattice.placement-preflight.v1", "compatible": True,
            "qualification": "unqualified", "dispatch_allowed": False,
            "remaining": ["fresh authoritative placement/disk/effect fences", "exact-profile boot/migration/restore/memory evidence", "qualified retained guest and host channels"]}


def retain(args):
    if not LABEL.fullmatch(args.reference):
        raise ValueError("invalid attempt/checkpoint reference")
    guest = Path(args.guest).resolve(strict=True)
    if not str(guest).startswith("/nix/store/") or not (guest / "manifest.json").is_file():
        raise ValueError("only an immutable registered guest closure may be retained")
    verify_manifest(guest / "manifest.json")
    roots = Path(args.roots)
    if not roots.is_absolute() or roots.is_symlink():
        raise ValueError("root directory must be an absolute real directory")
    roots.mkdir(mode=0o700, parents=True, exist_ok=True)
    root = roots / (args.kind + "-" + args.reference)
    with (roots / ".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if root.is_symlink():
            if root.resolve() != guest:
                raise ValueError("retention reference already binds another environment")
        elif root.exists():
            raise ValueError("retention reference is not a GC root")
        else:
            subprocess.run(["nix-store", "--add-root", str(root), "--indirect", "--realise", str(guest)], check=True, timeout=120)
        if not root.is_symlink() or root.resolve(strict=True) != guest:
            raise ValueError("Nix did not establish the requested GC root")
    return {"schema": "onix.lattice.environment-retention.v1", "kind": args.kind,
            "reference": args.reference, "root": str(root), "guest": str(guest),
            "release": "only after owner retires every live/checkpoint reference; never on process exit"}


def kiln_policy_check(cohort, policy_path, enrollment_path):
    """Kiln's own intake preflight: poll's parser and validation plus a dry admission probe."""
    entry = cohort["entries"]["coordinator"]
    program = immutable(entry["resolved_path"])
    if digest(program) != entry["blake3"]:
        raise ValueError("canonical controller executable changed")
    result = subprocess.run([str(program), "policy-check", "--policy", str(policy_path), "--enrollment", str(enrollment_path)],
                            capture_output=True, text=True, timeout=60)
    if result.returncode != 0:
        raise ValueError("Kiln refused the intake policy: " + result.stderr.strip()[:2048])
    return json.loads(result.stdout)


def validate_policy(configuration, repositories, classes, state_root, cohort, kiln_check=kiln_policy_check):
    config = Path(configuration)
    enrollment = document(config / "enrollment.json")
    if set(enrollment) != {"repositories", "actors"} or sorted(enrollment["repositories"]) != sorted(repositories) or not enrollment["actors"]:
        raise ValueError("enrollment must exactly match admitted repositories and explicit actors")
    # Kiln owns the policy's shape and meaning; only deployment limits are checked here.
    kiln_check(cohort, config / "github-policy.json", config / "enrollment.json")
    policy = document(config / "github-policy.json")
    repo = policy["repository"]
    # GitHub matches repository names case-insensitively (Kiln EventPolicy).
    identity = (repo["owner"] + "/" + repo["repository"]).lower()
    if identity not in {repository.lower() for repository in repositories}:
        raise ValueError("intake policy is not enrolled")
    if policy.get("terminal_policy") != "verified_pull_request":
        raise ValueError("this deployment only admits verified-PR delivery")
    budget = policy["budget"]
    if not 1 <= budget["attempts"] <= 8 or not 1 <= budget["minutes_per_attempt"] <= 1440:
        raise ValueError("implementation budget exceeds deployment limits")
    scope = document(config / "work-class.json")
    if scope.get("class") not in classes or str(scope.get("repository")).lower() != identity:
        raise ValueError("policy is not bound to an admitted work class/repository")
    if scope.get("policy_blake3") != digest(config / "github-policy.json"):
        raise ValueError("work class does not bind the actual intake policy")
    transport = document(config / "worker-transport-profile.json")
    if transport.get("schema") != "kiln.lattice-implementation-cli.v2":
        raise ValueError("unsupported actual worker transport profile")
    lattice = cohort["entries"]["lattice"]
    if immutable(transport["lattice_program"]) != immutable(lattice["resolved_path"]) or transport["executable_blake3"] != lattice["blake3"]:
        raise ValueError("worker transport must bind the actual immutable Lattice program")
    if transport.get("state_directory") != state_root + "/lattice/implementation" or transport.get("output_directory") != state_root + "/lattice/observations":
        raise ValueError("Lattice state/output must remain separate from the Kiln ledger and verifier")
    return {"policy": "admitted", "qualification": "unqualified"}


def _program_entry(value, cohort, name):
    entry = cohort["entries"][name]
    if not isinstance(value, dict) or immutable(value["path"]) != immutable(entry["resolved_path"]) or value.get("blake3") != entry["blake3"]:
        raise ValueError(f"model broker {name} does not match the admitted cohort")


def _secret_reference(value):
    """Parse Lattice's `SecretRef { provider, key, field: Option<String> }`.

    Lattice serializes the unset optional `field` as null (no
    skip_serializing_if), so its canonical form is `{"field": null, ...}`;
    absent and null both mean unset. Any other member is refused. An absent
    or null reference (no credential) parses to None.
    """
    if value is None:
        return None
    if not isinstance(value, dict) or not {"provider", "key"} <= set(value) <= {"provider", "key", "field"}:
        raise ValueError("model credential reference has missing or unexpected members")
    field = value.get("field")
    if not isinstance(value["provider"], str) or not isinstance(value["key"], str) or not (field is None or isinstance(field, str)):
        raise ValueError("model credential reference members have the wrong type")
    return (value["provider"], value["key"], field)


def validate_attempt(request, cohort, workspace_parent, credential_env=None):
    if request.get("schema") != "lattice.implementation-attempt-run.v3":
        raise ValueError("unsupported actual Lattice implementation request schema")
    workspace_id = request["envelope"]["workspace_id"]
    if not LABEL.fullmatch(workspace_id):
        raise ValueError("workspace identity is not a safe per-attempt label")
    parent = Path(workspace_parent).resolve(strict=True)
    workspace = parent / workspace_id
    if Path(request["workspace_root"]) != workspace or workspace.is_symlink():
        raise ValueError("request must bind its independent exact workspace directory")
    # Lattice v3: the worker never has a network device; its only route is the
    # attempt-local model broker the trusted host dispatcher runs.
    if request.get("network") is not False or "network_namespace" in request:
        raise ValueError("the worker must have no network grant; only the attempt-local model broker is admitted")
    host_local = {"kind": "host_local"}
    binding = request.get("execution_binding")
    if request.get("worker_compute") != host_local or not isinstance(binding, dict) or binding.get("compute") != host_local:
        raise ValueError("this deployment admits only host-local worker compute")
    omp = request["omp"]
    broker = omp.get("model_broker")
    if not isinstance(broker, dict) or broker.get("schema") != "lattice.candidate-model-broker.v1":
        raise ValueError("the worker request must select Lattice's attempt-local model broker")
    endpoint = broker.get("endpoint")
    if not isinstance(endpoint, str) or not (endpoint.startswith("https://") or endpoint.startswith("http://127.0.0.1:")):
        raise ValueError("model endpoint must be HTTPS or the dispatcher namespace's literal loopback")
    if omp.get("model") != "lattice/" + str(broker.get("model")):
        raise ValueError("OMP must select exactly the broker's single wire model")
    expected_credential = None if credential_env is None else ("env", credential_env, None)
    if _secret_reference(broker.get("credential")) != expected_credential:
        raise ValueError("model credential reference must match the dispatcher's configured runtime credential")
    _program_entry(broker.get("relay"), cohort, "relay")
    _program_entry(broker.get("shell"), cohort, "shell")
    if broker.get("sandbox_blake3") != cohort["entries"]["sandbox"]["blake3"]:
        raise ValueError("model broker sandbox identity does not match the admitted cohort")
    if type(request.get("output_limit_bytes")) is not int or not 1 <= request["output_limit_bytes"] <= MAX_OUTPUT_BYTES:
        raise ValueError("worker output limit exceeds the deployment bound")
    for field, entry_name in (("program", "worker"), ("sandbox_program", "sandbox")):
        entry = cohort["entries"][entry_name]
        actual = immutable(request[field])
        if actual != immutable(entry["resolved_path"]) or digest(actual) != entry["blake3"]:
            raise ValueError("worker/provider executable does not match the admitted cohort")
    if request["omp"]["revision"] != cohort["revisions"]["worker"] or request["omp"]["executable_blake3"] != cohort["entries"]["worker"]["blake3"]:
        raise ValueError("OMP profile does not match actual selected worker bytes/revision")
    for field in ("read_paths", "write_paths"):
        if not isinstance(request[field], list) or not request[field] or len(request[field]) > MAX_SOURCE_FILES:
            raise ValueError("explicit bounded workspace read/write grants are required")
        for item in request[field]:
            path = Path(item)
            if not isinstance(item, str) or not path.parts or path.is_absolute() or ".." in path.parts or item.startswith("\\"):
                raise ValueError("workspace grants must use native canonical relative paths")
            if field == "write_paths" and path.parts[0] in (".git", ".jj", ".omp", ".pi"):
                raise ValueError("worker cannot mutate VCS or harness/model configuration")
    for write in request["write_paths"]:
        if not any(write == read or write.startswith(read + "/") for read in request["read_paths"]):
            raise ValueError("native workspace write grant must be covered by a read grant")
    return workspace


def stage_tree(source, workspace):
    """Copy immutable input once; never overwrite possible worker effects."""
    if workspace.exists() or workspace.is_symlink():
        raise ValueError("workspace already exists; recover durable intent instead of re-preparing")
    # Exclusive creation never replaces another preparation, even if empty.
    # Crashes retain partial input for owner retirement; retries never recopy it.
    workspace.mkdir(mode=0o700)
    files = 0
    total = 0
    entries = 0
    for directory, directories, names in os.walk(source, followlinks=False):
        entries += len(directories) + len(names)
        if entries > MAX_SOURCE_FILES:
            raise ValueError("source tree entry bound exceeded")
        relative = Path(directory).relative_to(source)
        destination = workspace / relative
        destination.mkdir(mode=0o700, parents=True, exist_ok=True)
        for name in directories:
            item = Path(directory) / name
            if item.is_symlink() or (relative == Path(".") and name in (".git", ".jj")):
                raise ValueError("source contains a symlink or root VCS metadata")
        for name in names:
            if relative == Path(".") and name in (".git", ".jj"):
                raise ValueError("source contains root VCS metadata")
            item = Path(directory) / name
            metadata = item.lstat()
            files += 1
            total += metadata.st_size
            if not stat.S_ISREG(metadata.st_mode) or files > MAX_SOURCE_FILES or metadata.st_size > MAX_SOURCE_FILE_BYTES or total > MAX_SOURCE_BYTES:
                raise ValueError("source file type/count/byte bound exceeded")
            target = destination / name
            shutil.copyfile(item, target)
            target.chmod(0o755 if metadata.st_mode & 0o111 else 0o644)
    # Normalize immutable-store transport permissions into this execution before
    # native Lattice recomputes/admit its base snapshot and records file modes.


def _protected_directory(path, owner_uid=0):
    path = Path(path)
    metadata = path.lstat()
    if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != owner_uid or metadata.st_mode & 0o022:
        raise ValueError(f"protected directory has unsafe type, owner or permissions: {path}")
    return path


def _regular_owned(path, owner_uid, writable=False):
    path = Path(path)
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(descriptor, "rb") as source:
        metadata = os.fstat(source.fileno())
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != owner_uid or metadata.st_mode & 0o022:
            raise ValueError(f"runtime binding file has unsafe type, owner or permissions: {path}")
        if not writable and metadata.st_mode & 0o200:
            raise ValueError(f"runtime binding file remains owner-writable: {path}")
        if metadata.st_size > MAX_DOCUMENT_BYTES:
            raise ValueError("runtime binding document exceeds byte bound")
        return source.read(MAX_DOCUMENT_BYTES + 1)


def _owned_document(path, owner_uid=0):
    value = json.loads(_regular_owned(path, owner_uid))
    if not isinstance(value, dict):
        raise ValueError("runtime binding document must be an object")
    return value


def _controller(args):
    state = _protected_directory(Path(args.state_root))
    return _protected_directory(state / "controller")


def _operator(args):
    """Kiln's explicit local-operator authority, when the deployment names one."""
    operator = getattr(args, "local_operator", None)
    return ["--local-operator", operator] if operator else []


def _native(args, command, *flags, raw=False):
    cohort = document(immutable(Path(args.cohort) / "manifest.json"))
    entry = cohort["entries"]["coordinator"]
    program = immutable(entry["resolved_path"])
    if digest(program) != entry["blake3"]:
        raise ValueError("canonical controller executable changed")
    # Kiln runs only as the coordinator (the unit's User=). Root phases never
    # switch accounts: NoNewPrivileges keeps them without CAP_SETUID.
    if os.geteuid() == 0:
        raise ValueError("the canonical owner never runs as root")
    output = subprocess.check_output([str(program), command, "--database", str(Path(args.state_root) / "kiln/work.sqlite"),
                                      "--enrollment", str(immutable(Path(args.configuration) / "enrollment.json")),
                                      *map(str, flags)], timeout=60)
    if len(output) > MAX_DOCUMENT_BYTES:
        raise ValueError("canonical owner output exceeds byte bound")
    return output if raw else json.loads(output)


def _retained_claim(args):
    controller = _controller(args)
    reference = _owned_document(controller / "current.json")
    label = reference.get("claim")
    if not isinstance(label, str) or not re.fullmatch(r"[0-9a-f]{64}-[1-9][0-9]*\.json", label):
        raise ValueError("current claim reference is malformed")
    _protected_directory(controller / "claims")
    retained = _owned_document(controller / "claims" / label)
    attempt, fence = retained["identity"], retained["fence"]
    if not DIGEST.fullmatch(attempt) or type(fence) is not int or fence < 1:
        raise ValueError("canonical claim identity or fence is malformed")
    return retained


def _current(args, observation=None):
    """The canonical owner's current view of the retained claim.

    Non-root phases ask Kiln directly. Root phases never run Kiln (they cannot
    switch to the coordinator under NoNewPrivileges); they take the observation
    a coordinator phase of the same unit just retrieved and check it the same way.
    """
    retained = _retained_claim(args)
    if observation is None:
        current = _native(args, "inspect-attempt", "--attempt", retained["identity"], "--fence", retained["fence"])
    else:
        current = observation
    claim = current["attempt"]
    if any(claim.get(key) != retained.get(key) for key in ("identity", "fence", "work_identity", "work_revision", "claimed_at_ms")):
        raise ValueError("current owner claim differs from retained claim reference")
    return current


def _seal(path, value):
    write_document(path, value)
    Path(path).chmod(0o444)


# Hand-off between the phases of one controller unit: a coordinator phase (the
# unit's User=) runs Kiln and writes here; a root phase ("!" prefix: same
# sandbox, no User=) validates and seals into root-owned controller state.
# The spool is root-owned, sticky and ledger-group writable: each phase
# replaces only its own documents and every read checks the writer's UID.
def _spool(args):
    spool = Path(args.state_root) / "controller-spool"
    metadata = spool.lstat()
    if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != 0 or metadata.st_mode & 0o007:
        raise ValueError("controller spool has unsafe type, owner or permissions")
    return spool


def _spool_write(args, name, value):
    path = _spool(args) / name
    path.unlink(missing_ok=True)
    write_document(path, value)
    path.chmod(0o440 if os.geteuid() else 0o444)


def _spool_read(args, name, owner_uid):
    """Read a spool document written by exactly the expected phase account."""
    path = _spool(args) / name
    value = json.loads(_regular_owned(path, owner_uid, writable=False))
    if not isinstance(value, dict):
        raise ValueError("controller spool document must be an object")
    return value


def _spool_clear(args, *names):
    for name in names:
        (_spool(args) / name).unlink(missing_ok=True)


def _require_root(phase):
    if os.geteuid() != 0:
        raise ValueError(f"the {phase} phase belongs to the protected controller")
    # Sealed controller state is read by the other stage accounts.
    os.umask(0o022)


def claim_attempt(args):
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
        if claim.get("schema") != "kiln.implementation-attempt.v2" or not DIGEST.fullmatch(claim.get("identity", "")) or type(claim.get("fence")) is not int or claim["fence"] < 1:
            raise ValueError("canonical owner did not return an exact actual claim")
        leaf = f"{claim['identity']}-{claim['fence']}.json"
        _seal(claims / leaf, claim)
        temporary = controller / "current.new"
        _seal(temporary, {"claim": leaf})
        os.replace(temporary, controller / "current.json")
        return {"claimed": True, "claim": str(claims / leaf), "attempt": claim["identity"], "fence": claim["fence"]}


def prepare_fixture_intake(args):
    # Runs as the coordinator (the unit's User=); it only drives Kiln's
    # explicitly synthetic helper against the ledger, never root state.
    if os.geteuid() == 0:
        raise ValueError("fixture intake runs as the coordinator, not root")
    spec = document(immutable(Path(args.bundle) / "runtime-template.json"))
    if spec.get("schema") != "onix.kiln.runtime-template.v1" or spec.get("scope") != "synthetic-local-only":
        raise ValueError("fixture-only intake cannot admit live provider authority")
    helper = spec["fixture_admission"]
    program = immutable(helper["path"])
    if digest(program) != helper["blake3"]:
        raise ValueError("required synthetic intake helper executable changed")
    raw = subprocess.check_output([str(program), "prepare-intake", "--database", str(Path(args.state_root) / "kiln/work.sqlite"),
          "--enrollment", str(immutable(Path(args.configuration) / "enrollment.json"))], timeout=60, umask=0o007)
    if len(raw) > MAX_DOCUMENT_BYTES:
        raise ValueError("synthetic intake helper output exceeds bound")
    result = json.loads(raw)
    if result.get("schema") != "kiln.scripted-intake-binding.v1" or result.get("scope") != "synthetic-local-only":
        raise ValueError("helper did not return explicitly synthetic intake preparation")
    return result


def _expand_runtime(value, bindings):
    if isinstance(value, dict):
        if set(value) == {"runtime"}:
            key = value["runtime"]
            if key not in bindings:
                raise ValueError(f"unsupported runtime binding selector: {key}")
            return bindings[key]
        return {key: _expand_runtime(item, bindings) for key, item in value.items()}
    if isinstance(value, list):
        return [_expand_runtime(item, bindings) for item in value]
    return value


# Kiln's owner JSON spells WorkSourceKind in serde snake case; the Lattice
# request and Kiln's own dispatcher check (kiln-adapter-lattice worker.rs) use
# these wire names.
LATTICE_SOURCE_KINDS = {"git_hub_issue": "github_issue", "cairn_task": "cairn_task", "cairn_artifact": "cairn_artifact"}


def _lattice_source_kind(kind):
    if kind not in LATTICE_SOURCE_KINDS:
        raise ValueError(f"unsupported canonical work source kind: {kind}")
    return LATTICE_SOURCE_KINDS[kind]


def _binding_context(args, observation=None):
    template = immutable(Path(args.bundle) / "runtime-template.json")
    spec = document(template)
    if spec.get("schema") != "onix.kiln.runtime-template.v1":
        raise ValueError("immutable runtime template schema is unsupported")
    current = _current(args, observation)
    claim = current["attempt"]
    bindings = {"attempt": claim["identity"], "fence": claim["fence"], "work": claim["work_identity"],
                "work_revision": claim["work_revision"], "lease_until_ms": claim["lease_until_ms"],
                "claimed_at_ms": claim["claimed_at_ms"], "acceptance_digest": current["acceptance_digest"],
                "verification_profile": current["work"]["verification_profile"]}
    source = current["work"]["aliases"][0]
    # The scripted fixture keeps Kiln's fixed 3-minute window; a live template
    # may name its own bounded window, still capped by the current lease.
    window = spec.get("attempt_window_ms", 180_000)
    if type(window) is not int or not 60_000 <= window <= 3_600_000:
        raise ValueError("attempt window must be 1..60 minutes")
    bindings.update({"workspace": claim["identity"],
                     "workspace_root": str(Path(args.state_root) / "workspaces" / claim["identity"]),
                     "base": claim["base"], "base_oid": claim["base"]["native_id"],
                     "source_kind": _lattice_source_kind(source["kind"]), "source_id": source["native_id"], "readiness_snapshot": source["version"],
                     "expires_at_ms": min(claim["lease_until_ms"], claim["claimed_at_ms"] + window)})
    bindings["verification_profile_document"] = document(immutable(Path(args.bundle) / "verification-profile.json"))
    if current.get("publication_branch") is not None:
        bindings["publication_branch"] = current["publication_branch"]
    return template, spec, current, bindings


def _fixture_execution(args, spec, claim, prepared, plan):
    """Kiln's explicit scripted helper binds needs/plan/owner grants natively (as the coordinator)."""
    if spec.get("scope") != "synthetic-local-only":
        raise ValueError("fixture admission cannot grant live provider authority")
    helper = spec["fixture_admission"]
    program = immutable(helper["path"])
    if digest(program) != helper["blake3"]:
        raise ValueError("required synthetic admission helper executable changed")
    plan_seed = _spool(args) / "dispatch-plan-seed.json"
    plan_seed.unlink(missing_ok=True)
    write_document(plan_seed, plan)
    try:
        raw = subprocess.check_output([str(program), "bind-execution", "--database", str(Path(args.state_root) / "kiln/work.sqlite"),
             "--enrollment", str(immutable(Path(args.configuration) / "enrollment.json")),
             "--attempt", claim["identity"], "--fence", str(claim["fence"]),
             "--worker-request", str(prepared), "--dispatch-plan-template", str(plan_seed)], timeout=60, umask=0o007)
    finally:
        plan_seed.unlink(missing_ok=True)
    if len(raw) > MAX_DOCUMENT_BYTES:
        raise ValueError("synthetic admission helper output exceeds bound")
    admitted = json.loads(raw)
    if admitted.get("schema") != "kiln.scripted-execution-binding.v2" or admitted.get("scope") != "synthetic-local-only":
        raise ValueError("helper did not return an explicitly synthetic typed execution binding")
    seed = admitted["worker_seed"]
    if seed.get("dispatch_plan") != admitted["dispatch_plan_identity"]:
        raise ValueError("helper seed does not name its own admitted dispatch plan")
    return seed, admitted["dispatch_plan"], admitted["admission_observations"]


def _live_execution(args, spec, claim, request, plan, bindings):
    """Bind the live route through the native owner (as the coordinator): needs, plan, current grants.

    The host-owner reservation is retained beforehand by `host-owner-reserve`;
    this never mints a grant.
    """
    live = spec.get("live_execution")
    if not isinstance(live, dict) or set(live) != {"needs", "attempt_binding"}:
        raise ValueError("live dispatch template requires explicit work needs and provider fact references")
    scratch = _spool(args) / f"scratch-{claim['identity']}-{claim['fence']}"
    shutil.rmtree(scratch, ignore_errors=True)
    scratch.mkdir(mode=0o700)
    try:
        needs_seed = scratch / "needs-seed.json"
        write_document(needs_seed, _expand_runtime(live["needs"], bindings))
        needs = scratch / "needs.json"
        _native(args, "prepare-needs", "--work", claim["work_identity"], "--needs-file", needs_seed, "--output", needs, *_operator(args))
        attachment = document(needs)
        _native(args, "attach-needs", "--needs-file", needs, *_operator(args), raw=True)
        bindings["route_identity"] = request["execution_binding"]["model_routes"]["routes"][0]["route_identity"]
        plan["execution"] = {"requirements": attachment,
                             "attempt": _expand_runtime(live["attempt_binding"], bindings),
                             "native_request_profile": bindings["worker_profile"]}
        plan_path = scratch / "dispatch-plan.json"
        write_document(plan_path, plan)
        reservation = _native(args, "reserve-plan", "--plan-file", plan_path, *_operator(args))
    finally:
        shutil.rmtree(scratch)
    if not DIGEST.fullmatch(str(reservation.get("plan"))):
        raise ValueError("native reservation did not return the admitted plan identity")
    seed = json.loads(json.dumps(request))
    seed["envelope"]["policy_digest"] = attachment["policy_identity"]
    seed["dispatch_plan"] = reservation["plan"]
    seed["admitted_envelope"] = ""
    now = time.time_ns() // 1_000_000
    status = _native(args, "admission-status")
    observations = [item for item in status.get("eligibility", {}).values() if item["valid_until_ms"] >= now]
    if not observations:
        raise ValueError("no fresh owner eligibility observation is retained for this attempt")
    return seed, plan, observations


def _binding_summary(destination, claim, manifest):
    return {"path": str(destination), "attempt": claim["identity"], "fence": claim["fence"],
            "request_blake3": manifest["request_blake3"], "qualification": "scripted-unqualified"}


def _lattice(cohort):
    lattice = immutable(cohort["entries"]["lattice"]["resolved_path"])
    if digest(lattice) != cohort["entries"]["lattice"]["blake3"]:
        raise ValueError("native Lattice preparation executable changed")
    return lattice


def materialize_binding(args):
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
            raise ValueError("the observe phase runs as the coordinator")
        _spool_clear(args, observation_name, "dispatch-execution.json")
        current = _current(args)
        _spool_write(args, observation_name, current)
        return {"phase": "observe", "attempt": current["attempt"]["identity"], "fence": current["attempt"]["fence"]}
    if args.phase == "execute":
        if os.geteuid() == 0 or args.stage != "dispatch":
            raise ValueError("the execute phase runs as the coordinator for dispatch")
        staged = _spool_read(args, "dispatch-stage.json", 0)
        if staged.get("bound"):
            _spool_write(args, "dispatch-execution.json", {"bound": True})
            return {"phase": "execute", "bound": True}
        spec = document(immutable(Path(args.bundle) / "runtime-template.json"))
        if "fixture_admission" in spec:
            seed_request, plan, observations = _fixture_execution(args, spec, staged["claim"], staged["prepared"], staged["plan"])
        else:
            seed_request, plan, observations = _live_execution(args, spec, staged["claim"], staged["request"], staged["plan"], staged["bindings"])
        _spool_write(args, "dispatch-execution.json", {"seed_request": seed_request, "plan": plan, "observations": observations})
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
                _spool_clear(args, observation_name, "dispatch-stage.json", "dispatch-execution.json")
            return _binding_summary(destination, claim, _owned_document(destination / "manifest.json"))
        files = {}
        if args.stage == "dispatch" and args.phase == "stage":
            if claim["phase"] != "claimed" or claim["lease_until_ms"] <= time.time_ns() // 1_000_000:
                raise ValueError("dispatch materialization requires an actual current unexpired claim")
            # Exclusive: a partial failure is retained; a workspace is never
            # recopied or rebound over possible worker effects.
            destination.mkdir(mode=0o755)
            request = _expand_runtime(spec["dispatch"]["attempt.json"], bindings)
            envelope = request["envelope"]
            for field, value in (("work_id", claim["work_identity"]), ("work_version", claim["work_revision"]),
                                 ("attempt_id", claim["identity"]), ("fence", claim["fence"])):
                if envelope[field] != value:
                    raise ValueError("immutable dispatch template failed to bind actual claim")
            workspace = validate_attempt(request, cohort, args.workspace_parent, args.model_credential_env)
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
            subprocess.run([str(_lattice(cohort)), "implementation-attempt", "prepare", "--request", str(seed), "--output", str(output)],
                           check=True, timeout=60)
            output.chmod(0o444)
            request = json.loads(_regular_owned(output, 0))
            bindings["worker_profile"] = request["envelope"]["worker_profile"]
            plan = _expand_runtime(spec["dispatch"]["dispatch-plan.json"], bindings)
            _spool_write(args, "dispatch-stage.json", {
                "claim": claim, "request": request, "plan": plan, "prepared": str(output),
                "bindings": {key: value for key, value in bindings.items() if key != "verification_profile_document"}})
            return {"phase": "stage", "attempt": claim["identity"], "fence": claim["fence"]}
        if args.phase != "seal":
            raise ValueError("unsupported binding phase for this stage")
        if args.stage == "dispatch":
            if not destination.is_dir():
                raise ValueError("dispatch binding was not staged")
            output = destination / "prepared-request.json"
            request = json.loads(_regular_owned(output, 0))
            original_profile = request["envelope"]["worker_profile"]
            bindings["worker_profile"] = original_profile
            executed = _spool_read(args, "dispatch-execution.json", args.coordinator_uid)
            seed_request, plan, observations = executed["seed_request"], executed["plan"], executed["observations"]
            # Only the native policy association and the reserved plan identity
            # may change between preparations; every child execution grant
            # stays exactly as the immutable template bound it.
            previous = json.loads(json.dumps(request))
            previous["envelope"]["policy_digest"] = seed_request["envelope"]["policy_digest"]
            previous["dispatch_plan"] = seed_request.get("dispatch_plan")
            previous["admitted_envelope"] = ""
            if seed_request != previous or not DIGEST.fullmatch(str(previous["dispatch_plan"])):
                raise ValueError("execution binding changed request grants or omitted the reserved plan")
            if plan.get("attempt_identity") != claim["identity"] or plan.get("fence") != claim["fence"] or plan.get("work_identity") != claim["work_identity"]:
                raise ValueError("execution binding plan crosses the current claim")
            planned = destination / "planned-seed.json"
            _seal(planned, seed_request)
            final = destination / "final-request.json"
            subprocess.run([str(_lattice(cohort)), "implementation-attempt", "prepare", "--request", str(planned), "--output", str(final)], check=True, timeout=60)
            request = json.loads(_regular_owned(final, 0, writable=True))
            if request["envelope"]["worker_profile"] != original_profile or request.get("dispatch_plan") != seed_request["dispatch_plan"]:
                raise ValueError("planned preparation changed the native worker profile or plan binding")
            files = {name: _expand_runtime(value, bindings) for name, value in spec["dispatch"].items()
                     if name not in ("attempt.json", "dispatch-plan.json")}
            files["attempt.json"] = request
            files["dispatch-plan.json"] = plan
            files["admission-observations.json"] = observations
            for leftover in (planned, final, output, destination / "request-seed.json"):
                leftover.unlink()
        else:
            if claim["phase"] != "verified" or current.get("handoff") is None or current.get("verification") is None:
                raise ValueError("publication materialization requires actual retained handoff and independent verification")
            if destination.exists():
                raise ValueError("a partial publication binding is retained; it is never rebound")
            destination.mkdir(mode=0o755)
            handoff = current["handoff"]
            bindings.update({"candidate": handoff["candidate"], "tree": handoff["tree"],
                             "handoff": current["handoff_identity"], "verification": current["verification_identity"]})
            files = _expand_runtime(spec["publication"], bindings)
            source = files["publication-source-profile.json"]
            if source["schema"] != "kiln.github-publication-source.v1":
                raise ValueError("unsupported trusted publication source profile")
            if source["repository_path"] != str(Path(args.state_root) / "verifier/repository"):
                raise ValueError("publication source must bind the protected actual captured repository")
            source_root = _protected_directory(Path(args.state_root) / "publication-source")
            export = source_root / f"{claim['identity']}-{claim['fence']}"
            export.mkdir(mode=0o755)
            repository = export / "candidate"
            git = immutable(cohort["entries"]["git"]["resolved_path"])
            if digest(git) != cohort["entries"]["git"]["blake3"]:
                raise ValueError("publication export Git executable changed")
            acquisition = Path(args.state_root) / "verifier/repository"
            git_args = [str(git), "-c", "safe.directory=" + str(acquisition)]
            subprocess.run(git_args + ["clone", "--bare", "--no-local", "--no-hardlinks", "--", str(acquisition), str(repository)], check=True, timeout=60)
            retained_ref = "refs/kiln/implementation-candidates/" + claim["identity"]
            subprocess.run(git_args + ["-C", str(repository), "fetch", "--no-tags", "origin", retained_ref + ":" + retained_ref], check=True, timeout=60)
            subprocess.run([str(git), "-C", str(repository), "cat-file", "-e", handoff["candidate"]["native_id"] + "^{commit}"], check=True, timeout=30)
            subprocess.run([str(git), "-C", str(repository), "remote", "set-url", source["remote"]["remote_name"], source["remote"]["remote_url"]], check=True, timeout=30)
            source["repository_path"] = str(repository)
            for directory, _, names in os.walk(repository):
                Path(directory).chmod(0o755)
                for name in names:
                    (Path(directory) / name).chmod(0o444)
        entries = {}
        for name, value in files.items():
            if name not in STAGE_ENTRIES[args.stage]:
                raise ValueError("unexpected runtime stage entry")
            _seal(destination / name, value)
            entries[name] = digest(destination / name)
        request_blake3 = entries.get("attempt.json")
        if args.stage == "publication":
            dispatch_stage = _protected_directory(operation / "dispatch")
            dispatch_manifest = _owned_document(dispatch_stage / "manifest.json")
            request_blake3 = dispatch_manifest["request_blake3"]
            _regular_owned(dispatch_stage / "attempt.json", 0)
            if request_blake3 != digest(dispatch_stage / "attempt.json"):
                raise ValueError("publication request lineage differs from sealed dispatch bytes")
        manifest = {"schema": "onix.kiln.runtime-binding.v1", "stage": args.stage,
                    "attempt": claim["identity"], "fence": claim["fence"], "work": claim["work_identity"],
                    "work_revision": claim["work_revision"], "template_blake3": digest(template),
                    "cohort_manifest_blake3": digest(Path(args.cohort) / "manifest.json"),
                    "request_blake3": request_blake3, "entries": entries}
        _seal(destination / "manifest.json", manifest)
        destination.chmod(0o555)
        _spool_clear(args, observation_name, "dispatch-stage.json", "dispatch-execution.json")
        return _binding_summary(destination, claim, manifest)


STAGE_ENTRIES = {
    "dispatch": {"attempt.json", "dispatch-plan.json", "admission-observations.json", "verification-profile.json", "verifier-authority.json"},
    "publication": {"publication.json", "publication-source-profile.json"},
}


def runtime_binding(args):
    """Resolve a protected stage artifact against fresh canonical owner state."""
    template, _, current, _ = _binding_context(args)
    claim = current["attempt"]
    root = _protected_directory(_controller(args) / "bindings")
    operation = _protected_directory(root / f"{claim['identity']}-{claim['fence']}")
    stage = _protected_directory(operation / args.stage)
    manifest = _owned_document(stage / "manifest.json")
    if manifest.get("schema") != "onix.kiln.runtime-binding.v1" or manifest.get("stage") != args.stage:
        raise ValueError("runtime binding manifest schema/stage is unsupported")
    if any(manifest.get(key) != claim[field] for key, field in (("attempt", "identity"), ("fence", "fence"), ("work", "work_identity"), ("work_revision", "work_revision"))):
        raise ValueError("runtime binding belongs to another canonical claim")
    if manifest.get("cohort_manifest_blake3") != digest(Path(args.cohort) / "manifest.json") or manifest.get("template_blake3") != digest(template):
        raise ValueError("runtime binding immutable template/cohort changed")
    entries = manifest.get("entries")
    if not isinstance(entries, dict) or set(entries) != STAGE_ENTRIES[args.stage]:
        raise ValueError("runtime stage entry set is incomplete or unexpected")
    for name, expected in entries.items():
        raw = _regular_owned(stage / name, 0)
        if not isinstance(expected, str) or not DIGEST.fullmatch(expected) or digest(stage / name) != expected:
            raise ValueError(f"runtime binding bytes changed: {name}")
        json.loads(raw)
    if args.stage == "dispatch":
        request = _owned_document(stage / "attempt.json")
        plan = _owned_document(stage / "dispatch-plan.json")
        envelope = request["envelope"]
        if envelope["attempt_id"] != claim["identity"] or envelope["fence"] != claim["fence"] or plan["attempt_identity"] != claim["identity"] or plan["fence"] != claim["fence"]:
            raise ValueError("runtime request/plan does not bind the current claim")
        if envelope["work_id"] != claim["work_identity"] or envelope["work_version"] != claim["work_revision"] or plan["work_identity"] != claim["work_identity"] or plan["work_revision"] != claim["work_revision"]:
            raise ValueError("runtime request/plan crosses the current work version")
        if envelope["workspace_id"] != plan["workspace"]["identity"] or manifest["request_blake3"] != entries["attempt.json"]:
            raise ValueError("runtime request workspace or exact byte binding differs")
    else:
        dispatch_stage = _protected_directory(operation / "dispatch")
        dispatch_manifest = _owned_document(dispatch_stage / "manifest.json")
        _regular_owned(dispatch_stage / "attempt.json", 0)
        if manifest["request_blake3"] != dispatch_manifest["request_blake3"] or manifest["request_blake3"] != digest(dispatch_stage / "attempt.json"):
            raise ValueError("publication binding lost its exact native request lineage")
    return _binding_summary(stage, claim, manifest)


def attempt_inputs(args):
    bundle = immutable_tree(args.bundle)
    cohort = document(immutable(Path(args.cohort) / "manifest.json"))
    operation = Path(runtime_binding(args)["path"])
    request = _owned_document(operation / "attempt.json")
    workspace = validate_attempt(request, cohort, args.workspace_parent, args.model_credential_env)
    return bundle, operation, cohort, request, workspace


def check_attempt(args):
    _, operation, _, _, workspace = attempt_inputs(args)
    if not workspace.is_dir() or workspace.is_symlink():
        raise ValueError("controller-prepared actual claim workspace is absent or linked")
    return {"schema": "onix.kiln.workspace-preparation.v1", "workspace": str(workspace),
            "binding": str(operation), "disposition": "request-checked",
            "qualification": "scripted-unqualified", "base_verification": "Lattice native snapshot admission required"}


def export_candidate(args):
    bundle, operation, cohort, request, workspace = attempt_inputs(args)
    program = immutable(cohort["entries"]["lattice"]["resolved_path"])
    if digest(program) != cohort["entries"]["lattice"]["blake3"]:
        raise ValueError("native candidate observer executable changed")
    raw = subprocess.check_output([str(program), "implementation-attempt", "recover", "--request", str(operation / "attempt.json"), "--state", args.state], timeout=30)
    if len(raw) > MAX_DOCUMENT_BYTES:
        raise ValueError("native candidate observation exceeds bound")
    observation = json.loads(raw)
    if observation.get("schema") != "lattice.implementation-attempt-observation.v1" or observation.get("envelope") != request["envelope"]:
        raise ValueError("native recovery substituted the installed attempt envelope")
    result = observation.get("result", {})
    receipt = result.get("receipt")
    if result.get("disposition") != "produced" or result.get("blocker") is not None or not isinstance(receipt, dict):
        raise ValueError("only a complete native produced candidate can be exported")
    envelope = request["envelope"]
    if receipt.get("schema") != "lattice.candidate-receipt.v1" or receipt.get("disposition") != "produced" or receipt.get("blockers") != []:
        raise ValueError("native host candidate receipt is incomplete or blocked")
    if any(receipt.get(field) != envelope[field] for field in ("work_id", "attempt_id", "workspace_id")) or receipt.get("fence") != str(envelope["fence"]):
        raise ValueError("native candidate receipt crosses work, attempt, fence or workspace")
    if not LABEL.fullmatch(envelope["attempt_id"]) or type(envelope["fence"]) is not int or envelope["fence"] < 1:
        raise ValueError("candidate export requires an exact safe attempt/fence")
    parent = Path(args.output_parent).resolve(strict=True)
    exported = parent / (envelope["attempt_id"] + "-" + str(envelope["fence"]))
    exported.mkdir(mode=0o750)
    candidate = exported / "candidate"
    stage_tree(workspace, candidate)
    for directory, _, files in os.walk(candidate):
        Path(directory).chmod(0o750)
        for name in files:
            path = Path(directory) / name
            path.chmod(0o750 if path.stat().st_mode & 0o111 else 0o640)
    write_document(exported / "host-receipt.json", receipt)
    (exported / "host-receipt.json").chmod(0o640)
    with (exported / "native-observation.json").open("xb") as output:
        output.write(raw)
        output.flush()
        os.fsync(output.fileno())
    (exported / "native-observation.json").chmod(0o640)
    return {"schema": "onix.kiln.candidate-export.v1", "candidate_root": str(candidate),
            "host_receipt": str(exported / "host-receipt.json"), "accepted": False,
            "qualification": "unqualified", "next": "independent native capture-candidate and verify"}


def validate_verifier_authority(authority, root, worker_uid, cohort):
    expected = Path(root) / "verifier"
    if authority.get("worker_uid") != worker_uid:
        raise ValueError("verification authority must bind the actual editing worker UID")
    if Path(authority["repository_root"]) != expected / "repository" or Path(authority["scratch_root"]) != expected / "scratch":
        raise ValueError("trusted verification roots must remain separate from worker and ledger state")
    git = cohort["entries"]["git"]
    if immutable(authority["git"]["path"]) != immutable(git["resolved_path"]) or authority["git"]["blake3"] != git["blake3"]:
        raise ValueError("verification Git program must match the admitted actual toolchain")
    return {"authority": "deployment-bound", "qualification": "unqualified"}


def prepare_disks(args):
    if not LABEL.fullmatch(args.reference) or args.generation < 1:
        raise ValueError("mutable disks require an exact execution reference and positive generation")
    if not all(MIN_DISK_MIB <= size <= MAX_DISK_MIB for size in (args.workspace_mib, args.state_mib)):
        raise ValueError("mutable disk size exceeds the declared bound")
    directory = Path(args.directory)
    if not directory.is_absolute() or directory.parent.resolve(strict=True) != directory.parent:
        raise ValueError("mutable disk parent must be absolute and canonical")
    parent = directory.parent.stat()
    if parent.st_uid != os.geteuid() or parent.st_mode & 0o022:
        raise ValueError("mutable disk parent must be owned and not group/world writable")
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
        subprocess.run(["mkfs.ext4", "-F", "-q", "-U", "random", "-m", "0", str(path)], check=True, timeout=120)
        filesystem_id = subprocess.check_output(["blkid", "-p", "-s", "UUID", "-o", "value", str(path)], text=True, timeout=10).strip()
        if not re.fullmatch(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}", filesystem_id):
            raise ValueError("filesystem identity was not observed")
        disks[name] = {"path": str(path), "image_type": "raw", "filesystem": "ext4",
                       "filesystem_uuid": filesystem_id, "size_mib": size, "generation": args.generation}
    if disks["workspace"]["filesystem_uuid"] == disks["state"]["filesystem_uuid"]:
        raise ValueError("workspace and state must have independent filesystem identities")
    result = {"schema": "onix.lattice.mutable-disks.v1", "reference": args.reference,
              "disks": disks, "guest_identity": "generated-on-first-boot-not-observed",
              "credentials": "none-provisioned", "placement_authority": False, "qualification": "unqualified"}
    write_document(directory / "disks.json", result)
    return result


def main():
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
    for name in ("check-attempt", "export-candidate", "binding-path", "materialize-binding", "claim-attempt", "prepare-fixture-intake", "current-claim"):
        attempt = commands.add_parser(name)
        for option in ("bundle", "cohort"):
            attempt.add_argument("--" + option, required=True)
        attempt.add_argument("--configuration", required=True)
        attempt.add_argument("--state-root", required=True)
        attempt.add_argument("--coordinator-uid", type=int, default=930)
        attempt.add_argument("--stage", choices=tuple(STAGE_ENTRIES), default="dispatch")
        attempt.add_argument("--workspace-parent", required=name in ("check-attempt", "export-candidate", "materialize-binding"))
        # The env-reference name the request's broker credential must use; set
        # only when the dispatcher loads a model credential.
        attempt.add_argument("--model-credential-env")
        # Kiln's local-operator authority for admission-bound owner commands.
        attempt.add_argument("--local-operator")
        if name == "materialize-binding":
            attempt.add_argument("--worker-uid", type=int, required=True)
            attempt.add_argument("--phase", choices=("observe", "stage", "execute", "seal"), required=True)
        if name == "claim-attempt":
            attempt.add_argument("--lease-ms", type=int, required=True)
            attempt.add_argument("--phase", choices=("native", "seal"), required=True)
        if name == "export-candidate":
            attempt.add_argument("--state", required=True)
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
            result = compare_placements(document(args.source), document(args.destination))
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
        elif args.command == "verifier-authority":
            result = validate_verifier_authority(document(args.authority), args.root, args.worker_uid, document(Path(args.cohort) / "manifest.json"))
        elif args.command == "prepare-disks":
            result = prepare_disks(args)
        else:
            result = validate_policy(args.configuration, args.repository, args.work_class, args.state_root, document(Path(args.cohort) / "manifest.json"))
        print(json.dumps(result, sort_keys=True))
    except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError) as error:
        print(json.dumps({"qualification": "failed", "error": str(error)}), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
