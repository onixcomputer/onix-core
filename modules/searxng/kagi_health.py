"""Daily, bounded session canary. Output contains only a fixed health category."""

import argparse
import os
from collections.abc import Callable
from dataclasses import dataclass
from urllib.error import HTTPError
from urllib.request import HTTPRedirectHandler, Request, build_opener

from searx.engines.kagi_session import BROWSER_USER_AGENT
from searx.kagi_session_core import (
    MAX_HTML_BYTES,
    KagiPageError,
    KagiRateLimitError,
    KagiSessionError,
    KagiUpstreamError,
    parse_results,
    search_url,
    validate_token,
)

CANARY_QUERY = "SearXNG"
MAX_TIMEOUT_SECONDS = 30
DEFAULT_TIMEOUT_SECONDS = 10
HEALTHY = "healthy"


@dataclass(frozen=True)
class Reply:
    body: bytes
    status: int
    url: str
    content_type: str


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(
        self,
        _req: Request,
        _fp: object,
        _code: int,
        _msg: str,
        _headers: object,
        _newurl: str,
    ) -> None:
        return None


def fetch_session(token: str, timeout: float) -> Reply:
    request = Request(
        search_url(CANARY_QUERY),
        headers={
            "Cookie": "kagi_session=" + token,
            "Accept": "text/html",
            "Accept-Encoding": "identity",
            "User-Agent": BROWSER_USER_AGENT,
        },
    )
    opener = build_opener(NoRedirect())
    try:
        response = opener.open(request, timeout=timeout)
    except HTTPError as error:
        response = error
    with response:
        return Reply(
            response.read(MAX_HTML_BYTES + 1),
            response.status,
            response.geturl(),
            response.headers.get("Content-Type", ""),
        )


def probe(
    token: str,
    timeout: float,
    fetch: Callable[[str, float], Reply] = fetch_session,
) -> str:
    if (
        isinstance(timeout, bool)
        or not isinstance(timeout, (int, float))
        or not 0 < timeout <= MAX_TIMEOUT_SECONDS
    ):
        return "invalid_timeout"
    try:
        validate_token(token)
    except KagiSessionError:
        return "invalid_session_configuration"
    try:
        reply = fetch(token, timeout)
        parse_results(reply.body, reply.status, reply.url, reply.content_type)
    except KagiSessionError:
        return "session_rejected"
    except KagiRateLimitError:
        return "rate_limited"
    except KagiUpstreamError:
        return "upstream_error"
    except KagiPageError:
        return "unrecognized_response"
    except Exception:  # Never log transport exceptions that can contain request data.
        return "transport_or_probe_error"
    return HEALTHY


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--timeout-seconds", type=float, default=DEFAULT_TIMEOUT_SECONDS
    )
    args = parser.parse_args()
    status = probe(os.environ.get("KAGI_SESSION_TOKEN", ""), args.timeout_seconds)
    print("kagi_session_health=" + status)
    return 0 if status == HEALTHY else 1


if __name__ == "__main__":
    raise SystemExit(main())
