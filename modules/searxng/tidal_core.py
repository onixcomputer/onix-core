"""Pure, bounded Tidal catalog search rules. No account-library operations."""

import json
import re
from itertools import zip_longest
from urllib.parse import urlencode

SEARCH_URL = "https://api.tidal.com/v1/search"
RESULT_ORIGIN = "https://tidal.com/browse"
MAX_QUERY_CHARACTERS = 2048
MAX_RESPONSE_BYTES = 2 * 1024 * 1024
MAX_RESULTS = 20
MAX_TEXT_CHARACTERS = 1024
MAX_ID_DIGITS = 20
MAX_TOKEN_CHARACTERS = 16384
RESULT_TYPES = (("tracks", "track"), ("albums", "album"), ("artists", "artist"))


class TidalError(ValueError):
    """A secret-free validation error."""


def access_token(value: object) -> str:
    if (
        not isinstance(value, str)
        or not value
        or len(value) > MAX_TOKEN_CHARACTERS
        or re.fullmatch(r"[A-Za-z0-9._~+/=-]+", value) is None
    ):
        msg = "Tidal access token is missing or invalid"
        raise TidalError(msg)
    return value


def search_url(query: object, country: object) -> str:
    if (
        not isinstance(query, str)
        or not query.strip()
        or len(query) > MAX_QUERY_CHARACTERS
    ):
        msg = "Tidal search query is empty or too long"
        raise TidalError(msg)
    if not isinstance(country, str) or re.fullmatch(r"[A-Z]{2}", country) is None:
        msg = "Tidal country must be an uppercase two-letter code"
        raise TidalError(msg)
    return (
        SEARCH_URL
        + "?"
        + urlencode(
            {
                "query": query.strip(),
                "countryCode": country,
                "limit": MAX_RESULTS,
                "types": ",".join(plural.upper() for plural, _singular in RESULT_TYPES),
            }
        )
    )


def text(value: object) -> str:
    if not isinstance(value, str) or not value.strip():
        msg = "Tidal result text is missing or invalid"
        raise TidalError(msg)
    return value.strip()[:MAX_TEXT_CHARACTERS]


def result(item: object, kind: str) -> dict[str, str]:
    if not isinstance(item, dict):
        msg = "Tidal result is not an object"
        raise TidalError(msg)
    identifier = item.get("id")
    if (
        type(identifier) is not int
        or identifier <= 0
        or len(str(identifier)) > MAX_ID_DIGITS
    ):
        msg = "Tidal result identifier is invalid"
        raise TidalError(msg)
    title = text(item.get("name") if kind == "artist" else item.get("title"))
    description = kind.capitalize()
    if kind != "artist":
        artist = item.get("artist")
        artists = item.get("artists")
        if artist is not None:
            artists = [artist]
        if artists is not None:
            if not isinstance(artists, list) or not all(
                isinstance(entry, dict) for entry in artists
            ):
                msg = "Tidal result artists are malformed"
                raise TidalError(msg)
            names = [text(entry.get("name")) for entry in artists]
            if names:
                description += " — " + ", ".join(names)[:MAX_TEXT_CHARACTERS]
    return {
        "url": f"{RESULT_ORIGIN}/{kind}/{identifier}",
        "title": title,
        "content": description,
    }


def search_results(body: bytes) -> list[dict[str, str]]:
    if not isinstance(body, bytes) or len(body) > MAX_RESPONSE_BYTES:
        msg = "Tidal response exceeds its size limit"
        raise TidalError(msg)
    try:
        data = json.loads(body)
    except (ValueError, RecursionError):
        msg = "Tidal response is not valid JSON"
        raise TidalError(msg) from None
    if not isinstance(data, dict) or "status" in data or "error" in data:
        msg = "Tidal returned an error response"
        raise TidalError(msg)
    groups = []
    for plural, singular in RESULT_TYPES:
        group = data.get(plural)
        items = group.get("items") if isinstance(group, dict) else None
        if not isinstance(items, list) or len(items) > MAX_RESULTS:
            msg = "Tidal result group is missing or oversized"
            raise TidalError(msg)
        groups.append([result(item, singular) for item in items])
    # Interleave types so tracks do not hide all album and artist results.
    distinct = {}
    for row in zip_longest(*groups):
        for item in row:
            if item is not None:
                distinct.setdefault(item["url"], item)
    return list(distinct.values())[:MAX_RESULTS]
