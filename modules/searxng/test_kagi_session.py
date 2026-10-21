"""Synthetic offline fixtures. These do not prove live Kagi compatibility."""

import unittest
from http import HTTPStatus
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from urllib.parse import parse_qs, urlsplit

import httpx
import pytest
import searx
from flask import Flask
from jinja2 import Environment, FileSystemLoader
from lxml import html
from searx.engines import kagi_session as engine
from searx.engines import load_engine
from searx.exceptions import (
    SearxEngineAccessDeniedException,
    SearxEngineResponseException,
    SearxEngineTooManyRequestsException,
)
from searx.extended_types import sxng_request
from searx.kagi_session_core import (
    HTTP_OK,
    MAX_HTML_BYTES,
    MAX_QUERY_CHARACTERS,
    MAX_RESULTS,
    SEARCH_ENDPOINT,
    KagiPageError,
    KagiSessionError,
    admit_access_token,
    parse_results,
    search_url,
    validate_token,
)
from searx.kagi_unlock import install_kagi_unlock
from searx.preferences import Preferences, SetSetting
from searx.search.processors.online import OnlineProcessor, default_request_params

FIXTURE_SESSION = "fixture-session-not-a-real-credential"
FIXTURE_ACCESS = "fixture-access-not-a-real-credential"
HTTP_REDIRECT = 302
HTTP_UNAUTHORIZED = 401
HTTP_FORBIDDEN = 403
HTTP_RATE_LIMITED = 429
HTTP_SERVER_ERROR = 500
REQUEST_TIMEOUT_SECONDS = 10


TEST_ORIGIN = "https://search.example"


class UnlockTests(unittest.TestCase):
    def setUp(self):
        self.engine = SimpleNamespace(tokens=[FIXTURE_ACCESS])
        self.engines = {"kagi-private": self.engine}
        self.app = Flask(__name__)
        self.app.secret_key = "fixture-form-signing-secret"
        self.locked = False
        install_kagi_unlock(self.app, self.engines)

        @self.app.before_request
        def load_preferences():
            tokens = SetSetting("tokens")
            tokens.parse(sxng_request.cookies.get("tokens", ""))
            tokens.locked = self.locked
            sxng_request.preferences = SimpleNamespace(tokens=tokens)

        @self.app.get("/preferences", endpoint="preferences")
        def preferences_page():
            context = {}
            self.app.update_template_context(context)
            return {
                "nonce": context["kagi_form_nonce"],
                "tokens": sorted(sxng_request.preferences.tokens.values),
                "language": sxng_request.cookies.get("language"),
            }

        self.client = self.app.test_client()

    def post_token(self, candidate, origin=TEST_ORIGIN, fetch_site=None, accept=None):
        headers = {} if origin is None else {"Origin": origin}
        if accept is not None:
            headers["Accept"] = accept
        if fetch_site is not None:
            headers["Sec-Fetch-Site"] = fetch_site
        nonce = self.client.get("/preferences", base_url=TEST_ORIGIN).get_json()[
            "nonce"
        ]
        return self.client.post(
            "/kagi-access",
            base_url=TEST_ORIGIN,
            data={"kagi_engine_token": candidate, "kagi_form_nonce": nonce},
            headers=headers,
        )

    def test_issued_token_preserves_other_tokens_and_preferences(self):
        self.client.set_cookie("tokens", "other-engine-access", domain="search.example")
        self.client.set_cookie("language", "de", domain="search.example")
        response = self.post_token("  " + FIXTURE_ACCESS + "\n")
        assert response.status_code == HTTPStatus.SEE_OTHER
        assert "kagi_unlock=saved" in response.location
        assert response.headers["Cache-Control"] == "no-store"
        saved = self.client.get("/preferences", base_url=TEST_ORIGIN).get_json()
        assert set(saved["tokens"]) == {"other-engine-access", FIXTURE_ACCESS}
        assert saved["language"] == "de"
        assert len(response.headers.getlist("Set-Cookie")) == 1

    def test_bad_tokens_leave_existing_access_unchanged(self):
        self.client.set_cookie("tokens", "other-engine-access", domain="search.example")
        for candidate in (
            "",
            "wrong-token",
            FIXTURE_SESSION,
            "https://kagi.com/search?token=fixture",
        ):
            response = self.post_token(candidate)
            assert "kagi_unlock=rejected" in response.location
            assert not response.headers.getlist("Set-Cookie")
            assert (
                self.client.get_cookie("tokens", domain="search.example").value
                == "other-engine-access"
            )

    def test_cross_origin_get_and_locked_setting_reject(self):
        for origin in ("https://other.example", "https://search.example.other.example"):
            response = self.post_token(FIXTURE_ACCESS, origin)
            assert response.status_code == HTTPStatus.FORBIDDEN
            assert not response.headers.getlist("Set-Cookie")
        assert (
            self.client.get("/kagi-access", base_url=TEST_ORIGIN).status_code
            == HTTPStatus.METHOD_NOT_ALLOWED
        )
        self.locked = True
        response = self.post_token(FIXTURE_ACCESS)
        assert "kagi_unlock=rejected" in response.location
        assert not response.headers.getlist("Set-Cookie")

    def test_explicit_cross_origin_metadata_rejects_even_with_nonce(self):
        for origin, site in (
            ("null", "cross-site"),
            ("null", "same-site"),
            ("null", "none"),
            ("https://other.example", "same-origin"),
            (TEST_ORIGIN, "cross-site"),
        ):
            response = self.post_token(FIXTURE_ACCESS, origin, site)
            assert response.status_code == HTTPStatus.FORBIDDEN
            assert not response.headers.getlist("Set-Cookie")
        response = self.post_token(FIXTURE_ACCESS, "null", "same-origin")
        assert response.status_code == HTTPStatus.SEE_OTHER
        assert "kagi_unlock=saved" in response.location

    def test_json_unlock_reports_only_outcome_and_keeps_denials(self):
        response = self.post_token(
            FIXTURE_ACCESS, origin=None, accept="application/json"
        )
        assert response.status_code == HTTPStatus.OK
        assert response.get_json() == {"outcome": "saved"}
        response = self.post_token("wrong", origin=None, accept="application/json")
        assert response.get_json() == {"outcome": "rejected"}
        assert not response.headers.getlist("Set-Cookie")

    def test_headerless_obscura_form_accepts_session_bound_nonce(self):
        response = self.post_token(FIXTURE_ACCESS, origin=None)
        assert response.status_code == HTTPStatus.SEE_OTHER
        assert "kagi_unlock=saved" in response.location

    def test_missing_wrong_cross_session_and_tampered_nonce_reject(self):
        response = self.client.get("/preferences", base_url=TEST_ORIGIN)
        nonce = response.get_json()["nonce"]
        cookie_header = response.headers["Set-Cookie"]
        for flag in (
            "__Host-kagi_form=",
            "Secure",
            "HttpOnly",
            "SameSite=Strict",
            "Path=/",
        ):
            assert flag in cookie_header
        assert "Domain=" not in cookie_header
        for submitted in (None, "", "wrong", "雪"):
            data = {"kagi_engine_token": FIXTURE_ACCESS}
            if submitted is not None:
                data["kagi_form_nonce"] = submitted
            denied = self.client.post("/kagi-access", base_url=TEST_ORIGIN, data=data)
            assert denied.status_code == HTTPStatus.FORBIDDEN
            assert not denied.headers.getlist("Set-Cookie")
        other = self.app.test_client()
        data = {"kagi_engine_token": FIXTURE_ACCESS, "kagi_form_nonce": nonce}
        assert (
            other.post("/kagi-access", base_url=TEST_ORIGIN, data=data).status_code
            == HTTPStatus.FORBIDDEN
        )
        other.get("/preferences", base_url=TEST_ORIGIN)
        assert (
            other.post("/kagi-access", base_url=TEST_ORIGIN, data=data).status_code
            == HTTPStatus.FORBIDDEN
        )
        self.client.set_cookie("__Host-kagi_form", "tampered", domain="search.example")
        assert (
            self.client.post(
                "/kagi-access", base_url=TEST_ORIGIN, data=data
            ).status_code
            == HTTPStatus.FORBIDDEN
        )

    def test_unavailable_engine_rejects_without_a_cookie(self):
        self.engines.clear()
        response = self.post_token(FIXTURE_ACCESS)
        assert response.status_code == HTTPStatus.SERVICE_UNAVAILABLE
        assert not response.headers.getlist("Set-Cookie")

    def test_pure_admission_rejects_invalid_data_without_mutation(self):
        existing = frozenset({"other-engine-access"})
        allowed = frozenset({FIXTURE_ACCESS})
        assert (
            admit_access_token(existing, FIXTURE_ACCESS, allowed) == existing | allowed
        )
        for candidate in (None, False, [], {}, "", "wrong"):
            assert admit_access_token(existing, candidate, allowed) is None
        assert admit_access_token(existing, FIXTURE_ACCESS, frozenset()) is None
        assert existing == frozenset({"other-engine-access"})


class HealthTests(unittest.TestCase):
    def test_canary_categories_and_no_token_in_output(self):
        from searx.kagi_health import DEFAULT_TIMEOUT_SECONDS, Reply, probe

        def reply(body, status):
            return lambda _token, _timeout: Reply(
                body, status, SEARCH_ENDPOINT, "text/html"
            )

        assert (
            probe(
                FIXTURE_SESSION,
                DEFAULT_TIMEOUT_SECONDS,
                reply(result_html(), HTTPStatus.OK),
            )
            == "healthy"
        )
        cases = (
            (b"", HTTPStatus.UNAUTHORIZED, "session_rejected"),
            (b"", HTTPStatus.TOO_MANY_REQUESTS, "rate_limited"),
            (b"", HTTPStatus.SERVICE_UNAVAILABLE, "upstream_error"),
            (b"unknown page", HTTPStatus.OK, "unrecognized_response"),
        )
        for body, code, expected in cases:
            status = probe(FIXTURE_SESSION, DEFAULT_TIMEOUT_SECONDS, reply(body, code))
            assert status == expected
            assert FIXTURE_SESSION not in status

        def timeout(_token, _timeout):
            raise TimeoutError(FIXTURE_SESSION)

        assert (
            probe(FIXTURE_SESSION, DEFAULT_TIMEOUT_SECONDS, timeout)
            == "transport_or_probe_error"
        )

    def test_invalid_configuration_never_fetches(self):
        from searx.kagi_health import (
            DEFAULT_TIMEOUT_SECONDS,
            MAX_TIMEOUT_SECONDS,
            probe,
        )

        def forbidden_fetch(_token, _timeout):
            self.fail("Invalid configuration reached the HTTP port")

        for token in ("", "https://kagi.com/search?token=fixture", None):
            assert (
                probe(token, DEFAULT_TIMEOUT_SECONDS, forbidden_fetch)
                == "invalid_session_configuration"
            )
        for timeout in (0, -1, MAX_TIMEOUT_SECONDS + 1, None, True, "slow"):
            assert probe(FIXTURE_SESSION, timeout, forbidden_fetch) == "invalid_timeout"

    def test_transport_is_bounded_and_cannot_follow_redirects(self):
        from unittest.mock import MagicMock, patch

        from searx.kagi_health import DEFAULT_TIMEOUT_SECONDS, NoRedirect, fetch_session
        from searx.kagi_session_core import MAX_HTML_BYTES

        response = MagicMock()
        response.__enter__.return_value = response
        response.status = HTTPStatus.OK
        response.read.return_value = result_html()
        response.geturl.return_value = SEARCH_ENDPOINT
        response.headers.get.return_value = "text/html"
        with patch("searx.kagi_health.build_opener") as build:
            build.return_value.open.return_value = response
            fetch_session(FIXTURE_SESSION, DEFAULT_TIMEOUT_SECONDS)
            request = build.return_value.open.call_args.args[0]
            assert FIXTURE_SESSION not in request.full_url
            assert request.get_header("Cookie") == "kagi_session=" + FIXTURE_SESSION
            assert isinstance(build.call_args.args[0], NoRedirect)
            response.read.assert_called_once_with(MAX_HTML_BYTES + 1)
        assert (
            NoRedirect().redirect_request(
                None, None, HTTPStatus.FOUND, "", {}, "https://foreign.invalid/"
            )
            is None
        )


class AccessNoticeTests(unittest.TestCase):
    def test_packaged_webapp_compiles(self):
        webapp = Path(searx.__file__).parent / "webapp.py"
        compile(webapp.read_text(), str(webapp), "exec")

    def test_unlock_form_and_cookie_loss_notice(self):
        template_root = Path(searx.__file__).parent / "templates"
        template = Environment(
            loader=FileSystemLoader(template_root), autoescape=True
        ).get_template("simple/kagi-access.html")
        rendered = template.render(
            kagi_engine_available=True,
            kagi_access_allowed=False,
            kagi_has_tokens=False,
            kagi_unlock_attempt="saved",
            url_for=lambda endpoint, **_kwargs: (
                "/kagi-access" if endpoint == "kagi_unlock" else "/preferences"
            ),
        )
        document = html.fromstring(rendered)
        rendered_text = " ".join(document.text_content().split())
        assert document.xpath('//form[@method="post" and @action="/kagi-access"]')
        assert document.xpath('//input[@type="password"]')
        assert "did not return the saved cookie" in rendered_text
        rejected = template.render(
            kagi_engine_available=True,
            kagi_access_allowed=False,
            kagi_has_tokens=False,
            kagi_unlock_attempt="rejected",
            url_for=lambda _endpoint, **_kwargs: "/preferences",
        )
        rejected_text = " ".join(html.fromstring(rejected).text_content().split())
        assert "was not accepted" in rejected_text
        assert "did not return the saved cookie" not in rejected_text

    def test_locked_engine_is_visible_but_has_no_enable_control(self):
        template_root = Path(searx.__file__).parent / "templates"
        template = Environment(
            loader=FileSystemLoader(template_root), autoescape=True
        ).get_template("simple/kagi-locked-engine.html")
        for available in (True, False):
            rendered = template.render(
                categ="general",
                kagi_access_allowed=False,
                kagi_engine_available=available,
                enable_metrics=True,
            )
            document = html.fromstring("<table>" + rendered + "</table>")
            assert document.xpath('//*[@id="kagi-locked-engine"]')
            assert "kagi-private" in document.text_content()
            assert ("Locked" if available else "Unavailable") in document.text_content()
            assert not document.xpath("//input")
            assert document.xpath('//a[@href="#kagi-access-status"]')
        for category, allowed in (("general", True), ("images", False)):
            assert not template.render(
                categ=category, kagi_access_allowed=allowed
            ).strip()

    def test_results_hide_only_the_unlocked_panel(self):
        template_root = Path(searx.__file__).parent / "templates"
        template = Environment(
            loader=FileSystemLoader(template_root), autoescape=True
        ).get_template("simple/kagi-access.html")
        cases = (
            (True, True, True, "ready"),
            (True, False, False, "missing"),
            (True, False, True, "rejected"),
            (False, False, True, "unavailable"),
        )
        for endpoint in ("results", "preferences"):
            for available, accepted, has_tokens, expected in cases:
                with self.subTest(endpoint=endpoint, state=expected):
                    rendered = template.render(
                        endpoint=endpoint,
                        kagi_engine_available=available,
                        kagi_access_allowed=accepted,
                        kagi_has_tokens=has_tokens,
                        url_for=lambda _endpoint, **_kwargs: "/preferences",
                    )
                    if endpoint == "results" and expected == "ready":
                        assert not rendered.strip()
                    else:
                        assert f'data-state="{expected}"' in rendered

    def test_access_states_do_not_echo_credentials(self):
        template_root = Path(searx.__file__).parent / "templates"
        environment = Environment(
            loader=FileSystemLoader(template_root), autoescape=True
        )
        template = environment.get_template("simple/kagi-access.html")
        cases = (
            (True, True, True, "ready"),
            (True, False, False, "missing"),
            (True, False, True, "rejected"),
            (False, False, True, "unavailable"),
        )
        for available, accepted, has_tokens, expected in cases:
            rendered = template.render(
                kagi_engine_available=available,
                kagi_access_allowed=accepted,
                kagi_has_tokens=has_tokens,
                session_token=FIXTURE_SESSION,
                access_token=FIXTURE_ACCESS,
                url_for=lambda _endpoint, **_kwargs: "/preferences",
            )
            assert f'data-state="{expected}"' in rendered
            assert FIXTURE_SESSION not in rendered
            assert FIXTURE_ACCESS not in rendered


def result_html(url="https://example.org/page", title="Example &amp; result"):
    return (
        '<div class="search-result">'
        f'<a class="__sri_title_link" href="{url}">{title}</a>'
        '<div class="__sri-desc">A <b>useful</b> snippet.</div></div>'
    ).encode()


def parsed(
    body, status=HTTP_OK, url=SEARCH_ENDPOINT, content_type="text/html; charset=utf-8"
):
    return parse_results(body, status, url, content_type)


class CoreTests(unittest.TestCase):
    def test_main_result(self):
        assert parsed(result_html()) == [
            {
                "url": "https://example.org/page",
                "title": "Example & result",
                "content": "A useful snippet.",
            }
        ]

    def test_grouped_result(self):
        body = b"""<div class="sr-group"><div class="__srgi">
        <div class="__srgi-title"><a href="https://example.org/group">Group</a></div>
        <div class="__sri-desc">Grouped snippet</div></div></div>"""
        assert parsed(body)[0]["title"] == "Group"

    def test_deduplication_and_limit(self):
        assert len(parsed(result_html() + result_html())) == 1
        body = b"".join(
            result_html(f"https://example.org/{index}")
            for index in range(MAX_RESULTS + 1)
        )
        assert len(parsed(body)) == MAX_RESULTS

    def test_utf8_html_without_meta_charset(self):
        assert parsed(result_html(title="雪 café"))[0]["title"] == "雪 café"

    def test_declared_legacy_charset_and_invalid_charset(self):
        body = result_html(title="café").decode().encode("iso-8859-1")
        assert (
            parsed(body, content_type="text/html; charset=iso-8859-1")[0]["title"]
            == "café"
        )
        with pytest.raises(KagiPageError):
            parsed(result_html(), content_type="text/html; charset=not-a-charset")

    def test_grouped_results_keep_document_order(self):
        group = b'<div class="sr-group"><div class="__srgi"><div class="__srgi-title"><a href="https://example.org/first">First</a></div></div></div>'
        results = parsed(group + result_html())
        assert results[0]["title"] == "First"

    def test_query_encoding_and_boundary(self):
        query = "snow & café #?"
        url = search_url(query)
        assert parse_qs(urlsplit(url).query) == {"q": [query]}
        assert urlsplit(url).netloc == "kagi.com"
        assert "/html/search?" in search_url("x" * MAX_QUERY_CHARACTERS)

    def test_reject_invalid_queries(self):
        for query in (None, [], "", "  ", "x" * (MAX_QUERY_CHARACTERS + 1)):
            with (
                self.subTest(query_type=type(query).__name__),
                pytest.raises(ValueError, match="Kagi query"),
            ):
                search_url(query)

    def test_session_cookie_validation(self):
        validate_token(FIXTURE_SESSION)
        for token in (
            None,
            "",
            "$KAGI_SESSION_TOKEN",
            "secret\nother",
            "x;admin=true",
            "https://kagi.com/search?token=x",
            "Welcome to SOPS! Edit this file as you please!",
        ):
            with (
                self.subTest(token_type=type(token).__name__),
                pytest.raises(KagiSessionError),
            ):
                validate_token(token)

    def test_reject_http_errors_and_redirects(self):
        for status in (
            HTTP_REDIRECT,
            HTTP_UNAUTHORIZED,
            HTTP_FORBIDDEN,
        ):
            with self.subTest(status=status), pytest.raises(KagiSessionError):
                parsed(result_html(), status=status)

    def test_reject_endpoint_changes(self):
        for url in (
            "https://kagi.com/signin",
            "https://evil.example/html/search",
            "http://kagi.com/html/search",
            "https://kagi.com@evil.example/html/search",
            "https://[broken/html/search",
        ):
            with self.subTest(url=url), pytest.raises(KagiSessionError):
                parsed(result_html(), url=url)

    def test_reject_login_even_with_result_markup(self):
        with pytest.raises(KagiSessionError):
            parsed(b'<form><input type="password"></form>' + result_html())

    def test_reject_empty_changed_and_non_html_pages(self):
        for body in (
            b"",
            b"<html>No results</html>",
            b'{"data": []}',
            b"<script>login()</script>",
        ):
            with self.subTest(body=body), pytest.raises(KagiPageError):
                parsed(body)
        with pytest.raises(KagiPageError):
            parsed(result_html(), content_type="application/json")
        with pytest.raises(KagiPageError):
            parsed(b"x" * (MAX_HTML_BYTES + 1))

    def test_reject_missing_title_and_unsafe_result_url(self):
        for body in (
            b'<div class="search-result"><p>Changed markup</p></div>',
            result_html(title=""),
            result_html(url="javascript:alert(1)"),
            result_html(url="https://user:password@example.org/"),
            result_html(url="https://example.org/space here"),
            result_html(url="https://[broken/"),
        ):
            with self.subTest(body=body), pytest.raises(KagiPageError):
                parsed(body)


class AdapterTests(unittest.TestCase):
    def setUp(self):
        self.session_patch = patch.object(engine, "session_token", FIXTURE_SESSION)
        self.session_patch.start()
        self.addCleanup(self.session_patch.stop)

    def test_private_initialization(self):
        engine.init({"tokens": [FIXTURE_ACCESS]})
        for tokens in ([], [""], ["$KAGI_ENGINE_TOKEN"]):
            with self.subTest(tokens=tokens), pytest.raises(KagiSessionError):
                engine.init({"tokens": tokens})

    def test_real_engine_loader(self):
        settings = {
            "name": "kagi-private-fixture",
            "engine": "kagi_session",
            "session_token": FIXTURE_SESSION,
            "tokens": [FIXTURE_ACCESS],
            "timeout": REQUEST_TIMEOUT_SECONDS,
            "disabled": True,
        }
        loaded = load_engine(settings)
        assert loaded is not None
        loaded.init(settings)
        assert loaded.timeout == REQUEST_TIMEOUT_SECONDS
        assert loaded.disabled
        settings["tokens"] = []
        with pytest.raises(KagiSessionError):
            loaded.init(settings)

    def test_framework_access_token_gate(self):
        private_engine = SimpleNamespace(tokens=[FIXTURE_ACCESS])
        for values, expected in (
            ([], False),
            (["wrong"], False),
            ([FIXTURE_ACCESS], True),
        ):
            preference = SimpleNamespace(tokens=SimpleNamespace(values=values))
            assert Preferences.validate_token(preference, private_engine) == expected

    def test_request_contract(self):
        params = engine.request("fixture", default_request_params())
        assert params["cookies"] == {"kagi_session": FIXTURE_SESSION}
        assert FIXTURE_SESSION not in params["url"]
        assert "/api/" not in params["url"]
        assert not params["allow_redirects"]
        assert params["verify"]
        assert not params["raise_for_httperror"]
        assert params["method"] == "GET"
        next_page = engine.FIRST_PAGE + 1
        assert engine.request("fixture", {"pageno": next_page}) is None

    def test_request_rejects_bad_session_without_io(self):
        with patch.object(engine, "session_token", ""), pytest.raises(KagiSessionError):
            engine.request("fixture", default_request_params())

    def test_response_and_error_translation(self):
        response = SimpleNamespace(
            content=result_html(),
            status_code=HTTP_OK,
            url=SEARCH_ENDPOINT,
            headers={"content-type": "text/html"},
        )
        assert engine.response(response)[0]["title"] == "Example & result"
        response.status_code = HTTP_UNAUTHORIZED
        with pytest.raises(SearxEngineAccessDeniedException) as caught:
            engine.response(response)
        assert FIXTURE_SESSION not in str(caught.value)
        response.status_code = HTTP_OK
        response.content = b"login or changed page"
        with pytest.raises(SearxEngineResponseException):
            engine.response(response)

    def test_server_error_is_not_session_suspension(self):
        response = SimpleNamespace(
            content=b"server error",
            status_code=HTTP_SERVER_ERROR,
            url=SEARCH_ENDPOINT,
            headers={"content-type": "text/html"},
        )
        with pytest.raises(SearxEngineResponseException) as caught:
            engine.response(response)
        assert not isinstance(caught.value, SearxEngineAccessDeniedException)

    def test_rate_limit_uses_framework_backoff(self):
        response = SimpleNamespace(
            content=b"rate limit",
            status_code=HTTP_RATE_LIMITED,
            url=SEARCH_ENDPOINT,
            headers={"content-type": "text/html"},
        )
        with pytest.raises(SearxEngineTooManyRequestsException):
            engine.response(response)

    def test_framework_timeout_and_timeout_failure(self):
        fake_processor = SimpleNamespace(engine=SimpleNamespace(name="kagi-private"))
        with (
            patch("searx.network.set_timeout_for_thread") as set_timeout,
            patch("searx.network.reset_time_for_thread"),
            patch("searx.network.set_context_network_name"),
        ):
            OnlineProcessor.init_network_in_thread(
                fake_processor, start_time=0, timeout_limit=REQUEST_TIMEOUT_SECONDS
            )
            set_timeout.assert_called_once_with(REQUEST_TIMEOUT_SECONDS, start_time=0)
        params = engine.request("fixture", default_request_params())
        with patch(
            "searx.network.get", side_effect=httpx.ReadTimeout("fixture timeout")
        ) as send:
            with pytest.raises(httpx.ReadTimeout):
                OnlineProcessor._send_http_request(fake_processor, params)
            assert send.call_count == 1


if __name__ == "__main__":
    unittest.main()
