"""Offline positive and negative checks for private Tidal search."""

import io
import json
import os
import stat
import tempfile
import unittest
from datetime import UTC, datetime, timedelta
from functools import partial
from http import HTTPStatus
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
from urllib.parse import parse_qs, urlsplit

import pytest
from searx import engines, tidal_credentials, webadapter
from searx.exceptions import SearxEngineResponseException
from searx.preferences import Preferences
from searx.search.models import EngineRef
from searx.tidal_core import (
    MAX_QUERY_CHARACTERS,
    MAX_RESPONSE_BYTES,
    MAX_RESULTS,
    RESULT_TYPES,
    TidalError,
    access_token,
    search_results,
    search_url,
)
from searx.tidal_credentials import (
    MAX_CREDENTIAL_BYTES,
    NoRedirect,
    credential_token,
    read_token,
)

FIXTURE_TOKEN = "fixture.access-only"
PRIVATE_MODE = 0o600
PUBLIC_MODE = 0o644
FIXTURE_YEAR = 2026
FUTURE_DAYS = 1
NOW = datetime(FIXTURE_YEAR, 1, 1, tzinfo=UTC)


def encode(value):
    return json.dumps(value).encode()


def reply(count=1):
    return {
        plural: {
            "items": [
                {
                    "id": index + 1,
                    "title": "Example",
                    "name": "Artist",
                    "artist": {"name": "Artist"},
                }
                for index in range(count)
            ]
        }
        for plural, _singular in RESULT_TYPES
    }


def credentials(**overrides):
    return encode(
        {"access_token": FIXTURE_TOKEN, "refresh_token": "must-not-export", **overrides}
    )


class TidalTests(unittest.TestCase):
    def test_query_is_encoded_and_cannot_change_origin_or_country(self):
        query = "Radiohead&countryCode=XX#fragment"
        url = urlsplit(search_url(query, "US"))
        assert url.netloc == "api.tidal.com"
        assert url.path == "/v1/search"
        assert not url.fragment
        assert parse_qs(url.query)["query"] == [query]
        assert parse_qs(url.query)["countryCode"] == ["US"]
        for invalid in (None, "", " ", "x" * (MAX_QUERY_CHARACTERS + 1)):
            with pytest.raises(TidalError):
                search_url(invalid, "US")
        for country in (None, [], "us", "USA", "US\n"):
            with pytest.raises(TidalError):
                search_url("music", country)

    def test_results_include_all_types_and_are_bounded(self):
        results = search_results(encode(reply(MAX_RESULTS)))
        assert len(results) == MAX_RESULTS
        assert [item["url"] for item in results[: len(RESULT_TYPES)]] == [
            "https://tidal.com/browse/track/1",
            "https://tidal.com/browse/album/1",
            "https://tidal.com/browse/artist/1",
        ]
        assert search_results(encode(reply(0))) == []
        alternative = reply()
        album = alternative["albums"]["items"][0]
        album.pop("artist")
        album["artists"] = [{"name": "Alternate Artist"}]
        assert any(
            "Alternate Artist" in item["content"]
            for item in search_results(encode(alternative))
        )
        album.pop("artists")
        assert any(
            item["content"] == "Album" for item in search_results(encode(alternative))
        )
        data = reply()
        data["tracks"]["items"] *= MAX_RESULTS
        assert len(search_results(encode(data))) == len(RESULT_TYPES)

    def test_invalid_results_fail_without_partial_output(self):
        for body in (
            b"bad",
            b"x" * (MAX_RESPONSE_BYTES + 1),
            encode([]),
            encode({}),
            encode({"status": HTTPStatus.UNAUTHORIZED}),
        ):
            with pytest.raises(TidalError):
                search_results(body)
        for identifier in (None, True, 0, -1, "../bad", "https://evil.invalid/"):
            data = reply()
            data["tracks"]["items"][0]["id"] = identifier
            with pytest.raises(TidalError):
                search_results(encode(data))
        for mutation in (
            lambda item: item.pop("title"),
            lambda item: item.update(artist="malformed"),
        ):
            data = reply()
            mutation(data["tracks"]["items"][0])
            with pytest.raises(TidalError):
                search_results(encode(data))
        with pytest.raises(TidalError):
            search_results(encode(reply(MAX_RESULTS + 1)))

    def test_credentials_are_access_only_and_fail_closed(self):
        assert credential_token(credentials(), NOW) == FIXTURE_TOKEN
        future = (NOW + timedelta(days=FUTURE_DAYS)).isoformat()
        assert credential_token(credentials(expires_at=future), NOW) == FIXTURE_TOKEN
        for body in (
            b"bad",
            encode([]),
            credentials(expires_at=NOW.isoformat()),
            credentials(expires_at="invalid"),
            credentials(access_token="bad\r\nHeader: x"),
        ):
            with pytest.raises(TidalError) as caught:
                credential_token(body, NOW)
            assert "must-not-export" not in str(caught.value)
        for token in (None, "", "$TIDAL_SESSION_TOKEN", "a\nb", "Welcome to SOPS!"):
            with pytest.raises(TidalError):
                access_token(token)

    def test_private_file_read_rejects_missing_public_and_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "credentials.json"
            with pytest.raises(FileNotFoundError):
                read_token(str(path), NOW)
            path.write_bytes(credentials())
            path.chmod(PRIVATE_MODE)
            assert read_token(str(path), NOW) == FIXTURE_TOKEN
            link = Path(directory) / "link"
            link.symlink_to(path)
            with pytest.raises(OSError, match="Too many levels of symbolic links"):
                read_token(str(link), NOW)
            path.chmod(PUBLIC_MODE)
            with pytest.raises(TidalError):
                read_token(str(path), NOW)

    def test_credential_reader_edges_and_cli_output(self):
        for body in (
            b"x" * (MAX_CREDENTIAL_BYTES + 1),
            credentials(expires_at="2099-01-01T00:00:00"),
        ):
            with pytest.raises(TidalError):
                credential_token(body, NOW)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "credentials.json"
            path.write_bytes(credentials())
            path.chmod(PRIVATE_MODE)
            wrong_owner = SimpleNamespace(
                st_mode=stat.S_IFREG | PRIVATE_MODE, st_uid=os.getuid() + 1
            )
            with (
                patch.object(tidal_credentials.os, "fstat", return_value=wrong_owner),
                pytest.raises(TidalError),
            ):
                read_token(str(path), NOW)
            fifo = Path(directory) / "fifo"
            os.mkfifo(fifo, PRIVATE_MODE)
            with pytest.raises(TidalError):
                read_token(str(fifo), NOW)
        for terminal in (False, True):
            output, errors = io.StringIO(), io.StringIO()
            with (
                patch.object(
                    tidal_credentials, "read_token", return_value=FIXTURE_TOKEN
                ),
                patch("sys.argv", ["credential-tool", "export", "fixture-path"]),
                patch("sys.stdout", output),
                patch("sys.stderr", errors),
                patch.object(output, "isatty", return_value=terminal),
            ):
                status = tidal_credentials.main()
            assert status == int(terminal)
            assert output.getvalue() == ("" if terminal else FIXTURE_TOKEN)
            assert FIXTURE_TOKEN not in errors.getvalue()
        with (
            patch.object(tidal_credentials, "read_token", side_effect=OSError),
            patch("sys.argv", ["credential-tool", "check", "fixture-path"]),
            patch("sys.stderr", io.StringIO()) as errors,
        ):
            assert tidal_credentials.main() == 1
            assert FIXTURE_TOKEN not in errors.getvalue()

    def test_probe_bounds_and_auth_header(self):
        response = MagicMock()
        response.status = HTTPStatus.OK
        response.read.return_value = encode(reply())
        opener = MagicMock()
        opener.open.return_value.__enter__.return_value = response
        with patch.object(tidal_credentials, "build_opener", return_value=opener):
            assert tidal_credentials.probe(FIXTURE_TOKEN)["results"] == len(
                RESULT_TYPES
            )
        request = opener.open.call_args.args[0]
        assert request.get_header("Authorization") == "Bearer " + FIXTURE_TOKEN
        assert FIXTURE_TOKEN not in request.full_url
        response.read.assert_called_once_with(MAX_RESPONSE_BYTES + 1)
        response.read.return_value = b"x" * (MAX_RESPONSE_BYTES + 1)
        with (
            patch.object(tidal_credentials, "build_opener", return_value=opener),
            pytest.raises(TidalError),
        ):
            tidal_credentials.probe(FIXTURE_TOKEN)

    def test_native_query_gate_for_shared_and_dedicated_browser_keys(self):
        reference = EngineRef(name="tidal", category="music")
        for key in ("fixture-dedicated-key", "fixture-shared-kagi-key"):
            settings = {
                "name": "tidal",
                "engine": "tidal_catalog",
                "shortcut": "tidal",
                "session_token": FIXTURE_TOKEN,
                "tokens": [key],
            }
            engine = engines.load_engine(settings)
            engine.init(settings)
            for tokens in (None, [], [FIXTURE_TOKEN], ["bad\nkey"]):
                with pytest.raises(TidalError):
                    engine.init({"tokens": tokens})
            for candidate in ([], ["wrong"], [FIXTURE_TOKEN], [key]):
                preferences = SimpleNamespace(tokens=SimpleNamespace(values=candidate))
                preferences.validate_token = partial(
                    Preferences.validate_token, preferences
                )
                with patch.dict(webadapter.engines, {"tidal": engine}):
                    valid, unknown, denied = webadapter.validate_engineref_list(
                        [reference], preferences
                    )
                assert unknown == []
                assert bool(valid) == (candidate == [key])
                assert bool(denied) == (candidate != [key])

    def test_packaged_adapter_and_native_youtube(self):
        engine = engines.load_engine(
            {
                "name": "tidal-fixture",
                "engine": "tidal_catalog",
                "shortcut": "tdfixture",
                "session_token": FIXTURE_TOKEN,
            }
        )
        assert engine is not None
        engine.init({"tokens": ["fixture-browser-key"]})
        request = engine.request(
            "Radiohead", {"pageno": 1, "cookies": {"unrelated": "discard"}}
        )
        assert request["headers"]["Authorization"] == "Bearer " + FIXTURE_TOKEN
        assert FIXTURE_TOKEN not in request["url"]
        assert request["allow_redirects"] is False
        assert request["raise_for_httperror"] is False
        assert request["verify"] is True
        assert request["cookies"] == {}
        assert len(
            engine.response(
                SimpleNamespace(status_code=HTTPStatus.OK, content=encode(reply()))
            )
        ) == len(RESULT_TYPES)
        later_page = 2
        assert engine.request("Radiohead", {"pageno": later_page}) is None
        for status in (
            HTTPStatus.UNAUTHORIZED,
            HTTPStatus.FORBIDDEN,
            HTTPStatus.TOO_MANY_REQUESTS,
            HTTPStatus.FOUND,
        ):
            with pytest.raises(SearxEngineResponseException) as caught:
                engine.response(
                    SimpleNamespace(status_code=status, content=FIXTURE_TOKEN.encode())
                )
            assert FIXTURE_TOKEN not in str(caught.value)
        with patch.object(engine, "session_token", ""), pytest.raises(TidalError):
            engine.init({})
        youtube = engines.load_engine(
            {
                "name": "youtube-fixture",
                "engine": "youtube_noapi",
                "shortcut": "ytfixture",
            }
        )
        assert youtube is not None
        assert youtube.about.require_api_key is False
        assert "music" in youtube.categories
        assert "videos" in youtube.categories
        assert (
            NoRedirect().redirect_request(
                None, None, None, None, None, "https://evil.invalid"
            )
            is None
        )


if __name__ == "__main__":
    unittest.main()
