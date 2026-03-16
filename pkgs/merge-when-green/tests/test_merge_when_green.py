#!/usr/bin/env python3
"""Tests for merge-when-green, focused on the buildbot expansion and check classification."""

import importlib.util
from pathlib import Path
from unittest.mock import patch

# Load the module from its hyphenated filename
_spec = importlib.util.spec_from_file_location(
    "merge_when_green",
    str(Path(__file__).parent.parent / "merge-when-green.py"),
)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

# Pull functions into module scope
classify_checks = _mod.classify_checks
check_pr_completion = _mod.check_pr_completion
parse_buildbot_url = _mod.parse_buildbot_url
_parse_nix_log_tail = _mod._parse_nix_log_tail
_fetch_buildbot_json = _mod._fetch_buildbot_json
_get_step_log_tail = _mod._get_step_log_tail
_get_active_step = _mod._get_active_step
_check_one_build_request = _mod._check_one_build_request
query_buildbot_subbuilds = _mod.query_buildbot_subbuilds
run_buildbot_check_if_needed = _mod.run_buildbot_check_if_needed


# ---------------------------------------------------------------------------
# classify_checks
# ---------------------------------------------------------------------------


class TestClassifyChecks:
    """Tests for classify_checks (refactored from count_check_states)."""

    def test_empty_checks(self):
        pending, failed, passed, details = classify_checks([])
        assert (pending, failed, passed) == (0, 0, 0)
        assert details == []

    def test_single_passing_check_run(self):
        checks = [
            {
                "__typename": "CheckRun",
                "name": "ci/build",
                "status": "COMPLETED",
                "conclusion": "SUCCESS",
                "detailsUrl": "https://example.com/build/1",
            }
        ]
        pending, failed, passed, details = classify_checks(checks)
        assert (pending, failed, passed) == (0, 0, 1)
        assert details == [("ci/build", "✅", "https://example.com/build/1")]

    def test_single_failing_check_run(self):
        checks = [
            {
                "__typename": "CheckRun",
                "name": "ci/test",
                "status": "COMPLETED",
                "conclusion": "FAILURE",
                "detailsUrl": "https://example.com/build/2",
            }
        ]
        pending, failed, passed, details = classify_checks(checks)
        assert (pending, failed, passed) == (0, 1, 0)
        assert details == [("ci/test", "❌", "https://example.com/build/2")]

    def test_pending_check_run(self):
        checks = [
            {
                "__typename": "CheckRun",
                "name": "ci/lint",
                "status": "IN_PROGRESS",
                "conclusion": None,
                "detailsUrl": None,
            }
        ]
        pending, failed, passed, details = classify_checks(checks)
        assert (pending, failed, passed) == (1, 0, 0)
        assert details == [("ci/lint", "⏳", None)]

    def test_neutral_and_skipped_count_as_passed(self):
        checks = [
            {
                "__typename": "CheckRun",
                "name": "optional-lint",
                "status": "COMPLETED",
                "conclusion": "NEUTRAL",
            },
            {
                "__typename": "CheckRun",
                "name": "platform-skip",
                "status": "COMPLETED",
                "conclusion": "SKIPPED",
            },
        ]
        pending, failed, passed, details = classify_checks(checks)
        assert (pending, failed, passed) == (0, 0, 2)
        assert all(sym == "✅" for _, sym, _ in details)

    def test_status_context_pending(self):
        checks = [
            {
                "__typename": "StatusContext",
                "context": "buildbot/ci",
                "state": "PENDING",
                "targetUrl": "https://buildbot.example.com/#/builders/1/builds/5",
            }
        ]
        pending, failed, passed, details = classify_checks(checks)
        assert (pending, failed, passed) == (1, 0, 0)
        assert details[0] == (
            "buildbot/ci",
            "⏳",
            "https://buildbot.example.com/#/builders/1/builds/5",
        )

    def test_status_context_success(self):
        checks = [
            {
                "__typename": "StatusContext",
                "context": "buildbot/ci",
                "state": "SUCCESS",
                "targetUrl": "https://buildbot.example.com/#/builders/1/builds/5",
            }
        ]
        pending, failed, passed, details = classify_checks(checks)
        assert (pending, failed, passed) == (0, 0, 1)
        assert details[0][1] == "✅"

    def test_status_context_failure(self):
        checks = [
            {
                "__typename": "StatusContext",
                "context": "buildbot/ci",
                "state": "FAILURE",
                "targetUrl": "https://buildbot.example.com/#/builders/1/builds/5",
            }
        ]
        pending, failed, passed, details = classify_checks(checks)
        assert (pending, failed, passed) == (0, 1, 0)
        assert details[0][1] == "❌"

    def test_status_context_neutral_counts_as_passed(self):
        checks = [
            {"__typename": "StatusContext", "context": "info", "state": "NEUTRAL"}
        ]
        _, _, passed, details = classify_checks(checks)
        assert passed == 1
        assert details[0][1] == "✅"

    def test_mixed_check_types(self):
        checks = [
            {
                "__typename": "CheckRun",
                "name": "ci/build",
                "status": "COMPLETED",
                "conclusion": "SUCCESS",
                "detailsUrl": "https://gh.com/1",
            },
            {
                "__typename": "StatusContext",
                "context": "buildbot/ci",
                "state": "PENDING",
                "targetUrl": "https://bb.com/2",
            },
            {
                "__typename": "CheckRun",
                "name": "ci/test",
                "status": "COMPLETED",
                "conclusion": "FAILURE",
                "detailsUrl": "https://gh.com/3",
            },
        ]
        pending, failed, passed, details = classify_checks(checks)
        assert (pending, failed, passed) == (1, 1, 1)
        assert len(details) == 3

    def test_name_fallback_to_context(self):
        """StatusContext uses 'context' field, not 'name'."""
        checks = [
            {"__typename": "StatusContext", "context": "my-context", "state": "SUCCESS"}
        ]
        _, _, _, details = classify_checks(checks)
        assert details[0][0] == "my-context"

    def test_name_fallback_to_unknown(self):
        checks = [
            {
                "__typename": "CheckRun",
                "status": "COMPLETED",
                "conclusion": "SUCCESS",
            }
        ]
        _, _, _, details = classify_checks(checks)
        assert details[0][0] == "unknown"

    def test_url_fallback_to_target_url(self):
        """StatusContext uses 'targetUrl' instead of 'detailsUrl'."""
        checks = [
            {
                "__typename": "StatusContext",
                "context": "x",
                "state": "SUCCESS",
                "targetUrl": "https://target.example.com",
            }
        ]
        _, _, _, details = classify_checks(checks)
        assert details[0][2] == "https://target.example.com"

    def test_unknown_typename_ignored(self):
        """Checks with unrecognized __typename are silently skipped."""
        checks = [{"__typename": "SomethingNew", "name": "x", "status": "COMPLETED"}]
        pending, failed, passed, details = classify_checks(checks)
        assert (pending, failed, passed) == (0, 0, 0)
        assert details == []


# ---------------------------------------------------------------------------
# check_pr_completion
# ---------------------------------------------------------------------------


class TestCheckPrCompletion:
    def test_merged(self):
        result = check_pr_completion(
            {"state": "MERGED", "mergeable": "MERGEABLE", "autoMergeRequest": {}},
            pending=0,
            failed=0,
        )
        assert result == (True, "PR successfully merged!")

    def test_closed(self):
        result = check_pr_completion(
            {"state": "CLOSED", "mergeable": "UNKNOWN", "autoMergeRequest": {}},
            pending=0,
            failed=0,
        )
        assert result == (False, "PR was closed")

    def test_auto_merge_disabled(self):
        result = check_pr_completion(
            {"state": "OPEN", "mergeable": "MERGEABLE", "autoMergeRequest": None},
            pending=0,
            failed=0,
        )
        assert result == (False, "Auto-merge was disabled")

    def test_conflicting(self):
        result = check_pr_completion(
            {"state": "OPEN", "mergeable": "CONFLICTING", "autoMergeRequest": {}},
            pending=0,
            failed=0,
        )
        assert result == (False, "PR has merge conflicts")

    def test_all_failed_no_pending(self):
        result = check_pr_completion(
            {"state": "OPEN", "mergeable": "MERGEABLE", "autoMergeRequest": {}},
            pending=0,
            failed=3,
        )
        assert result == (False, "3 checks failed")

    def test_still_pending(self):
        result = check_pr_completion(
            {"state": "OPEN", "mergeable": "MERGEABLE", "autoMergeRequest": {}},
            pending=2,
            failed=0,
        )
        assert result is None

    def test_pending_with_failures_still_waiting(self):
        """If some checks are pending and some failed, keep waiting — more may pass."""
        result = check_pr_completion(
            {"state": "OPEN", "mergeable": "MERGEABLE", "autoMergeRequest": {}},
            pending=1,
            failed=1,
        )
        assert result is None

    def test_merged_trumps_failures(self):
        """Merged state wins regardless of check counts."""
        result = check_pr_completion(
            {"state": "MERGED", "mergeable": "UNKNOWN", "autoMergeRequest": None},
            pending=5,
            failed=3,
        )
        assert result == (True, "PR successfully merged!")

    def test_closed_trumps_auto_merge(self):
        """Closed state wins even if auto-merge was set."""
        result = check_pr_completion(
            {"state": "CLOSED", "mergeable": "MERGEABLE", "autoMergeRequest": {}},
            pending=0,
            failed=0,
        )
        assert result == (False, "PR was closed")


# ---------------------------------------------------------------------------
# parse_buildbot_url
# ---------------------------------------------------------------------------


class TestParseBuildBotUrl:
    def test_standard_fragment_url(self):
        url = "https://buildbot.blr.dev/#/builders/42/builds/17"
        result = parse_buildbot_url(url)
        assert result == ("buildbot.blr.dev", "42", "17")

    def test_api_style_url(self):
        url = "https://buildbot.thalheim.io/api/v2/builders/5/builds/100"
        result = parse_buildbot_url(url)
        assert result == ("buildbot.thalheim.io", "5", "100")

    def test_no_builders_path(self):
        assert parse_buildbot_url("https://example.com/some/page") is None

    def test_empty_string(self):
        assert parse_buildbot_url("") is None

    def test_malformed_url_no_host(self):
        assert parse_buildbot_url("builders/1/builds/2") is None

    def test_large_ids(self):
        url = "https://bb.example.org/#/builders/99999/builds/123456"
        result = parse_buildbot_url(url)
        assert result == ("bb.example.org", "99999", "123456")


# ---------------------------------------------------------------------------
# _parse_nix_log_tail
# ---------------------------------------------------------------------------


class TestParseNixLogTail:
    def test_building_drv(self):
        log = "building '/nix/store/abc123-hello-2.12.drv'..."
        assert _parse_nix_log_tail(log) == "building hello-2.12"

    def test_copying_path(self):
        log = "copying path '/nix/store/xyz789-glibc-2.38' to 'ssh://...'..."
        assert _parse_nix_log_tail(log) == "copying glibc-2.38"

    def test_fetching_path(self):
        log = "fetching path '/nix/store/def456-python3-3.11.6'..."
        assert _parse_nix_log_tail(log) == "fetching python3-3.11.6"

    def test_nix3_style_building(self):
        log = "building foo-1.2.3 (3 built, 12 to do)"
        assert _parse_nix_log_tail(log) == "building foo-1.2.3 (3 built, 12 to do)"

    def test_evaluating(self):
        log = "evaluating derivation 'foo'"
        assert _parse_nix_log_tail(log) == "evaluating derivation 'foo'"

    def test_last_match_wins(self):
        """Should pick the last meaningful line (walking backwards)."""
        log = (
            "building '/nix/store/aaa-old.drv'...\n"
            "some noise\n"
            "building '/nix/store/bbb-new.drv'...\n"
        )
        assert _parse_nix_log_tail(log) == "building new"

    def test_no_match(self):
        assert _parse_nix_log_tail("random output\nnothing useful\n") is None

    def test_empty_string(self):
        assert _parse_nix_log_tail("") is None

    def test_mixed_events_takes_latest(self):
        log = (
            "copying path '/nix/store/aaa-early' to ...\n"
            "noise\n"
            "fetching path '/nix/store/bbb-later'...\n"
        )
        assert _parse_nix_log_tail(log) == "fetching later"

    def test_whitespace_stripped(self):
        log = "   building '/nix/store/abc-trimmed.drv'...   "
        assert _parse_nix_log_tail(log) == "building trimmed"

    def test_long_evaluating_line_truncated(self):
        long_name = "x" * 100
        log = f"evaluating {long_name}"
        result = _parse_nix_log_tail(log)
        assert len(result) <= 80


# ---------------------------------------------------------------------------
# query_buildbot_subbuilds (mocked API)
# ---------------------------------------------------------------------------


def _make_steps_response(steps: list[dict]) -> dict:
    return {"steps": steps}


def _make_buildrequests_response(requests: list[dict]) -> dict:
    return {"buildrequests": requests}


def _make_builds_response(builds: list[dict]) -> dict:
    return {"builds": builds}


class TestQueryBuildbotSubbuilds:
    def test_unparseable_url(self):
        assert query_buildbot_subbuilds("https://example.com/nope") == []

    @patch.object(_mod, "_fetch_buildbot_json")
    def test_no_triggered_steps(self, mock_fetch):
        """If the parent build has no trigger steps, return empty."""
        mock_fetch.return_value = _make_steps_response(
            [{"name": "checkout", "urls": []}]
        )
        result = query_buildbot_subbuilds(
            "https://bb.example.com/#/builders/1/builds/1"
        )
        assert result == []

    @patch.object(_mod, "_fetch_buildbot_json")
    def test_two_subbuilds_both_passed(self, mock_fetch):
        def api_dispatch(url):
            if "/builders/1/builds/1/steps" in url:
                return _make_steps_response(
                    [
                        {
                            "name": "trigger-build",
                            "urls": [
                                {"url": "https://bb.example.com/buildrequests/10"},
                                {"url": "https://bb.example.com/buildrequests/11"},
                            ],
                        }
                    ]
                )
            if "buildrequests/10" in url and "property" in url:
                return _make_buildrequests_response(
                    [
                        {
                            "results": 0,
                            "properties": {
                                "virtual_builder_name": [
                                    "project#checks.x86_64-linux.aspen1"
                                ]
                            },
                        }
                    ]
                )
            if "buildrequests/11" in url and "property" in url:
                return _make_buildrequests_response(
                    [
                        {
                            "results": 0,
                            "properties": {
                                "virtual_builder_name": [
                                    "project#checks.x86_64-linux.aspen2"
                                ]
                            },
                        }
                    ]
                )
            return {}

        mock_fetch.side_effect = api_dispatch
        result = query_buildbot_subbuilds(
            "https://bb.example.com/#/builders/1/builds/1"
        )
        assert len(result) == 2
        names = [r[0] for r in result]
        assert "checks.x86_64-linux.aspen1" in names
        assert "checks.x86_64-linux.aspen2" in names
        assert all(r[1] == "✅" for r in result)
        assert all(r[2] is None for r in result)

    @patch.object(_mod, "_fetch_buildbot_json")
    def test_in_progress_build_shows_step_info(self, mock_fetch):
        def api_dispatch(url):
            if "/builders/1/builds/1/steps" in url:
                return _make_steps_response(
                    [
                        {
                            "name": "trigger-build",
                            "urls": [
                                {"url": "https://bb.example.com/buildrequests/20"}
                            ],
                        }
                    ]
                )
            if "buildrequests/20" in url and "property" in url:
                return _make_buildrequests_response(
                    [
                        {
                            "results": None,  # in-progress
                            "properties": {
                                "virtual_builder_name": [
                                    "proj#checks.x86_64-linux.pine"
                                ]
                            },
                        }
                    ]
                )
            if "buildrequests/20/builds" in url:
                return _make_builds_response([{"buildid": 99}])
            if "builds/99/steps" in url:
                return _make_steps_response(
                    [
                        {"name": "checkout", "complete": True, "state_string": "done"},
                        {
                            "name": "nix-build",
                            "complete": False,
                            "state_string": "running",
                            "stepid": 555,
                        },
                    ]
                )
            if "steps/555/logs" in url:
                return {"logs": [{"logid": 777, "num_lines": 50}]}
            if "logs/777/contents" in url:
                return {
                    "logchunks": [
                        {
                            "content": "building '/nix/store/abc123-nixos-system-pine.drv'...\n"
                        }
                    ]
                }
            return {}

        mock_fetch.side_effect = api_dispatch
        result = query_buildbot_subbuilds(
            "https://bb.example.com/#/builders/1/builds/1"
        )
        assert len(result) == 1
        name, symbol, step_info = result[0]
        assert name == "checks.x86_64-linux.pine"
        assert symbol == "🔨"
        assert step_info == "building nixos-system-pine"

    @patch.object(_mod, "_fetch_buildbot_json")
    def test_failed_subbuild(self, mock_fetch):
        def api_dispatch(url):
            if "/builders/1/builds/1/steps" in url:
                return _make_steps_response(
                    [
                        {
                            "name": "trigger-build",
                            "urls": [
                                {"url": "https://bb.example.com/buildrequests/30"}
                            ],
                        }
                    ]
                )
            if "buildrequests/30" in url and "property" in url:
                return _make_buildrequests_response(
                    [
                        {
                            "results": 2,  # failure
                            "properties": {
                                "virtual_builder_name": [
                                    "proj#checks.x86_64-linux.bonsai"
                                ]
                            },
                        }
                    ]
                )
            return {}

        mock_fetch.side_effect = api_dispatch
        result = query_buildbot_subbuilds(
            "https://bb.example.com/#/builders/1/builds/1"
        )
        assert len(result) == 1
        assert result[0] == ("checks.x86_64-linux.bonsai", "❌", None)

    @patch.object(_mod, "_fetch_buildbot_json")
    def test_warning_and_skipped_results(self, mock_fetch):
        def api_dispatch(url):
            if "/builders/1/builds/1/steps" in url:
                return _make_steps_response(
                    [
                        {
                            "name": "trigger-build",
                            "urls": [
                                {"url": "https://bb.example.com/buildrequests/40"},
                                {"url": "https://bb.example.com/buildrequests/41"},
                            ],
                        }
                    ]
                )
            if "buildrequests/40" in url and "property" in url:
                return _make_buildrequests_response(
                    [
                        {
                            "results": 1,  # warnings
                            "properties": {
                                "virtual_builder_name": ["proj#checks.warn"]
                            },
                        }
                    ]
                )
            if "buildrequests/41" in url and "property" in url:
                return _make_buildrequests_response(
                    [
                        {
                            "results": 3,  # skipped
                            "properties": {
                                "virtual_builder_name": ["proj#checks.skip"]
                            },
                        }
                    ]
                )
            return {}

        mock_fetch.side_effect = api_dispatch
        result = query_buildbot_subbuilds(
            "https://bb.example.com/#/builders/1/builds/1"
        )
        assert len(result) == 2
        symbols = {r[0]: r[1] for r in result}
        assert symbols["checks.warn"] == "⏭️"
        assert symbols["checks.skip"] == "⏭️"

    @patch.object(_mod, "_fetch_buildbot_json")
    def test_results_sorted_by_name(self, mock_fetch):
        def api_dispatch(url):
            if "/builders/1/builds/1/steps" in url:
                return _make_steps_response(
                    [
                        {
                            "name": "trigger-build",
                            "urls": [
                                {"url": "https://bb.example.com/buildrequests/50"},
                                {"url": "https://bb.example.com/buildrequests/51"},
                                {"url": "https://bb.example.com/buildrequests/52"},
                            ],
                        }
                    ]
                )
            if "buildrequests/50" in url and "property" in url:
                return _make_buildrequests_response(
                    [
                        {
                            "results": 0,
                            "properties": {"virtual_builder_name": ["proj#zebra"]},
                        }
                    ]
                )
            if "buildrequests/51" in url and "property" in url:
                return _make_buildrequests_response(
                    [
                        {
                            "results": 0,
                            "properties": {"virtual_builder_name": ["proj#alpha"]},
                        }
                    ]
                )
            if "buildrequests/52" in url and "property" in url:
                return _make_buildrequests_response(
                    [
                        {
                            "results": 0,
                            "properties": {"virtual_builder_name": ["proj#middle"]},
                        }
                    ]
                )
            return {}

        mock_fetch.side_effect = api_dispatch
        result = query_buildbot_subbuilds(
            "https://bb.example.com/#/builders/1/builds/1"
        )
        names = [r[0] for r in result]
        assert names == ["alpha", "middle", "zebra"]

    @patch.object(_mod, "_fetch_buildbot_json")
    def test_api_error_returns_empty(self, mock_fetch):
        """Network errors when fetching steps should not crash."""
        import urllib.error

        mock_fetch.side_effect = urllib.error.URLError("timeout")
        result = query_buildbot_subbuilds(
            "https://bb.example.com/#/builders/1/builds/1"
        )
        assert result == []

    @patch.object(_mod, "_fetch_buildbot_json")
    def test_queued_build_request(self, mock_fetch):
        """Build request with no builds yet shows 'queued'."""

        def api_dispatch(url):
            if "/builders/1/builds/1/steps" in url:
                return _make_steps_response(
                    [
                        {
                            "name": "trigger-build",
                            "urls": [
                                {"url": "https://bb.example.com/buildrequests/60"}
                            ],
                        }
                    ]
                )
            if "buildrequests/60" in url and "property" in url:
                return _make_buildrequests_response(
                    [
                        {
                            "results": None,
                            "properties": {
                                "virtual_builder_name": ["proj#checks.queued-thing"]
                            },
                        }
                    ]
                )
            if "buildrequests/60/builds" in url:
                return _make_builds_response([])  # no builds yet
            return {}

        mock_fetch.side_effect = api_dispatch
        result = query_buildbot_subbuilds(
            "https://bb.example.com/#/builders/1/builds/1"
        )
        assert len(result) == 1
        assert result[0] == ("checks.queued-thing", "🔨", "queued")


# ---------------------------------------------------------------------------
# _check_one_build_request
# ---------------------------------------------------------------------------


class TestCheckOneBuildRequest:
    @patch.object(_mod, "_fetch_buildbot_json")
    def test_name_from_virtual_builder_name(self, mock_fetch):
        mock_fetch.return_value = _make_buildrequests_response(
            [
                {
                    "results": 0,
                    "properties": {
                        "virtual_builder_name": ["onix-core#checks.x86_64-linux.aspen1"]
                    },
                }
            ]
        )
        name, symbol, step = _check_one_build_request("bb.example.com", 1)
        assert name == "checks.x86_64-linux.aspen1"
        assert symbol == "✅"
        assert step is None

    @patch.object(_mod, "_fetch_buildbot_json")
    def test_name_fallback_to_request_id(self, mock_fetch):
        mock_fetch.return_value = _make_buildrequests_response(
            [{"results": 0, "properties": {}}]
        )
        name, _, _ = _check_one_build_request("bb.example.com", 42)
        assert name == "request-42"

    @patch.object(_mod, "_fetch_buildbot_json")
    def test_virtual_builder_name_without_hash(self, mock_fetch):
        mock_fetch.return_value = _make_buildrequests_response(
            [
                {
                    "results": 0,
                    "properties": {"virtual_builder_name": ["simple-name"]},
                }
            ]
        )
        name, _, _ = _check_one_build_request("bb.example.com", 1)
        assert name == "simple-name"

    @patch.object(_mod, "_fetch_buildbot_json")
    def test_api_failure_returns_none(self, mock_fetch):
        import urllib.error

        mock_fetch.side_effect = urllib.error.URLError("refused")
        assert _check_one_build_request("bb.example.com", 1) is None


# ---------------------------------------------------------------------------
# _get_active_step
# ---------------------------------------------------------------------------


class TestGetActiveStep:
    @patch.object(_mod, "_fetch_buildbot_json")
    def test_no_builds_returns_queued(self, mock_fetch):
        mock_fetch.return_value = _make_builds_response([])
        assert _get_active_step("bb.example.com", 1) == "queued"

    @patch.object(_mod, "_fetch_buildbot_json")
    def test_running_step_returns_state_string(self, mock_fetch):
        def api_dispatch(url):
            if "/buildrequests/" in url:
                return _make_builds_response([{"buildid": 10}])
            if "/builds/10/steps" in url:
                return _make_steps_response(
                    [
                        {"name": "checkout", "complete": True},
                        {
                            "name": "build",
                            "complete": False,
                            "state_string": "running",
                            "stepid": 99,
                        },
                    ]
                )
            if "/steps/99/logs" in url:
                return {"logs": []}
            return {}

        mock_fetch.side_effect = api_dispatch
        result = _get_active_step("bb.example.com", 1)
        # No log data, so falls back to the state_string
        assert result == "running"

    @patch.object(_mod, "_fetch_buildbot_json")
    def test_all_steps_complete_returns_none(self, mock_fetch):
        def api_dispatch(url):
            if "/buildrequests/" in url:
                return _make_builds_response([{"buildid": 10}])
            return _make_steps_response([{"name": "done", "complete": True}])

        mock_fetch.side_effect = api_dispatch
        assert _get_active_step("bb.example.com", 1) is None


# ---------------------------------------------------------------------------
# _get_step_log_tail
# ---------------------------------------------------------------------------


class TestGetStepLogTail:
    @patch.object(_mod, "_fetch_buildbot_json")
    def test_returns_parsed_nix_line(self, mock_fetch):
        def api_dispatch(url):
            if "/logs" in url and "contents" not in url:
                return {"logs": [{"logid": 1, "num_lines": 100}]}
            return {
                "logchunks": [{"content": "building '/nix/store/abc-hello.drv'...\n"}]
            }

        mock_fetch.side_effect = api_dispatch
        assert _get_step_log_tail("bb.example.com", 1) == "building hello"

    @patch.object(_mod, "_fetch_buildbot_json")
    def test_no_logs_returns_none(self, mock_fetch):
        mock_fetch.return_value = {"logs": []}
        assert _get_step_log_tail("bb.example.com", 1) is None

    @patch.object(_mod, "_fetch_buildbot_json")
    def test_zero_lines_returns_none(self, mock_fetch):
        mock_fetch.return_value = {"logs": [{"logid": 1, "num_lines": 0}]}
        assert _get_step_log_tail("bb.example.com", 1) is None

    @patch.object(_mod, "_fetch_buildbot_json")
    def test_api_error_returns_none(self, mock_fetch):
        import urllib.error

        mock_fetch.side_effect = urllib.error.URLError("timeout")
        assert _get_step_log_tail("bb.example.com", 1) is None


# ---------------------------------------------------------------------------
# run_buildbot_check_if_needed
# ---------------------------------------------------------------------------


class TestRunBuildbotCheckIfNeeded:
    def test_skips_if_already_done(self):
        result = run_buildbot_check_if_needed(
            {"url": "https://github.com/org/repo/pull/1"},
            failed=1,
            pending=0,
            buildbot_check_done=True,
        )
        assert result is True

    def test_skips_if_pending_remains(self):
        result = run_buildbot_check_if_needed(
            {"url": "https://github.com/org/repo/pull/1"},
            failed=1,
            pending=1,
            buildbot_check_done=False,
        )
        assert result is False

    def test_skips_if_no_failures(self):
        result = run_buildbot_check_if_needed(
            {"url": "https://github.com/org/repo/pull/1"},
            failed=0,
            pending=0,
            buildbot_check_done=False,
        )
        assert result is False

    @patch("shutil.which", return_value=None)
    def test_no_buildbot_pr_check_binary(self, mock_which):
        """If buildbot-pr-check is not in PATH, still returns True (marks done)."""
        result = run_buildbot_check_if_needed(
            {"url": "https://github.com/org/repo/pull/1"},
            failed=1,
            pending=0,
            buildbot_check_done=False,
        )
        # The function runs the check block (failed > 0, pending == 0, not done)
        # but shutil.which returns None so it doesn't actually run the command
        assert result is True
