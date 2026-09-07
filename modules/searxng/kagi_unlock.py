"""Same-origin form adapter for one private engine's cookie.

The existing SearXNG preferences object reads cookies. Only its token cookie
is updated here. The normal search engine gate remains authoritative.
"""

from collections.abc import Mapping
from http import HTTPStatus
from secrets import compare_digest, token_urlsafe
from typing import Any

from flask import Flask, Response, redirect, session, url_for
from searx.extended_types import sxng_request
from searx.kagi_session_core import admit_access_token

ENGINE_NAME = "kagi-private"
FORM_NONCE_BYTES = 32
FORM_NONCE_KEY = "kagi_form_nonce"


def install_kagi_unlock(app: Flask, engines: Mapping[str, Any]) -> None:
    """Install a POST-only endpoint without exposing account credentials."""

    app.config.update(
        SESSION_COOKIE_NAME="__Host-kagi_form",
        SESSION_COOKIE_SECURE=True,
        SESSION_COOKIE_HTTPONLY=True,
        SESSION_COOKIE_SAMESITE="Strict",
        SESSION_COOKIE_PATH="/",
    )

    @app.context_processor
    def form_context() -> dict[str, str]:
        if FORM_NONCE_KEY not in session:
            session[FORM_NONCE_KEY] = token_urlsafe(FORM_NONCE_BYTES)
        return {FORM_NONCE_KEY: session[FORM_NONCE_KEY]}

    @app.post("/kagi-access", endpoint="kagi_unlock")
    def unlock() -> Response:
        origin = sxng_request.headers.get("Origin")
        fetch_site = sxng_request.headers.get("Sec-Fetch-Site")
        expected_origin = sxng_request.host_url.rstrip("/")
        # Reject explicit cross-origin metadata, but do not require headers
        # that privacy-preserving browsers can omit. The signed session
        # and unpredictable hidden form nonce provide the CSRF boundary.
        origin_consistent = origin in (
            None,
            "null",
            expected_origin,
        ) and fetch_site in (None, "same-origin")
        expected_nonce = session.get(FORM_NONCE_KEY)
        submitted_nonce = sxng_request.form.get(FORM_NONCE_KEY)
        nonce_valid = (
            isinstance(expected_nonce, str)
            and isinstance(submitted_nonce, str)
            and bool(expected_nonce)
            and compare_digest(expected_nonce.encode(), submitted_nonce.encode())
        )
        if not origin_consistent or not nonce_valid:
            return Response(
                "The unlock form expired or its browser cookie is missing. Reload Preferences and try again.",
                status=HTTPStatus.FORBIDDEN,
                mimetype="text/plain",
            )
        engine = engines.get(ENGINE_NAME)
        if engine is None:
            return Response(
                "The Kagi engine is unavailable.",
                status=HTTPStatus.SERVICE_UNAVAILABLE,
                mimetype="text/plain",
            )
        tokens = sxng_request.preferences.tokens
        updated = admit_access_token(
            frozenset(tokens.values),
            sxng_request.form.get("kagi_engine_token"),
            frozenset(engine.tokens),
        )
        accepted = updated is not None and not tokens.locked
        outcome = "saved" if accepted else "rejected"
        response = redirect(
            url_for("preferences", kagi_unlock=outcome),
            code=HTTPStatus.SEE_OTHER,
        )
        response.headers["Cache-Control"] = "no-store"
        if accepted:
            assert updated is not None
            tokens.values = set(updated)
            tokens.save("tokens", response)
        return response
