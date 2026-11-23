import hashlib
import hmac
import json
import shlex

KILN_ROOT = "/var/lib/kiln-implementation"


def kiln_status(node):
    node.succeed("systemctl start kiln-implementation-status.service")
    return json.loads(node.succeed("tail -n 1 /var/log/kiln-implementation-coordinator/status.jsonl"))


def scripted_claim(node):
    """Claim issue #1 offline through Kiln's real intake path (`drain`).

    One locally signed `issues` delivery, no GitHub call, credential share,
    worker or model; then the registered host-local owner admits and observes,
    and the controller claims. Shared by the pilot boot and flow tests.
    """
    deployment = json.loads(node.succeed("cat /etc/kiln-implementation/deployment.json"))
    configuration = deployment["configuration"]
    implementer = f"{deployment['cohort']}/environment/bin/kiln-implementer"
    common = f"--database {KILN_ROOT}/kiln/work.sqlite --enrollment {configuration}/enrollment.json"
    secret = b"kiln-pilot-offline-webhook-secret"
    body = json.dumps({
        "action": "opened",
        "repository": {"id": 1467234739, "name": "implementer-sandbox", "owner": {"login": "OnixResearch"}},
        "sender": {"login": "brittonr"},
        "issue": {"number": 1, "title": "word_count counts empty words and ignores tabs and newlines",
                  "body": "scripted offline delivery", "state": "open", "updated_at": "2026-11-22T00:00:00Z"},
    }, sort_keys=True)
    signature = "sha256=" + hmac.new(secret, body.encode(), hashlib.sha256).hexdigest()
    spool = f"{KILN_ROOT}/kiln/offline-intake"
    node.succeed(f"install -d -m 0700 -o kiln-implementation-coordinator -g kiln-implementation-ledger {spool}")
    node.succeed(f"printf %s {shlex.quote(secret.decode())} > {spool}/secret && chown kiln-implementation-coordinator {spool}/secret && chmod 0400 {spool}/secret")
    # Kiln's delivery queue schema (kiln-implementer src/queue.rs).
    enqueue = ("import sqlite3,sys; c=sqlite3.connect(sys.argv[1]); "
               "c.execute('CREATE TABLE IF NOT EXISTS implementation_deliveries (delivery_id TEXT PRIMARY KEY, event TEXT NOT NULL, signature TEXT NOT NULL, body BLOB NOT NULL, recorded_at_ms INTEGER NOT NULL)'); "
               "c.execute('INSERT INTO implementation_deliveries VALUES (?,?,?,?,?)', ('00000000-0000-4000-8000-000000000001','issues',sys.argv[2],sys.argv[3].encode(),1)); c.commit()")
    # The ledger's other writers run with UMask=0007; keep its files group-writable.
    node.succeed(f"runuser -u kiln-implementation-coordinator -- sh -c 'umask 0007; exec python3 -c \"$0\" \"$@\"' "
                 f"{shlex.quote(enqueue)} {spool}/queue.sqlite {shlex.quote(signature)} {shlex.quote(body)}")
    drained = node.succeed(f"runuser -u kiln-implementation-coordinator -- sh -c 'umask 0007; exec \"$@\"' sh {implementer} drain {common} "
                           f"--queue {spool}/queue.sqlite --secret-file {spool}/secret --policy {configuration}/github-policy.json "
                           "--maximum-deliveries 16 --limit 16")
    print(drained)
    assert kiln_status(node)["work"] == 1
    for stage in ("host-owner-admit", "host-owner-observe", "claim"):
        node.succeed(f"systemctl start kiln-implementation-{stage}.service")
    reference = json.loads(node.succeed(f"cat {KILN_ROOT}/controller/current.json"))["claim"]
    claim = json.loads(node.succeed(f"cat {KILN_ROOT}/controller/claims/{reference}"))
    print(claim)
    assert len(claim["identity"]) == 64 and claim["fence"] >= 1, claim
    node.succeed(f"test $(stat -c %u {KILN_ROOT}/controller/current.json) = 0")
    assert kiln_status(node)["attempts"] == 1
    return {"cohort": deployment["cohort"], "configuration": configuration, "implementer": implementer,
            "common": common, "claim": claim,
            "binding": f"{KILN_ROOT}/controller/bindings/{claim['identity']}-{claim['fence']}/dispatch"}
