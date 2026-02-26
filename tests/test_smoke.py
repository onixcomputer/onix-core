"""Smoke tests for onix-core repo structure."""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def test_flake_exists() -> None:
    """Ensure flake.nix exists at repo root."""
    assert (ROOT / "flake.nix").is_file()


def test_machines_dir_exists() -> None:
    """Ensure machines directory exists."""
    assert (ROOT / "machines").is_dir()


def test_inventory_dir_exists() -> None:
    """Ensure inventory directory exists."""
    assert (ROOT / "inventory").is_dir()
