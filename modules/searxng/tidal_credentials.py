"""Read Drift's canonical credentials without copying or refreshing its refresh token.

The export command emits a secret. Pipe it directly to Clan, never to a terminal.
"""

import argparse
import json
import os
import stat
import sys
from datetime import UTC, datetime
from http import HTTPStatus
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, Request, build_opener

from searx.tidal_core import (
    MAX_RESPONSE_BYTES,
    TidalError,
    access_token,
    search_results,
    search_url,
)

MAX_CREDENTIAL_BYTES = 64 * 1024
NON_OWNER_PERMISSION_BITS = 0o077
PROBE_TIMEOUT_SECONDS = 10
PROBE_QUERY = "Radiohead"


def credential_token(body: bytes, now: datetime) -> str:
    if len(body) > MAX_CREDENTIAL_BYTES:
        msg = "Drift credential file exceeds its size limit"
        raise TidalError(msg)
    try:
        data = json.loads(body)
        if not isinstance(data, dict):
            raise TypeError
        expiry = data.get("expires_at")
        if expiry is not None:
            expiry = datetime.fromisoformat(expiry)
            if expiry.tzinfo is None or expiry <= now:
                raise ValueError
        return access_token(data.get("access_token"))
    except (ValueError, TypeError, RecursionError):
        msg = "Drift authorization is malformed or expired"
        raise TidalError(msg) from None


def read_token(path: str, now: datetime) -> str:
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(descriptor, "rb") as source:
        metadata = os.fstat(source.fileno())
        if (
            not stat.S_ISREG(metadata.st_mode)
            or metadata.st_mode & NON_OWNER_PERMISSION_BITS
            or metadata.st_uid != os.getuid()
        ):
            msg = "Drift credentials must be a private regular file owned by the caller"
            raise TidalError(msg)
        return credential_token(source.read(MAX_CREDENTIAL_BYTES + 1), now)


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(
        self,
        _request: Request,
        _file: object,
        _code: int,
        _message: str,
        _headers: object,
        _newurl: str,
    ) -> None:
        return None


def probe(token: str) -> dict:
    request = Request(  # noqa: S310 -- Fixed HTTPS origin, verified TLS, no redirects.
        search_url(PROBE_QUERY, "US"),
        headers={
            "Authorization": "Bearer " + access_token(token),
            "Accept": "application/json",
        },
    )
    with build_opener(NoRedirect()).open(
        request, timeout=PROBE_TIMEOUT_SECONDS
    ) as reply:
        if reply.status != HTTPStatus.OK:
            msg = "Tidal probe failed"
            raise TidalError(msg)
        results = search_results(reply.read(MAX_RESPONSE_BYTES + 1))
    return {"status": "ok", "results": len(results)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("check", "probe", "export"))
    parser.add_argument(
        "path", help="Explicit path to Drift's canonical credentials.json"
    )
    args = parser.parse_args()
    try:
        token = read_token(args.path, datetime.now(UTC))
        if args.action == "export":
            if sys.stdout.isatty():
                msg = "Refusing to print a credential to a terminal"
                raise TidalError(msg)
            sys.stdout.write(token)
        elif args.action == "probe":
            print(json.dumps(probe(token)))
        else:
            print('{"status":"valid_access_snapshot"}')
    except HTTPError as error:
        print(
            json.dumps({"status": "http_error", "http_status": error.code}),
            file=sys.stderr,
        )
        return 1
    except TidalError as error:
        print(
            json.dumps({"status": "validation_error", "reason": str(error)}),
            file=sys.stderr,
        )
        return 1
    except (OSError, URLError):
        print('{"status":"credential_or_probe_error"}', file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
