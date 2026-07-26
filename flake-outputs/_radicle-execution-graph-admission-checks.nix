# r[verify onix.radicle_source_admission.evidence]
{
  self,
  pkgs,
  lib,
  system,
  ...
}:
let
  receiptSchemaVersion = 1;
  canonicalThreshold = 2;
  nativeDesiredCount = 4;
  publicHttpsCount = 3;
  boundedExecRid = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo";
  artifactAuthRid = "rad:z4JGYYW7WsesXUq7MXVdx16Fawu2f";
  executionGraphRid = "rad:z2oYsb9jGTyp68BKYhzpivY1eK58a";
  privateFixtureRid = "rad:z3t9ykR1HfG9UkyKoQQg5ikkzrTxg";
  expectedPublicRids = [
    boundedExecRid
    artifactAuthRid
    executionGraphRid
  ];
  expectedDelegates = [
    "did:key:z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx"
    "did:key:z6MkjCqx5ksRqcDeNeuEnz53udbUHebRLHhddCxecWJu9koE"
    "did:key:z6MkmkA6sEzzMffaWqKEKJcDh8LjAzgrJLrTNi971KN3X6sh"
  ];
  requiredNonClaims = [
    "graph-correctness"
    "consumer-correctness"
    "release-readiness"
    "seed-delegate-authority"
    "automatic-https-failover"
    "whole-stack-github-independence"
  ];
  wasm = import ../lib/wasm.nix {
    plugins = self.packages.${system}.wasm-plugins;
  };
  receiptSource = ../evidence/radicle/execution-graph-source-admission-v1.ncl;
  receiptJsonPath = ../evidence/radicle/execution-graph-source-admission-v1.json;
  receiptHashPath = ../evidence/radicle/execution-graph-source-admission-v1.blake3;
  receipt = wasm.evalNickelFile receiptSource;
  receiptJson = builtins.fromJSON (builtins.readFile receiptJsonPath);
  expectedReceiptHash = lib.removeSuffix "\n" (builtins.readFile receiptHashPath);
  receiptAccepted =
    candidate:
    candidate.schema_version == receiptSchemaVersion
    && candidate.receipt_type == "onix.radicle-execution-graph-source-admission.v1"
    && candidate.status == "accepted"
    && candidate.repository.rid == executionGraphRid
    && candidate.repository.reviewed_commit == "03736f1ec46c377ff86b451260ad68aa70ff3b0b"
    &&
      candidate.repository.source_archive_blake3
      == "4b5aa3756369236fc82fbbf501d35993cfa208f142694cdd30ca370d6241192c"
    &&
      candidate.repository.publication_receipt_blake3
      == "5573a000f71f1992ed3aa6ddb1197aca29b2b551ef58643b5bd930bef78270cf"
    && candidate.governance.identity_revision == "d407356b5fd5465c62aca4d7d6c61156947cbac1"
    && candidate.governance.delegates == expectedDelegates
    && candidate.governance.threshold == canonicalThreshold
    && candidate.governance.signed_refs_feature == "parent"
    && candidate.policy.public_rids == expectedPublicRids
    && candidate.policy.private_rids == [ privateFixtureRid ]
    && candidate.policy.https_rids == expectedPublicRids
    && candidate.policy.ci_rids == [ boundedExecRid ]
    && candidate.deployment.native_desired_count == nativeDesiredCount
    && candidate.deployment.public_https_count == publicHttpsCount
    && candidate.deployment.runtime_overrides == "absent"
    && candidate.probes.aspen_native == "verified"
    && candidate.probes.desktop_native == "verified"
    && candidate.probes.https == "verified"
    && candidate.probes.unknown_rid == "rejected"
    && candidate.probes.receive_pack == "rejected"
    && candidate.probes.wrong_service == "rejected"
    && candidate.probes.missing_object == "rejected"
    && builtins.all (claim: builtins.elem claim candidate.non_claims) requiredNonClaims
    && builtins.all (path: !(lib.hasPrefix "/" path)) candidate.evidence;
  negativeReceipts = [
    (receipt // { status = "staged"; })
    (
      receipt
      // {
        governance = receipt.governance // {
          threshold = 1;
        };
      }
    )
    (
      receipt
      // {
        policy = receipt.policy // {
          public_rids = expectedPublicRids ++ [ executionGraphRid ];
        };
      }
    )
    (
      receipt
      // {
        policy = receipt.policy // {
          ci_rids = [
            boundedExecRid
            executionGraphRid
          ];
        };
      }
    )
    (
      receipt
      // {
        deployment = receipt.deployment // {
          runtime_overrides = "present";
        };
      }
    )
    (
      receipt
      // {
        probes = receipt.probes // {
          receive_pack = "accepted";
        };
      }
    )
    (receipt // { non_claims = [ ]; })
  ];
in
{
  checks.radicle-execution-graph-source-admission =
    assert lib.assertMsg (
      receipt == receiptJson
    ) "execution-graph admission Nickel and JSON evidence differ";
    assert lib.assertMsg (receiptAccepted receipt)
      "accepted execution-graph admission evidence failed validation";
    assert lib.assertMsg (builtins.all (
      candidate: !(receiptAccepted candidate)
    ) negativeReceipts) "unsafe execution-graph admission evidence was accepted";
    pkgs.runCommand "radicle-execution-graph-source-admission"
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
