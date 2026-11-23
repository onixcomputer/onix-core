#!/usr/bin/env python3
"""Build typed, immutable input templates for the closed scripted campaign fixture."""
import argparse
import json
from pathlib import Path
import subprocess


def read(path):
    return json.loads(Path(path).read_bytes())


def put(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, sort_keys=True, indent=2) + "\n")


def digest(path):
    return subprocess.check_output(["b3sum", "--no-names", str(path)], text=True, timeout=60).strip()


def template_identity(label):
    # Parser-only placeholders in the immutable dispatch-plan template. The native binder replaces these before admission.
    return subprocess.check_output(["b3sum", "--no-names"], input=label.encode(), text=False, timeout=60).decode().split()[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("output", "cohort", "campaign-cohort", "drive-contract", "campaign-constructor", "setpriv"):
        parser.add_argument("--" + name, required=True, type=Path)
    args = parser.parse_args()
    root = args.output.resolve(strict=True)
    campaign = root / "campaign"
    campaign.mkdir(mode=0o755, exist_ok=True)
    attempt = root / "attempt"
    configuration = root / "configuration"
    bundle = read(root / "bundle-manifest.json")
    selected = read(attempt / "cairn-snapshot.json").get("selection")
    if not isinstance(selected, list) or len(selected) != 1:
        raise ValueError("native Cairn source snapshot must select exactly one fixture unit")
    change = selected[0].get("change")
    unit = selected[0].get("unit")
    task = unit.removeprefix("task:") if isinstance(unit, str) else ""
    if not isinstance(change, str) or not change or not task:
        raise ValueError("native Cairn snapshot lacks its exact selected change/task identity")
    base = bundle["base"]
    repository = "qualification/disposable"
    campaign_id = "scripted-native-cairn"
    projection_path = campaign / "decision-projection.json"
    projection_path.write_bytes(Path(__file__).with_name("decision-projection.json").read_bytes())
    projection_identity = digest(projection_path)
    put(campaign / "workflow-profile.json", {
        "schema": "kiln.scripted-workflow-profile.v1",
        "profile": "spec_driven",
        "campaign_workflow_blake3": digest(args.campaign_cohort / "workflow.ncl"),
        "implementation_profile_blake3": digest(root / "profile.ncl"),
    })
    put(campaign / "integration-policy.json", {
        "schema": "kiln.scripted-integration-policy.v1",
        "route": "github_pull_request",
        "base_branch": "main",
        "required_checks": ["acceptance"],
        "required_reviews": [],
        "required_approvals": 0,
        "lifecycle_action": "observe_reviewed_sync",
    })
    put(campaign / "start-command-template.json", {
        "command": "start",
        "contract": {
            "schema": "kiln.implementation-campaign.v1",
            "campaign_id": campaign_id,
            "revision": 1,
            "repository": repository,
            "members": [{
                "selector": {"kind": "tasks", "change": change, "tasks": [task]},
                "profile": "spec_driven",
                "required_checks": ["acceptance"],
                "required_reviews": [],
                "goal": "verified_candidate",
                "prerequisite_inclusion": False,
                "context": [{
                    "decision_id": "scripted-operator-choice",
                    "native_adr_id": None,
                    "revision": "fixture-revision-1",
                    "selected_alternative": "write-only-authorized-output",
                    "evidence": [],
                    "supersedes": [],
                    "projection_identity": projection_identity,
                    "required": True,
                }],
            }],
            "max_concurrency": 1,
            "max_outstanding_decisions": 1,
            "require_one_writer_per_repository": True,
        },
    })
    seed = read(attempt / "runtime-template.json")["dispatch"]["attempt.json"]
    put(campaign / "worker-request-template.json", seed)
    scenario = read(root / "scenario.json")
    output_contract = digest(root / "scenario.json")
    worker_profile_revision = seed.get("envelope", {}).get("worker_profile")
    if not isinstance(worker_profile_revision, str) or len(worker_profile_revision) != 64:
        raise ValueError("selected native worker request omitted its exact profile revision")
    put(campaign / "work-needs.json", {
        "work_version": "",
        "task_family": "scripted_implementation",
        "output_contract": output_contract,
        "definition": {"source": "scripted-local-fixture", "id": "implementation-contract"},
        "profile_revision": worker_profile_revision,
        "policy_ref": "",
        "harness": "omp",
        "tools": ["write"],
        "sandbox": "isolated_snapshot",
        "execution_backend": "native_lattice_local",
        "model_backend": "scripted_local",
        "context_tokens": 4096,
        "execution_resources": [{"unit": "worker_requests", "amount": 1}],
        "modalities": ["text"],
        "model_artifact": None,
        "qualification_subject": "scripted-local-only",
        "qualification_corpus": repository,
        "qualification_protocol": "scripted-local-omp-v1",
    })
    put(campaign / "dispatch-plan-template.json", {
        "schema": "kiln.implementation-dispatch-plan.v2",
        "work_identity": template_identity("scripted-campaign-work-template-v1"),
        "work_revision": 1,
        "attempt_identity": template_identity("scripted-campaign-attempt-template-v1"),
        "fence": 1,
        "repository": repository,
        "base": base,
        "workspace": {
            "identity": template_identity("scripted-campaign-workspace-template-v1"),
            "isolation": "isolated_snapshot",
            "network": True,
            "credentials": False,
        },
        "provider_profile": "scripted-local-omp",
        "permitted_paths": ["src/scripted_model_result.txt"],
        "permitted_effects": ["write_source"],
        "controls": {"cancel": True, "pause": False, "resume": False},
        "deadline_minutes": 2,
        "token_budget": 4096,
        "invocation_budget": 4,
        "expected_output": output_contract,
        "execution": None,
    })
    manifest = read(args.campaign_cohort / "manifest.json")
    selected_lattice = manifest["entries"]["lattice"]
    transport = {
        "schema": "kiln.lattice-implementation-cli.v2",
        "lattice_program": selected_lattice["resolved_path"],
        "executable_blake3": selected_lattice["blake3"],
        "state_directory": "/var/lib/kiln-implementation/lattice/implementation",
        "output_directory": "/var/lib/kiln-implementation/lattice/observations",
    }
    put(configuration / "campaign-worker-transport-profile.json", transport)
    authority = {
        "repository": repository,
        "repository_root": "/var/lib/kiln-implementation/verifier/repository",
        "scratch_root": "/var/lib/kiln-implementation/verifier/scratch",
        "git": {"path": manifest["entries"]["git"]["resolved_path"], "blake3": manifest["entries"]["git"]["blake3"]},
        "worker_uid": 931,
    }
    put(campaign / "verifier-authority.json", authority)
    cairn_policy_path = configuration / "cairn-policy.json"
    cairn_policy = read(cairn_policy_path)
    profile = {
        "campaign_id": campaign_id,
        "campaign_database": "/var/lib/kiln-implementation/campaign/campaign.sqlite",
        "implementation_database": "/var/lib/kiln-implementation/kiln/work.sqlite",
        "decision_contexts": {projection_identity: str(projection_path)},
        "verification_routes": {
            bundle["verification_profile"]: {
                "ci_service_profile": str(root / "ci-service-profile.json"),
                "verification_profile": str(attempt / "verification-profile.json"),
            }
        },
        "verifier_authority": str(campaign / "verifier-authority.json"),
        "bound_input_directory": "/var/lib/kiln-implementation/campaign/bound-input",
        "candidate_export_directory": "/var/lib/kiln-implementation/campaign/candidate-export",
        "worker": {
            "dispatch_plan": "/var/lib/kiln-implementation/campaign/dispatch-plan-template.json",
            "request": str(campaign / "worker-request-template.json"),
            "admission_observations": None,
        },
        "native_cairn": {
            "repository_root": "/var/lib/kiln-implementation/campaign/source",
            "source": {"contract_version": 1, "provider_namespace": "cairn", "native_kind": "git_commit", "native_id": base["native_id"]},
            "implementation_policy": cairn_policy,
        },
        "delivery": {
            "route": "github_pull_request",
            "github": {
                "enrollment": str(configuration / "enrollment.json"),
                "remote_profile": "/var/lib/kiln-implementation/campaign/publication-source-profile.json",
                "publication_policy": {
                    "base_branch": "main",
                    "title": "Scripted selected Cairn implementation",
                    "body": "Closed-loopback scripted campaign. Not live-model or production qualification.",
                },
                "landing_policy": {"required_checks": ["acceptance"], "required_approvals": 0},
                "lifecycle_action": "observe_reviewed_sync",
                "lifecycle_receipt_template": ".cairn/changes/{task}/lifecycle.json",
                "repository": "/var/lib/kiln-implementation/verifier/repository",
                "authoritative_report_directory": "/var/lib/kiln-implementation/verifier/reports",
                "timeout_ms": 300000,
            },
            "native_git": None,
        },
        "claim_lease_ms": 180000,
        "maximum_operations": 16,
        "workspace": {
            "repository": repository,
            "repository_path": "/var/lib/kiln-implementation/campaign/source",
            "work_root": "/var/lib/kiln-implementation/campaign/workspaces",
            "max_entries": 4096,
            "max_path_bytes": 4096,
            "max_file_bytes": 4194304,
            "max_total_bytes": 67108864,
        },
    }
    put(campaign / "drive-inputs.json", profile)
    setpriv = args.setpriv.resolve(strict=True)
    setpriv_identity = digest(setpriv)
    expression = campaign / "drive-profile.ncl"
    expression.write_text(f'''let constructor = (import "{args.campaign_constructor}").generate in
constructor
  (import "{args.campaign_cohort / 'manifest.json'}")
  (import "{campaign / 'drive-inputs.json'}")
  {{ enrollment = "{configuration / 'enrollment.json'}",
     transport_profile = "{configuration / 'campaign-worker-transport-profile.json'}",
     campaign_credential_path = "/run/kiln-scripted-campaign-publisher",
     cairn_policy_path = "{cairn_policy_path}", setpriv = "{setpriv}",
     setpriv_blake3 = "{setpriv_identity}", cairn_policy_identity = "{digest(cairn_policy_path)}",
     coordinator_uid = 930, executor_uid = 931, publisher_uid = 932, verifier_uid = 933, data_gid = 931 }}
  (import "{args.drive_contract}")
''')
    output_profile = (campaign / "drive-profile.json").open("wb")
    try:
        subprocess.run(["nickel", "export", "--format", "json", str(expression)], check=True, stdout=output_profile, timeout=120)
    finally:
        output_profile.close()
    remote_template = json.loads(subprocess.check_output(
        ["nickel", "export", "--format", "json", str(root / "remote.ncl")], timeout=120
    ))
    put(campaign / "remote-template.json", remote_template)
    (root / "prepare_campaign_plan.py").write_bytes(Path(__file__).with_name("prepare_campaign_plan.py").read_bytes())
    (root / "prepare_campaign_start.py").write_bytes(Path(__file__).with_name("prepare_campaign_start.py").read_bytes())
    files = {
        str(path.relative_to(root)): digest(path)
        for path in sorted(root.rglob("*"))
        if path.is_file() and path.name != "bundle-manifest.json"
    }
    bundle["schema"] = "onix.kiln.scripted-input-bundle.v3"
    bundle["campaign_cohort_manifest_blake3"] = digest(args.campaign_cohort / "manifest.json")
    bundle["files"] = files
    put(root / "bundle-manifest.json", bundle)


if __name__ == "__main__":
    main()
