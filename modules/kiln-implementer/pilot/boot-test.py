# Appended to offline-intake.py (json, scripted_claim, kiln_status); the NixOS
# test driver injects subtest and the pilot node.
# ruff: noqa: F821
import re

stages = [
    "poll",
    "cairn-intake",
    "claim",
    "prepare-fixture-intake",
    "bind-dispatch",
    "bind-publication",
    "admission-status",
    "host-owner-admit",
    "host-owner-observe",
    "host-owner-reserve",
    "host-owner-release",
    "reserve",
    "dispatch",
    "recover-dispatch",
    "cancel-worker",
    "export-candidate",
    "capture-candidate",
    "verify",
    "prepare-publication",
    "publish",
    "status",
]
support = [
    "kiln-pilot-model-netns",
    "kiln-pilot-model-relay",
    "kiln-pilot-model-bridge",
    "kiln-pilot-acquire-verifier-source",
]

pilot.wait_for_unit("multi-user.target")

with subtest("every stage unit exists and nothing started on boot"):
    for unit in (
        [f"kiln-implementation-{stage}" for stage in stages]
        + ["kiln-implementation-policy-check"]
        + support
    ):
        state = pilot.succeed(
            f"systemctl show {unit}.service -p LoadState -p ActiveState -p UnitFileState --value"
        ).split()
        assert state[0] == "loaded", (unit, state)
        assert state[1] == "inactive", (unit, state)
    pilot.succeed(
        "test -f /etc/static/kiln-implementation/deployment.json || test -f /etc/kiln-implementation/deployment.json"
    )
    pilot.succeed("test ! -e /run/kiln-pilot-credentials")
    pilot.succeed("test ! -e /var/lib/kiln-implementation/controller/current.json")
    deployment = json.loads(
        pilot.succeed("cat /etc/kiln-implementation/deployment.json")
    )
    assert deployment["landing"] == "disabled", deployment
    assert deployment["automatic_dispatch"] is False, deployment
    assert deployment["publication_mode"] == "verified-pr", deployment
    assert deployment["model_credential"] is True, deployment
    assert deployment["repositories"] == ["onixresearch/implementer-sandbox"], (
        deployment
    )

with subtest("the immutable configuration is admitted"):
    pilot.succeed("systemctl start kiln-implementation-policy-check.service")

with subtest("the registered host-local owner admits and observes without credentials"):
    pilot.succeed("systemctl start kiln-implementation-host-owner-admit.service")
    pilot.succeed("systemctl start kiln-implementation-host-owner-observe.service")
    print(
        pilot.succeed(
            "cat /var/log/kiln-implementation-coordinator/host-owner-admit.jsonl /var/log/kiln-implementation-coordinator/host-owner-observe.jsonl"
        )
    )
    # Reserve and release bind an exact retained claim; there is none.
    for stage in ("host-owner-reserve", "host-owner-release"):
        pilot.fail(f"systemctl start kiln-implementation-{stage}.service")

with subtest("credential-bearing stages refuse without their credential"):
    for stage in ("poll", "publish", "dispatch"):
        pilot.fail(f"systemctl start kiln-implementation-{stage}.service")
    for stage in ("poll", "publish"):
        journal = pilot.succeed(
            f"journalctl -b -u kiln-implementation-{stage}.service --no-pager"
        )
        assert "CREDENTIALS" in journal or "credential" in journal.lower(), (
            stage,
            journal,
        )
    pilot.fail("systemctl start kiln-pilot-acquire-verifier-source.service")

with subtest("bound stages refuse without a canonical claim"):
    for stage in (
        "bind-dispatch",
        "reserve",
        "export-candidate",
        "capture-candidate",
        "bind-publication",
        "prepare-publication",
    ):
        pilot.fail(f"systemctl start kiln-implementation-{stage}.service")
        result = pilot.succeed(
            f"systemctl show kiln-implementation-{stage}.service -p Result --value"
        ).strip()
        assert result == "exit-code", (stage, result)
    # Verify refuses even earlier: it requires the canonical CI enrollment,
    # which cannot open the verifier repository before its acquisition.
    pilot.fail("systemctl start kiln-implementation-verify.service")
    assert (
        pilot.succeed(
            "systemctl show kiln-implementation-ci-enroll.service -p Result --value"
        ).strip()
        == "exit-code"
    )
    assert (
        pilot.succeed(
            "systemctl show kiln-implementation-verify.service -p ExecMainStartTimestampMonotonic --value"
        ).strip()
        == "0"
    )
    pilot.succeed("systemctl start kiln-implementation-status.service")
    status = json.loads(
        pilot.succeed("tail -n 1 /var/log/kiln-implementation-coordinator/status.jsonl")
    )
    print(status)
    assert status.get("attempts", 0) == 0, status
    assert status.get("work", 0) == 0, status
    pilot.succeed("test ! -e /var/lib/kiln-implementation/controller/current.json")

with subtest("root SSH takes only the key from the share"):
    pilot.wait_for_unit("sshd.service")
    pilot.succeed("test ! -e /run/kiln-pilot-ssh/root")
    effective = pilot.succeed("sshd -T").lower()
    for line in (
        "passwordauthentication no",
        "kbdinteractiveauthentication no",
        "allowusers root",
        "authorizedkeysfile /run/kiln-pilot-ssh/%u",
        "allowtcpforwarding no",
    ):
        assert line in effective, (line, effective)
    assert (
        "permitrootlogin prohibit-password" in effective
        or "permitrootlogin without-password" in effective
    ), effective
    # A throwaway operator key generated in the guest; never in the store.
    pilot.succeed("ssh-keygen -q -t ed25519 -N '' -f /root/pilot-ssh")
    pilot.succeed(
        "install -d -m 0700 /run/kiln-pilot-credentials && install -m 0600 /root/pilot-ssh.pub /run/kiln-pilot-credentials/ssh.pub"
    )
    pilot.succeed(
        "systemctl restart kiln-pilot-ssh-authorized-key.service sshd.service"
    )
    pilot.wait_for_open_port(22)
    options = "-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/root/known_hosts"
    assert (
        pilot.succeed(
            f"ssh {options} -i /root/pilot-ssh root@127.0.0.1 -- id -u"
        ).strip()
        == "0"
    )
    refused = pilot.fail(
        f"ssh {options} -o PubkeyAuthentication=no -o PreferredAuthentications=password,keyboard-interactive root@127.0.0.1 -- true 2>&1"
    )
    assert "Permission denied (publickey)" in refused, refused
    pilot.fail(
        f"ssh {options} -i /root/pilot-ssh kiln-implementation-executor@127.0.0.1 -- true"
    )
    # A private key placed in the share is refused rather than trusted.
    pilot.succeed("cp /root/pilot-ssh /run/kiln-pilot-credentials/pilot-ssh")
    pilot.fail("systemctl restart kiln-pilot-ssh-authorized-key.service")
    pilot.succeed("test ! -e /run/kiln-pilot-ssh/root")
    pilot.succeed(
        "rm -rf /run/kiln-pilot-credentials /root/pilot-ssh /root/pilot-ssh.pub"
    )

with subtest("egress: only the relay account reaches the gateway"):
    ruleset = pilot.succeed("nft list table inet kiln-pilot-egress")
    assert "skuid 936" in ruleset, ruleset
    assert "dport 8080" in ruleset, ruleset
    for uid in (930, 931, 932, 933):
        pilot.fail(
            f"setpriv --reuid={uid} --regid=65534 --clear-groups curl -sS -m 3 http://10.0.2.2:8080/v1/models"
        )
    for uid in (931, 933):
        pilot.fail(
            f"setpriv --reuid={uid} --regid=65534 --clear-groups curl -sS -m 3 https://1.1.1.1/"
        )
    pilot.succeed("systemctl start kiln-pilot-model-netns.service")
    namespace = (
        pilot.succeed("ip -n kiln-implementation-model -o link show")
        .strip()
        .splitlines()
    )
    assert len(namespace) == 1, namespace
    assert ": lo:" in namespace[0], namespace
    pilot.fail(
        "ip netns exec kiln-implementation-model setpriv --reuid=931 --regid=65534 --clear-groups curl -sS -m 3 http://10.0.2.2:8080/v1/models"
    )

with subtest("a scripted issue delivery is claimed and bound offline"):
    # Kiln's real intake path on one locally signed delivery for issue #1
    # (offline-intake.py): no GitHub call, credential share, worker or model.
    claimed = scripted_claim(pilot)
    claim, binding = claimed["claim"], claimed["binding"]
    for stage in ("host-owner-reserve", "host-owner-observe", "bind-dispatch"):
        pilot.succeed(f"systemctl start kiln-implementation-{stage}.service")
    pilot.succeed(f"test $(stat -c %u {binding}/manifest.json) = 0")
    for name in ("attempt.json", "dispatch-plan.json", "admission-observations.json"):
        pilot.succeed(
            f"runuser -u kiln-implementation-executor -- test -r {binding}/{name}"
        )
        pilot.succeed(
            f"runuser -u kiln-implementation-executor -- test ! -w {binding}/{name}"
        )
    request = json.loads(pilot.succeed(f"cat {binding}/attempt.json"))
    assert request["dispatch_plan"], request["envelope"]
    assert request["envelope"]["attempt_id"] == claim["identity"], request["envelope"]
    pilot.succeed(
        f"test $(stat -c %U {request['workspace_root']}) = kiln-implementation-executor"
    )
    # Publication binding needs an independently verified candidate.
    pilot.fail("systemctl start kiln-implementation-bind-publication.service")
    refusal = pilot.succeed(
        "journalctl -b -u kiln-implementation-bind-publication.service --no-pager"
    )
    assert "publication materialization requires actual retained handoff" in refusal, (
        refusal
    )

    # Native reserve, then the dispatcher's own pre-start check exactly as the
    # dispatch unit runs it (same argv, account and umask), without starting
    # the transport, the worker or the model broker.
    pilot.succeed("systemctl start kiln-implementation-reserve.service")
    shown = pilot.succeed(
        "systemctl show -p ExecStartPre --value kiln-implementation-dispatch.service"
    )
    found = re.search(r"argv\[\]=(.*?) ; ignore_errors=", shown)
    assert found is not None, shown
    argv = found.group(1)
    assert " check-attempt " in argv, argv
    assert "--model-credential-env KILN_IMPLEMENTATION_MODEL_KEY" in argv, argv
    checked = json.loads(
        pilot.succeed(
            "systemd-run --wait --collect --pipe --quiet -p User=kiln-implementation-executor "
            f"-p Group=kiln-implementation-ledger -p UMask=0007 -- {argv}"
        )
        .strip()
        .splitlines()[-1]
    )
    assert checked["disposition"] == "request-checked", checked
    assert checked["workspace"] == request["workspace_root"], checked
    # Lattice's exact worker sandbox for this sealed request, under the
    # dispatch unit's own settings: a no-op, then OMP's version. No broker,
    # relay, transport or model call.
    pilot.succeed("install -d -m 0755 /run/kiln-pilot-worker-probe")
    pilot.succeed(
        f"printf %s {binding}/attempt.json > /run/kiln-pilot-worker-probe/request"
    )
    pilot.succeed("chmod 0444 /run/kiln-pilot-worker-probe/request")
    for probe in ("true", "omp-version"):
        status, _ = pilot.execute(
            f"systemctl start kiln-pilot-worker-sandbox-probe@{probe}.service"
        )
        output = pilot.succeed(
            f"cat /var/log/kiln-implementation-executor/sandbox-probe-{probe}.out "
            f"/var/log/kiln-implementation-executor/sandbox-probe-{probe}.err"
        )
        print(f"worker sandbox probe {probe}: rc={status} {output.strip()}")
        assert status == 0, output
        assert probe != "omp-version" or "omp/" in output, output
    pilot.succeed("test ! -s /var/log/kiln-implementation-executor/dispatch.jsonl")
    pilot.succeed('test -z "$(ls -A /var/lib/kiln-implementation/lattice)"')
