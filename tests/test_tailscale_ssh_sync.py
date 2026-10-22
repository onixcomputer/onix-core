"""Behavioral regressions for generated Tailscale SSH address inventories."""

from __future__ import annotations

import errno
import importlib.util
import json
import os
import shutil
import stat
import subprocess
import sys
from pathlib import Path
from types import ModuleType
from typing import Any

import pytest

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "inventory/home-profiles/brittonr/base/tailscale-ssh-sync.py"


@pytest.fixture(scope="module")
def sync_module() -> ModuleType:
    spec = importlib.util.spec_from_file_location("tailscale_ssh_sync", SCRIPT)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def peer(
    name: str,
    address: str,
    *,
    online: bool = True,
    hostname: str = "raw-device",
) -> dict[str, Any]:
    return {
        "DNSName": name,
        "HostName": hostname,
        "TailscaleIPs": [address],
        "Online": online,
    }


def snapshot(*peers: dict[str, Any]) -> dict[str, Any]:
    return {
        "BackendState": "Running",
        "Self": peer("self.tail-a.ts.net.", "100.64.0.1"),
        "Peer": {f"peer-{index}": node for index, node in enumerate(peers)},
    }


@pytest.fixture(scope="module")
def openssh() -> str:
    executable = shutil.which("ssh")
    if executable is None:
        pytest.skip("OpenSSH ssh is required for configuration interpretation")
    return executable


@pytest.fixture
def ssh_config(tmp_path: Path) -> tuple[Path, Path]:
    generated = tmp_path / "tailscale_hosts"
    config = tmp_path / "ssh_config"
    config.write_text(
        "Host *\n"
        "  AddressFamily inet\n"
        "  User policy-user\n"
        "  IdentityFile /no-such-tailscale-sync-test-key\n"
        "  StrictHostKeyChecking yes\n"
        f'Include "{generated}"\n',
        encoding="utf-8",
    )
    return config, generated


def ssh_options(executable: str, config: Path, alias: str) -> dict[str, str]:
    result = subprocess.run(
        [
            executable,
            "-G",
            "-F",
            str(config),
            "-o",
            "CanonicalizeHostname=no",
            alias,
        ],
        check=True,
        capture_output=True,
        text=True,
        timeout=10,
    )
    return dict(line.split(" ", 1) for line in result.stdout.splitlines())


def test_openssh_resolves_self_and_offline_aliases_without_changing_policy(
    sync_module: ModuleType,
    openssh: str,
    ssh_config: tuple[Path, Path],
) -> None:
    config, generated = ssh_config
    offline = peer(
        "Offline.Tail-A.ts.net.",
        "100.64.0.2",
        online=False,
        hostname="raw hostname\n  User root",
    )
    offline["TailscaleIPs"].insert(0, "fd7a:115c:a1e0::2")
    sync_module.write_config(generated, sync_module.render_config(snapshot(offline)))

    for alias, address in (
        ("self", "100.64.0.1"),
        ("self.tail-a.ts.net", "100.64.0.1"),
        ("offline", "100.64.0.2"),
        ("offline.tail-a.ts.net", "100.64.0.2"),
    ):
        options = ssh_options(openssh, config, alias)
        assert options["hostname"] == address
        assert options["addressfamily"] == "inet"
        assert options["user"] == "policy-user"
        assert options["identityfile"] == "/no-such-tailscale-sync-test-key"
        assert options["stricthostkeychecking"] in {"yes", "true"}


def test_duplicate_device_hostnames_use_distinct_assigned_dns_names(
    sync_module: ModuleType,
    openssh: str,
    ssh_config: tuple[Path, Path],
) -> None:
    config, generated = ssh_config
    status = snapshot(
        peer("phone.tail-a.ts.net.", "100.64.0.2", hostname="phone"),
        peer("phone-1.tail-a.ts.net.", "100.64.0.3", hostname="phone"),
    )
    sync_module.write_config(generated, sync_module.render_config(status))

    for alias, address in (
        ("phone", "100.64.0.2"),
        ("phone.tail-a.ts.net", "100.64.0.2"),
        ("phone-1", "100.64.0.3"),
        ("phone-1.tail-a.ts.net", "100.64.0.3"),
    ):
        assert ssh_options(openssh, config, alias)["hostname"] == address


def test_ambiguous_short_aliases_are_omitted_but_full_names_still_resolve(
    sync_module: ModuleType,
    openssh: str,
    ssh_config: tuple[Path, Path],
) -> None:
    config, generated = ssh_config
    status = snapshot(
        peer("worker.tail-a.ts.net.", "100.64.0.2"),
        peer("Worker.tail-b.ts.net.", "100.64.0.3", online=False),
    )
    sync_module.write_config(generated, sync_module.render_config(status))

    assert ssh_options(openssh, config, "worker")["hostname"] == "worker"
    assert (
        ssh_options(openssh, config, "worker.tail-a.ts.net")["hostname"] == "100.64.0.2"
    )
    assert (
        ssh_options(openssh, config, "worker.tail-b.ts.net")["hostname"] == "100.64.0.3"
    )


def test_complete_null_peer_inventory_removes_deleted_aliases(
    sync_module: ModuleType,
    openssh: str,
    ssh_config: tuple[Path, Path],
) -> None:
    config, generated = ssh_config
    status = snapshot(peer("retired.tail-a.ts.net.", "100.64.0.2"))
    sync_module.write_config(generated, sync_module.render_config(status))
    assert ssh_options(openssh, config, "retired")["hostname"] == "100.64.0.2"

    status["Peer"] = None
    sync_module.write_config(generated, sync_module.render_config(status))
    assert ssh_options(openssh, config, "retired")["hostname"] == "retired"
    assert (
        ssh_options(openssh, config, "retired.tail-a.ts.net")["hostname"]
        == "retired.tail-a.ts.net"
    )
    assert ssh_options(openssh, config, "self")["hostname"] == "100.64.0.1"


@pytest.fixture
def status_command(tmp_path: Path) -> tuple[Path, Path, Path]:
    """A real subprocess for failures at the CLI's external-command boundary."""
    command = tmp_path / "fake-tailscale"
    payload = command.with_suffix(".json")
    mode = command.with_suffix(".mode")
    command.write_text(
        f"""#!{sys.executable}
import sys
import time
from pathlib import Path

command = Path(__file__)
mode = command.with_suffix(".mode").read_text(encoding="utf-8")
if mode == "timeout":
    time.sleep(60)
sys.stdout.buffer.write(command.with_suffix(".json").read_bytes())
if mode == "fail":
    sys.exit(7)
""",
        encoding="utf-8",
    )
    command.chmod(0o700)
    payload.write_text(json.dumps(snapshot()), encoding="utf-8")
    mode.write_text("ok", encoding="utf-8")
    return command, payload, mode


@pytest.fixture
def last_good(
    tmp_path: Path, sync_module: ModuleType
) -> tuple[Path, bytes, os.stat_result]:
    output = tmp_path / "ssh" / "tailscale_hosts"
    status = snapshot(peer("retained.tail-a.ts.net.", "100.64.0.2", online=False))
    sync_module.write_config(output, sync_module.render_config(status))
    return output, output.read_bytes(), output.stat()


def assert_preserved(output: Path, data: bytes, info: os.stat_result) -> None:
    assert output.read_bytes() == data
    after = output.stat()
    assert after.st_ino == info.st_ino
    assert after.st_mtime_ns == info.st_mtime_ns
    assert stat.S_IMODE(after.st_mode) == 0o600
    assert list(output.parent.iterdir()) == [output]


@pytest.mark.parametrize(
    ("field", "value"),
    [
        pytest.param(
            "DNSName",
            "node.tail-a.ts.net.\nHost *\n  ProxyCommand /bin/false",
            id="dns-directive-injection",
        ),
        pytest.param("DNSName", "*.tail-a.ts.net.", id="dns-host-pattern"),
        pytest.param("DNSName", "\N{KELVIN SIGN}.tail-a.ts.net.", id="dns-non-ascii"),
        pytest.param("DNSName", "node", id="dns-not-fqdn"),
        pytest.param("DNSName", f"{'x' * 64}.tail-a.ts.net.", id="dns-long-label"),
        pytest.param(
            "TailscaleIPs", ["100.64.0.3\n  User root"], id="ip-directive-injection"
        ),
        pytest.param("TailscaleIPs", ["100.64.0.3/32"], id="ip-not-an-address"),
        pytest.param(
            "TailscaleIPs", ["100.64.0.3", "not-an-ip"], id="ip-invalid-secondary"
        ),
        pytest.param("TailscaleIPs", ["fd7a:115c:a1e0::3"], id="ip-no-ipv4"),
        pytest.param("TailscaleIPs", ["100.64.0.3", "fe80::3%eth0"], id="ip-scope-id"),
        pytest.param("TailscaleIPs", [100640003], id="ip-not-a-string"),
        pytest.param("TailscaleIPs", [], id="ip-empty"),
    ],
)
def test_untrusted_node_metadata_preserves_last_good(
    field: str,
    value: object,
    sync_module: ModuleType,
    status_command: tuple[Path, Path, Path],
    last_good: tuple[Path, bytes, os.stat_result],
) -> None:
    command, payload, _mode = status_command
    output, data, info = last_good
    status = snapshot(peer("new.tail-a.ts.net.", "100.64.0.3"))
    status["Peer"]["peer-0"][field] = value
    payload.write_text(json.dumps(status), encoding="utf-8")

    assert sync_module.main(["--tailscale", str(command), "--output", str(output)]) == 1
    assert_preserved(output, data, info)


@pytest.mark.parametrize(
    "fault",
    [
        "not-running",
        "missing-self",
        "missing-peer-inventory",
        "malformed-peer-inventory",
        "malformed-peer-entry",
        "conflicting-full-name",
    ],
)
def test_incomplete_or_conflicting_status_preserves_last_good(
    fault: str,
    sync_module: ModuleType,
    status_command: tuple[Path, Path, Path],
    last_good: tuple[Path, bytes, os.stat_result],
) -> None:
    command, payload, _mode = status_command
    output, data, info = last_good
    status = snapshot(peer("new.tail-a.ts.net.", "100.64.0.3"))
    if fault == "not-running":
        status["BackendState"] = "Starting"
    elif fault == "missing-self":
        del status["Self"]
    elif fault == "missing-peer-inventory":
        del status["Peer"]
    elif fault == "malformed-peer-inventory":
        status["Peer"] = []
    elif fault == "malformed-peer-entry":
        status["Peer"]["peer-0"] = None
    else:
        status["Peer"]["peer-0"]["DNSName"] = "SELF.tail-a.ts.net."
    payload.write_text(json.dumps(status), encoding="utf-8")

    assert sync_module.main(["--tailscale", str(command), "--output", str(output)]) == 1
    assert_preserved(output, data, info)


@pytest.mark.parametrize("payload_bytes", [b"not JSON", b"\xff"])
def test_invalid_command_output_preserves_last_good(
    payload_bytes: bytes,
    sync_module: ModuleType,
    status_command: tuple[Path, Path, Path],
    last_good: tuple[Path, bytes, os.stat_result],
) -> None:
    command, payload, _mode = status_command
    output, data, info = last_good
    payload.write_bytes(payload_bytes)

    assert sync_module.main(["--tailscale", str(command), "--output", str(output)]) == 1
    assert_preserved(output, data, info)


@pytest.mark.parametrize("failure", ["fail", "timeout", "missing"])
def test_command_failure_preserves_last_good(
    failure: str,
    sync_module: ModuleType,
    status_command: tuple[Path, Path, Path],
    last_good: tuple[Path, bytes, os.stat_result],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    command, _payload, mode = status_command
    output, data, info = last_good
    mode.write_text(failure, encoding="utf-8")
    if failure == "timeout":
        monkeypatch.setattr(sync_module, "STATUS_TIMEOUT_SECONDS", 0.05)
    elif failure == "missing":
        command = command.with_name("missing-tailscale")

    assert sync_module.main(["--tailscale", str(command), "--output", str(output)]) == 1
    assert_preserved(output, data, info)


@pytest.mark.parametrize("failure", ["fsync", "replace"])
def test_output_failure_preserves_last_good_and_removes_temporary_files(
    failure: str,
    sync_module: ModuleType,
    status_command: tuple[Path, Path, Path],
    last_good: tuple[Path, bytes, os.stat_result],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    command, payload, _mode = status_command
    output, data, info = last_good
    payload.write_text(
        json.dumps(snapshot(peer("new.tail-a.ts.net.", "100.64.0.3"))),
        encoding="utf-8",
    )

    def fail_fsync(_descriptor: int) -> None:
        raise OSError(errno.ENOSPC, os.strerror(errno.ENOSPC))

    def fail_replace(_source: Path, _target: Path) -> Path:
        raise OSError(errno.EACCES, os.strerror(errno.EACCES))

    if failure == "fsync":
        monkeypatch.setattr(sync_module.os, "fsync", fail_fsync)
    else:
        monkeypatch.setattr(Path, "replace", fail_replace)

    assert sync_module.main(["--tailscale", str(command), "--output", str(output)]) == 1
    assert_preserved(output, data, info)


def test_atomic_refresh_stages_complete_private_content_and_skips_identical_rewrites(
    sync_module: ModuleType,
    last_good: tuple[Path, bytes, os.stat_result],
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    output, old_data, old_info = last_good
    status = snapshot(peer("new.tail-a.ts.net.", "100.64.0.3"))
    content = sync_module.render_config(status)
    original_replace = Path.replace

    def inspect_replace(source: Path, target: Path) -> Path:
        assert target == output
        assert source.parent == output.parent
        assert output.read_bytes() == old_data
        assert source.read_bytes() == content.encode("ascii")
        assert stat.S_IMODE(source.stat().st_mode) == 0o600
        return original_replace(source, target)

    with monkeypatch.context() as patch:
        patch.setattr(Path, "replace", inspect_replace)
        assert sync_module.write_config(output, content) is True

    new_data = output.read_bytes()
    new_info = output.stat()
    assert new_data == content.encode("ascii")
    assert new_info.st_ino != old_info.st_ino
    assert stat.S_IMODE(new_info.st_mode) == 0o600
    assert sync_module.write_config(output, content) is False
    assert_preserved(output, new_data, new_info)


def test_identical_content_permissions_are_repaired_without_rewriting(
    sync_module: ModuleType,
    last_good: tuple[Path, bytes, os.stat_result],
) -> None:
    output, data, info = last_good
    output.chmod(0o644)

    assert sync_module.write_config(output, data.decode("ascii")) is False
    assert_preserved(output, data, info)
