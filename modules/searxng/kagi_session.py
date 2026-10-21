"""SearXNG adapter for personal Kagi HTML searches, not the paid API.

SearXNG owns HTTP execution, TLS verification, timeouts, and engine access
checks. This adapter constructs a request and translates pure parser errors.
"""

from typing import Any

from searx.exceptions import (
    SearxEngineAccessDeniedException,
    SearxEngineResponseException,
    SearxEngineTooManyRequestsException,
)
from searx.kagi_session_core import (
    KagiPageError,
    KagiRateLimitError,
    KagiSessionError,
    parse_results,
    search_url,
    validate_token,
)

about = {
    "website": "https://kagi.com",
    "use_official_api": False,
    "require_api_key": False,
    "results": "HTML",
}
categories = ["general", "web"]
paging = False
safesearch = False
time_range_support = False
session_token = ""
FIRST_PAGE = 1
BROWSER_USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
)


def init(engine_settings: dict[str, Any]) -> None:
    validate_token(session_token)
    # No public engine can spend the account's subscription allowance.
    access_tokens = engine_settings.get("tokens", [])
    if not access_tokens or not all(
        isinstance(token, str) and token and "$" not in token for token in access_tokens
    ):
        msg = "Kagi requires a private engine access token"
        raise KagiSessionError(msg)


def request(query: str, params: dict[str, Any]) -> dict[str, Any] | None:
    validate_token(session_token)
    if params.get("pageno", FIRST_PAGE) != FIRST_PAGE:
        return None
    params["url"] = search_url(query)
    params["method"] = "GET"
    params["headers"] = {
        "User-Agent": BROWSER_USER_AGENT,
        "Accept": "text/html",
    }
    params["cookies"] = {"kagi_session": session_token}
    params["allow_redirects"] = False
    params["max_redirects"] = 0
    params["raise_for_httperror"] = False
    params["verify"] = True
    return params


def response(resp: Any) -> list[dict[str, str]]:
    try:
        return parse_results(
            resp.content,
            resp.status_code,
            str(resp.url),
            resp.headers.get("content-type", ""),
        )
    except KagiSessionError as error:
        raise SearxEngineAccessDeniedException(
            message="Kagi session search was rejected"
        ) from error
    except KagiRateLimitError as error:
        raise SearxEngineTooManyRequestsException(
            message="Kagi rate limit reached"
        ) from error
    except KagiPageError as error:
        raise SearxEngineResponseException(str(error)) from error
