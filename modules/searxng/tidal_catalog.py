"""Tidal catalog adapter using an access-only snapshot of Drift authorization."""

from http import HTTPStatus
from typing import Any

from searx.exceptions import SearxEngineResponseException
from searx.tidal_core import TidalError, access_token, search_results, search_url

categories = ["music"]
paging = False
session_token = ""
country_code = "US"
FIRST_PAGE = 1
about = {
    "website": "https://tidal.com/",
    "use_official_api": True,
    "require_api_key": True,
    "results": "JSON",
}


def init(settings: dict[str, Any]) -> None:
    access_token(session_token)
    tokens = settings.get("tokens")
    if not isinstance(tokens, list) or not tokens or session_token in tokens:
        msg = "Private Tidal search requires separate browser access tokens"
        raise TidalError(msg)
    for token in tokens:
        access_token(token)
    search_url("configuration check", country_code)


def request(query: str, params: dict[str, Any]) -> dict[str, Any] | None:
    if params.get("pageno", FIRST_PAGE) != FIRST_PAGE:
        return None
    try:
        url = search_url(query, country_code)
        token = access_token(session_token)
    except TidalError as error:
        raise SearxEngineResponseException(str(error)) from None
    params.update(
        {
            "url": url,
            "method": "GET",
            "headers": {
                "Authorization": "Bearer " + token,
                "Accept": "application/json",
            },
            "cookies": {},
            "auth": None,
            "allow_redirects": False,
            "raise_for_httperror": False,
            "verify": True,
        }
    )
    return params


def response(resp: Any) -> list[dict[str, str]]:
    if resp.status_code in (HTTPStatus.UNAUTHORIZED, HTTPStatus.FORBIDDEN):
        msg = "Tidal authorization expired or was rejected; import current Drift authorization"
        raise SearxEngineResponseException(msg)
    if resp.status_code != HTTPStatus.OK:
        msg = "Tidal catalog returned an HTTP error"
        raise SearxEngineResponseException(msg)
    try:
        return search_results(resp.content)
    except TidalError as error:
        raise SearxEngineResponseException(str(error)) from None
