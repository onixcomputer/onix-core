#!/usr/bin/env python3
"""Construct immutable synthetic inputs with real native owner codecs.

Executed only by the explicit Nix fixture derivation. This creates no claim,
lease, candidate, check result, provider allocation, branch effect, or PR.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess


def run(*arguments, **kwargs):
    return subprocess.check_output(list(map(str, arguments)), timeout=120, **kwargs)


def put(path, value):
    path = Path(path)
    with path.open("x") as output:
        json.dump(value, output, sort_keys=True, indent=2)
        output.write("\n")


def load(path):
    return json.loads(Path(path).read_bytes())


def blake3(path):
    return run("b3sum", "--no-names", path, text=True).strip()


def frozen(path):
    path = Path(path).resolve(strict=True)
    if not str(path).startswith("/nix/store/") or not path.is_file() or not path.stat().st_mode & 0o111:
        raise ValueError("fixture requires a real immutable executable: " + str(path))
    return {"path": str(path), "blake3": blake3(path)}


def export_profile(source, inputs, field, scratch):
    input_path = scratch / (field + "-inputs.json")
    expression = scratch / (field + ".ncl")
    put(input_path, inputs)
    expression.write_text(f'std.record.get {json.dumps(field)} ((import {json.dumps(str(source / "profile.ncl"))}) (import {json.dumps(str(input_path))}))\n')
    return json.loads(run("nickel", "export", "--format", "json", expression))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for option in ("cohort", "fixture-helper", "cairn-source", "cairn-policy", "python", "fixtures", "github-fixture", "output", "scratch"):
        parser.add_argument("--" + option, required=True, type=Path)
    args = parser.parse_args()
    output = args.output
    scratch = args.scratch
    scratch.mkdir(mode=0o700)
    output.mkdir()
    attempt = output / "attempt"
    base = attempt / "base"
    base.mkdir(parents=True)
    configuration = output / "configuration"
    configuration.mkdir()
    manifest = load(args.cohort / "manifest.json")
    required = {"coordinator", "verifier", "dispatch", "cairn_intake", "lattice", "cairn", "worker", "sandbox", "relay", "shell", "nix", "git"}
    if manifest["schema"] != "onix.kiln.implementation-cohort.v1" or not required <= set(manifest["entries"]):
        raise ValueError("actual consumer cohort is incomplete")
    programs = {}
    for name in required:
        entry = manifest["entries"][name]
        programs[name] = frozen(entry["resolved_path"])
        if programs[name]["blake3"] != entry["blake3"]:
            raise ValueError("actual cohort executable identity changed: " + name)
    if manifest["revisions"]["worker"] != "e325ffc73ab86e03bdd20a91b77d8e2b3964c906":
        raise ValueError("the real selected OMP source revision is required")
    helper = frozen(args.fixture_helper)
    python = frozen(args.python)
    source = args.fixtures
    shutil.copytree(source / "source", base, dirs_exist_ok=True)
    shutil.copytree(args.cairn_source / "fixtures/basic/.cairn", base / ".cairn")
    for directory, _, names in os.walk(base):
        Path(directory).chmod(0o755)
        for name in names:
            (Path(directory) / name).chmod(0o644)
    snapshot_raw = run(programs["cairn"]["path"], "implementation-ready", "--root", base,
                       "--policy", args.cairn_policy, "--limit", "1")
    snapshot = json.loads(snapshot_raw)
    if snapshot.get("schema") != "cairn.implementation-ready.v1" or snapshot.get("outcome") != "ready" or not snapshot.get("complete") or len(snapshot.get("selection", [])) != 1:
        raise ValueError("the actual native Cairn fixture must select exactly one ready input")
    (attempt / "cairn-snapshot.json").write_bytes(snapshot_raw)
    acceptance_ids = sorted({"accepted", *snapshot["selection"][0].get("requirement_references", [])})
    changed = output / "changed-source"
    shutil.copytree(base, changed)
    tasks = changed / ".cairn/changes/demo/tasks.md"
    tasks.write_text(tasks.read_text().replace("Define fixture work.", "Define changed fixture work."))
    changed_raw = run(programs["cairn"]["path"], "implementation-ready", "--root", changed,
                      "--policy", args.cairn_policy, "--limit", "1")
    changed_snapshot = json.loads(changed_raw)
    if changed_snapshot.get("outcome") != "ready" or changed_snapshot.get("selection") == snapshot["selection"]:
        raise ValueError("actual changed Cairn source did not produce a new ready version")
    (attempt / "cairn-source-change-snapshot.json").write_bytes(changed_raw)
    git = programs["git"]["path"]
    repo = scratch / "repository"
    shutil.copytree(base, repo)
    environment = os.environ | {"GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null",
        "GIT_AUTHOR_NAME": "Scripted fixture", "GIT_AUTHOR_EMAIL": "scripted@example.invalid",
        "GIT_COMMITTER_NAME": "Scripted fixture", "GIT_COMMITTER_EMAIL": "scripted@example.invalid",
        "GIT_AUTHOR_DATE": "2000-01-01T00:00:00Z", "GIT_COMMITTER_DATE": "2000-01-01T00:00:00Z"}
    run(git, "init", "--initial-branch=main", repo, env=environment)
    run(git, "-C", repo, "add", "--all", env=environment)
    run(git, "-C", repo, "commit", "-m", "Immutable synthetic implementation baseline", env=environment)
    oid = run(git, "-C", repo, "rev-parse", "HEAD", text=True, env=environment).strip()
    run(git, "clone", "--bare", "--no-hardlinks", repo, output / "repository.git", env=environment)
    remote = json.loads(run("nickel", "export", "--format", "json", source / "remote.ncl"))
    remote_path = scratch / "remote.json"
    put(remote_path, remote)
    remote_binding = json.loads(run(helper["path"], "prepare-remote-template", "--profile", remote_path))
    if remote_binding.get("schema") != "kiln.scripted-remote-binding.v1" or remote_binding.get("scope") != "synthetic-local-template":
        raise ValueError("native helper did not admit the explicit synthetic remote template")
    seed_identity = blake3(args.cohort / "manifest.json")
    inputs = {"seed_identity": seed_identity, "verification_identity": seed_identity,
        "output_contract_identity": blake3(source / "scenario.json"),
        "base": {"contract_version": 1, "provider_namespace": "git", "native_kind": "commit", "native_id": oid},
        "python": python, "git": programs["git"], "worker": programs["worker"], "sandbox": programs["sandbox"],
        "relay": programs["relay"], "shell": programs["shell"],
        "lattice": programs["lattice"], "fixture_helper": helper, "worker_revision": manifest["revisions"]["worker"],
        "acceptance_ids": acceptance_ids, "remote_identity": remote_binding["remote_identity"]}
    profile_seed = scratch / "verification-seed.json"
    put(profile_seed, export_profile(source, inputs, "verification", scratch))
    prepared = json.loads(run(programs["coordinator"]["path"], "prepare-verification-profile", "--profile", profile_seed,
                              "--output", attempt / "verification-profile.json"))
    inputs["verification_identity"] = prepared["verification_profile"]
    for name, value in export_profile(source, inputs, "configuration", scratch).items():
        put(configuration / name, value)
    put(configuration / "work-class.json", {"class": "bug", "repository": "qualification/disposable",
        "policy_blake3": blake3(configuration / "github-policy.json")})
    put(attempt / "runtime-template.json", export_profile(source, inputs, "runtime_template", scratch))
    ci_seed = scratch / "ci-service-seed.json"
    put(ci_seed, export_profile(source, inputs, "ci_service_seed", scratch))
    ci = json.loads(run(helper["path"], "prepare-ci", "--verification-profile", attempt / "verification-profile.json",
                        "--service-profile-template", ci_seed))
    if ci.get("schema") != "kiln.scripted-ci-binding.v1" or ci.get("scope") != "synthetic-local-only":
        raise ValueError("native helper did not bind the actual protected canonical CI profile")
    put(output / "ci-service-profile.json", ci["service_profile"])
    for name in ("scenario.json", "model_server.py", "profile.ncl", "remote.ncl"):
        shutil.copyfile(source / name, output / name)
    shutil.copyfile(args.github_fixture, output / "github_fixture.py")
    put(output / "bundle-manifest.json", {"schema": "onix.kiln.scripted-input-bundle.v2", "qualification": "scripted-unqualified",
        "scope": "synthetic-local-only", "cohort_manifest_blake3": seed_identity, "fixture_helper": helper,
        "construction_program": {"path": str(Path(__file__).resolve()), "blake3": blake3(Path(__file__))},
        "cairn_source": str(args.cairn_source), "cairn_policy": str(args.cairn_policy), "cairn_policy_blake3": blake3(args.cairn_policy),
        "base": inputs["base"], "verification_profile": inputs["verification_identity"],
        "files": {str(path.relative_to(output)): blake3(path) for path in sorted(output.rglob("*")) if path.is_file()}})


if __name__ == "__main__":
    main()
