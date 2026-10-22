#!/usr/bin/env python3
"""Refresh SSH address aliases from a complete local Tailscale status snapshot."""

from __future__ import annotations

import argparse
import ipaddress
import json
import os
import re
import stat
import subprocess
import sys
import tempfile
from collections import Counter
from collections.abc import Sequence
from pathlib import Path

STATUS_TIMEOUT_SECONDS = 10
DNS_LABEL = re.compile(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?")


class SyncError(Exception):
    """The status command did not supply a safe, complete address inventory."""


def read_status(tailscale: str) -> object:
    """Fetch status once, with a bounded daemon/command wait."""
    try:
        result = subprocess.run(
            [tailscale, "status", "--json"],
            check=True,
            capture_output=True,
            timeout=STATUS_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired as error:
        message = f"tailscale status timed out after {STATUS_TIMEOUT_SECONDS} seconds"
        raise SyncError(message) from error
    except subprocess.CalledProcessError as error:
        message = f"tailscale status exited with status {error.returncode}"
        raise SyncError(message) from error
    except OSError as error:
        message = f"could not run tailscale status: {error.strerror}"
        raise SyncError(message) from error

    try:
        return json.loads(result.stdout)
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        message = "tailscale status did not return valid JSON"
        raise SyncError(message) from error


def node_target(node: object) -> tuple[str, str]:
    """Validate an assigned DNS name and every IP, then select an assigned IPv4."""
    if not isinstance(node, dict):
        message = "tailscale status contains a missing or invalid node"
        raise SyncError(message)

    raw_name = node.get("DNSName")
    if not isinstance(raw_name, str) or not raw_name.isascii():
        message = "tailscale node has an invalid DNSName"
        raise SyncError(message)
    name = raw_name.removesuffix(".").lower()
    labels = name.split(".")
    if (
        len(name) > 253
        or len(labels) < 2
        or any(DNS_LABEL.fullmatch(label) is None for label in labels)
    ):
        message = "tailscale node has an invalid DNSName"
        raise SyncError(message)

    raw_ips = node.get("TailscaleIPs")
    if not isinstance(raw_ips, list) or not raw_ips:
        message = "tailscale node is missing assigned IP addresses"
        raise SyncError(message)
    ipv4: ipaddress.IPv4Address | None = None
    for raw_ip in raw_ips:
        if not isinstance(raw_ip, str) or "%" in raw_ip:
            message = "tailscale node has an invalid assigned IP address"
            raise SyncError(message)
        try:
            address = ipaddress.ip_address(raw_ip)
        except ValueError as error:
            message = "tailscale node has an invalid assigned IP address"
            raise SyncError(message) from error
        if isinstance(address, ipaddress.IPv4Address) and (
            ipv4 is None or address < ipv4
        ):
            ipv4 = address
    if ipv4 is None:
        message = "tailscale node is missing an assigned IPv4 address"
        raise SyncError(message)
    return name, str(ipv4)


def render_config(status: object) -> str:
    """Render only Host/HostName, retaining offline nodes and unique short names."""
    if not isinstance(status, dict) or status.get("BackendState") != "Running":
        message = "tailscale status is unavailable or not running"
        raise SyncError(message)
    peers = status.get("Peer")
    if "Peer" not in status or (peers is not None and not isinstance(peers, dict)):
        message = "tailscale status is missing its peer inventory"
        raise SyncError(message)
    if peers is None:
        peers = {}

    name, address = node_target(status.get("Self"))
    targets = {name: address}
    for node in peers.values():
        name, address = node_target(node)
        if name in targets and targets[name] != address:
            message = "tailscale status assigns conflicting IPv4 addresses to a DNSName"
            raise SyncError(message)
        targets[name] = address

    short_counts = Counter(name.partition(".")[0] for name in targets)
    blocks = []
    for name, address in sorted(targets.items()):
        short = name.partition(".")[0]
        aliases = f"{short} {name}" if short_counts[short] == 1 else name
        blocks.append(f"Host {aliases}\n  HostName {address}\n")
    return "\n".join(blocks)


def write_config(output: Path, content: str) -> bool:
    """Atomically publish a private file; return False for unchanged content."""
    data = content.encode("ascii")
    try:
        if not output.is_symlink() and output.read_bytes() == data:
            if stat.S_IMODE(output.stat().st_mode) != 0o600:
                output.chmod(0o600)
            return False
    except FileNotFoundError:
        pass

    output.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="wb", prefix=f".{output.name}.", dir=output.parent, delete=False
        ) as temporary:
            temporary_path = Path(temporary.name)
            os.fchmod(temporary.fileno(), 0o600)
            temporary.write(data)
            temporary.flush()
            os.fsync(temporary.fileno())
        temporary_path.replace(output)
        return True
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--tailscale",
        default="tailscale",
        help="Tailscale executable (default: tailscale)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path.home() / ".ssh" / "tailscale_hosts",
        help="Generated SSH address file (default: ~/.ssh/tailscale_hosts)",
    )
    args = parser.parse_args(argv)
    try:
        content = render_config(read_status(args.tailscale))
        write_config(args.output.expanduser(), content)
    except (SyncError, OSError) as error:
        print(f"tailscale-ssh-sync: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
