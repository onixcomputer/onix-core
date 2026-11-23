#!/usr/bin/env python3
"""Construct the protected scripted campaign command from actual owner state and immutable materials."""
import argparse
import json
import os
from pathlib import Path
import re
import stat
import subprocess


IDENTITY = re.compile(r"[0-9a-f]{64}\Z")
CHANGE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]{0,127}\Z")
OUTPUT = Path("/var/lib/kiln-implementation/campaign/start-command.json")


def read_json(path: Path):
    return json.loads(path.read_bytes())


def store_file(path: Path) -> Path:
    resolved = path.resolve(strict=True)
    if not resolved.is_file() or not str(resolved).startswith("/nix/store/"):
        raise ValueError(f"campaign material must be an immutable store file: {path}")
    return resolved


def digest_file(path: Path) -> str:
    identity = subprocess.check_output(["b3sum", "--no-names", str(store_file(path))], timeout=60, text=True).strip()
    if not IDENTITY.fullmatch(identity):
        raise ValueError(f"invalid BLAKE3 identity for {path}")
    return identity

def store_directory(path: Path) -> Path:
    resolved = path.resolve(strict=True)
    if not resolved.is_dir() or not str(resolved).startswith("/nix/store/"):
        raise ValueError(f"campaign repository must be an immutable store directory: {path}")
    return resolved


def digest_bytes(value: bytes) -> str:
    identity = subprocess.check_output(["b3sum", "--no-names"], input=value, timeout=60, text=False).decode().strip()
    if not IDENTITY.fullmatch(identity):
        raise ValueError("invalid BLAKE3 identity for native instruction bytes")
    return identity


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("template", "admission-status", "manifest", "repository", "workflow", "policy", "integration-policy", "agent-definition", "work", "output"):
        parser.add_argument("--" + name, required=True, type=Path if name != "work" else str)
    args = parser.parse_args()
    if not IDENTITY.fullmatch(args.work):
        raise ValueError("work identity must be an exact native content id")
    output = args.output
    if output != OUTPUT or output.parent.resolve(strict=True) != OUTPUT.parent:
        raise ValueError("campaign command output must be the protected runtime operator-input path")

    template_path = store_file(args.template)
    status_path = args.admission_status
    metadata = status_path.lstat()
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_size == 0 or metadata.st_size > 16 * 1024 * 1024:
        raise ValueError("canonical admission snapshot must be a bounded ordinary runtime file")
    if status_path != Path("/var/lib/kiln-implementation/campaign/admission-status.json"):
        raise ValueError("admission input must be the protected runtime canonical snapshot")
    manifest_path = store_file(args.manifest)
    repository_path = store_directory(args.repository)
    workflow_path = store_file(args.workflow)
    policy_path = store_file(args.policy)
    integration_policy_path = store_file(args.integration_policy)
    agent_definition_path = store_file(args.agent_definition)
    template = read_json(template_path)
    status = read_json(status_path)
    manifest = read_json(manifest_path)

    contract = template.get("contract")
    if template.get("command") != "start" or not isinstance(contract, dict):
        raise ValueError("immutable campaign start template is malformed")
    if "parent_budget_id" in contract or "agent_definition" in contract:
        raise ValueError("immutable start template must not self-declare owner ancestry or agent identity")
    members = contract.get("members")
    if not isinstance(members, list) or len(members) != 1:
        raise ValueError("scripted fixture must bind exactly one selected member")
    member = members[0]
    selector = member.get("selector", {})
    change = selector.get("change")
    tasks = selector.get("tasks")
    if selector.get("kind") != "tasks" or not isinstance(change, str) or not CHANGE.fullmatch(change) or not isinstance(tasks, list) or len(tasks) != 1 or not isinstance(tasks[0], str):
        raise ValueError("campaign template lacks its exact bounded Cairn task selector")

    items = status.get("items")
    accounts = status.get("accounts")
    if not isinstance(items, dict) or len(items) != 1 or not isinstance(accounts, dict) or len(accounts) != 1:
        raise ValueError("scripted campaign requires exactly one canonical queue row and budget account")
    item = items.get(args.work)
    if not isinstance(item, dict) or item.get("work_version") != args.work:
        raise ValueError("canonical admission snapshot lacks the exact prepared work row")
    if item.get("phase") != "pre_claim" or item.get("reason") != "eligible" or item.get("claim") is not None:
        raise ValueError("campaign ancestry requires the still-unclaimed canonical eligible row")
    account_id = item.get("account")
    account = accounts.get(account_id) if isinstance(account_id, str) else None
    if not isinstance(account, dict) or account.get("identity") != account_id or account.get("parent") is not None or account.get("parent_attempt") is not None:
        raise ValueError("prepared work does not bind an actual canonical root BudgetAccount")
    if account.get("campaign") != "scripted_local" or account.get("tenant") != "scripted_local" \
        or item.get("campaign") != "scripted_local" or item.get("tenant") != "scripted_local" \
        or item.get("repository") != "qualification-disposable" or account.get("deadline_ms") != item.get("deadline_ms"):
        raise ValueError("canonical budget account or queue row is outside the exact synthetic fixture scope")

    base = manifest.get("base", {}).get("native_id")
    if not isinstance(base, str) or not re.fullmatch(r"[0-9a-f]{40,64}", base):
        raise ValueError("immutable fixture repository manifest lacks its exact baseline commit")
    instruction_path = f"{base}:.cairn/changes/{change}/tasks.md"
    instructions = subprocess.check_output([
        "git", f"--git-dir={repository_path}", "show", instruction_path,
    ], timeout=60)
    if not instructions or len(instructions) > 65_536:
        raise ValueError("selected native Cairn task instructions are empty or over bound")

    member["profile_version"] = digest_file(workflow_path)
    member["repository_instructions"] = digest_bytes(instructions)
    member["policy"] = digest_file(policy_path)
    member["integration_policy"] = digest_file(integration_policy_path)
    contract["parent_budget_id"] = account_id
    contract["agent_definition"] = digest_file(agent_definition_path)

    payload = (json.dumps(template, sort_keys=True, indent=2) + "\n").encode()
    fd = os.open(output, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0), 0o600)
    try:
        with os.fdopen(fd, "wb", closefd=False) as destination:
            destination.write(payload)
            destination.flush()
            os.fsync(destination.fileno())
        os.fchmod(fd, 0o600)
    finally:
        os.close(fd)


if __name__ == "__main__":
    main()
