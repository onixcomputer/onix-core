"""Device-free deployment tests. These are NOT worker/KVM qualification."""
import copy
import importlib.util
import json
import hashlib
import os
from pathlib import Path
import tempfile
import subprocess
import threading
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from types import SimpleNamespace
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / "modules/kiln-implementer/qualification.py"
spec = importlib.util.spec_from_file_location("kiln_deployment_qualification", SOURCE)
qualification = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qualification)
GITHUB_SOURCE = Path(__file__).resolve().parent / "kiln-implementation-github-fixture.py"
github_spec = importlib.util.spec_from_file_location("kiln_scripted_github_fixture", GITHUB_SOURCE)
github_fixture = importlib.util.module_from_spec(github_spec)
github_spec.loader.exec_module(github_fixture)


class PlacementTests(unittest.TestCase):
    def observation(self, host):
        return {"schema": "onix.lattice.placement-observation.v1", "host": host,
                "guest": "/nix/store/guest", "manifest_blake3": "a" * 64,
                "vmm": {"path": "/nix/store/actual-vmm", "blake3": "b" * 64},
                "vmm_actual_version": "cloud-hypervisor v54.0", "launch_blake3": "c" * 64,
                "closure": ["/nix/store/environment", "/nix/store/guest"],
                "closure_verified": True, "retention_observed": True, "kvm": "accessible-unqualified"}

    def test_matching_placements_are_only_preflight_not_dispatch_authority(self):
        result = qualification.compare_placements(self.observation("source"), self.observation("destination"))
        self.assertTrue(result["compatible"])
        self.assertFalse(result["dispatch_allowed"])
        self.assertEqual(result["qualification"], "unqualified")

    def test_each_cohort_dimension_is_independently_required(self):
        for field in ("guest", "manifest_blake3", "vmm", "vmm_actual_version", "launch_blake3", "closure"):
            with self.subTest(field=field):
                target = self.observation("destination")
                target[field] = "different"
                with self.assertRaisesRegex(ValueError, "mismatch"):
                    qualification.compare_placements(self.observation("source"), target)

    def test_same_host_missing_kvm_or_unverified_closure_is_rejected(self):
        for target in (self.observation("source"), self.observation("destination") | {"kvm": "unsupported"},
                       self.observation("destination") | {"closure_verified": False},
                       self.observation("destination") | {"retention_observed": False}):
            with self.assertRaises(ValueError):
                qualification.compare_placements(self.observation("source"), target)

    def test_document_bounds_and_retained_evidence_no_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "receipt.json"
            qualification.write_document(path, {"qualification": "unqualified"})
            with self.assertRaises(FileExistsError):
                qualification.write_document(path, {"qualification": "qualified"})
            self.assertEqual(qualification.document(path)["qualification"], "unqualified")
            path.write_bytes(b"x" * (qualification.MAX_DOCUMENT_BYTES + 1))
            with self.assertRaisesRegex(ValueError, "bound"):
                qualification.document(path)

    def test_non_store_manifest_entries_and_unsupported_schema_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            path.write_text(json.dumps({"schema": "other"}))
            with self.assertRaisesRegex(ValueError, "schema|manifest"):
                qualification.verify_manifest(path)
            with self.assertRaisesRegex(ValueError, "immutable"):
                qualification.immutable(path)


class PolicyTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.documents = {
            "enrollment.json": {"repositories": ["owner/repo"], "actors": ["operator"]},
            "github-policy.json": {"repository": {"owner": "owner", "repository": "repo"},
                "terminal_policy": "verified_pull_request", "acceptance": ["case"], "permitted_paths": ["src/"],
                "base": {"id": "exact-base"}, "budget": {"attempts": 2, "minutes_per_attempt": 30}},
            "work-class.json": {"class": "bug", "repository": "owner/repo", "policy_blake3": "d" * 64},
        }
        self.documents["worker-transport-profile.json"] = {
            "schema": "kiln.lattice-implementation-cli.v2", "lattice_program": "/nix/store/lattice",
            "executable_blake3": "d" * 64, "state_directory": "/var/lib/pilot/lattice/implementation",
            "output_directory": "/var/lib/pilot/lattice/observations"}
        self.cohort = {"entries": {"lattice": {"resolved_path": "/nix/store/lattice", "blake3": "d" * 64}}}

    def tearDown(self):
        self.directory.cleanup()

    def validate(self, kiln_check=None):
        for name, value in self.documents.items():
            (self.root / name).write_text(json.dumps(value))
        # Substitute only immutable-store/digest observations and Kiln's own
        # policy-check process; run the actual deployment admission function.
        self.kiln_calls = []
        kiln_check = kiln_check or (lambda cohort, policy, enrollment: self.kiln_calls.append((policy, enrollment)))
        with patch.object(qualification, "digest", return_value="d" * 64), patch.object(qualification, "immutable", side_effect=Path):
            return qualification.validate_policy(self.root, ["owner/repo"], ["bug"], "/var/lib/pilot", self.cohort, kiln_check=kiln_check)

    def test_explicit_policy_is_admitted_but_not_qualified(self):
        self.assertEqual(self.validate(), {"policy": "admitted", "qualification": "unqualified"})

    def test_unenrolled_repo_wrong_class_or_policy_digest_is_denied(self):
        for change in ({"repository": "other/repo"}, {"class": "all"}, {"policy_blake3": "0" * 64}):
            with self.subTest(change=change):
                self.documents["work-class.json"] = {"class": "bug", "repository": "owner/repo", "policy_blake3": "d" * 64} | change
                with self.assertRaises(ValueError):
                    self.validate()

    def test_wrong_transport_program_state_output_and_schema_are_denied(self):
        baseline = copy.deepcopy(self.documents["worker-transport-profile.json"])
        cases = [{"schema": "legacy-exchange"}, {"lattice_program": "/nix/store/other-program"},
                 {"executable_blake3": "0" * 64}, {"state_directory": "/var/lib/pilot/kiln"},
                 {"output_directory": "/var/lib/pilot/verifier"}]
        for change in cases:
            with self.subTest(change=change):
                self.documents["worker-transport-profile.json"] = baseline | change
                with self.assertRaises(ValueError):
                    self.validate()

    def test_automatic_landing_and_excess_budget_are_denied(self):
        baseline = copy.deepcopy(self.documents["github-policy.json"])
        for change in ({"terminal_policy": "automatic_landing"}, {"budget": {"attempts": 9, "minutes_per_attempt": 30}}):
            self.documents["github-policy.json"] = baseline | change
            with self.assertRaises(ValueError):
                self.validate()

    def test_kiln_policy_check_is_authoritative(self):
        self.validate()
        self.assertEqual(self.kiln_calls, [(self.root / "github-policy.json", self.root / "enrollment.json")])

        def refuse(cohort, policy, enrollment):
            raise ValueError("Kiln refused the intake policy: base.contract_version missing")
        with self.assertRaisesRegex(ValueError, "Kiln refused"):
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
            self.assertEqual((second / "src/code").read_text(), "baseline")
            self.assertEqual((source / "src/code").read_text(), "baseline")
            self.assertEqual((first / "src/code").stat().st_mode & 0o777, 0o644)
            with self.assertRaisesRegex(ValueError, "already exists"):
                qualification.stage_tree(source, first)
            self.assertEqual((first / "src/code").read_text(), "candidate")

    def test_partial_or_hostile_source_is_retained_not_retried(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            source.mkdir()
            (source / "escape").symlink_to(root)
            target = root / "attempt"
            with self.assertRaises(ValueError):
                qualification.stage_tree(source, target)
            self.assertTrue(target.is_dir())
            with self.assertRaisesRegex(ValueError, "already exists"):
                qualification.stage_tree(source, target)

    def test_vcs_metadata_and_source_bounds_are_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            source.mkdir()
            (source / ".git").write_text("gitdir: host-state")
            with self.assertRaisesRegex(ValueError, "VCS"):
                qualification.stage_tree(source, root / "attempt-vcs")
            (source / ".git").unlink()
            (source / "large").write_bytes(b"xx")
            with patch.object(qualification, "MAX_SOURCE_FILE_BYTES", 1):
                with self.assertRaisesRegex(ValueError, "bound"):
                    qualification.stage_tree(source, root / "attempt-large")

    def test_actual_request_grants_match_cohort_and_broker_route(self):
        with tempfile.TemporaryDirectory() as directory:
            parent = Path(directory)
            workspace = parent / "attempt-a"
            entries = {name: {"resolved_path": "/nix/store/" + name, "blake3": "e" * 64}
                       for name in ("worker", "sandbox", "relay", "shell")}
            cohort = {"entries": entries, "revisions": {"worker": "revision"}}
            broker = {"schema": "lattice.candidate-model-broker.v1", "endpoint": "http://127.0.0.1:18080/v1/chat/completions",
                      "model": "provider/model", "credential": None, "sandbox_blake3": "e" * 64,
                      "relay": {"path": "/nix/store/relay", "blake3": "e" * 64},
                      "shell": {"path": "/nix/store/shell", "blake3": "e" * 64}}
            local = {"kind": "host_local"}
            request = {"schema": "lattice.implementation-attempt-run.v3", "envelope": {"workspace_id": "attempt-a"},
                       "workspace_root": str(workspace), "network": False, "output_limit_bytes": 1024,
                       "program": "/nix/store/worker", "sandbox_program": "/nix/store/sandbox",
                       "omp": {"revision": "revision", "executable_blake3": "e" * 64, "model": "lattice/provider/model",
                               "model_broker": broker},
                       "worker_compute": local, "execution_binding": {"schema": "lattice.execution-binding.v1", "compute": local},
                       "read_paths": ["src", ".cairn"], "write_paths": ["src"]}
            keyed = request | {"omp": request["omp"] | {"model_broker": broker | {
                "credential": {"provider": "env", "key": "KILN_IMPLEMENTATION_MODEL_KEY"}}}}
            with patch.object(qualification, "immutable", side_effect=Path), patch.object(qualification, "digest", return_value="e" * 64):
                self.assertEqual(qualification.validate_attempt(request, cohort, parent), workspace)
                self.assertEqual(qualification.validate_attempt(keyed, cohort, parent, "KILN_IMPLEMENTATION_MODEL_KEY"), workspace)
                with self.assertRaisesRegex(ValueError, "credential"):
                    qualification.validate_attempt(keyed, cohort, parent)
                with self.assertRaisesRegex(ValueError, "credential"):
                    qualification.validate_attempt(request, cohort, parent, "KILN_IMPLEMENTATION_MODEL_KEY")
                # Lattice's canonical SecretRef serializes the unset field as null.
                key = {"provider": "env", "key": "KILN_IMPLEMENTATION_MODEL_KEY"}
                with_broker = lambda credential: request | {"omp": request["omp"] | {"model_broker": broker | {"credential": credential}}}
                self.assertEqual(qualification.validate_attempt(with_broker(key | {"field": None}), cohort, parent, "KILN_IMPLEMENTATION_MODEL_KEY"), workspace)
                for credential in (key | {"field": "token"}, key | {"extra": None}, key | {"provider": "file"},
                                   key | {"key": "OTHER"}, {"provider": "env"}, key | {"field": 1}):
                    with self.subTest(credential=credential):
                        with self.assertRaisesRegex(ValueError, "credential"):
                            qualification.validate_attempt(with_broker(credential), cohort, parent, "KILN_IMPLEMENTATION_MODEL_KEY")
                for change in ({"network": True}, {"network_namespace": "/run/netns/model"},
                               {"schema": "lattice.implementation-attempt-run.v1"},
                               {"worker_compute": {"kind": "remote"}}, {"workspace_root": str(parent / "other")},
                               {"omp": request["omp"] | {"model": "lattice/other"}},
                               {"omp": request["omp"] | {"model_broker": broker | {"endpoint": "http://10.0.2.2:8080/v1/chat/completions"}}},
                               {"omp": request["omp"] | {"model_broker": broker | {"sandbox_blake3": "f" * 64}}},
                               {"write_paths": ["."]}, {"write_paths": ["../escape"]},
                               {"write_paths": [".omp"]}, {"read_paths": ["/run/secrets"]},
                               {"program": "/nix/store/other-worker"}, {"output_limit_bytes": 0}):
                    with self.subTest(change=change):
                        with self.assertRaises(ValueError):
                            qualification.validate_attempt(request | change, cohort, parent)

    def test_verifier_authority_matches_actual_worker_and_private_roots(self):
        cohort = {"entries": {"git": {"resolved_path": "/nix/store/git", "blake3": "f" * 64}}}
        authority = {"worker_uid": 931, "repository_root": "/var/lib/pilot/verifier/repository",
                     "scratch_root": "/var/lib/pilot/verifier/scratch", "git": {"path": "/nix/store/git", "blake3": "f" * 64}}
        with patch.object(qualification, "immutable", side_effect=Path):
            self.assertEqual(qualification.validate_verifier_authority(authority, "/var/lib/pilot", 931, cohort)["authority"], "deployment-bound")
            for change in ({"worker_uid": 0}, {"repository_root": "/var/lib/pilot/workspaces/attempt"},
                           {"scratch_root": "/var/lib/pilot/kiln"}, {"git": {"path": "/nix/store/wrong", "blake3": "f" * 64}}):
                with self.assertRaises(ValueError):
                    qualification.validate_verifier_authority(authority | change, "/var/lib/pilot", 931, cohort)


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
        envelope = {"work_id": "work", "attempt_id": "attempt", "workspace_id": "workspace", "fence": 3}
        request = {"envelope": envelope}
        cohort = {"entries": {"lattice": {"resolved_path": "/nix/store/lattice", "blake3": "a" * 64}}}
        receipt = {"schema": "lattice.candidate-receipt.v1", "work_id": "work", "attempt_id": "attempt",
                   "workspace_id": "workspace", "fence": "3", "disposition": "produced", "blockers": [],
                   "base_identity": "b" * 64, "candidate_identity": "c" * 64, "diff_identity": "d" * 64,
                   "changed_paths": ["code"]}
        observation = {"schema": "lattice.implementation-attempt-observation.v1", "envelope": envelope,
                       "result": {"disposition": "produced", "receipt": receipt, "blocker": None}}
        args = SimpleNamespace(state=str(root / "state"), output_parent=str(output))
        binding = {"path": str(root), "attempt": "attempt", "fence": 3}
        sent = (root / "request-sent.json", {"state_directory": args.state})
        return args, (root, binding, cohort, request, workspace), observation, sent

    def test_produced_native_result_exports_bytes_not_acceptance(self):
        with tempfile.TemporaryDirectory() as directory:
            args, inputs, observation, sent = self.fixture(directory)
            # Scripted durable native observation only; not worker execution or
            # proof of cross-UID permissions. Actual capture rehashes this tree.
            with patch.object(qualification, "attempt_inputs", return_value=inputs), patch.object(qualification, "immutable", side_effect=Path), patch.object(qualification, "digest", return_value="a" * 64), patch.object(qualification, "_sent_request", return_value=sent), patch.object(qualification.subprocess, "check_output", return_value=json.dumps(observation).encode()) as lattice:
                result = qualification.export_candidate(args)
                # Lattice recovers from the request it ran, not the admitted one.
                self.assertEqual(lattice.call_args.args[0][2:], ["recover", "--request", str(sent[0]), "--state", args.state])
                self.assertFalse(result["accepted"])
                self.assertEqual(result["qualification"], "unqualified")
                candidate = Path(result["candidate_root"])
                self.assertEqual((candidate / "code").read_text(), "candidate")
                # Directories stay 0750 in the capture group; files carry
                # exactly Git's modes, which Kiln's byte receipt admits.
                self.assertEqual(candidate.stat().st_mode & 0o777, 0o750)
                self.assertEqual((candidate / "bin").stat().st_mode & 0o777, 0o750)
                self.assertEqual((candidate / "code").stat().st_mode & 0o777, 0o644)
                self.assertEqual((candidate / "bin/run").stat().st_mode & 0o777, 0o755)
                self.assertEqual(qualification.document(result["host_receipt"]), observation["result"]["receipt"])
                with self.assertRaises(FileExistsError):
                    qualification.export_candidate(args)

    def test_unknown_crossed_or_forged_receipts_never_export(self):
        with tempfile.TemporaryDirectory() as directory:
            args, inputs, baseline, sent = self.fixture(directory)
            cases = []
            unknown = copy.deepcopy(baseline)
            unknown["result"]["disposition"] = "unknown"
            cases.append(unknown)
            stale = copy.deepcopy(baseline)
            stale["result"]["receipt"]["fence"] = "2"
            cases.append(stale)
            forged = copy.deepcopy(baseline)
            forged["schema"] = "worker-success-message"
            cases.append(forged)
            crossed = copy.deepcopy(baseline)
            crossed["envelope"]["attempt_id"] = "other-attempt"
            cases.append(crossed)
            for observation in cases:
                with patch.object(qualification, "attempt_inputs", return_value=inputs), patch.object(qualification, "immutable", side_effect=Path), patch.object(qualification, "digest", return_value="a" * 64), patch.object(qualification, "_sent_request", return_value=sent), patch.object(qualification.subprocess, "check_output", return_value=json.dumps(observation).encode()):
                    with self.assertRaises(ValueError):
                        qualification.export_candidate(args)
            self.assertEqual(list(Path(args.output_parent).iterdir()), [])


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
        transport = {"output_directory": str(output), "state_directory": str(root / "lattice/implementation")}
        (configuration / "worker-transport-profile.json").write_text(json.dumps(transport))
        (configuration / "enrollment.json").write_text("{}")
        args = SimpleNamespace(configuration=str(configuration), state_root=str(root), state=transport["state_directory"])
        cohort = {"entries": {"dispatch": {"resolved_path": "/nix/store/dispatch", "blake3": "e" * 64}}}
        resolution = {"schema": "kiln.lattice-sent-request.v1", "attempt": "a" * 64, "fence": 1, "recorded": True,
                      "request": str(sent), "request_blake3": "e" * 64, "state_directory": transport["state_directory"]}
        return args, cohort, operation, {"attempt": "a" * 64, "fence": 1}, resolution

    def resolve(self, args, cohort, operation, claim, resolution, admitted="e" * 64):
        digests = lambda path: admitted if Path(path).name == "attempt.json" else "e" * 64
        with patch.object(qualification, "immutable", side_effect=Path), patch.object(qualification, "digest", side_effect=digests), \
             patch.object(qualification.subprocess, "check_output", return_value=json.dumps(resolution).encode()) as kiln:
            request, _ = qualification._sent_request(args, cohort, operation, claim)
        return request, kiln.call_args.args[0]

    def test_recorded_lineage_request_is_the_profile_frozen_file(self):
        with tempfile.TemporaryDirectory() as directory:
            args, cohort, operation, claim, resolution = self.fixture(directory)
            request, argv = self.resolve(args, cohort, operation, claim, resolution, admitted="f" * 64)
            self.assertEqual(request, Path(resolution["request"]))
            self.assertEqual(argv[-2:], ["--sent-request", "true"])
            self.assertEqual(argv[argv.index("--worker-request") + 1], str(operation / "attempt.json"))
            # A legacy launch sent the admitted bytes, and only those.
            legacy = resolution | {"recorded": False}
            self.assertEqual(self.resolve(args, cohort, operation, claim, legacy)[0], Path(resolution["request"]))
            with self.assertRaisesRegex(ValueError, "admitted bytes"):
                self.resolve(args, cohort, operation, claim, legacy, admitted="f" * 64)

    def test_crossed_misplaced_or_untyped_resolutions_are_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            args, cohort, operation, claim, resolution = self.fixture(directory)
            root = Path(directory)
            (root / ("request-" + "e" * 64 + ".json")).write_text("{}")
            for change in ({"attempt": "b" * 64}, {"fence": 2}, {"fence": "1"}, {"recorded": "true"},
                           {"schema": "kiln.lattice-sent-request.v0"}, {"extra": None},
                           {"request": str(root / ("request-" + "e" * 64 + ".json"))},
                           {"request_blake3": "f" * 64},
                           {"state_directory": str(root / "other")}):
                with self.subTest(change=change):
                    with self.assertRaises(ValueError):
                        self.resolve(args, cohort, operation, claim, resolution | change)
            with self.assertRaises(ValueError):
                self.resolve(SimpleNamespace(**vars(args) | {"state": str(root / "other")}), cohort, operation, claim, resolution)
            sent = Path(resolution["request"])
            sent.unlink()
            sent.symlink_to(operation / "attempt.json")
            with self.assertRaisesRegex(ValueError, "ordinary file"):
                self.resolve(args, cohort, operation, claim, resolution)


class RuntimeBindingTests(unittest.TestCase):
    """Device-free protection/codec tests, not native worker qualification."""

    def test_regular_binding_rejects_symlinks_and_writable_entries(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "entry.json"
            target.write_text('{"bound": true}')
            with self.assertRaisesRegex(ValueError, "owner-writable"):
                qualification._regular_owned(target, os.getuid())
            target.chmod(0o444)
            self.assertEqual(json.loads(qualification._regular_owned(target, os.getuid())), {"bound": True})
            link = root / "linked.json"
            link.symlink_to(target)
            with self.assertRaises(OSError):
                qualification._regular_owned(link, os.getuid())
            target.chmod(0o666)
            with self.assertRaisesRegex(ValueError, "permissions"):
                qualification._regular_owned(target, os.getuid())

    def test_runtime_selectors_retain_types_and_reject_unknown_authority(self):
        seed = {"fence": {"runtime": "fence"}, "lease": {"runtime": "lease_until_ms"}, "static": "literal"}
        self.assertEqual(qualification._expand_runtime(seed, {"fence": 9, "lease_until_ms": 123}),
                         {"fence": 9, "lease": 123, "static": "literal"})
        with self.assertRaisesRegex(ValueError, "unsupported runtime"):
            qualification._expand_runtime({"runtime": "invented_capacity"}, {})

    def test_dispatch_binding_does_not_require_future_publication(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            attempt, work = "a" * 64, "b" * 64
            stage = root / "bindings" / (attempt + "-3") / "dispatch"
            stage.mkdir(parents=True)
            claim = {"identity": attempt, "fence": 3, "work_identity": work, "work_revision": 7}
            request = {"envelope": {"attempt_id": attempt, "fence": 3, "work_id": work, "work_version": 7, "workspace_id": attempt}}
            plan = {"attempt_identity": attempt, "fence": 3, "work_identity": work, "work_revision": 7, "workspace": {"identity": attempt}}
            values = {name: {} for name in qualification.STAGE_ENTRIES["dispatch"]}
            values.update({"attempt.json": request, "dispatch-plan.json": plan})
            hash_file = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
            for name, value in values.items():
                qualification._seal(stage / name, value)
            entries = {name: hash_file(stage / name) for name in values}
            manifest = {"schema": "onix.kiln.runtime-binding.v1", "stage": "dispatch", "attempt": attempt, "fence": 3,
                        "work": work, "work_revision": 7, "cohort_manifest_blake3": "c" * 64,
                        "template_blake3": "c" * 64, "request_blake3": entries["attempt.json"], "entries": entries}
            qualification._seal(stage / "manifest.json", manifest)
            real_directory, real_owned = qualification._protected_directory, qualification._owned_document
            args = SimpleNamespace(stage="dispatch", cohort="/nix/store/cohort")
            with patch.object(qualification, "_binding_context", return_value=(Path("/nix/store/template"), {}, {"attempt": claim}, {})), \
                 patch.object(qualification, "_controller", return_value=root), \
                 patch.object(qualification, "_protected_directory", side_effect=lambda path: real_directory(path, os.getuid())), \
                 patch.object(qualification, "_owned_document", side_effect=lambda path: real_owned(path, os.getuid())), \
                 patch.object(qualification, "_regular_owned", wraps=qualification._regular_owned) as regular, \
                 patch.object(qualification, "digest", side_effect=lambda path: hash_file(path) if Path(path).parent == stage else "c" * 64):
                # Only the test process UID is substituted; production fixes root.
                original = regular._mock_wraps
                regular.side_effect = lambda path, owner: original(path, os.getuid())
                self.assertEqual(qualification.runtime_binding(args)["path"], str(stage))
                self.assertFalse((stage / "publication.json").exists())
                (stage / "attempt.json").chmod(0o644)
                with self.assertRaisesRegex(ValueError, "owner-writable"):
                    qualification.runtime_binding(args)



class GithubObjectFixtureTests(unittest.TestCase):
    def test_actual_objects_target_guard_and_retained_single_pr(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            work, bare = root / "work", root / "remote.git"
            environment = os.environ | {"GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null",
                "GIT_AUTHOR_NAME": "fixture", "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
                "GIT_COMMITTER_NAME": "fixture", "GIT_COMMITTER_EMAIL": "fixture@example.invalid"}
            def git(*arguments):
                return subprocess.check_output(["git", *map(str, arguments)], env=environment, stderr=subprocess.PIPE, text=True).strip()
            git("init", "--initial-branch=main", work)
            (work / "file").write_text("baseline")
            git("-C", work, "add", ".")
            git("-C", work, "commit", "-m", "baseline")
            base = git("-C", work, "rev-parse", "HEAD")
            git("clone", "--bare", "--no-hardlinks", work, bare)
            (work / "file").write_text("candidate")
            git("-C", work, "commit", "-am", "candidate")
            candidate = git("-C", work, "rev-parse", "HEAD")
            plan = {"repository": "qualification/disposable", "branch": "kiln/impl-fixture", "base_branch": "main", "base": base, "candidate": candidate}
            state = root / "state"
            fixture = github_fixture.Fixture(plan, state, False, bare)
            self.assertIsNone(fixture.branch_sha)
            server = github_fixture.ThreadingHTTPServer(("127.0.0.1", 0), fixture.handler())
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            def post(suffix, value):
                request = Request(f"http://127.0.0.1:{server.server_port}/repos/qualification/disposable/{suffix}",
                    data=json.dumps(value).encode(), method="POST",
                    headers={"Authorization": "Bearer scripted-publisher-only", "Content-Type": "application/json"})
                with urlopen(request, timeout=5) as response:
                    return json.load(response)
            try:
                with self.assertRaises(HTTPError) as refused:
                    post("git/refs", {"ref": "refs/heads/" + plan["branch"], "sha": candidate})
                self.assertEqual(refused.exception.code, 405)
                with self.assertRaises(HTTPError) as missing:
                    post("pulls", {"head": plan["branch"], "base": "main"})
                self.assertEqual(missing.exception.code, 422)
                git("-C", work, "push", str(bare), candidate + ":refs/heads/" + plan["branch"])
                fixture.refresh_branch()
                self.assertEqual(fixture.branch_sha, candidate)
                self.assertEqual(post("pulls", {"head": plan["branch"], "base": "main"})["number"], 1)
                with self.assertRaises(HTTPError) as duplicate:
                    post("pulls", {"head": plan["branch"], "base": "main"})
                self.assertEqual(duplicate.exception.code, 422)
            finally:
                server.shutdown()
                server.server_close()
                thread.join(timeout=5)
            reopened = github_fixture.Fixture(plan, state, False, bare)
            self.assertEqual(reopened.pull["number"], 1)
            self.assertEqual(reopened.branch_sha, candidate)
            git("-C", bare, "update-ref", "refs/heads/main", candidate, base)
            with self.assertRaisesRegex(ValueError, "target moved"):
                reopened.refresh_branch()


class MutableDiskTests(unittest.TestCase):
    def test_new_disk_files_have_separate_observed_ids_and_never_replace(self):
        with tempfile.TemporaryDirectory() as directory:
            args = SimpleNamespace(directory=str(Path(directory) / "attempt"), reference="attempt-a", generation=1,
                                   workspace_mib=qualification.MIN_DISK_MIB, state_mib=qualification.MIN_DISK_MIB)
            # Only formatting/UUID observation is substituted. These are sparse
            # local file-boundary fixtures, explicitly not filesystem/KVM proof.
            ids = ["11111111-1111-1111-1111-111111111111\n", "22222222-2222-2222-2222-222222222222\n"]
            with patch.object(qualification.subprocess, "run") as format_disk, patch.object(qualification.subprocess, "check_output", side_effect=ids):
                result = qualification.prepare_disks(args)
                self.assertEqual(format_disk.call_count, 2)
                self.assertFalse(result["placement_authority"])
                self.assertEqual(result["qualification"], "unqualified")
                self.assertNotEqual(result["disks"]["workspace"]["filesystem_uuid"], result["disks"]["state"]["filesystem_uuid"])
                for disk in result["disks"].values():
                    self.assertEqual(Path(disk["path"]).stat().st_size, qualification.MIN_DISK_MIB * qualification.MIB_BYTES)
                    self.assertEqual(Path(disk["path"]).stat().st_mode & 0o777, 0o600)
                with self.assertRaises(FileExistsError):
                    qualification.prepare_disks(args)

    def test_size_generation_and_reused_filesystem_ids_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            baseline = {"directory": str(Path(directory) / "attempt"), "reference": "attempt", "generation": 1,
                        "workspace_mib": qualification.MIN_DISK_MIB, "state_mib": qualification.MIN_DISK_MIB}
            for change in ({"generation": 0}, {"reference": "../escape"}, {"workspace_mib": 0}, {"state_mib": qualification.MAX_DISK_MIB + 1}):
                with self.assertRaises(ValueError):
                    qualification.prepare_disks(SimpleNamespace(**(baseline | change)))
            duplicate = "11111111-1111-1111-1111-111111111111\n"
            with patch.object(qualification.subprocess, "run"), patch.object(qualification.subprocess, "check_output", return_value=duplicate):
                with self.assertRaisesRegex(ValueError, "independent"):
                    qualification.prepare_disks(SimpleNamespace(**baseline))
            self.assertTrue((Path(baseline["directory"]) / "workspace.raw").exists())
            self.assertFalse((Path(baseline["directory"]) / "disks.json").exists())


if __name__ == "__main__":
    unittest.main()
