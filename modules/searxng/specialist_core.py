"""Pure requests and result normalization for public developer catalogs."""

import json
import re
from dataclasses import dataclass
from urllib.parse import quote, urlencode

from lxml import html

MAX_QUERY_CHARACTERS = 256
MAX_RESULTS = 20
MAX_RESPONSE_BYTES = 2 * 1024 * 1024
MAX_CATALOG_BYTES = 8 * 1024 * 1024
MAX_CATALOG_ENTRIES = 10000
MAX_TITLE_CHARACTERS = 512
MAX_CONTENT_CHARACTERS = 1000
OPTION_NAME_BOOST = 3
SCHEMA_VERSION = 51
CHANNEL = "unstable"
BACKEND_URL = (
    f"https://search.nixos.org/backend/latest-{SCHEMA_VERSION}-nixos-{CHANNEL}/_search"
)
SOURCE_TYPES = {"nixos": "option", "home_manager": "home-manager-option"}
EXACT_RANK = 0
TITLE_RANK = 1
TERMS_RANK = 2
DESCRIPTION_RANK = 3


class SpecialistError(ValueError):
    """The query or catalog does not satisfy the admitted contract."""


def validate_query(query: object) -> str:
    if (
        not isinstance(query, str)
        or not query.strip()
        or len(query) > MAX_QUERY_CHARACTERS
    ):
        msg = "Search query is empty or too long"
        raise SpecialistError(msg)
    return query.strip()


def option_query(query: str, source: str) -> dict:
    query = validate_query(query)
    if not isinstance(source, str) or source not in SOURCE_TYPES:
        msg = "Unknown option source"
        raise SpecialistError(msg)
    return {
        "size": MAX_RESULTS,
        "query": {
            "bool": {
                "filter": [{"term": {"type": SOURCE_TYPES[source]}}],
                "must": [
                    {
                        "multi_match": {
                            "query": query,
                            "fields": [
                                f"option_name^{OPTION_NAME_BOOST}",
                                "option_description",
                            ],
                            "operator": "and",
                        }
                    }
                ],
            }
        },
    }


def text_content(value: object) -> str:
    if value is None:
        return ""
    if not isinstance(value, str):
        msg = "Description must be text"
        raise SpecialistError(msg)
    try:
        text = html.fromstring("<div>" + value + "</div>").text_content()
    except (ValueError, TypeError):
        msg = "Description is malformed"
        raise SpecialistError(msg) from None
    return " ".join(text.split())[:MAX_CONTENT_CHARACTERS]


def decode_json(body: bytes, maximum: int) -> object:
    if not isinstance(body, bytes) or len(body) > maximum:
        msg = "Catalog response exceeds its size limit"
        raise SpecialistError(msg)
    try:
        return json.loads(body)
    except (ValueError, UnicodeError):
        msg = "Catalog response is not valid JSON"
        raise SpecialistError(msg) from None


def option_results(body: bytes, source: str) -> list[dict[str, str]]:
    if not isinstance(source, str) or source not in SOURCE_TYPES:
        msg = "Unknown option source"
        raise SpecialistError(msg)
    data = decode_json(body, MAX_RESPONSE_BYTES)
    if not isinstance(data, dict) or "error" in data or data.get("timed_out"):
        msg = "Option backend returned an error"
        raise SpecialistError(msg)
    shards = data.get("_shards", {})
    if not isinstance(shards, dict) or shards.get("failed", 0) != 0:
        msg = "Option backend returned incomplete results"
        raise SpecialistError(msg)
    hits = data.get("hits", {})
    hits = hits.get("hits") if isinstance(hits, dict) else None
    if not isinstance(hits, list) or len(hits) > MAX_RESULTS:
        msg = "Option result list is malformed"
        raise SpecialistError(msg)
    results = []
    for hit in hits:
        record = hit.get("_source") if isinstance(hit, dict) else None
        if not isinstance(record, dict) or record.get("type") != SOURCE_TYPES[source]:
            msg = "Option result has the wrong source"
            raise SpecialistError(msg)
        name = record.get("option_name")
        if (
            not isinstance(name, str)
            or not name.strip()
            or len(name) > MAX_TITLE_CHARACTERS
        ):
            msg = "Option result has no valid name"
            raise SpecialistError(msg)
        params = urlencode(
            {"channel": CHANNEL, "source": source, "query": name, "show": name}
        )
        results.append(
            {
                "title": name,
                "url": "https://search.nixos.org/options?" + params,
                "content": text_content(record.get("option_description")),
            }
        )
    return results


@dataclass(frozen=True)
class CatalogEntry:
    title: str
    url: str
    content: str


def path_title(path: object) -> str:
    if (
        not isinstance(path, list)
        or not path
        or not all(
            isinstance(part, str)
            and part
            and part not in (".", "..")
            and "/" not in part
            and "\\" not in part
            for part in path
        )
    ):
        msg = "Noogle path is malformed"
        raise SpecialistError(msg)
    title = ".".join(path)
    if len(title) > MAX_TITLE_CHARACTERS:
        msg = "Noogle path is too long"
        raise SpecialistError(msg)
    return title


def noogle_catalog(body: bytes) -> tuple[CatalogEntry, ...]:
    data = decode_json(body, MAX_CATALOG_BYTES)
    records = data.get("data") if isinstance(data, dict) else None
    if (
        not isinstance(records, list)
        or not records
        or len(records) > MAX_CATALOG_ENTRIES
    ):
        msg = "Noogle catalog is malformed"
        raise SpecialistError(msg)
    entries = {}
    for record in records:
        meta = record.get("meta") if isinstance(record, dict) else None
        if not isinstance(meta, dict):
            msg = "Noogle metadata is missing"
            raise SpecialistError(msg)
        path = meta.get("path")
        path_title(path)
        url = "https://noogle.dev/f/" + "/".join(quote(part, safe="") for part in path)
        content = record.get("content")
        if content is not None and not isinstance(content, dict):
            msg = "Noogle documentation is malformed"
            raise SpecialistError(msg)
        description = text_content(content.get("content") if content else None)
        aliases = meta.get("aliases")
        if aliases is None:
            aliases = []
        if not isinstance(aliases, list):
            msg = "Noogle aliases are malformed"
            raise SpecialistError(msg)
        for candidate in [path, *aliases]:
            title = path_title(candidate)
            entries.setdefault(title, CatalogEntry(title, url, description))
            if len(entries) > MAX_CATALOG_ENTRIES:
                msg = "Noogle catalog has too many entries"
                raise SpecialistError(msg)
    return tuple(entries.values())


def search_catalog(
    entries: tuple[CatalogEntry, ...], query: str
) -> list[dict[str, str]]:
    query = validate_query(query).casefold()
    terms = re.findall(r"[\w'-]+", query)
    if not terms:
        return []
    matches = []
    for entry in entries:
        title = entry.title.casefold()
        combined = title + " " + entry.content.casefold()
        if not all(term in combined for term in terms):
            continue
        rank = DESCRIPTION_RANK
        if title == query:
            rank = EXACT_RANK
        elif query in title:
            rank = TITLE_RANK
        elif all(term in title for term in terms):
            rank = TERMS_RANK
        matches.append((rank, entry))
    ordered = sorted(
        matches, key=lambda match: (match[0], len(match[1].title), match[1].title)
    )
    return [
        {"title": entry.title, "url": entry.url, "content": entry.content}
        for _, entry in ordered[:MAX_RESULTS]
    ]
