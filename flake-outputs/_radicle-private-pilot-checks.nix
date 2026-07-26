# r[verify onix.radicle_private_pilot.evidence]
# r[verify onix.radicle_private_pilot.evidence.scenario.accepted]
{
  self,
  pkgs,
  lib,
  system,
  ...
}:
let
  receiptSchemaVersion = 1;
  nativeRepositoryCount = 4;
  authorizedAcquisitionCount = 2;
  deniedAcquisitionCount = 2;
  approvalThreshold = 1;
  incompleteAllowedPeerCount = 2;
  stateRecordCount = 303242;
  stateByteCount = 57970684391;
  recoveryRecordCount = 6;
  recoveryByteCount = 72363700;
  restoredRepositoryCount = 6763;
  httpOk = 200;
  httpNotFound = 404;
  boundedExecRid = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo";
  artifactAuthRid = "rad:z4JGYYW7WsesXUq7MXVdx16Fawu2f";
  executionGraphRid = "rad:z2oYsb9jGTyp68BKYhzpivY1eK58a";
  privateRid = "rad:z3t9ykR1HfG9UkyKoQQg5ikkzrTxg";
  publicRids = [
    boundedExecRid
    artifactAuthRid
    executionGraphRid
  ];
  privateCommit = "ff4ff027817465b1bb04251a8a98db42cc610b0c";
  privateSourceBlake3 = "514904bdcf5f23b0813c567efbc8b6732248de94482037a58011bfff3fc26853";
  privateIdentityRevision = "7fe3c9bd6a2d01a8317acb44ba386988375898da";
  privateIdentityRoot = "bf5e168201192881cf34e9ff7f7c39ee42dc7d62";
  privateIdentityBlake3 = "a080d88d7b9cd58bf08130308c487b968863191caafea7f7f0e973471a2ed3b2";
  privateSigrefs = "fc566eae3a5954df30d9499e0f85fe1b45a34d46";
  authorDid = "did:key:z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx";
  aspenNodeId = "z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8";
  desktopNodeId = "z6MkkQCj5EczNiVzDzCkX9ewHNJ7NDEXSKbuRiS1x7o72yeG";
  authorizedClientDid = "did:key:z6MkwGV7ypRii8RjoSotmUbuKU4MwGQf3iw8AdhuJkkyD4wd";
  deniedClientDid = "did:key:z6MksVCc4QAvmZrZXX2MWoGwo9XqDUbiFjsjDZuRZrbgEu6h";
  allowedPeers = [
    "did:key:${aspenNodeId}"
    "did:key:${desktopNodeId}"
    authorizedClientDid
  ];
  requiredNonClaims = [
    "production-secret-confidentiality"
    "global-metadata-secrecy"
    "traffic-analysis-resistance"
    "anonymity"
    "multi-delegate-private-governance"
    "secure-deletion"
    "automatic-failover"
    "geographic-independence"
    "source-correctness"
    "protocol-enforced-ci"
    "release-readiness"
    "whole-fleet-migration-readiness"
  ];
  receiptSource = ../evidence/radicle/private-pilot-v1.ncl;
  receiptJsonPath = ../evidence/radicle/private-pilot-v1.json;
  receiptHashPath = ../evidence/radicle/private-pilot-v1.blake3;
  wasm = import ../lib/wasm.nix {
    plugins = self.packages.${system}.wasm-plugins;
  };
  receipt = wasm.evalNickelFile receiptSource;
  receiptJson = builtins.fromJSON (builtins.readFile receiptJsonPath);
  expectedReceiptHash = lib.removeSuffix "\n" (builtins.readFile receiptHashPath);
  acquisitionAccepted =
    expectedSeed: candidate:
    candidate.seed_node_id == expectedSeed
    && candidate.client_did == authorizedClientDid
    && candidate.fresh_profile
    && candidate.direct_seed_only
    && candidate.commit == privateCommit
    && candidate.source_archive_blake3 == privateSourceBlake3;
  denialAccepted =
    expectedSeed: candidate:
    candidate.seed_node_id == expectedSeed
    && candidate.client_did == deniedClientDid
    && candidate.fresh_profile
    && candidate.inventory_private_rid_absent
    && candidate.clone_rejected
    && candidate.checkout_absent;
  seedAccepted =
    expectedHost: expectedNode: expectedFingerprint: candidate:
    candidate.host == expectedHost
    && candidate.node_id == expectedNode
    && candidate.node_fingerprint == expectedFingerprint
    && lib.hasPrefix "/nix/store/" candidate.system_closure
    && candidate.reconciled_repository_count == nativeRepositoryCount
    && candidate.identity_revision == privateIdentityRevision
    && candidate.delegate_sigrefs == privateSigrefs
    && candidate.commit == privateCommit
    && candidate.source_archive_blake3 == privateSourceBlake3;
  receiptAccepted =
    candidate:
    candidate.schema_version == receiptSchemaVersion
    && candidate.receipt_type == "onix.radicle-private-pilot.v1"
    && candidate.status == "accepted"
    && candidate.observed_date == "2026-07-25"
    && candidate.policy.implementation_revision == "956cc432ad990c346326718d3a94c512e9020427"
    && candidate.policy.public_rids == publicRids
    && candidate.policy.private_rids == [ privateRid ]
    && candidate.policy.https_rids == publicRids
    && candidate.policy.ci_rids == [ boundedExecRid ]
    && candidate.policy.signed_refs_feature == "parent"
    && candidate.publication.rid == privateRid
    && candidate.publication.visibility == "private"
    && candidate.publication.reviewed_commit == privateCommit
    && candidate.publication.source_archive_blake3 == privateSourceBlake3
    && candidate.publication.identity_revision == privateIdentityRevision
    && candidate.publication.identity_root == privateIdentityRoot
    && candidate.publication.identity_blake3 == privateIdentityBlake3
    && candidate.publication.delegate == authorDid
    && candidate.publication.approval_threshold == approvalThreshold
    && candidate.publication.delegate_sigrefs == privateSigrefs
    && candidate.publication.allowed_peers == allowedPeers
    && candidate.publication.denied_peer == deniedClientDid
    && candidate.publication.non_secret_fixture
    &&
      seedAccepted "aspen1" aspenNodeId "SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE"
        candidate.primary
    &&
      seedAccepted "britton-desktop" desktopNodeId "SHA256:JHQTPqoMr4kLqBsrAPSRNXUuzETiHAoiKBM/VWftmEg"
        candidate.replica
    && builtins.length candidate.authorized_acquisitions == authorizedAcquisitionCount
    && acquisitionAccepted aspenNodeId (builtins.elemAt candidate.authorized_acquisitions 0)
    && acquisitionAccepted desktopNodeId (builtins.elemAt candidate.authorized_acquisitions 1)
    && builtins.length candidate.denied_acquisitions == deniedAcquisitionCount
    && denialAccepted aspenNodeId (builtins.elemAt candidate.denied_acquisitions 0)
    && denialAccepted desktopNodeId (builtins.elemAt candidate.denied_acquisitions 1)
    && candidate.https.private_upload_pack_status == httpNotFound
    && candidate.https.private_receive_pack_status == httpNotFound
    && candidate.https.public_upload_pack_status == httpOk
    && candidate.backup.encrypted
    && candidate.backup.source_failure_domain == "aspen-primary-site"
    && candidate.backup.target_failure_domain == "britton-desktop-workstation"
    && candidate.backup.source_failure_domain != candidate.backup.target_failure_domain
    && candidate.backup.archive == "aspen1-britton-desktop-2026-07-25T22:22:31"
    &&
      candidate.backup.state_manifest_blake3
      == "915134d3d2245cf6b823558fa32abc04c04346ee05c635eae28600f78920bff1"
    && candidate.backup.state_records == stateRecordCount
    && candidate.backup.state_bytes == stateByteCount
    &&
      candidate.backup.recovery_manifest_blake3
      == "f07e19303e8880b01b2baac97cf11f2f207030fdbe64224d6d26e6a940e3dddd"
    && candidate.backup.recovery_records == recoveryRecordCount
    && candidate.backup.recovery_bytes == recoveryByteCount
    && candidate.recovery.result == "verified"
    && candidate.recovery.repository_count == restoredRepositoryCount
    && candidate.recovery.node_id == aspenNodeId
    && candidate.recovery.node_fingerprint == "SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE"
    && candidate.recovery.private_commit == privateCommit
    && candidate.recovery.private_identity_revision == privateIdentityRevision
    && candidate.recovery.private_sigrefs == privateSigrefs
    && candidate.recovery.private_source_blake3 == privateSourceBlake3
    && candidate.recovery.cleanup_verified
    && candidate.authority_boundary.seed_allowed_credentials == [ "machine-scoped-radicle-node-key" ]
    && candidate.authority_boundary.seed_forbidden_authorities_absent
    && candidate.authority_boundary.desktop_native_only
    && candidate.authority_boundary.private_https_absent
    && candidate.authority_boundary.private_ci_absent
    && candidate.authority_boundary.runtime_override_removed
    && builtins.all (claim: builtins.elem claim candidate.non_claims) requiredNonClaims
    && builtins.all (path: !(lib.hasPrefix "/" path)) candidate.evidence;
  negativeReceipts = [
    (receipt // { status = "rejected"; })
    (
      receipt
      // {
        publication = receipt.publication // {
          visibility = "public";
        };
      }
    )
    (
      receipt
      // {
        publication = receipt.publication // {
          allowed_peers = lib.take incompleteAllowedPeerCount allowedPeers;
        };
      }
    )
    (
      receipt
      // {
        policy = receipt.policy // {
          ci_rids = [
            boundedExecRid
            privateRid
          ];
        };
      }
    )
    (
      receipt
      // {
        denied_acquisitions = [
          ((builtins.elemAt receipt.denied_acquisitions 0) // { clone_rejected = false; })
          (builtins.elemAt receipt.denied_acquisitions 1)
        ];
      }
    )
    (
      receipt
      // {
        https = receipt.https // {
          private_upload_pack_status = httpOk;
        };
      }
    )
    (
      receipt
      // {
        backup = receipt.backup // {
          encrypted = false;
        };
      }
    )
    (
      receipt
      // {
        recovery = receipt.recovery // {
          private_commit = privateIdentityRevision;
        };
      }
    )
    (
      receipt
      // {
        recovery = receipt.recovery // {
          cleanup_verified = false;
        };
      }
    )
    (
      receipt
      // {
        authority_boundary = receipt.authority_boundary // {
          runtime_override_removed = false;
        };
      }
    )
    (receipt // { non_claims = [ ]; })
  ];
in
{
  checks.radicle-private-pilot =
    assert lib.assertMsg (receipt == receiptJson) "private pilot Nickel and JSON evidence differ";
    assert lib.assertMsg (receiptAccepted receipt)
      "accepted private pilot evidence failed deterministic validation";
    assert lib.assertMsg (builtins.all (
      candidate: !(receiptAccepted candidate)
    ) negativeReceipts) "unsafe private pilot evidence was accepted";
    pkgs.runCommand "radicle-private-pilot"
      {
        nativeBuildInputs = [ pkgs.b3sum ];
      }
      ''
        actual_hash="$(b3sum ${receiptJsonPath} | cut -d ' ' -f 1)"
        test "$actual_hash" = ${lib.escapeShellArg expectedReceiptHash}
        printf '%s\n' \
          'receipt=accepted' \
          'negative_receipts=rejected' \
          'receipt_blake3=${expectedReceiptHash}' \
          > "$out"
      '';
}
