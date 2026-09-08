"""Public NixOS Search adapter for NixOS and Home Manager options."""

import json
from http import HTTPStatus
from typing import Any

from searx.exceptions import SearxEngineResponseException
from searx.specialist_core import (
    BACKEND_URL,
    SpecialistError,
    option_query,
    option_results,
)

categories = ["it", "software wikis"]
paging = False
option_source = "nixos"
about = {
    "website": "https://search.nixos.org/options",
    "use_official_api": True,
    "require_api_key": False,
    "results": "JSON",
}
# This read-only pair is published in the NixOS Search web client's index.js.
# It is not a user credential or a Kagi account credential.
PUBLIC_FRONTEND_AUTH = ("aWVSALXpZv", "X8gPHnzL52wFEekuxsfQ9cSh")
FIRST_PAGE = 1


def request(query: str, params: dict[str, Any]) -> dict[str, Any] | None:
    if params.get("pageno", FIRST_PAGE) != FIRST_PAGE:
        return None
    params.update(
        {
            "url": BACKEND_URL,
            "method": "POST",
            "data": json.dumps(option_query(query, option_source)),
            "headers": {
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
            "auth": PUBLIC_FRONTEND_AUTH,
            "allow_redirects": False,
            "verify": True,
        }
    )
    return params


def response(resp: Any) -> list[dict[str, str]]:
    if resp.status_code != HTTPStatus.OK:
        msg = "Option backend returned an HTTP error"
        raise SearxEngineResponseException(msg)
    try:
        return option_results(resp.content, option_source)
    except SpecialistError as error:
        raise SearxEngineResponseException(str(error)) from error
