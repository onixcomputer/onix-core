"""Positive and negative specialist-engine checks against the packaged runtime."""

import json
import unittest
from http import HTTPStatus
from pathlib import Path
from types import SimpleNamespace
from urllib.parse import parse_qs, urlsplit

import pytest
import searx
from searx.engines import load_engine
from searx.engines import nix_options as adapter
from searx.exceptions import SearxEngineResponseException
from searx.specialist_core import (
    BACKEND_URL,
    MAX_CATALOG_BYTES,
    MAX_QUERY_CHARACTERS,
    MAX_RESPONSE_BYTES,
    SOURCE_TYPES,
    SpecialistError,
    noogle_catalog,
    option_query,
    option_results,
    search_catalog,
)


def encoded(value):
    return json.dumps(value).encode()


def option_reply(source="nixos", name="services.openssh.enable"):
    return encoded(
        {
            "hits": {
                "hits": [
                    {
                        "_source": {
                            "type": SOURCE_TYPES[source],
                            "option_name": name,
                            "option_description": "<p>Enable <b>SSH</b>.</p>",
                        }
                    }
                ]
            }
        }
    )


def catalog_record(path, aliases=None, description=""):
    return {
        "meta": {"path": path, "aliases": aliases},
        "content": {"content": description},
    }


class SpecialistTests(unittest.TestCase):
    def test_option_query_and_result_source_isolation(self):
        for source, document_type in SOURCE_TYPES.items():
            query = option_query('ssh "x"', source)
            assert query["query"]["bool"]["filter"] == [
                {"term": {"type": document_type}}
            ]
            result = option_results(option_reply(source), source)[0]
            assert result["content"] == "Enable SSH."
            assert parse_qs(urlsplit(result["url"]).query)["source"] == [source]
            other = "home_manager" if source == "nixos" else "nixos"
            with pytest.raises(SpecialistError):
                option_results(option_reply(other), source)
        assert option_results(encoded({"hits": {"hits": []}}), "nixos") == []

    def test_bad_option_queries_and_responses_reject(self):
        for query in ("", " ", None, True, "x" * (MAX_QUERY_CHARACTERS + 1)):
            with pytest.raises(SpecialistError):
                option_query(query, "nixos")
        for source in ("foreign", None, []):
            with pytest.raises(SpecialistError):
                option_query("ssh", source)
            with pytest.raises(SpecialistError):
                option_results(option_reply(), source)
        for body in (
            b"not JSON",
            b"x" * (MAX_RESPONSE_BYTES + 1),
            encoded([]),
            encoded({}),
            encoded({"error": "failure"}),
            encoded({"error": {}, "hits": {"hits": []}}),
            encoded({"_shards": {"failed": 1}, "hits": {"hits": []}}),
            encoded({"timed_out": True}),
            encoded({"hits": {"hits": [{"_source": {"type": "option"}}]}}),
        ):
            with pytest.raises(SpecialistError):
                option_results(body, "nixos")

    def test_result_links_cannot_inject_parameters(self):
        name = "x&source=foreign#fragment"
        result = option_results(option_reply(name=name), "nixos")[0]
        url = urlsplit(result["url"])
        assert url.netloc == "search.nixos.org"
        assert parse_qs(url.query)["query"] == [name]
        assert parse_qs(url.query)["source"] == ["nixos"]
        assert not url.fragment

    def test_catalog_aliases_ranking_and_empty_results(self):
        records = [
            catalog_record(["lib", "longName"], description="mkIf in documentation"),
            catalog_record(
                ["lib", "modules", "mkIf"], [["lib", "mkIf"]], "Conditional module"
            ),
        ]
        entries = noogle_catalog(encoded({"data": records}))
        result = search_catalog(entries, "lib.mkIf")[0]
        assert result["title"] == "lib.mkIf"
        assert result["url"] == "https://noogle.dev/f/lib/modules/mkIf"
        assert search_catalog(entries, "no-such-function") == []
        assert search_catalog(entries, "!!!") == []
        assert search_catalog(entries, "mkIf")[0]["title"] == "lib.mkIf"

    def test_catalog_rejects_invalid_and_unsafe_records(self):
        for data in (
            [],
            {},
            {"data": []},
            {"data": [{}]},
            {"data": [catalog_record(["..", "bad"])]},
            {"data": [catalog_record(["lib/../../bad"])]},
            {"data": [catalog_record(["lib"], aliases=False)]},
        ):
            with pytest.raises(SpecialistError):
                noogle_catalog(encoded(data))
        with pytest.raises(SpecialistError):
            noogle_catalog(b"x" * (MAX_CATALOG_BYTES + 1))
        with pytest.raises(SpecialistError):
            search_catalog((), "")

    def test_native_loader_keeps_option_sources_separate(self):
        loaded = []
        for source in SOURCE_TYPES:
            engine = load_engine(
                {
                    "name": "fixture-" + source.replace("_", "-"),
                    "engine": "nix_options",
                    "option_source": source,
                }
            )
            assert engine is not None
            loaded.append(engine)
        for engine in loaded:
            params = engine.request("enable", {"pageno": 1})
            assert params["url"] == BACKEND_URL
            assert params["method"] == "POST"
            assert params["verify"]
            assert not params["allow_redirects"]
            assert json.loads(params["data"])["query"]["bool"]["filter"] == [
                {"term": {"type": SOURCE_TYPES[engine.option_source]}}
            ]
            assert engine.request("enable", {"pageno": 1 + 1}) is None
        with pytest.raises(SearxEngineResponseException):
            adapter.response(
                SimpleNamespace(status_code=HTTPStatus.OK, content=b"not JSON")
            )

    def test_real_pinned_catalog_and_github_load_without_kagi(self):
        engine = load_engine({"name": "fixture-noogle", "engine": "noogle_catalog"})
        assert engine is not None
        engine.init({})
        assert engine.engine_type == "offline"
        assert any(
            result["title"] == "lib.mkIf" for result in engine.search("lib.mkIf", {})
        )
        assert load_engine({"name": "fixture-github", "engine": "github"}) is not None
        root = Path(searx.__file__).parent
        assert (root / "data/noogle-notices.txt").is_file()
        assert not (root / "templates/simple/kagi-access.html").exists()


if __name__ == "__main__":
    unittest.main()
