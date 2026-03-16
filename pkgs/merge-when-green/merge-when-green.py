#!/usr/bin/env python3
"""
merge-when-green - Create PR and merge when CI passes
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from enum import Enum
from pathlib import Path
from typing import Any


class Colors:
    """ANSI color codes for terminal output."""

    BLUE = "\033[94m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    GRAY = "\033[90m"
    BOLD = "\033[1m"
    RESET = "\033[0m"


class Platform(Enum):
    """Git hosting platform."""

    GITHUB = "github"
    GITEA = "gitea"


def print_info(message: str) -> None:
    """Print an informational message."""
    print(message)


def print_success(message: str) -> None:
    """Print a success message in green."""
    print(f"{Colors.GREEN}{message}{Colors.RESET}")


def print_error(message: str) -> None:
    """Print an error message in red."""
    print(f"{Colors.RED}{message}{Colors.RESET}")


def print_warning(message: str) -> None:
    """Print a warning message in yellow."""
    print(f"{Colors.YELLOW}{message}{Colors.RESET}")


def print_header(message: str) -> None:
    """Print a header message in bold."""
    print(f"\n{Colors.BOLD}{message}{Colors.RESET}")


def print_subtle(message: str) -> None:
    """Print a subtle message in gray."""
    print(f"{Colors.GRAY}{message}{Colors.RESET}")


def run(
    cmd: list[str], check: bool = True, capture: bool = False
) -> subprocess.CompletedProcess[str]:
    """Run a command."""
    if capture:
        result = subprocess.run(cmd, check=False, capture_output=True, text=True)
        if result.returncode != 0 and check:
            raise subprocess.CalledProcessError(result.returncode, cmd)
        return result
    return subprocess.run(cmd, check=check, text=True)


def detect_platform() -> Platform:
    """Detect platform: GitHub or Gitea."""
    # Try GitHub first
    result = run(["gh", "repo", "view", "--json", "name"], check=False, capture=True)
    if result.returncode == 0:
        print_subtle("Detected GitHub")
        return Platform.GITHUB

    # Try Gitea
    result = run(["tea", "repos", "list", "--limit", "1"], check=False, capture=True)
    if result.returncode == 0:
        print_subtle("Detected Gitea")
        return Platform.GITEA

    print_warning("Could not detect platform, defaulting to GitHub")
    return Platform.GITHUB


def ensure_auto_merge_enabled(platform: Platform) -> None:
    """Bail early if auto-merge is not enabled on the repo."""
    if platform != Platform.GITHUB:
        return
    result = run(
        ["gh", "api", "repos/{owner}/{repo}", "--jq", ".allow_auto_merge"],
        check=False,
        capture=True,
    )
    if result.returncode == 0 and result.stdout.strip() == "false":
        print_error(
            "Auto-merge is not enabled on this repository.\n"
            "Enable it with:\n"
            "  gh api repos/{owner}/{repo} --method PATCH -f allow_auto_merge=true"
        )
        sys.exit(1)


def get_default_branch(platform: Platform) -> str:
    """Get default branch."""
    if platform == Platform.GITHUB:
        result = run(
            [
                "gh",
                "repo",
                "view",
                "--json",
                "defaultBranchRef",
                "--jq",
                ".defaultBranchRef.name",
            ],
            capture=True,
        )
        return result.stdout.strip()

    # Gitea: use git symbolic-ref
    result = run(
        ["git", "symbolic-ref", "refs/remotes/origin/HEAD"], check=False, capture=True
    )
    if result.returncode == 0:
        return result.stdout.strip().split("/")[-1]
    return "main"


def get_repo_info() -> tuple[str, str, str]:
    """Parse git remote to get API URL, owner, repo."""
    result = run(["git", "remote", "get-url", "origin"], capture=True)
    remote_url = result.stdout.strip()

    # SSH: git@host:owner/repo.git or HTTPS: https://host/owner/repo.git
    match = re.match(
        r"(?:https?://|git@)([^/:]+)[:/]([^/]+)/(.+?)(?:\.git)?$", remote_url
    )
    if not match:
        msg = f"Could not parse remote URL: {remote_url}"
        raise RuntimeError(msg)

    host, owner, repo = match.groups()
    api_url = f"https://{host}"
    return api_url, owner, repo


def check_pr_exists(branch: str, platform: Platform) -> bool:
    """Check if a PR already exists for this branch."""
    if platform == Platform.GITHUB:
        result = run(
            ["gh", "pr", "view", branch, "--json", "state"],
            check=False,
            capture=True,
        )
        if result.returncode == 0:
            try:
                pr_data = json.loads(result.stdout)
                state = pr_data.get("state")
                return bool(state == "OPEN")
            except json.JSONDecodeError:
                pass
    else:
        # Gitea
        result = run(
            ["tea", "pulls", "list", "--output", "json", "--state", "open"],
            check=False,
            capture=True,
        )
        if result.returncode == 0:
            try:
                prs = json.loads(result.stdout)
                for pr in prs:
                    if pr.get("head", {}).get("ref") == branch:
                        return True
            except json.JSONDecodeError:
                pass
    return False


def create_pr_github(branch: str, target: str, title: str, body: str) -> str:
    """Create GitHub PR and enable auto-merge."""
    result = run(
        [
            "gh",
            "pr",
            "create",
            "--title",
            title,
            "--body",
            body,
            "--base",
            target,
            "--head",
            branch,
        ],
        check=False,
    )
    if result.returncode != 0:
        print_warning("PR creation failed, likely already exists")

    print_warning("Enabling auto-merge...")
    run(["gh", "pr", "merge", branch, "--auto", "--rebase"])
    print_success("Auto-merge enabled")
    return branch


def create_pr_gitea(branch: str, target: str, title: str, body: str) -> str:
    """Create Gitea PR and enable server-side auto-merge."""
    # Create PR
    result = run(
        [
            "tea",
            "pulls",
            "create",
            "--head",
            branch,
            "--base",
            target,
            "--title",
            title,
            "--description",
            body,
            "--output",
            "json",
        ],
        capture=True,
    )

    try:
        pr_data = json.loads(result.stdout)
        pr_index = str(pr_data["index"])
    except (json.JSONDecodeError, KeyError):
        print_warning("Could not parse PR number, using branch name")
        return branch

    # Enable auto-merge via API
    print_warning("Enabling auto-merge...")
    api_url, owner, repo = get_repo_info()
    token = os.environ.get("GITEA_TOKEN")

    url = f"{api_url}/api/v1/repos/{owner}/{repo}/pulls/{pr_index}/merge"
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"token {token}"

    data = json.dumps(
        {
            "Do": "merge",
            "merge_when_checks_succeed": True,
            "delete_branch_after_merge": True,
        }
    ).encode()

    req = urllib.request.Request(url, data=data, headers=headers, method="POST")  # noqa: S310
    try:
        urllib.request.urlopen(req, timeout=10)  # noqa: S310
        print_success("Auto-merge enabled")
    except (urllib.error.HTTPError, urllib.error.URLError) as e:
        print_warning(f"Could not enable auto-merge: {e}")

    return pr_index


def check_github_pr_state(pr_id: str) -> bool | None:
    """Check GitHub PR state. Returns True if merged, False if closed, None if open."""
    result = run(
        ["gh", "pr", "view", pr_id, "--json", "state"], check=False, capture=True
    )
    if result.returncode != 0:
        return None
    pr_data = json.loads(result.stdout)
    state = pr_data.get("state", "")
    if state == "MERGED":
        return True
    if state == "CLOSED":
        print_error("PR was closed")
        return False
    return None


def check_gitea_pr_state(pr_id: str) -> bool | None:
    """Check Gitea PR state. Returns True if merged, False if closed, None if open."""
    result = run(
        ["tea", "pulls", "list", "--output", "json", "--state", "all"],
        check=False,
        capture=True,
    )
    if result.returncode != 0:
        return None

    try:
        prs = json.loads(result.stdout)
        for pr in prs:
            if str(pr.get("index")) == pr_id:
                state = pr.get("state", "").lower()
                if state == "closed":
                    if pr.get("merged"):
                        return True
                    print_error("PR was closed without merging")
                    return False
                break
    except json.JSONDecodeError:
        pass
    return None


def classify_checks(
    checks: list[dict[str, Any]],
) -> tuple[int, int, int, list[tuple[str, str, str | None]]]:
    """Classify check states from PR status checks.

    Returns (pending, failed, passed, details) where details is a list of
    (name, status_symbol, details_url) tuples for each check.
    """
    pending = failed = passed = 0
    details: list[tuple[str, str, str | None]] = []
    for check in checks:
        name = check.get("name") or check.get("context") or "unknown"
        url = check.get("detailsUrl") or check.get("targetUrl")
        if check.get("__typename") == "CheckRun":
            status = check.get("status")
            conclusion = check.get("conclusion")
            if status != "COMPLETED":
                pending += 1
                details.append((name, "⏳", url))
            elif conclusion in ["SUCCESS", "NEUTRAL", "SKIPPED"]:
                passed += 1
                details.append((name, "✅", url))
            else:
                failed += 1
                details.append((name, "❌", url))
        elif check.get("__typename") == "StatusContext":
            check_state = check.get("state")
            if check_state == "PENDING":
                pending += 1
                details.append((name, "⏳", url))
            elif check_state in ["SUCCESS", "NEUTRAL"]:
                passed += 1
                details.append((name, "✅", url))
            else:
                failed += 1
                details.append((name, "❌", url))
    return pending, failed, passed, details


def check_pr_completion(
    pr_data: dict[str, Any], pending: int, failed: int
) -> tuple[bool, str] | None:
    """Check if PR has reached a completion state. Returns None if still waiting."""
    state = pr_data.get("state", "UNKNOWN")
    mergeable = pr_data.get("mergeable", "UNKNOWN")
    auto_merge = pr_data.get("autoMergeRequest") is not None

    if state == "MERGED":
        return True, "PR successfully merged!"

    if state == "CLOSED":
        return False, "PR was closed"

    if not auto_merge:
        return False, "Auto-merge was disabled"

    if mergeable == "CONFLICTING":
        return False, "PR has merge conflicts"

    if failed > 0 and pending == 0:
        return False, f"{failed} checks failed"

    return None  # Still waiting


def get_pr_status_github(pr_id: str) -> tuple[dict[str, Any] | None, str]:
    """Get PR status from GitHub."""
    result = run(
        [
            "gh",
            "pr",
            "view",
            pr_id,
            "--json",
            "state,mergeable,autoMergeRequest,statusCheckRollup,url",
        ],
        check=False,
        capture=True,
    )

    if result.returncode != 0:
        return None, "Failed to get PR status"

    try:
        pr_data = json.loads(result.stdout)
    except json.JSONDecodeError:
        return None, "Failed to parse PR status"
    else:
        return pr_data, ""


def run_buildbot_check_if_needed(
    pr_data: dict[str, Any], failed: int, pending: int, buildbot_check_done: bool
) -> bool:
    """Run buildbot-pr-check if needed."""
    if failed > 0 and pending == 0 and not buildbot_check_done:
        pr_url = pr_data.get("url", "")
        if pr_url and shutil.which("buildbot-pr-check"):
            print_warning(
                "\nRunning buildbot-pr-check to get detailed failure information..."
            )
            run(["buildbot-pr-check", pr_url], check=False)
            print()  # Add blank line after buildbot-pr-check output
        return True
    return buildbot_check_done


def parse_buildbot_url(url: str) -> tuple[str, str, str] | None:
    """Parse buildbot URL into (base_url, builder_id, build_num)."""
    match = re.search(r"/builders/(\d+)/builds/(\d+)", url)
    if not match:
        return None
    # Extract hostname from https://buildbot.example.com/#/builders/...
    try:
        base_url = url.split("//")[1].split("/")[0]
    except IndexError:
        return None
    return base_url, match.group(1), match.group(2)


def _fetch_buildbot_json(url: str) -> Any:
    """Fetch JSON from buildbot API with timeout."""
    req = urllib.request.Request(url)  # noqa: S310
    req.add_header("User-Agent", "merge-when-green/0.3")
    with urllib.request.urlopen(req, timeout=10) as resp:  # noqa: S310
        return json.loads(resp.read())


def _parse_nix_log_tail(raw: str) -> str | None:
    """Extract the last meaningful status line from nix build log output."""
    # Walk backwards through lines for the last interesting event
    for line in reversed(raw.splitlines()):
        line = line.strip()
        # "building '/nix/store/hash-name.drv'..."
        m = re.search(r"building '/nix/store/[a-z0-9]+-(.+?)\.drv'", line)
        if m:
            return f"building {m.group(1)}"
        # "copying path '/nix/store/hash-name' to ..."
        m = re.search(r"copying path '/nix/store/[a-z0-9]+-(.+?)'", line)
        if m:
            return f"copying {m.group(1)}"
        # "fetching path '/nix/store/hash-name'..."
        m = re.search(r"fetching path '/nix/store/[a-z0-9]+-(.+?)'", line)
        if m:
            return f"fetching {m.group(1)}"
        # nix3-style: "building foo-1.2.3 (3 built, 12 to do)"
        # nom-style: sometimes "building foo (3/47)"
        m = re.search(r"(building|evaluating) .+", line)
        if m:
            return m.group(0)[:80]
    return None


def _get_step_log_tail(base_url: str, step_id: int) -> str | None:
    """Fetch the last ~4KB of the active step's log."""
    try:
        logs_data = _fetch_buildbot_json(
            f"https://{base_url}/api/v2/steps/{step_id}/logs"
        )
        logs = logs_data.get("logs", [])
        if not logs:
            return None

        log_id = logs[0].get("logid")
        num_lines = logs[0].get("num_lines", 0)
        if not log_id or num_lines == 0:
            return None

        # Fetch last 30 lines of log content
        offset = max(0, num_lines - 30)
        content_data = _fetch_buildbot_json(
            f"https://{base_url}/api/v2/logs/{log_id}/contents?offset={offset}&limit=30"
        )
        chunks = content_data.get("logchunks", [])
        raw = "".join(c.get("content", "") for c in chunks)
        return _parse_nix_log_tail(raw)
    except (
        urllib.error.URLError,
        urllib.error.HTTPError,
        json.JSONDecodeError,
        KeyError,
    ):
        return None


def _get_active_step(base_url: str, req_id: int) -> str | None:
    """Get the currently running step and what it's doing."""
    try:
        builds_data = _fetch_buildbot_json(
            f"https://{base_url}/api/v2/buildrequests/{req_id}/builds"
        )
        builds = builds_data.get("builds", [])
        if not builds:
            return "queued"

        build_id = builds[0].get("buildid")
        if not build_id:
            return None

        steps_data = _fetch_buildbot_json(
            f"https://{base_url}/api/v2/builds/{build_id}/steps"
        )
        # Find the currently running step (last incomplete one)
        for step in steps_data.get("steps", []):
            if not step.get("complete", False):
                step_name = step.get("name", "")
                state = step.get("state_string", "")
                label = state if state else step_name

                # For build steps, dig into the log for derivation detail
                step_id = step.get("stepid")
                if step_id and "build" in step_name.lower():
                    drv = _get_step_log_tail(base_url, step_id)
                    if drv:
                        return drv

                return label
        return None
    except (
        urllib.error.URLError,
        urllib.error.HTTPError,
        json.JSONDecodeError,
        KeyError,
    ):
        return None


def _check_one_build_request(
    base_url: str, req_id: int
) -> tuple[str, str, str | None] | None:
    """Check status of a single build request. Returns (name, symbol, step_info)."""
    try:
        data = _fetch_buildbot_json(
            f"https://{base_url}/api/v2/buildrequests/{req_id}?property=*"
        )
        request = data["buildrequests"][0]
        result_code = request.get("results")
        properties = request.get("properties", {})

        # Get name from virtual_builder_name property
        name = None
        if "virtual_builder_name" in properties:
            vname = properties["virtual_builder_name"][0]
            name = vname.split("#", 1)[1] if "#" in vname else vname
        if not name:
            name = f"request-{req_id}"

        # Map result code to symbol
        step_info = None
        if result_code is None:
            symbol = "🔨"
            step_info = _get_active_step(base_url, req_id)
        elif result_code == 0:
            symbol = "✅"
        elif result_code in (1, 3):  # warnings, skipped
            symbol = "⏭️"
        else:
            symbol = "❌"

        return name, symbol, step_info
    except (
        urllib.error.URLError,
        urllib.error.HTTPError,
        json.JSONDecodeError,
        KeyError,
        IndexError,
    ):
        return None


def query_buildbot_subbuilds(
    details_url: str,
) -> list[tuple[str, str, str | None]]:
    """Query Buildbot API for sub-build statuses.

    Returns list of (name, symbol, step_info) for each triggered sub-build.
    """
    parsed = parse_buildbot_url(details_url)
    if not parsed:
        return []
    base_url, builder_id, build_num = parsed

    # Get triggered build request IDs from build steps
    try:
        steps_data = _fetch_buildbot_json(
            f"https://{base_url}/api/v2/builders/{builder_id}/builds/{build_num}/steps"
        )
    except (urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError):
        return []

    request_ids = []
    for step in steps_data.get("steps", []):
        if "build" in step.get("name", "").lower():
            for url_info in step.get("urls", []):
                match = re.search(r"buildrequests/(\d+)", url_info.get("url", ""))
                if match:
                    request_ids.append(int(match.group(1)))

    if not request_ids:
        return []

    # Query all build requests in parallel
    results: list[tuple[str, str, str | None]] = []
    workers = min(20, len(request_ids))
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {
            pool.submit(_check_one_build_request, base_url, rid): rid
            for rid in sorted(request_ids)
        }
        for future in as_completed(futures):
            result = future.result()
            if result:
                results.append(result)

    # Sort by name for stable output
    results.sort(key=lambda r: r[0])
    return results


def wait_for_merge(platform: Platform, pr_id: str) -> bool:
    """Wait for PR to be merged."""
    print_header(f"Waiting for PR '{pr_id}' to merge...")

    if platform == Platform.GITEA:
        # Gitea: simple polling
        while True:
            result = check_gitea_pr_state(pr_id)
            if result is not None:
                return result
            print(f"[{time.strftime('%H:%M:%S')}] Waiting...")
            time.sleep(30)

    # GitHub: detailed check monitoring
    buildbot_check_done = False
    prev_lines = 0
    while True:
        pr_data, error = get_pr_status_github(pr_id)
        if pr_data is None:
            print_error(error)
            return False

        checks = pr_data.get("statusCheckRollup", [])
        pending, failed, passed, details = classify_checks(checks)

        # Move cursor up to overwrite previous output
        if prev_lines > 0:
            sys.stdout.write(f"\033[{prev_lines}A\033[J")

        # Print summary line
        print(
            f"[{time.strftime('%H:%M:%S')}] "
            f"Checks - {Colors.GREEN}Passed: {passed}{Colors.RESET}, "
            f"{Colors.RED}Failed: {failed}{Colors.RESET}, "
            f"{Colors.YELLOW}Pending: {pending}{Colors.RESET}"
        )
        # Print per-check details, with buildbot sub-builds expanded
        extra_lines = 0
        for name, symbol, details_url in details:
            print(f"  {symbol} {name}")
            if details_url and "buildbot" in details_url:
                subbuilds = query_buildbot_subbuilds(details_url)
                for sub_name, sub_symbol, step_info in subbuilds:
                    if step_info:
                        print(
                            f"    {sub_symbol} {sub_name}"
                            f" {Colors.GRAY}({step_info}){Colors.RESET}"
                        )
                    else:
                        print(f"    {sub_symbol} {sub_name}")
                    extra_lines += 1
        sys.stdout.flush()
        prev_lines = 1 + len(details) + extra_lines

        # Run buildbot-pr-check if we have failing checks
        buildbot_check_done = run_buildbot_check_if_needed(
            pr_data, failed, pending, buildbot_check_done
        )

        # Check for completion
        completion = check_pr_completion(pr_data, pending, failed)
        if completion is not None:
            success, message = completion
            if not success:
                print_error(f"\n{message}")
            return success

        # Still waiting
        time.sleep(10)


def get_pr_message_from_editor(default_branch: str) -> tuple[str, str]:
    """Get PR title/body by opening editor with commit messages."""
    remote = (
        "upstream"
        if "upstream" in run(["git", "remote"], capture=True).stdout
        else "origin"
    )
    commits = run(
        [
            "git",
            "log",
            "--reverse",
            "--pretty=format:%s%n%n%b%n%n",
            f"{remote}/{default_branch}..HEAD",
        ],
        capture=True,
    ).stdout

    with tempfile.NamedTemporaryFile(
        mode="w+", suffix="_COMMIT_EDITMSG", delete=False
    ) as f:
        f.write(commits)
        f.flush()
        editor = os.environ.get("EDITOR", "vim")
        subprocess.run([editor, f.name], check=True)
        f.seek(0)
        msg = f.read()
    Path(f.name).unlink()

    lines = msg.split("\n", 1)
    return lines[0], lines[1] if len(lines) > 1 else ""


def prepare_repository(default_branch: str) -> int:
    """Prepare repository: pull, format check. Returns 0 if ready, 1 on error."""
    print_header("Preparing changes...")
    run(["git", "pull", "--rebase", "origin", default_branch])

    # Use nix fmt instead of flake-fmt
    print_header("Checking code formatting...")
    result = run(["nix", "fmt"], check=False)
    if result.returncode != 0:
        print_warning("Formatting issues found. Attempting to fix...")
        run(
            [
                "git",
                "absorb",
                "--force",
                "--and-rebase",
                "--base",
                f"origin/{default_branch}",
            ],
            check=False,
        )
        if sys.stdin.isatty() and sys.stdout.isatty():
            run(["lazygit"], check=False)
        else:
            print_error("Formatting check failed. Please run 'nix fmt' manually.")
        return 1

    result = run(["git", "diff", "--quiet", f"origin/{default_branch}"], check=False)
    if result.returncode == 0:
        print_success("No changes to merge")
        return 1
    return 0


def get_pr_message(message_arg: str | None, default_branch: str) -> tuple[str, str]:
    """Get PR title and body from args or editor."""
    if message_arg:
        lines = message_arg.split("\n", 1)
        title = lines[0]
        body = lines[1] if len(lines) > 1 else ""
        return title, body
    return get_pr_message_from_editor(default_branch)


def push_branch(branch_name: str, default_branch: str) -> str:
    """Push branch and return the branch name to use for PR."""
    current_branch = run(
        ["git", "branch", "--show-current"], capture=True
    ).stdout.strip()

    if current_branch == default_branch:
        branch_name = f"merge-when-green-{os.environ.get('USER', 'user')}"
    else:
        branch_name = current_branch

    print_header("Pushing changes...")
    run(["git", "push", "--force", "origin", f"HEAD:{branch_name}"])
    return branch_name


def enable_automerge_existing_pr(branch_name: str, platform: Platform) -> str:
    """Enable auto-merge on existing PR. Returns PR ID."""
    print_warning("Enabling auto-merge...")
    if platform == Platform.GITHUB:
        run(["gh", "pr", "merge", branch_name, "--auto", "--rebase"])
        print_success("Auto-merge enabled")
        return branch_name

    # Gitea: need to get the PR number first
    result = run(
        ["tea", "pulls", "list", "--output", "json", "--state", "open"],
        capture=True,
    )
    try:
        prs = json.loads(result.stdout)
        for pr in prs:
            if pr.get("head", {}).get("ref") == branch_name:
                pr_id = str(pr["index"])
                # Enable auto-merge via API
                api_url, owner, repo = get_repo_info()
                token = os.environ.get("GITEA_TOKEN")
                url = f"{api_url}/api/v1/repos/{owner}/{repo}/pulls/{pr_id}/merge"
                headers = {"Content-Type": "application/json"}
                if token:
                    headers["Authorization"] = f"token {token}"
                data = json.dumps(
                    {
                        "Do": "merge",
                        "merge_when_checks_succeed": True,
                        "delete_branch_after_merge": True,
                    }
                ).encode()
                req = urllib.request.Request(  # noqa: S310
                    url, data=data, headers=headers, method="POST"
                )
                try:
                    urllib.request.urlopen(req, timeout=10)  # noqa: S310
                    print_success("Auto-merge enabled")
                except (urllib.error.HTTPError, urllib.error.URLError) as e:
                    print_warning(f"Could not enable auto-merge: {e}")
                return pr_id
    except json.JSONDecodeError:
        print_warning("Could not parse PR list")
    return branch_name


def finalize_merge(platform: Platform, pr_id: str, default_branch: str) -> int:
    """Wait for merge and rebase. Returns exit code."""
    if wait_for_merge(platform, pr_id):
        print_success("\nPR merged!")
        run(["git", "fetch", "origin", default_branch])
        run(["git", "rebase", f"origin/{default_branch}"])
        print_success("Rebased onto latest changes")
        return 0
    return 1


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(description="Create PR and merge when CI passes")
    parser.add_argument(
        "--no-wait", action="store_true", help="Don't wait for CI checks to complete"
    )
    parser.add_argument(
        "-m", "--message", help="PR title and body (separated by newline)"
    )
    args = parser.parse_args()

    platform = detect_platform()
    ensure_auto_merge_enabled(platform)

    print_header("Getting repository information...")
    default_branch = get_default_branch(platform)
    print_info(f"Target branch: {Colors.BLUE}{default_branch}{Colors.RESET}")

    if prepare_repository(default_branch) != 0:
        return 1

    branch_name = push_branch("", default_branch)

    # Check if PR already exists
    if check_pr_exists(branch_name, platform):
        print_success("Using existing pull request")
        pr_id = enable_automerge_existing_pr(branch_name, platform)
    else:
        title, body = get_pr_message(args.message, default_branch)
        print_header("Creating pull request...")
        if platform == Platform.GITHUB:
            pr_id = create_pr_github(branch_name, default_branch, title, body)
        else:
            pr_id = create_pr_gitea(branch_name, default_branch, title, body)
        print_success("Pull request created")

    if not args.no_wait:
        return finalize_merge(platform, pr_id, default_branch)

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print_warning("\nInterrupted")
        sys.exit(130)
    except subprocess.CalledProcessError as e:
        sys.exit(e.returncode)
