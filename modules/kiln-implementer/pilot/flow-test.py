# Offline composition of the live pilot after dispatch (#49 run 6 escaped the
# boot test there). Two bug guests with a host-owner reservation, so Kiln
# sends Lattice the admitted request plus one budget `lineage`; Kiln's
# scripted authless model answers on each guest's loopback behind the same
# relay and bridge. No GitHub, credential share or publication.
# Appended to offline-intake.py (json, KILN_ROOT, scripted_claim, kiln_status,
# Any); the NixOS test driver injects start_all, subtest and the nodes.
# ruff: noqa: F821

start_all()
dispatch_log = "/var/log/kiln-implementation-executor/dispatch.jsonl"
evidence = "/var/lib/kiln-pilot-flow-model/evidence.json"


def dispatch_ready(node: Any) -> dict[str, Any]:
    node.wait_for_unit("multi-user.target")
    claimed = scripted_claim(node)
    node.succeed("systemctl start kiln-pilot-acquire-verifier-source.service")
    for stage in (
        "host-owner-reserve",
        "host-owner-observe",
        "bind-dispatch",
        "reserve",
    ):
        node.succeed(f"systemctl start kiln-implementation-{stage}.service")
    return claimed


def serve_model(node: Any, delay: int) -> None:
    # Kiln's fixture binds only 127.0.0.1:18700, the flow guest's relay upstream.
    node.succeed(
        "systemd-run --unit kiln-pilot-flow-model -p DynamicUser=yes -p StateDirectory=kiln-pilot-flow-model "
        "python3 /etc/kiln-pilot-flow/model_server.py --scenario /etc/kiln-pilot-flow/scenario.json "
        f"--evidence {evidence} --response-delay-seconds {delay}"
    )
    node.wait_until_succeeds("ss -ltn | grep -F 127.0.0.1:18700")


def observation(node: Any) -> dict[str, Any]:
    return json.loads(node.succeed(f"tail -n 1 {dispatch_log}"))


def stage(node: Any, name: str) -> None:
    """Start one stage; on failure, show its own stderr log and journal first."""
    status, _ = node.execute(f"systemctl start kiln-implementation-{name}.service")
    if status != 0:
        _, logs = node.execute(
            f"tail -n 40 /var/log/kiln-implementation-*/{name}.stderr; "
            f"journalctl -b -u kiln-implementation-{name}.service -o cat --no-pager | tail -n 40"
        )
        msg = f"stage {name} failed (exit {status}):\n{logs}"
        raise AssertionError(msg)


def sent_request(node: Any, claimed: dict[str, Any]) -> dict[str, Any]:
    """Kiln's read-only resolution of the bytes Lattice ran; they carry the lineage."""
    resolved = json.loads(
        node.succeed(
            "runuser -u kiln-implementation-executor -g kiln-implementation-ledger -- sh -c 'umask 0007; exec \"$@\"' sh "
            f"{claimed['cohort']}/environment/bin/kiln-lattice-dispatch {claimed['common']} "
            f"--worker-request {claimed['binding']}/attempt.json "
            f"--worker-transport-profile {claimed['configuration']}/worker-transport-profile.json --sent-request true"
        )
    )
    print(f"sent-request {node.name}: {json.dumps(resolved, sort_keys=True)}")
    assert resolved["schema"] == "kiln.lattice-sent-request.v1", resolved
    assert resolved["recorded"] is True, resolved
    assert resolved["attempt"] == claimed["claim"]["identity"], resolved
    assert resolved["fence"] == claimed["claim"]["fence"], resolved
    assert (
        resolved["request"]
        == f"{KILN_ROOT}/lattice/observations/request-{resolved['request_blake3']}.json"
    ), resolved
    assert resolved["state_directory"] == f"{KILN_ROOT}/lattice/implementation", (
        resolved
    )
    sent = json.loads(node.succeed(f"cat {resolved['request']}"))
    admitted = json.loads(node.succeed(f"cat {claimed['binding']}/attempt.json"))
    lineage = sent.pop("lineage")
    assert lineage["schema"] == "lattice.kiln-budget-lineage.v1", lineage
    assert "lineage" not in admitted, (
        "the sent request is not the admitted request plus one lineage"
    )
    assert sent == admitted, (
        "the sent request is not the admitted request plus one lineage"
    )
    return resolved


with subtest("an operator cancel stops a lineage-bearing worker mid-flight"):
    claimed = dispatch_ready(cancel)
    # The fixture holds its first response, so the worker is live and waiting.
    serve_model(cancel, 100)
    cancel.succeed("systemctl start --no-block kiln-implementation-dispatch.service")
    cancel.wait_until_succeeds(f"test -s {evidence}", timeout=120)
    resolved = sent_request(cancel, claimed)
    stage(cancel, "cancel-worker")
    journal = cancel.succeed(
        "journalctl -b -u kiln-implementation-cancel-worker.service -o cat --no-pager"
    )
    outcome = json.loads(
        [line for line in journal.splitlines() if "onix.kiln.worker-cancel.v1" in line][
            -1
        ]
    )
    print(f"cancel-worker: {json.dumps(outcome, sort_keys=True)}")
    assert outcome["request"] == resolved["request"], outcome
    assert outcome["lattice"]["cancellation_requested"] is True, outcome
    cancel.wait_until_succeeds(
        "test $(systemctl show kiln-implementation-dispatch.service -p ActiveState --value) != activating",
        timeout=120,
    )
    cancelled = observation(cancel)
    assert cancelled["result"]["disposition"] == "cancelled", cancelled
    status = kiln_status(cancel)
    assert status["cancelled"] == 1, status
    assert status["verified"] == 0, status
    cancel.succeed("! pgrep -u kiln-implementation-executor")
    cancel.fail("systemctl start kiln-implementation-export-candidate.service")

with subtest(
    "a lineage-bearing dispatch produces, exports, captures and verifies offline"
):
    claimed = dispatch_ready(produce)
    serve_model(produce, 0)
    produce.succeed("systemctl start kiln-implementation-dispatch.service")
    result = observation(produce)
    assert result["result"]["disposition"] == "produced", result
    produce.wait_until_succeeds(
        f'jq -e \'.events[-1] == {{"outcome": "completed", "requests": 2}}\' {evidence}',
        timeout=60,
    )
    sent_request(produce, claimed)
    # Export recovers from the recorded sent request, not the sealed attempt.json.
    stage(produce, "export-candidate")
    claim = claimed["claim"]
    exported = f"{KILN_ROOT}/candidate-export/{claim['identity']}-{claim['fence']}"
    produce.succeed(
        f"test -s {exported}/native-observation.json && test -s {exported}/host-receipt.json"
    )
    produce.succeed(f"grep -q split_whitespace {exported}/candidate/src/lib.rs")
    stage(produce, "capture-candidate")
    # The canonical CI service enrolls the project once; a rerun (or reboot)
    # finds it enrolled and succeeds without a second intake.
    stage(produce, "ci-enroll")
    produce.succeed("systemctl restart kiln-implementation-ci-enroll.service")
    enrollment = produce.succeed(
        "journalctl -b -u kiln-implementation-ci-enroll.service -o cat --no-pager"
    )
    print(enrollment)
    assert "implementer-sandbox: enrolled" in enrollment, enrollment
    assert "implementer-sandbox: already enrolled" in enrollment, enrollment
    stage(produce, "verify")
    status = kiln_status(produce)
    assert status["verified"] == 1, status
    assert status["published"] == 0, status

with subtest("offline publish passes Kiln's remote check and stops at the network"):
    # Kiln validates the publication remote against the durable repository key
    # before any network call (publication.rs `validate_source_profile`,
    # github_publication_remote_mismatch); only then does it contact GitHub,
    # which this guest cannot reach (github_publication_remote_unknown).
    stage(produce, "bind-publication")
    stage(produce, "prepare-publication")
    # A placeholder token: Kiln checks only its form before the remote check.
    produce.succeed("install -d -m 0700 /run/kiln-pilot-credentials")
    produce.succeed(
        "printf %s offline-placeholder-token > /run/kiln-pilot-credentials/publisher"
    )
    produce.succeed("chmod 0600 /run/kiln-pilot-credentials/publisher")
    produce.fail("systemctl start kiln-implementation-publish.service")
    refusal = produce.succeed(
        "cat /var/log/kiln-implementation-publisher/publish.stderr"
    )
    print(refusal)
    assert "github_publication_remote_mismatch" not in refusal, refusal
    assert (
        "github_publication_remote_unknown" in refusal
        or "branch outcome remains unknown" in refusal
    ), refusal
    produce.succeed("test ! -s /var/log/kiln-implementation-publisher/publish.jsonl")
    assert kiln_status(produce)["published"] == 0
