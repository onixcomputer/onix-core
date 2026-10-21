"""Offline search of a content-pinned public Noogle catalog."""

from pathlib import Path
from typing import Any

from searx.specialist_core import (
    MAX_CATALOG_BYTES,
    CatalogEntry,
    noogle_catalog,
    search_catalog,
)

engine_type = "offline"
categories = ["it", "software wikis"]
paging = False
about = {
    "website": "https://noogle.dev",
    "use_official_api": False,
    "require_api_key": False,
    "results": "JSON",
}
_entries: tuple[CatalogEntry, ...] = ()


def init(_settings: dict[str, Any]) -> None:
    global _entries
    path = Path(__file__).parent.parent / "data" / "noogle-catalog.json"
    with path.open("rb") as source:
        _entries = noogle_catalog(source.read(MAX_CATALOG_BYTES + 1))


def search(query: str, _params: dict[str, Any]) -> list[dict[str, str]]:
    return search_catalog(_entries, query)
