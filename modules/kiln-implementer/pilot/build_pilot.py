#!/usr/bin/env python3
"""Construct the immutable live-pilot inputs with Kiln's native codecs.

Executed only by the pilot Nix derivation. It freezes the reviewed sandbox
baseline, the verification profile (natively prepared, checks not run) and
the dedicated canonical CI graph. It creates no claim, lease, grant,
candidate, check result, branch or PR, and holds no credential.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess

REQUIRED = {"coordinator", "verifier", "dispatch", "lattice", "worker", "sandbox", "relay", "shell", "git"}


def run(*arguments):
    return subprocess.check_output(list(map(str, arguments)), timeout=300)


def put(path, value):
    with Path(path).open("x") as output:
        json.dump(value, output, sort_keys=True, indent=2)
        output.write("\n")


def blake3(path):
    return run("b3sum", "--no-names", path).decode().strip()


def frozen(path):
    path = Path(path).resolve(strict=True)
    if not str(path).startswith("/nix/store/") or not path.is_file() or not path.stat().st_mode & 0o111:
        raise ValueError("pilot requires a real immutable executable: " + str(path))
    return {"path": str(path), "blake3": blake3(path)}


def export(profile, inputs, field, scratch):
    input_path = scratch / (field + "-inputs.json")
    expression = scratch / (field + ".ncl")
    put(input_path, inputs)
    expression.write_text(f"std.record.get {json.dumps(field)} ((import {json.dumps(str(profile))}) (import {json.dumps(str(input_path))}))\n")
    return json.loads(run("nickel", "export", "--format", "json", expression))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for option in ("cohort", "source", "profile", "cargo-check", "host-owner-contract", "spec", "output", "scratch"):
        parser.add_argument("--" + option, required=True, type=Path)
    args = parser.parse_args()
    scratch, output = args.scratch, args.output
    scratch.mkdir(mode=0o700)
    spec = json.loads(args.spec.read_text())
    manifest = json.loads((args.cohort / "manifest.json").read_text())
    if manifest["schema"] != "onix.kiln.implementation-cohort.v1" or not REQUIRED <= set(manifest["entries"]):
        raise ValueError("actual consumer cohort is incomplete")
    programs = {}
    for name in REQUIRED:
        programs[name] = frozen(manifest["entries"][name]["resolved_path"])
        if programs[name]["blake3"] != manifest["entries"][name]["blake3"]:
            raise ValueError("actual cohort executable identity changed: " + name)
    attempt = output / "attempt"
    base = attempt / "base"
    configuration = output / "configuration"
    configuration.mkdir(parents=True)
    # The reviewed baseline tree; normalized modes, no VCS metadata.
    shutil.copytree(args.source, base, ignore=shutil.ignore_patterns(".git"))
    for directory, _, names in os.walk(base):
        Path(directory).chmod(0o755)
        for name in names:
            (Path(directory) / name).chmod(0o644)
    repository = spec["repository"]
    remote_bytes = f"kiln.native-git-remote.v1\0https-strict-tls\0{repository['remote_url']}\0-".encode()
    remote_path = scratch / "remote-identity.bytes"
    remote_path.write_bytes(remote_bytes)
    seed = blake3(args.cohort / "manifest.json")
    inputs = {
        "seed_identity": seed, "verification_identity": seed,
        "output_contract_identity": blake3(args.spec), "remote_identity": blake3(remote_path),
        # Kiln's kiln_core::types::ExternalRef; every field is required.
        "base": {"contract_version": 1, "provider_namespace": "git", "native_kind": "commit", "native_id": repository["base"]},
        "git": programs["git"], "worker": programs["worker"], "sandbox": programs["sandbox"],
        "relay": programs["relay"], "shell": programs["shell"], "lattice": programs["lattice"],
        "cargo_check": frozen(args.cargo_check), "worker_revision": manifest["revisions"]["worker"],
        "spec": spec,
    }
    verification_seed = scratch / "verification-seed.json"
    put(verification_seed, export(args.profile, inputs, "verification", scratch))
    prepared = json.loads(run(programs["coordinator"]["path"], "prepare-verification-profile",
                              "--profile", verification_seed, "--output", attempt / "verification-profile.json"))
    inputs["verification_identity"] = prepared["verification_profile"]
    for name, value in export(args.profile, inputs, "configuration", scratch).items():
        put(configuration / name, value)
    put(configuration / "work-class.json", {"class": spec["name"] if spec["name"] == "bug" else "bounded-feature",
        "repository": repository["key"], "policy_blake3": blake3(configuration / "github-policy.json")})
    template = export(args.profile, inputs, "runtime_template", scratch)
    # Kiln derives the only publishable remote from the durable lowercase
    # repository key and compares it as an exact string (kiln-adapter-github
    # src/publication.rs:605-614 `validate_source_profile`, owner/name split at
    # :786-808 `repository_parts`); any other spelling is
    # github_publication_remote_mismatch before any network call.
    owner, name = repository["key"].split("/")
    remote = template["publication"]["publication-source-profile.json"]["remote"]["remote_url"]
    if remote != f"https://github.com/{owner}/{name}.git" or repository["remote_url"] != remote:
        raise ValueError(f"publication remote {remote} is not Kiln's derivation from {repository['key']}")
    put(attempt / "runtime-template.json", template)
    # Kiln's typed host-owner registration, exported through its own contract.
    owner_input = scratch / "host-owner-input.json"
    put(owner_input, export(args.profile, inputs, "host_owner_input", scratch))
    owner_expression = scratch / "host-owner.ncl"
    owner_expression.write_text(f"(import {json.dumps(str(args.host_owner_contract))}) (import {json.dumps(str(owner_input))})\n")
    (configuration / "host-owner.json").write_bytes(run("nickel", "export", "--format", "json", owner_expression))
    ci_template = scratch / "ci-service-template.json"
    put(ci_template, export(args.profile, inputs, "ci_service_template", scratch))
    run(programs["verifier"]["path"], "implementation-verification-graph", "--template", ci_template,
        "--verification-profile", attempt / "verification-profile.json",
        "--project", repository["name"], "--output", output / "ci-service-profile.json")
    put(output / "pilot-manifest.json", {
        "schema": "onix.kiln.live-pilot-inputs.v1", "qualification": "unqualified", "case": spec,
        "cohort_manifest_blake3": seed, "verification_profile": prepared["verification_profile"],
        "checks_executed": False, "construction_program": {"path": str(Path(__file__).resolve()), "blake3": blake3(Path(__file__))},
        "files": {str(path.relative_to(output)): blake3(path) for path in sorted(output.rglob("*")) if path.is_file()},
    })


if __name__ == "__main__":
    main()
