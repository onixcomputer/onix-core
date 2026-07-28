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
  producerThreshold = 1;
  nativePublicCount = 4;
  publicHttpsCount = 4;
  sourceArchiveBytes = 1781760;
  boundedExecRid = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo";
  artifactAuthRid = "rad:z4JGYYW7WsesXUq7MXVdx16Fawu2f";
  executionGraphRid = "rad:z2oYsb9jGTyp68BKYhzpivY1eK58a";
  choregraphRid = "rad:zL2ncTUeASVYwcoGkEXv9JKgGbAF";
  privateFixtureRid = "rad:z3t9ykR1HfG9UkyKoQQg5ikkzrTxg";
  expectedPublicRids = [
    boundedExecRid
    artifactAuthRid
    executionGraphRid
    choregraphRid
  ];
  expectedDelegates = [
    "did:key:z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx"
  ];
  requiredNonClaims = [
    "choregraph-correctness"
    "consumer-correctness"
    "release-eligibility"
    "seed-delegate-authority"
    "indefinite-availability"
    "whole-stack-correctness"
  ];
  wasm = import ../lib/wasm.nix {
    plugins = self.packages.${system}.wasm-plugins;
  };
  receiptSource = ../evidence/radicle/choregraph-source-admission-v1.ncl;
  receiptJsonPath = ../evidence/radicle/choregraph-source-admission-v1.json;
  receiptHashPath = ../evidence/radicle/choregraph-source-admission-v1.blake3;
  receipt = wasm.evalNickelFile receiptSource;
  receiptJson = builtins.fromJSON (builtins.readFile receiptJsonPath);
  expectedReceiptHash = lib.removeSuffix "\n" (builtins.readFile receiptHashPath);
  receiptAccepted =
    candidate:
    candidate.schema_version == receiptSchemaVersion
    && candidate.receipt_type == "onix.radicle-choregraph-source-admission.v1"
    && candidate.status == "accepted"
    && candidate.repository.rid == choregraphRid
    && candidate.repository.reviewed_commit == "fc47c5f4ecbb7b4341af690fa42199f25d57f54c"
    &&
      candidate.repository.source_archive_blake3
      == "dcb1faf95a7487145496ce986ae1639908600ace5bd77c4d96a37a530a7538a5"
    && candidate.repository.source_archive_bytes == sourceArchiveBytes
    &&
      candidate.repository.release_bundle_blake3
      == "a2ac1336679542fa9573b356daddc18266fdda8147ddbe28f85aa37d135030d9"
    &&
      candidate.repository.candidate_blake3
      == "e4b5cd7bd77d78c20cf8b96cd0c038144028d2287000757c8ab68f5f5dfdff1a"
    && candidate.repository.license == "AGPL-3.0-or-later"
    && candidate.producer.delegates == expectedDelegates
    && candidate.producer.threshold == producerThreshold
    && candidate.producer.signed_refs_feature == "parent"
    && candidate.producer.publication_authority == "operator-authorized"
    && candidate.policy.public_rids == expectedPublicRids
    && candidate.policy.private_rids == [ privateFixtureRid ]
    && candidate.policy.https_rids == expectedPublicRids
    && candidate.policy.ci_rids == [ boundedExecRid ]
    && candidate.deployment.native_public_count == nativePublicCount
    && candidate.deployment.public_https_count == publicHttpsCount
    && candidate.deployment.runtime_overrides == "absent"
    && candidate.probes.aspen_native == "verified"
    && candidate.probes.desktop_native == "verified"
    && candidate.probes.independent_replica == "paintedlife-verified"
    && candidate.probes.https == "verified"
    && candidate.probes.archive == "verified"
    && candidate.probes.git_fsck == "verified"
    && candidate.probes.unknown_rid == "rejected-404"
    && candidate.probes.receive_pack == "rejected-404"
    && candidate.probes.wrong_service == "rejected-404"
    && candidate.probes.endpoint_root == "rejected-404"
    && builtins.all (claim: builtins.elem claim candidate.non_claims) requiredNonClaims
    && builtins.all (path: !(lib.hasPrefix "/" path)) candidate.evidence;
  negativeReceipts = [
    (receipt // { status = "staged"; })
    (
      receipt
      // {
        repository = receipt.repository // {
          reviewed_commit = "main";
        };
      }
    )
    (
      receipt
      // {
        repository = receipt.repository // {
          license = "MIT";
        };
      }
    )
    (
      receipt
      // {
        producer = receipt.producer // {
          signed_refs_feature = "root";
        };
      }
    )
    (
      receipt
      // {
        policy = receipt.policy // {
          public_rids = expectedPublicRids ++ [ choregraphRid ];
        };
      }
    )
    (
      receipt
      // {
        policy = receipt.policy // {
          ci_rids = [
            boundedExecRid
            choregraphRid
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
  checks.radicle-choregraph-source-admission =
    assert lib.assertMsg (
      receipt == receiptJson
    ) "Choregraph admission Nickel and JSON evidence differ";
    assert lib.assertMsg (receiptAccepted receipt)
      "accepted Choregraph admission evidence failed validation";
    assert lib.assertMsg (builtins.all (
      candidate: !(receiptAccepted candidate)
    ) negativeReceipts) "unsafe Choregraph admission evidence was accepted";
    pkgs.runCommand "radicle-choregraph-source-admission"
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
