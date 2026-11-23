"""Device-free deployment tests. These are NOT worker/KVM qualification."""

import copy
import errno
import hashlib
import importlib.util
import json
import os
import re
import subprocess
import tempfile
import threading
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import Request, urlopen

import pytest

SOURCE = (
    Path(__file__).resolve().parents[1] / "modules/kiln-implementer/qualification.py"
)
spec = importlib.util.spec_from_file_location("kiln_deployment_qualification", SOURCE)
qualification = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qualification)
GITHUB_SOURCE = (
    Path(__file__).resolve().parent / "kiln-implementation-github-fixture.py"
)
github_spec = importlib.util.spec_from_file_location(
    "kiln_scripted_github_fixture", GITHUB_SOURCE
)
github_fixture = importlib.util.module_from_spec(github_spec)
github_spec.loader.exec_module(github_fixture)


class PlacementTests(unittest.TestCase):
    def observation(self, host):
        return {
            "schema": "onix.lattice.placement-observation.v1",
            "host": host,
            "guest": "/nix/store/guest",
            "manifest_blake3": "a" * 64,
            "vmm": {"path": "/nix/store/actual-vmm", "blake3": "b" * 64},
            "vmm_actual_version": "cloud-hypervisor v54.0",
            "launch_blake3": "c" * 64,
            "closure": ["/nix/store/environment", "/nix/store/guest"],
            "closure_verified": True,
            "retention_observed": True,
            "kvm": "accessible-unqualified",
        }

    def test_matching_placements_are_only_preflight_not_dispatch_authority(self):
        result = qualification.compare_placements(
            self.observation("source"), self.observation("destination")
        )
        assert result["compatible"]
        assert not result["dispatch_allowed"]
        assert result["qualification"] == "unqualified"

    def test_each_cohort_dimension_is_independently_required(self):
        for field in (
            "guest",
            "manifest_blake3",
            "vmm",
            "vmm_actual_version",
            "launch_blake3",
            "closure",
        ):
            with self.subTest(field=field):
                target = self.observation("destination")
                target[field] = "different"
                with pytest.raises(ValueError, match="mismatch"):
                    qualification.compare_placements(self.observation("source"), target)

    def test_same_host_missing_kvm_or_unverified_closure_is_rejected(self):
        for target, refusal in (
            (self.observation("source"), "two distinct placement hosts are required"),
            (
                self.observation("destination") | {"kvm": "unsupported"},
                "KVM unavailable: unsupported, not qualified",
            ),
            (
                self.observation("destination") | {"closure_verified": False},
                "missing verified staging or retention observation",
            ),
            (
                self.observation("destination") | {"retention_observed": False},
                "missing verified staging or retention observation",
            ),
        ):
            with pytest.raises(ValueError, match=refusal):
                qualification.compare_placements(self.observation("source"), target)

    def test_document_bounds_and_retained_evidence_no_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "receipt.json"
            qualification.write_document(path, {"qualification": "unqualified"})
            with pytest.raises(FileExistsError):
                qualification.write_document(path, {"qualification": "qualified"})
            assert qualification.document(path)["qualification"] == "unqualified"
            path.write_bytes(b"x" * (qualification.MAX_DOCUMENT_BYTES + 1))
            with pytest.raises(ValueError, match="bound"):
                qualification.document(path)

    def test_non_store_manifest_entries_and_unsupported_schema_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            path.write_text(json.dumps({"schema": "other"}))
            with pytest.raises(ValueError, match="unsupported guest manifest"):
                qualification.verify_manifest(path)
            with pytest.raises(ValueError, match="immutable"):
                qualification.immutable(path)


class PolicyTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.documents = {
            "enrollment.json": {"repositories": ["owner/repo"], "actors": ["operator"]},
            "github-policy.json": {
                "repository": {"owner": "owner", "repository": "repo"},
                "terminal_policy": "verified_pull_request",
                "acceptance": ["case"],
                "permitted_paths": ["src/"],
                "base": {"id": "exact-base"},
                "budget": {"attempts": 2, "minutes_per_attempt": 30},
            },
            "work-class.json": {
                "class": "bug",
                "repository": "owner/repo",
                "policy_blake3": "d" * 64,
            },
        }
        self.documents["worker-transport-profile.json"] = {
            "schema": "kiln.lattice-implementation-cli.v2",
            "lattice_program": "/nix/store/lattice",
            "executable_blake3": "d" * 64,
            "state_directory": "/var/lib/pilot/lattice/implementation",
            "output_directory": "/var/lib/pilot/lattice/observations",
        }
        self.cohort = {
            "entries": {
                "lattice": {"resolved_path": "/nix/store/lattice", "blake3": "d" * 64}
            }
        }

    def tearDown(self):
        self.directory.cleanup()

    def validate(self, kiln_check=None):
        for name, value in self.documents.items():
            (self.root / name).write_text(json.dumps(value))
        # Substitute only immutable-store/digest observations and Kiln's own
        # policy-check process; run the actual deployment admission function.
        self.kiln_calls = []
        kiln_check = kiln_check or (
            lambda cohort, policy, enrollment: self.kiln_calls.append(
                (policy, enrollment)
            )
        )
        with (
            patch.object(qualification, "digest", return_value="d" * 64),
            patch.object(qualification, "immutable", side_effect=Path),
        ):
            return qualification.validate_policy(
                self.root,
                ["owner/repo"],
                ["bug"],
                "/var/lib/pilot",
                self.cohort,
                kiln_check=kiln_check,
            )

    def test_explicit_policy_is_admitted_but_not_qualified(self):
        assert self.validate() == {"policy": "admitted", "qualification": "unqualified"}

    def test_unenrolled_repo_wrong_class_or_policy_digest_is_denied(self):
        bound = "policy is not bound to an admitted work class/repository"
        for change, refusal in (
            ({"repository": "other/repo"}, bound),
            ({"class": "all"}, bound),
            (
                {"policy_blake3": "0" * 64},
                "work class does not bind the actual intake policy",
            ),
        ):
            with self.subTest(change=change):
                self.documents["work-class.json"] = {
                    "class": "bug",
                    "repository": "owner/repo",
                    "policy_blake3": "d" * 64,
                } | change
                with pytest.raises(ValueError, match=refusal):
                    self.validate()

    def test_wrong_transport_program_state_output_and_schema_are_denied(self):
        baseline = copy.deepcopy(self.documents["worker-transport-profile.json"])
        program = "worker transport must bind the actual immutable Lattice program"
        roots = "Lattice state/output must remain separate from the Kiln ledger"
        cases = [
            ({"schema": "legacy-exchange"}, "unsupported actual worker transport"),
            ({"lattice_program": "/nix/store/other-program"}, program),
            ({"executable_blake3": "0" * 64}, program),
            ({"state_directory": "/var/lib/pilot/kiln"}, roots),
            ({"output_directory": "/var/lib/pilot/verifier"}, roots),
        ]
        for change, refusal in cases:
            with self.subTest(change=change):
                self.documents["worker-transport-profile.json"] = baseline | change
                with pytest.raises(ValueError, match=refusal):
                    self.validate()

    def test_automatic_landing_and_excess_budget_are_denied(self):
        baseline = copy.deepcopy(self.documents["github-policy.json"])
        for change, refusal in (
            (
                {"terminal_policy": "automatic_landing"},
                "this deployment only admits verified-PR delivery",
            ),
            (
                {"budget": {"attempts": 9, "minutes_per_attempt": 30}},
                "implementation budget exceeds deployment limits",
            ),
        ):
            self.documents["github-policy.json"] = baseline | change
            with pytest.raises(ValueError, match=refusal):
                self.validate()

    def test_kiln_policy_check_is_authoritative(self):
        self.validate()
        assert self.kiln_calls == [
            (self.root / "github-policy.json", self.root / "enrollment.json")
        ]

        def refuse(cohort, policy, enrollment):
            msg = "Kiln refused the intake policy: base.contract_version missing"
            raise ValueError(msg)

        with pytest.raises(ValueError, match="Kiln refused"):
            self.validate(kiln_check=refuse)


class WorkspaceTests(unittest.TestCase):
    def test_two_attempts_share_source_not_mutable_state(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            source.mkdir()
            (source / "src").mkdir()
            (source / "src/code").write_text("baseline")
            (source / "src/code").chmod(0o444)
            first, second = root / "attempt-a", root / "attempt-b"
            qualification.stage_tree(source, first)
            qualification.stage_tree(source, second)
            (first / "src/code").write_text("candidate")
            assert (second / "src/code").read_text() == "baseline"
            assert (source / "src/code").read_text() == "baseline"
            assert (first / "src/code").stat().st_mode & 511 == 420
            with pytest.raises(ValueError, match="already exists"):
                qualification.stage_tree(source, first)
            assert (first / "src/code").read_text() == "candidate"

    def test_partial_or_hostile_source_is_retained_not_retried(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            source.mkdir()
            (source / "escape").symlink_to(root)
            target = root / "attempt"
            with pytest.raises(ValueError, match="source contains a symlink"):
                qualification.stage_tree(source, target)
            assert target.is_dir()
            with pytest.raises(ValueError, match="already exists"):
                qualification.stage_tree(source, target)

    def test_vcs_metadata_and_source_bounds_are_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            source.mkdir()
            (source / ".git").write_text("gitdir: host-state")
            with pytest.raises(ValueError, match="VCS"):
                qualification.stage_tree(source, root / "attempt-vcs")
            (source / ".git").unlink()
            (source / "large").write_bytes(b"xx")
            with (
                patch.object(qualification, "MAX_SOURCE_FILE_BYTES", 1),
                pytest.raises(ValueError, match="bound"),
            ):
                qualification.stage_tree(source, root / "attempt-large")

    def test_actual_request_grants_match_cohort_and_broker_route(self):
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            workspace = parent / "attempt-a"
            entries = {
                name: {"resolved_path": "/nix/store/" + name, "blake3": "e" * 64}
                for name in ("worker", "sandbox", "relay", "shell")
            }
            cohort = {"entries": entries, "revisions": {"worker": "revision"}}
            broker = {
                "schema": "lattice.candidate-model-broker.v1",
                "endpoint": "http://127.0.0.1:18080/v1/chat/completions",
                "model": "provider/model",
                "credential": None,
                "sandbox_blake3": "e" * 64,
                "relay": {"path": "/nix/store/relay", "blake3": "e" * 64},
                "shell": {"path": "/nix/store/shell", "blake3": "e" * 64},
            }
            local = {"kind": "host_local"}
            request = {
                "schema": "lattice.implementation-attempt-run.v3",
                "envelope": {"workspace_id": "attempt-a"},
                "workspace_root": str(workspace),
                "network": False,
                "output_limit_bytes": 1024,
                "program": "/nix/store/worker",
                "sandbox_program": "/nix/store/sandbox",
                "omp": {
                    "revision": "revision",
                    "executable_blake3": "e" * 64,
                    "model": "lattice/provider/model",
                    "model_broker": broker,
                },
                "worker_compute": local,
                "execution_binding": {
                    "schema": "lattice.execution-binding.v1",
                    "compute": local,
                },
                "read_paths": ["src", ".cairn"],
                "write_paths": ["src"],
            }
            keyed = request | {
                "omp": request["omp"]
                | {
                    "model_broker": broker
                    | {
                        "credential": {
                            "provider": "env",
                            "key": "KILN_IMPLEMENTATION_MODEL_KEY",
                        }
                    }
                }
            }
            with (
                patch.object(qualification, "immutable", side_effect=Path),
                patch.object(qualification, "digest", return_value="e" * 64),
            ):
                assert (
                    qualification.validate_attempt(request, cohort, parent) == workspace
                )
                assert (
                    qualification.validate_attempt(
                        keyed, cohort, parent, "KILN_IMPLEMENTATION_MODEL_KEY"
                    )
                    == workspace
                )
                with pytest.raises(ValueError, match="credential"):
                    qualification.validate_attempt(keyed, cohort, parent)
                with pytest.raises(ValueError, match="credential"):
                    qualification.validate_attempt(
                        request, cohort, parent, "KILN_IMPLEMENTATION_MODEL_KEY"
                    )
                # Lattice's canonical SecretRef serializes the unset field as null.
                key = {"provider": "env", "key": "KILN_IMPLEMENTATION_MODEL_KEY"}
                with_broker = lambda credential: (
                    request
                    | {
                        "omp": request["omp"]
                        | {"model_broker": broker | {"credential": credential}}
                    }
                )
                assert (
                    qualification.validate_attempt(
                        with_broker(key | {"field": None}),
                        cohort,
                        parent,
                        "KILN_IMPLEMENTATION_MODEL_KEY",
                    )
                    == workspace
                )
                for credential in (
                    key | {"field": "token"},
                    key | {"extra": None},
                    key | {"provider": "file"},
                    key | {"key": "OTHER"},
                    {"provider": "env"},
                    key | {"field": 1},
                ):
                    with (
                        self.subTest(credential=credential),
                        pytest.raises(ValueError, match="credential"),
                    ):
                        qualification.validate_attempt(
                            with_broker(credential),
                            cohort,
                            parent,
                            "KILN_IMPLEMENTATION_MODEL_KEY",
                        )
                relative = "workspace grants must use native canonical relative paths"
                for change, refusal in (
                    ({"network": True}, "the worker must have no network grant"),
                    (
                        {"network_namespace": "/run/netns/model"},
                        "the worker must have no network grant",
                    ),
                    (
                        {"schema": "lattice.implementation-attempt-run.v1"},
                        "unsupported actual Lattice implementation request schema",
                    ),
                    (
                        {"worker_compute": {"kind": "remote"}},
                        "this deployment admits only host-local worker compute",
                    ),
                    (
                        {"workspace_root": str(parent / "other")},
                        "request must bind its independent exact workspace directory",
                    ),
                    (
                        {"omp": request["omp"] | {"model": "lattice/other"}},
                        "OMP must select exactly the broker's single wire model",
                    ),
                    (
                        {
                            "omp": request["omp"]
                            | {
                                "model_broker": broker
                                | {
                                    "endpoint": "http://10.0.2.2:8080/v1/chat/completions"
                                }
                            }
                        },
                        "model endpoint must be HTTPS or the dispatcher namespace",
                    ),
                    (
                        {
                            "omp": request["omp"]
                            | {"model_broker": broker | {"sandbox_blake3": "f" * 64}}
                        },
                        "model broker sandbox identity does not match",
                    ),
                    ({"write_paths": ["."]}, relative),
                    ({"write_paths": ["../escape"]}, relative),
                    (
                        {"write_paths": [".omp"]},
                        "worker cannot mutate VCS or harness/model configuration",
                    ),
                    ({"read_paths": ["/run/secrets"]}, relative),
                    (
                        {"program": "/nix/store/other-worker"},
                        "worker/provider executable does not match",
                    ),
                    (
                        {"output_limit_bytes": 0},
                        "worker output limit exceeds the deployment bound",
                    ),
                ):
                    with (
                        self.subTest(change=change),
                        pytest.raises(ValueError, match=refusal),
                    ):
                        qualification.validate_attempt(request | change, cohort, parent)

    def test_verifier_authority_matches_actual_worker_and_private_roots(self):
        cohort = {
            "entries": {"git": {"resolved_path": "/nix/store/git", "blake3": "f" * 64}}
        }
        authority = {
            "worker_uid": 931,
            "repository_root": "/var/lib/pilot/verifier/repository",
            "scratch_root": "/var/lib/pilot/verifier/scratch",
            "git": {"path": "/nix/store/git", "blake3": "f" * 64},
        }
        with patch.object(qualification, "immutable", side_effect=Path):
            assert (
                qualification.validate_verifier_authority(
                    authority, "/var/lib/pilot", 931, cohort
                )["authority"]
                == "deployment-bound"
            )
            roots = "trusted verification roots must remain separate"
            for change, refusal in (
                (
                    {"worker_uid": 0},
                    "verification authority must bind the actual editing worker UID",
                ),
                ({"repository_root": "/var/lib/pilot/workspaces/attempt"}, roots),
                ({"scratch_root": "/var/lib/pilot/kiln"}, roots),
                (
                    {"git": {"path": "/nix/store/wrong", "blake3": "f" * 64}},
                    "verification Git program must match",
                ),
            ):
                with pytest.raises(ValueError, match=refusal):
                    qualification.validate_verifier_authority(
                        authority | change, "/var/lib/pilot", 931, cohort
                    )


class CandidateExportTests(unittest.TestCase):
    def fixture(self, directory):
        root = Path(directory)
        workspace = root / "workspace"
        workspace.mkdir()
        (workspace / "code").write_text("candidate")
        # A file the worker made executable, in a subdirectory.
        (workspace / "bin").mkdir()
        (workspace / "bin/run").write_text("#!/bin/sh\n")
        (workspace / "bin/run").chmod(0o700)
        output = root / "exports"
        output.mkdir()
        envelope = {
            "work_id": "work",
            "attempt_id": "attempt",
            "workspace_id": "workspace",
            "fence": 3,
        }
        request = {"envelope": envelope}
        cohort = {
            "entries": {
                "lattice": {"resolved_path": "/nix/store/lattice", "blake3": "a" * 64}
            }
        }
        receipt = {
            "schema": "lattice.candidate-receipt.v1",
            "work_id": "work",
            "attempt_id": "attempt",
            "workspace_id": "workspace",
            "fence": "3",
            "disposition": "produced",
            "blockers": [],
            "base_identity": "b" * 64,
            "candidate_identity": "c" * 64,
            "diff_identity": "d" * 64,
            "changed_paths": ["code"],
        }
        observation = {
            "schema": "lattice.implementation-attempt-observation.v1",
            "envelope": envelope,
            "result": {"disposition": "produced", "receipt": receipt, "blocker": None},
        }
        args = SimpleNamespace(state=str(root / "state"), output_parent=str(output))
        binding = {"path": str(root), "attempt": "attempt", "fence": 3}
        sent = (root / "request-sent.json", {"state_directory": args.state})
        return args, (root, binding, cohort, request, workspace), observation, sent

    def test_produced_native_result_exports_bytes_not_acceptance(self):
        with tempfile.TemporaryDirectory() as directory:
            args, inputs, observation, sent = self.fixture(directory)
            # Scripted durable native observation only; not worker execution or
            # proof of cross-UID permissions. Actual capture rehashes this tree.
            with (
                patch.object(qualification, "attempt_inputs", return_value=inputs),
                patch.object(qualification, "immutable", side_effect=Path),
                patch.object(qualification, "digest", return_value="a" * 64),
                patch.object(qualification, "_sent_request", return_value=sent),
                patch.object(
                    qualification.subprocess,
                    "check_output",
                    return_value=json.dumps(observation).encode(),
                ) as lattice,
            ):
                result = qualification.export_candidate(args)
                # Lattice recovers from the request it ran, not the admitted one.
                assert lattice.call_args.args[0][2:] == [
                    "recover",
                    "--request",
                    str(sent[0]),
                    "--state",
                    args.state,
                ]
                assert not result["accepted"]
                assert result["qualification"] == "unqualified"
                candidate = Path(result["candidate_root"])
                assert (candidate / "code").read_text() == "candidate"
                # Directories stay 0750 in the capture group; files carry
                # exactly Git's modes, which Kiln's byte receipt admits.
                assert candidate.stat().st_mode & 511 == 488
                assert (candidate / "bin").stat().st_mode & 511 == 488
                assert (candidate / "code").stat().st_mode & 511 == 420
                assert (candidate / "bin/run").stat().st_mode & 511 == 493
                assert (
                    qualification.document(result["host_receipt"])
                    == observation["result"]["receipt"]
                )
                with pytest.raises(FileExistsError):
                    qualification.export_candidate(args)

    def test_unknown_crossed_or_forged_receipts_never_export(self):
        with tempfile.TemporaryDirectory() as directory:
            args, inputs, baseline, sent = self.fixture(directory)
            substituted = "native recovery substituted the installed attempt envelope"
            cases = []
            unknown = copy.deepcopy(baseline)
            unknown["result"]["disposition"] = "unknown"
            cases.append(
                (unknown, "only a complete native produced candidate can be exported")
            )
            stale = copy.deepcopy(baseline)
            stale["result"]["receipt"]["fence"] = "2"
            cases.append((stale, "native candidate receipt crosses work"))
            forged = copy.deepcopy(baseline)
            forged["schema"] = "worker-success-message"
            cases.append((forged, substituted))
            crossed = copy.deepcopy(baseline)
            crossed["envelope"]["attempt_id"] = "other-attempt"
            cases.append((crossed, substituted))
            for observation, refusal in cases:
                with (
                    patch.object(qualification, "attempt_inputs", return_value=inputs),
                    patch.object(qualification, "immutable", side_effect=Path),
                    patch.object(qualification, "digest", return_value="a" * 64),
                    patch.object(qualification, "_sent_request", return_value=sent),
                    patch.object(
                        qualification.subprocess,
                        "check_output",
                        return_value=json.dumps(observation).encode(),
                    ),
                    pytest.raises(ValueError, match=refusal),
                ):
                    qualification.export_candidate(args)
            assert list(Path(args.output_parent).iterdir()) == []


class SentRequestTests(unittest.TestCase):
    """The request Lattice ran, as Kiln's read-only `--sent-request` mode resolves it."""

    def fixture(self, directory):
        root = Path(directory)
        output = root / "lattice/observations"
        output.mkdir(parents=True)
        operation = root / "binding"
        operation.mkdir()
        (operation / "attempt.json").write_text("{}")
        sent = output / ("request-" + "e" * 64 + ".json")
        sent.write_text("{}")
        configuration = root / "configuration"
        configuration.mkdir()
        transport = {
            "output_directory": str(output),
            "state_directory": str(root / "lattice/implementation"),
        }
        (configuration / "worker-transport-profile.json").write_text(
            json.dumps(transport)
        )
        (configuration / "enrollment.json").write_text("{}")
        args = SimpleNamespace(
            configuration=str(configuration),
            state_root=str(root),
            state=transport["state_directory"],
        )
        cohort = {
            "entries": {
                "dispatch": {"resolved_path": "/nix/store/dispatch", "blake3": "e" * 64}
            }
        }
        resolution = {
            "schema": "kiln.lattice-sent-request.v1",
            "attempt": "a" * 64,
            "fence": 1,
            "recorded": True,
            "request": str(sent),
            "request_blake3": "e" * 64,
            "state_directory": transport["state_directory"],
        }
        return args, cohort, operation, {"attempt": "a" * 64, "fence": 1}, resolution

    def resolve(self, args, cohort, operation, claim, resolution, admitted="e" * 64):
        digests = lambda path: (
            admitted if Path(path).name == "attempt.json" else "e" * 64
        )
        with (
            patch.object(qualification, "immutable", side_effect=Path),
            patch.object(qualification, "digest", side_effect=digests),
            patch.object(
                qualification.subprocess,
                "check_output",
                return_value=json.dumps(resolution).encode(),
            ) as kiln,
        ):
            request, _ = qualification._sent_request(args, cohort, operation, claim)
        return request, kiln.call_args.args[0]

    def test_recorded_lineage_request_is_the_profile_frozen_file(self):
        with tempfile.TemporaryDirectory() as directory:
            args, cohort, operation, claim, resolution = self.fixture(directory)
            request, argv = self.resolve(
                args, cohort, operation, claim, resolution, admitted="f" * 64
            )
            assert request == Path(resolution["request"])
            assert argv[-2:] == ["--sent-request", "true"]
            assert argv[argv.index("--worker-request") + 1] == str(
                operation / "attempt.json"
            )
            # A legacy launch sent the admitted bytes, and only those.
            legacy = resolution | {"recorded": False}
            assert self.resolve(args, cohort, operation, claim, legacy)[0] == Path(
                resolution["request"]
            )
            with pytest.raises(ValueError, match="admitted bytes"):
                self.resolve(args, cohort, operation, claim, legacy, admitted="f" * 64)

    def test_crossed_misplaced_or_untyped_resolutions_are_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            args, cohort, operation, claim, resolution = self.fixture(directory)
            root = Path(directory)
            (root / ("request-" + "e" * 64 + ".json")).write_text("{}")
            claim_refusal = "sent request belongs to another canonical claim"
            typed = "dispatcher did not return a typed sent-request resolution"
            frozen = "sent request is not the profile's frozen request file"
            for change, refusal in (
                ({"attempt": "b" * 64}, claim_refusal),
                ({"fence": 2}, claim_refusal),
                ({"fence": "1"}, claim_refusal),
                ({"recorded": "true"}, claim_refusal),
                ({"schema": "kiln.lattice-sent-request.v0"}, typed),
                ({"extra": None}, typed),
                ({"request": str(root / ("request-" + "e" * 64 + ".json"))}, frozen),
                ({"request_blake3": "f" * 64}, frozen),
                (
                    {"state_directory": str(root / "other")},
                    "sent request names another Lattice state root",
                ),
            ):
                with (
                    self.subTest(change=change),
                    pytest.raises(ValueError, match=refusal),
                ):
                    self.resolve(args, cohort, operation, claim, resolution | change)
            with pytest.raises(
                ValueError, match="worker transport output/state roots differ"
            ):
                self.resolve(
                    SimpleNamespace(**vars(args) | {"state": str(root / "other")}),
                    cohort,
                    operation,
                    claim,
                    resolution,
                )
            sent = Path(resolution["request"])
            sent.unlink()
            sent.symlink_to(operation / "attempt.json")
            with pytest.raises(ValueError, match="ordinary file"):
                self.resolve(args, cohort, operation, claim, resolution)


class RuntimeBindingTests(unittest.TestCase):
    """Device-free protection/codec tests, not native worker qualification."""

    def test_regular_binding_rejects_symlinks_and_writable_entries(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "entry.json"
            target.write_text('{"bound": true}')
            with pytest.raises(ValueError, match="owner-writable"):
                qualification._regular_owned(target, os.getuid())
            target.chmod(0o444)
            assert json.loads(qualification._regular_owned(target, os.getuid())) == {
                "bound": True
            }
            link = root / "linked.json"
            link.symlink_to(target)
            with pytest.raises(OSError, match=re.escape(str(link))) as refused:
                qualification._regular_owned(link, os.getuid())
            assert refused.value.errno == errno.ELOOP
            target.chmod(0o666)
            with pytest.raises(ValueError, match="permissions"):
                qualification._regular_owned(target, os.getuid())

    def test_runtime_selectors_retain_types_and_reject_unknown_authority(self):
        seed = {
            "fence": {"runtime": "fence"},
            "lease": {"runtime": "lease_until_ms"},
            "static": "literal",
        }
        assert qualification._expand_runtime(
            seed, {"fence": 9, "lease_until_ms": 123}
        ) == {"fence": 9, "lease": 123, "static": "literal"}
        with pytest.raises(ValueError, match="unsupported runtime"):
            qualification._expand_runtime({"runtime": "invented_capacity"}, {})

    def test_dispatch_binding_does_not_require_future_publication(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            attempt, work = "a" * 64, "b" * 64
            stage = root / "bindings" / (attempt + "-3") / "dispatch"
            stage.mkdir(parents=True)
            claim = {
                "identity": attempt,
                "fence": 3,
                "work_identity": work,
                "work_revision": 7,
            }
            request = {
                "envelope": {
                    "attempt_id": attempt,
                    "fence": 3,
                    "work_id": work,
                    "work_version": 7,
                    "workspace_id": attempt,
                }
            }
            plan = {
                "attempt_identity": attempt,
                "fence": 3,
                "work_identity": work,
                "work_revision": 7,
                "workspace": {"identity": attempt},
            }
            values = {name: {} for name in qualification.STAGE_ENTRIES["dispatch"]}
            values.update({"attempt.json": request, "dispatch-plan.json": plan})
            hash_file = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
            for name, value in values.items():
                qualification._seal(stage / name, value)
            entries = {name: hash_file(stage / name) for name in values}
            manifest = {
                "schema": "onix.kiln.runtime-binding.v1",
                "stage": "dispatch",
                "attempt": attempt,
                "fence": 3,
                "work": work,
                "work_revision": 7,
                "cohort_manifest_blake3": "c" * 64,
                "template_blake3": "c" * 64,
                "request_blake3": entries["attempt.json"],
                "entries": entries,
            }
            qualification._seal(stage / "manifest.json", manifest)
            real_directory, real_owned = (
                qualification._protected_directory,
                qualification._owned_document,
            )
            args = SimpleNamespace(stage="dispatch", cohort="/nix/store/cohort")
            with (
                patch.object(
                    qualification,
                    "_binding_context",
                    return_value=(
                        Path("/nix/store/template"),
                        {},
                        {"attempt": claim},
                        {},
                    ),
                ),
                patch.object(qualification, "_controller", return_value=root),
                patch.object(
                    qualification,
                    "_protected_directory",
                    side_effect=lambda path: real_directory(path, os.getuid()),
                ),
                patch.object(
                    qualification,
                    "_owned_document",
                    side_effect=lambda path: real_owned(path, os.getuid()),
                ),
                patch.object(
                    qualification, "_regular_owned", wraps=qualification._regular_owned
                ) as regular,
                patch.object(
                    qualification,
                    "digest",
                    side_effect=lambda path: (
                        hash_file(path) if Path(path).parent == stage else "c" * 64
                    ),
                ),
            ):
                # Only the test process UID is substituted; production fixes root.
                original = regular._mock_wraps
                regular.side_effect = lambda path, owner: original(path, os.getuid())
                assert qualification.runtime_binding(args)["path"] == str(stage)
                assert not (stage / "publication.json").exists()
                (stage / "attempt.json").chmod(0o644)
                with pytest.raises(ValueError, match="owner-writable"):
                    qualification.runtime_binding(args)


class GithubObjectFixtureTests(unittest.TestCase):
    def test_actual_objects_target_guard_and_retained_single_pr(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            work, bare = root / "work", root / "remote.git"
            environment = os.environ | {
                "GIT_CONFIG_NOSYSTEM": "1",
                "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_AUTHOR_NAME": "fixture",
                "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
                "GIT_COMMITTER_NAME": "fixture",
                "GIT_COMMITTER_EMAIL": "fixture@example.invalid",
            }

            def git(*arguments):
                return subprocess.check_output(
                    ["git", *map(str, arguments)],
                    env=environment,
                    stderr=subprocess.PIPE,
                    text=True,
                ).strip()

            git("init", "--initial-branch=main", work)
            (work / "file").write_text("baseline")
            git("-C", work, "add", ".")
            git("-C", work, "commit", "-m", "baseline")
            base = git("-C", work, "rev-parse", "HEAD")
            git("clone", "--bare", "--no-hardlinks", work, bare)
            (work / "file").write_text("candidate")
            git("-C", work, "commit", "-am", "candidate")
            candidate = git("-C", work, "rev-parse", "HEAD")
            plan = {
                "repository": "qualification/disposable",
                "branch": "kiln/impl-fixture",
                "base_branch": "main",
                "base": base,
                "candidate": candidate,
            }
            state = root / "state"
            fixture = github_fixture.Fixture(plan, state, False, bare)
            assert fixture.branch_sha is None
            server = github_fixture.ThreadingHTTPServer(
                ("127.0.0.1", 0), fixture.handler()
            )
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()

            def post(suffix, value):
                request = Request(
                    f"http://127.0.0.1:{server.server_port}/repos/qualification/disposable/{suffix}",
                    data=json.dumps(value).encode(),
                    method="POST",
                    headers={
                        "Authorization": "Bearer scripted-publisher-only",
                        "Content-Type": "application/json",
                    },
                )
                with urlopen(request, timeout=5) as response:
                    return json.load(response)

            try:
                with pytest.raises(HTTPError) as refused:
                    post(
                        "git/refs",
                        {"ref": "refs/heads/" + plan["branch"], "sha": candidate},
                    )
                assert refused.value.code == 405
                with pytest.raises(HTTPError) as missing:
                    post("pulls", {"head": plan["branch"], "base": "main"})
                assert missing.value.code == 422
                git(
                    "-C",
                    work,
                    "push",
                    str(bare),
                    candidate + ":refs/heads/" + plan["branch"],
                )
                fixture.refresh_branch()
                assert fixture.branch_sha == candidate
                assert (
                    post("pulls", {"head": plan["branch"], "base": "main"})["number"]
                    == 1
                )
                with pytest.raises(HTTPError) as duplicate:
                    post("pulls", {"head": plan["branch"], "base": "main"})
                assert duplicate.value.code == 422
            finally:
                server.shutdown()
                server.server_close()
                thread.join(timeout=5)
            reopened = github_fixture.Fixture(plan, state, False, bare)
            assert reopened.pull["number"] == 1
            assert reopened.branch_sha == candidate
            git("-C", bare, "update-ref", "refs/heads/main", candidate, base)
            with pytest.raises(ValueError, match="target moved"):
                reopened.refresh_branch()


class MutableDiskTests(unittest.TestCase):
    def test_new_disk_files_have_separate_observed_ids_and_never_replace(self):
        with tempfile.TemporaryDirectory() as directory:
            args = SimpleNamespace(
                directory=str(Path(directory) / "attempt"),
                reference="attempt-a",
                generation=1,
                workspace_mib=qualification.MIN_DISK_MIB,
                state_mib=qualification.MIN_DISK_MIB,
            )
            # Only formatting/UUID observation is substituted. These are sparse
            # local file-boundary fixtures, explicitly not filesystem/KVM proof.
            ids = [
                "11111111-1111-1111-1111-111111111111\n",
                "22222222-2222-2222-2222-222222222222\n",
            ]
            with (
                patch.object(qualification.subprocess, "run") as format_disk,
                patch.object(qualification.subprocess, "check_output", side_effect=ids),
            ):
                result = qualification.prepare_disks(args)
                assert format_disk.call_count == 2
                assert not result["placement_authority"]
                assert result["qualification"] == "unqualified"
                assert (
                    result["disks"]["workspace"]["filesystem_uuid"]
                    != result["disks"]["state"]["filesystem_uuid"]
                )
                for disk in result["disks"].values():
                    assert (
                        Path(disk["path"]).stat().st_size
                        == qualification.MIN_DISK_MIB * qualification.MIB_BYTES
                    )
                    assert Path(disk["path"]).stat().st_mode & 511 == 384
                with pytest.raises(FileExistsError):
                    qualification.prepare_disks(args)

    def test_size_generation_and_reused_filesystem_ids_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            baseline = {
                "directory": str(Path(directory) / "attempt"),
                "reference": "attempt",
                "generation": 1,
                "workspace_mib": qualification.MIN_DISK_MIB,
                "state_mib": qualification.MIN_DISK_MIB,
            }
            identity = "mutable disks require an exact execution reference"
            bound = "mutable disk size exceeds the declared bound"
            for change, refusal in (
                ({"generation": 0}, identity),
                ({"reference": "../escape"}, identity),
                ({"workspace_mib": 0}, bound),
                ({"state_mib": qualification.MAX_DISK_MIB + 1}, bound),
            ):
                with pytest.raises(ValueError, match=refusal):
                    qualification.prepare_disks(SimpleNamespace(**(baseline | change)))
            duplicate = "11111111-1111-1111-1111-111111111111\n"
            with (
                patch.object(qualification.subprocess, "run"),
                patch.object(
                    qualification.subprocess, "check_output", return_value=duplicate
                ),
                pytest.raises(ValueError, match="independent"),
            ):
                qualification.prepare_disks(SimpleNamespace(**baseline))
            assert (Path(baseline["directory"]) / "workspace.raw").exists()
            assert not (Path(baseline["directory"]) / "disks.json").exists()


if __name__ == "__main__":
    unittest.main()
