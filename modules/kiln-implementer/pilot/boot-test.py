import hashlib
import hmac
import json
import re
import shlex

stages = [
    "poll", "cairn-intake", "claim", "prepare-fixture-intake", "bind-dispatch", "bind-publication",
    "admission-status", "host-owner-admit", "host-owner-observe", "host-owner-reserve", "host-owner-release",
    "reserve", "dispatch", "recover-dispatch", "cancel-worker", "export-candidate",
    "capture-candidate", "verify", "prepare-publication", "publish", "status",
]
support = ["kiln-pilot-model-netns", "kiln-pilot-model-relay", "kiln-pilot-model-bridge", "kiln-pilot-acquire-verifier-source"]

pilot.wait_for_unit("multi-user.target")

with subtest("every stage unit exists and nothing started on boot"):
    for unit in [f"kiln-implementation-{stage}" for stage in stages] + ["kiln-implementation-policy-check"] + support:
        state = pilot.succeed(f"systemctl show {unit}.service -p LoadState -p ActiveState -p UnitFileState --value").split()
        assert state[0] == "loaded" and state[1] == "inactive", (unit, state)
    pilot.succeed("test -f /etc/static/kiln-implementation/deployment.json || test -f /etc/kiln-implementation/deployment.json")
    pilot.succeed("test ! -e /run/kiln-pilot-credentials")
    pilot.succeed("test ! -e /var/lib/kiln-implementation/controller/current.json")
    deployment = json.loads(pilot.succeed("cat /etc/kiln-implementation/deployment.json"))
    assert deployment["landing"] == "disabled" and deployment["automatic_dispatch"] is False, deployment
    assert deployment["publication_mode"] == "verified-pr" and deployment["model_credential"] is True, deployment
    assert deployment["repositories"] == ["onixresearch/implementer-sandbox"], deployment

with subtest("the immutable configuration is admitted"):
    pilot.succeed("systemctl start kiln-implementation-policy-check.service")

with subtest("the registered host-local owner admits and observes without credentials"):
    pilot.succeed("systemctl start kiln-implementation-host-owner-admit.service")
    pilot.succeed("systemctl start kiln-implementation-host-owner-observe.service")
    print(pilot.succeed("cat /var/log/kiln-implementation-coordinator/host-owner-admit.jsonl /var/log/kiln-implementation-coordinator/host-owner-observe.jsonl"))
    # Reserve and release bind an exact retained claim; there is none.
    for stage in ("host-owner-reserve", "host-owner-release"):
        pilot.fail(f"systemctl start kiln-implementation-{stage}.service")

with subtest("credential-bearing stages refuse without their credential"):
    for stage in ("poll", "publish", "dispatch"):
        pilot.fail(f"systemctl start kiln-implementation-{stage}.service")
    for stage in ("poll", "publish"):
        journal = pilot.succeed(f"journalctl -b -u kiln-implementation-{stage}.service --no-pager")
        assert "CREDENTIALS" in journal or "credential" in journal.lower(), (stage, journal)
    pilot.fail("systemctl start kiln-pilot-acquire-verifier-source.service")

with subtest("bound stages refuse without a canonical claim"):
    for stage in ("bind-dispatch", "reserve", "export-candidate", "capture-candidate", "verify", "bind-publication", "prepare-publication"):
        pilot.fail(f"systemctl start kiln-implementation-{stage}.service")
        result = pilot.succeed(f"systemctl show kiln-implementation-{stage}.service -p Result --value").strip()
        assert result == "exit-code", (stage, result)
    pilot.succeed("systemctl start kiln-implementation-status.service")
    status = json.loads(pilot.succeed("tail -n 1 /var/log/kiln-implementation-coordinator/status.jsonl"))
    print(status)
    assert status.get("attempts", 0) == 0 and status.get("work", 0) == 0, status
    pilot.succeed("test ! -e /var/lib/kiln-implementation/controller/current.json")

with subtest("root SSH takes only the key from the share"):
    pilot.wait_for_unit("sshd.service")
    pilot.succeed("test ! -e /run/kiln-pilot-ssh/root")
    effective = pilot.succeed("sshd -T").lower()
    for line in ("passwordauthentication no", "kbdinteractiveauthentication no", "allowusers root",
                 "authorizedkeysfile /run/kiln-pilot-ssh/%u", "allowtcpforwarding no"):
        assert line in effective, (line, effective)
    assert "permitrootlogin prohibit-password" in effective or "permitrootlogin without-password" in effective, effective
    # A throwaway operator key generated in the guest; never in the store.
    pilot.succeed("ssh-keygen -q -t ed25519 -N '' -f /root/pilot-ssh")
    pilot.succeed("install -d -m 0700 /run/kiln-pilot-credentials && install -m 0600 /root/pilot-ssh.pub /run/kiln-pilot-credentials/ssh.pub")
    pilot.succeed("systemctl restart kiln-pilot-ssh-authorized-key.service sshd.service")
    pilot.wait_for_open_port(22)
    options = "-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/root/known_hosts"
    assert pilot.succeed(f"ssh {options} -i /root/pilot-ssh root@127.0.0.1 -- id -u").strip() == "0"
    refused = pilot.fail(f"ssh {options} -o PubkeyAuthentication=no -o PreferredAuthentications=password,keyboard-interactive root@127.0.0.1 -- true 2>&1")
    assert "Permission denied (publickey)" in refused, refused
    pilot.fail(f"ssh {options} -i /root/pilot-ssh kiln-implementation-executor@127.0.0.1 -- true")
    # A private key placed in the share is refused rather than trusted.
    pilot.succeed("cp /root/pilot-ssh /run/kiln-pilot-credentials/pilot-ssh")
    pilot.fail("systemctl restart kiln-pilot-ssh-authorized-key.service")
    pilot.succeed("test ! -e /run/kiln-pilot-ssh/root")
    pilot.succeed("rm -rf /run/kiln-pilot-credentials /root/pilot-ssh /root/pilot-ssh.pub")

with subtest("egress: only the relay account reaches the gateway"):
    ruleset = pilot.succeed("nft list table inet kiln-pilot-egress")
    assert "skuid 936" in ruleset and "dport 8080" in ruleset, ruleset
    for uid in (930, 931, 932, 933):
        pilot.fail(f"setpriv --reuid={uid} --regid=65534 --clear-groups curl -sS -m 3 http://10.0.2.2:8080/v1/models")
    for uid in (931, 933):
        pilot.fail(f"setpriv --reuid={uid} --regid=65534 --clear-groups curl -sS -m 3 https://1.1.1.1/")
    pilot.succeed("systemctl start kiln-pilot-model-netns.service")
    namespace = pilot.succeed("ip -n kiln-implementation-model -o link show").strip().splitlines()
    assert len(namespace) == 1 and ": lo:" in namespace[0], namespace
    pilot.fail("ip netns exec kiln-implementation-model setpriv --reuid=931 --regid=65534 --clear-groups curl -sS -m 3 http://10.0.2.2:8080/v1/models")

with subtest("a scripted issue delivery is claimed and bound offline"):
    # Kiln's real intake path (`drain`) on one locally signed `issues` delivery
    # for issue #1: no GitHub call, no credential share, no worker or model.
    deployment = json.loads(pilot.succeed("cat /etc/kiln-implementation/deployment.json"))
    cohort, configuration = deployment["cohort"], deployment["configuration"]
    implementer = f"{cohort}/environment/bin/kiln-implementer"
    common = f"--database /var/lib/kiln-implementation/kiln/work.sqlite --enrollment {configuration}/enrollment.json"
    secret = b"kiln-pilot-boot-test-webhook-secret"
    body = json.dumps({
        "action": "opened",
        "repository": {"id": 1467234739, "name": "implementer-sandbox", "owner": {"login": "OnixResearch"}},
        "sender": {"login": "brittonr"},
        "issue": {"number": 1, "title": "word_count counts empty words and ignores tabs and newlines",
                  "body": "scripted boot-test delivery", "state": "open", "updated_at": "2026-11-22T00:00:00Z"},
    }, sort_keys=True)
    signature = "sha256=" + hmac.new(secret, body.encode(), hashlib.sha256).hexdigest()
    spool = "/var/lib/kiln-implementation/kiln/boot-intake"
    pilot.succeed(f"install -d -m 0700 -o kiln-implementation-coordinator -g kiln-implementation-ledger {spool}")
    pilot.succeed(f"printf %s {shlex.quote(secret.decode())} > {spool}/secret && chown kiln-implementation-coordinator {spool}/secret && chmod 0400 {spool}/secret")
    enqueue = ("import sqlite3,sys; c=sqlite3.connect(sys.argv[1]); "
               "c.execute('CREATE TABLE IF NOT EXISTS implementation_deliveries (delivery_id TEXT PRIMARY KEY, event TEXT NOT NULL, signature TEXT NOT NULL, body BLOB NOT NULL, recorded_at_ms INTEGER NOT NULL)'); "
               "c.execute('INSERT INTO implementation_deliveries VALUES (?,?,?,?,?)', ('00000000-0000-4000-8000-000000000001','issues',sys.argv[2],sys.argv[3].encode(),1)); c.commit()")
    pilot.succeed(f"runuser -u kiln-implementation-coordinator -- python3 -c {shlex.quote(enqueue)} {spool}/queue.sqlite {shlex.quote(signature)} {shlex.quote(body)}")
    drained = pilot.succeed(f"runuser -u kiln-implementation-coordinator -- {implementer} drain {common} --queue {spool}/queue.sqlite "
                            f"--secret-file {spool}/secret --policy {configuration}/github-policy.json --maximum-deliveries 16 --limit 16")
    print(drained)
    pilot.succeed("systemctl start kiln-implementation-status.service")
    assert json.loads(pilot.succeed("tail -n 1 /var/log/kiln-implementation-coordinator/status.jsonl"))["work"] == 1
    for stage in ("host-owner-admit", "host-owner-observe", "claim"):
        pilot.succeed(f"systemctl start kiln-implementation-{stage}.service")
    reference = json.loads(pilot.succeed("cat /var/lib/kiln-implementation/controller/current.json"))["claim"]
    claim = json.loads(pilot.succeed(f"cat /var/lib/kiln-implementation/controller/claims/{reference}"))
    print(claim)
    assert len(claim["identity"]) == 64 and claim["fence"] >= 1, claim
    pilot.succeed("test $(stat -c %u /var/lib/kiln-implementation/controller/current.json) = 0")
    pilot.succeed("systemctl start kiln-implementation-status.service")
    assert json.loads(pilot.succeed("tail -n 1 /var/log/kiln-implementation-coordinator/status.jsonl"))["attempts"] == 1
    for stage in ("host-owner-reserve", "host-owner-observe", "bind-dispatch"):
        pilot.succeed(f"systemctl start kiln-implementation-{stage}.service")
    binding = f"/var/lib/kiln-implementation/controller/bindings/{claim['identity']}-{claim['fence']}/dispatch"
    pilot.succeed(f"test $(stat -c %u {binding}/manifest.json) = 0")
    for name in ("attempt.json", "dispatch-plan.json", "admission-observations.json"):
        pilot.succeed(f"runuser -u kiln-implementation-executor -- test -r {binding}/{name}")
        pilot.succeed(f"runuser -u kiln-implementation-executor -- test ! -w {binding}/{name}")
    request = json.loads(pilot.succeed(f"cat {binding}/attempt.json"))
    assert request["dispatch_plan"] and request["envelope"]["attempt_id"] == claim["identity"], request["envelope"]
    pilot.succeed(f"test $(stat -c %U {request['workspace_root']}) = kiln-implementation-executor")
    # Publication binding needs an independently verified candidate.
    pilot.fail("systemctl start kiln-implementation-bind-publication.service")
    refusal = pilot.succeed("journalctl -b -u kiln-implementation-bind-publication.service --no-pager")
    assert "publication materialization requires actual retained handoff" in refusal, refusal

    # Native reserve, then the dispatcher's own pre-start check exactly as the
    # dispatch unit runs it (same argv, account and umask), without starting
    # the transport, the worker or the model broker.
    pilot.succeed("systemctl start kiln-implementation-reserve.service")
    shown = pilot.succeed("systemctl show -p ExecStartPre --value kiln-implementation-dispatch.service")
    found = re.search(r"argv\[\]=(.*?) ; ignore_errors=", shown)
    assert found is not None, shown
    argv = found.group(1)
    assert " check-attempt " in argv and "--model-credential-env KILN_IMPLEMENTATION_MODEL_KEY" in argv, argv
    checked = json.loads(pilot.succeed(
        "systemd-run --wait --collect --pipe --quiet -p User=kiln-implementation-executor "
        f"-p Group=kiln-implementation-ledger -p UMask=0007 -- {argv}").strip().splitlines()[-1])
    assert checked["disposition"] == "request-checked" and checked["workspace"] == request["workspace_root"], checked
    # Lattice's exact worker sandbox for this sealed request, under the
    # dispatch unit's own settings: a no-op, then OMP's version. No broker,
    # relay, transport or model call.
    pilot.succeed("install -d -m 0755 /run/kiln-pilot-worker-probe")
    pilot.succeed(f"printf %s {binding}/attempt.json > /run/kiln-pilot-worker-probe/request")
    pilot.succeed("chmod 0444 /run/kiln-pilot-worker-probe/request")
    for probe in ("true", "omp-version"):
        status, _ = pilot.execute(f"systemctl start kiln-pilot-worker-sandbox-probe@{probe}.service")
        output = pilot.succeed(f"cat /var/log/kiln-implementation-executor/sandbox-probe-{probe}.out "
                               f"/var/log/kiln-implementation-executor/sandbox-probe-{probe}.err")
        print(f"worker sandbox probe {probe}: rc={status} {output.strip()}")
        assert status == 0, output
        assert probe != "omp-version" or "omp/" in output, output
    pilot.succeed("test ! -s /var/log/kiln-implementation-executor/dispatch.jsonl")
    pilot.succeed("test -z \"$(ls -A /var/lib/kiln-implementation/lattice)\"")