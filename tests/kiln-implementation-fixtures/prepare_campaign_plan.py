#!/usr/bin/env python3
"""Add canonical prepared WorkNeeds to the scripted campaign's plan template."""
import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--template", required=True, type=Path)
    parser.add_argument("--needs", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    plan = json.loads(args.template.read_bytes())
    needs = json.loads(args.needs.read_bytes())
    if plan.get("schema") != "kiln.implementation-dispatch-plan.v2":
        raise ValueError("campaign dispatch plan template has the wrong native schema")
    if "requirements_identity" not in needs or "work_revision" not in needs:
        raise ValueError("work-needs input is not the actual canonical prepared attachment")
    work = needs.get("work_identity")
    policy = needs.get("policy_identity")
    if not isinstance(work, str) or len(work) != 64 or not isinstance(policy, str) or len(policy) != 64:
        raise ValueError("prepared WorkNeeds omitted canonical work or policy identity")
    profile = needs.get("needs", {}).get("profile_revision")
    if not isinstance(profile, str) or len(profile) != 64:
        raise ValueError("prepared WorkNeeds omitted the selected model profile identity")
    plan["execution"] = {
        "requirements": needs,
        "attempt": {
            "work_version": work,
            "attempt": work,
            "fence": 1,
            "worker": {"source": "scripted-local-fixture", "id": profile},
            "execution_grant": {"source": "scripted-local-fixture", "id": work},
            "model_services": [{"source": "scripted-local-fixture", "id": "kiln-scripted/scripted-v1"}],
            "request_admissions": [{"source": "scripted-local-fixture", "id": "/run/netns/kiln-scripted-model"}],
        },
        "native_request_profile": None,
    }
    args.output.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    with args.output.open("x") as target:
        json.dump(plan, target, sort_keys=True, indent=2)
        target.write("\n")


if __name__ == "__main__":
    main()
