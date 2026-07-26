# r[verify onix.radicle_source_admission.policy]
# r[verify onix.radicle_source_admission.derivation]
# r[verify onix.radicle_source_admission.validation]
# r[verify onix.radicle_source_admission.evidence]
{
  self,
  pkgs,
  lib,
  system,
  ...
}:
let
  boundedExecRid = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo";
  artifactAuthRid = "rad:z4JGYYW7WsesXUq7MXVdx16Fawu2f";
  artifactAuthCommit = "799459346d5416fbd7b9f55840a7371441b55afa";
  artifactAuthBlake3 = "246a7cad91e7e8a158e22da21f3bff3e61aa0431a58936b5a739178bc62064c7";
  policyRevision = "a3f5a18b36a0c874c1fce0d47acee19932f4d931";
  artifactAuthPublicationRevision = "e41340bec587b6d049b5cc518ec7db925dde84be";
  artifactAuthPublicationBlake3 = "e58a3de4d6b3b32a547c3cfe5c3e829292cda73891c7776f214f5d4edce10b1c";
  receiptSchemaVersion = 1;
  repositoryCount = 2;
  delegateCount = 3;
  approvalThreshold = 2;
  publicOriginCount = 1;
  httpNotFound = 404;
  expectedRepositories = [
    {
      name = "bounded-exec";
      rid = boundedExecRid;
      reviewed_commit = "29dac88ecded94457572db3fdfaaaab95fa91525";
      source_archive_blake3 = "4fbbf8f0749262469f00748e04c775180488dba800303f139172656d25931927";
    }
    {
      name = "artifact-auth";
      rid = artifactAuthRid;
      reviewed_commit = artifactAuthCommit;
      source_archive_blake3 = artifactAuthBlake3;
    }
  ];
  expectedDelegates = [
    "did:key:z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx"
    "did:key:z6MkjCqx5ksRqcDeNeuEnz53udbUHebRLHhddCxecWJu9koE"
    "did:key:z6MkmkA6sEzzMffaWqKEKJcDh8LjAzgrJLrTNi971KN3X6sh"
  ];
  requiredNonClaims = [
    "artifact-auth-source-correctness"
    "valence-behavior-correctness"
    "live-delegate-replacement"
    "third-delegate-live-convergence"
    "private-repository-confidentiality"
    "automatic-https-failover"
    "geographic-or-building-power-independence"
    "protocol-enforced-mandatory-ci"
    "release-readiness"
    "whole-stack-github-independence"
  ];
  wasm = import ../lib/wasm.nix {
    plugins = self.packages.${system}.wasm-plugins;
  };
  receiptSource = ../evidence/radicle/source-admission-v1.ncl;
  receiptJsonPath = ../evidence/radicle/source-admission-v1.json;
  receiptHashPath = ../evidence/radicle/source-admission-v1.blake3;
  receipt = wasm.evalNickelFile receiptSource;
  receiptJson = builtins.fromJSON (builtins.readFile receiptJsonPath);
  expectedReceiptHash = lib.removeSuffix "\n" (builtins.readFile receiptHashPath);
  endpointAccepted =
    endpoint: expectedHost: expectedNodeId: expectedFingerprint: expectedClientNid:
    endpoint.host == expectedHost
    && endpoint.node_id == expectedNodeId
    && endpoint.node_fingerprint == expectedFingerprint
    && lib.hasPrefix "/nix/store/" endpoint.system_closure
    && endpoint.reconciled_repository_count == repositoryCount
    && endpoint.client_nid == expectedClientNid
    && endpoint.commit == artifactAuthCommit
    && endpoint.source_archive_blake3 == artifactAuthBlake3
    && endpoint.undeclared_rid == "rejected"
    && endpoint.isolated_egress == "blocked"
    && endpoint.storage_access == "blocked"
    && endpoint.secret_access == "blocked";
  receiptAccepted =
    candidate:
    candidate.schema_version == receiptSchemaVersion
    && candidate.receipt_type == "onix.radicle-source-admission.v1"
    && candidate.status == "accepted"
    && candidate.observed_date == "2026-07-25"
    && candidate.policy.source_revision == policyRevision
    && candidate.policy.signed_refs_feature == "parent"
    && candidate.policy.repositories == expectedRepositories
    && candidate.policy.ci_rids == [ boundedExecRid ]
    && candidate.publication.repository == "artifact-auth"
    && candidate.publication.revision == artifactAuthPublicationRevision
    && candidate.publication.receipt_type == "artifact-auth.radicle-publication.v1"
    && candidate.publication.receipt_blake3 == artifactAuthPublicationBlake3
    && candidate.publication.status == "accepted"
    && builtins.length candidate.governance.delegates == delegateCount
    && candidate.governance.delegates == expectedDelegates
    && candidate.governance.approval_threshold == approvalThreshold
    && candidate.governance.signed_main_delegates == lib.take approvalThreshold expectedDelegates
    && candidate.governance.offline_delegate == lib.last expectedDelegates
    && candidate.governance.identity_revision == "c22900ae6b7b5637aa0e378fe00503cf02c6d1bf"
    && candidate.governance.identity_root == "e95f12e9791861f072e9a60f7d0d75f08428d721"
    &&
      candidate.governance.public_bundle_blake3
      == "7f96561a705151266e83641bdc53cf692518f0e5507f10acc3074c45d6ebca5f"
    &&
      endpointAccepted candidate.primary "aspen1" "z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8"
        "SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE"
        "z6MkkQEGLf4NPLDzwguTX7LWQYxQvWnbjFvh2mECYHzuPPvb"
    &&
      endpointAccepted candidate.replica "britton-desktop"
        "z6MkkQCj5EczNiVzDzCkX9ewHNJ7NDEXSKbuRiS1x7o72yeG"
        "SHA256:JHQTPqoMr4kLqBsrAPSRNXUuzETiHAoiKBM/VWftmEg"
        "z6Mku6MfTxgiBW2gtDpAJqk6Cf6FStVbNx4JrcyDjb9bUTqQ"
    && candidate.https.url == "https://git.onix.computer/z4JGYYW7WsesXUq7MXVdx16Fawu2f.git"
    && candidate.https.commit == artifactAuthCommit
    && candidate.https.source_archive_blake3 == artifactAuthBlake3
    && candidate.https.unknown_rid_status == httpNotFound
    && candidate.https.receive_pack_status == httpNotFound
    && candidate.https.root_status == httpNotFound
    && candidate.https.public_origin_count == publicOriginCount
    && candidate.authority_boundary.seed_allowed_credentials == [ "machine-scoped-radicle-node-key" ]
    && candidate.authority_boundary.seed_forbidden_authorities_absent
    && candidate.authority_boundary.ci_rids == [ boundedExecRid ]
    && !candidate.authority_boundary.artifact_auth_ci_enabled
    && candidate.authority_boundary.desktop_native_only
    && builtins.all (claim: builtins.elem claim candidate.non_claims) requiredNonClaims
    && builtins.all (path: !(lib.hasPrefix "/" path)) candidate.evidence;
  negativeReceipts = [
    (receipt // { status = "rejected"; })
    (
      receipt
      // {
        publication = receipt.publication // {
          receipt_blake3 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
        };
      }
    )
    (
      receipt
      // {
        policy = receipt.policy // {
          repositories = receipt.policy.repositories ++ [
            {
              name = "unknown";
              rid = "rad:z3gqcJUoA1n9HaHKufZs5FCSGazv5";
              reviewed_commit = artifactAuthCommit;
              source_archive_blake3 = artifactAuthBlake3;
            }
          ];
        };
      }
    )
    (
      receipt
      // {
        policy = receipt.policy // {
          ci_rids = [
            boundedExecRid
            artifactAuthRid
          ];
        };
      }
    )
    (
      receipt
      // {
        replica = receipt.replica // {
          reconciled_repository_count = repositoryCount + 1;
        };
      }
    )
    (
      receipt
      // {
        https = receipt.https // {
          url = "https://github.com/OnixResearch/artifact-auth";
        };
      }
    )
    (
      receipt
      // {
        authority_boundary = receipt.authority_boundary // {
          artifact_auth_ci_enabled = true;
        };
      }
    )
    (receipt // { non_claims = [ ]; })
  ];
in
{
  checks.radicle-source-admission =
    assert lib.assertMsg (receipt == receiptJson) "source admission Nickel and JSON evidence differ";
    assert lib.assertMsg (receiptAccepted receipt)
      "accepted source admission evidence failed deterministic validation";
    assert lib.assertMsg (builtins.all (
      candidate: !(receiptAccepted candidate)
    ) negativeReceipts) "unsafe source admission evidence was accepted";
    pkgs.runCommand "radicle-source-admission"
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
