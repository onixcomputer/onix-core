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
  receiptSchemaVersion = 1;
  canonicalThreshold = 1;
  nativeDesiredCount = 5;
  publicHttpsCount = 4;
  boundedExecRid = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo";
  artifactAuthRid = "rad:z4JGYYW7WsesXUq7MXVdx16Fawu2f";
  executionGraphRid = "rad:z2oYsb9jGTyp68BKYhzpivY1eK58a";
  durableFilePublicationRid = "rad:z3tAR4For7qw8ZirkJzoDw1VNDDLM";
  privateFixtureRid = "rad:z3t9ykR1HfG9UkyKoQQg5ikkzrTxg";
  reviewedCommit = "951c27f59003cea9bfdb40ed4d89653d50fada1f";
  sourceArchiveBlake3 = "2c1d8b5adc8d7384f48a6f8336165e38c3eb196337ebbd66707e157a64b63210";
  cairnArchiveReceiptBlake3 = "3a11ed34c922a32678f4e5e72bd9ea48b3e3d0eba35edf0c821c27f5a7920fe4";
  producerIdentityRevision = "8d6d95454c09449708e687b51e80c787750e75e3";
  publisherSigrefs = "8aa111383236ef76578edb18dbc5410395a42763";
  policyImplementationRevision = "8211b290622d7e8aa7f07198b125cd9169f59f0c";
  expectedAspenClosure = "/nix/store/j2mvzq86wwdrgna1972av3cm868rq9ni-nixos-system-aspen1-26.11.20260629.7a1a647";
  expectedDesktopClosure = "/nix/store/8zr3fdh5sf16d8bxjpgkgc4cg1m9snid-nixos-system-britton-desktop-26.11.20260629.7a1a647";
  expectedPublicRids = [
    boundedExecRid
    artifactAuthRid
    executionGraphRid
    durableFilePublicationRid
  ];
  expectedDelegates = [
    "did:key:z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx"
  ];
  requiredNonClaims = [
    "library-correctness"
    "consumer-correctness"
    "release-readiness"
    "seed-delegate-authority"
    "automatic-https-failover"
    "radicle-only-replica-bootstrap"
    "permanent-network-availability"
    "retention-or-deletion-authority"
  ];
  wasm = import ../lib/wasm.nix {
    plugins = self.packages.${system}.wasm-plugins;
  };
  receiptSource = ../evidence/radicle/durable-file-publication-source-admission-v1.ncl;
  receiptJsonPath = ../evidence/radicle/durable-file-publication-source-admission-v1.json;
  receiptHashPath = ../evidence/radicle/durable-file-publication-source-admission-v1.blake3;
  receipt = wasm.evalNickelFile receiptSource;
  receiptJson = builtins.fromJSON (builtins.readFile receiptJsonPath);
  expectedReceiptHash = lib.removeSuffix "\n" (builtins.readFile receiptHashPath);
  aspenConfig = self.nixosConfigurations.aspen1.config;
  desktopConfig = self.nixosConfigurations.britton-desktop.config;
  aspenPolicyCommand = builtins.unsafeDiscardStringContext aspenConfig.systemd.services.radicle-policy-reconcile.serviceConfig.ExecStart;
  desktopPolicyCommand = builtins.unsafeDiscardStringContext desktopConfig.systemd.services.radicle-policy-reconcile.serviceConfig.ExecStart;
  repositoryPath = lib.removePrefix "rad:" durableFilePublicationRid;
  aspenHttpsLocations = aspenConfig.services.nginx.virtualHosts."git.onix.computer".locations;
  policyDerivationValid =
    lib.hasInfix durableFilePublicationRid aspenPolicyCommand
    && lib.hasInfix durableFilePublicationRid desktopPolicyCommand
    && builtins.hasAttr "= /${repositoryPath}.git/info/refs" aspenHttpsLocations
    && builtins.hasAttr "= /${repositoryPath}.git/git-upload-pack" aspenHttpsLocations
    && !(builtins.hasAttr "= /${repositoryPath}.git/git-receive-pack" aspenHttpsLocations);
  receiptAccepted =
    candidate:
    candidate.schema_version == receiptSchemaVersion
    && candidate.receipt_type == "onix.radicle-durable-file-publication-source-admission.v1"
    && candidate.status == "accepted"
    && candidate.repository.rid == durableFilePublicationRid
    && candidate.repository.reviewed_commit == reviewedCommit
    && candidate.repository.source_archive_blake3 == sourceArchiveBlake3
    && candidate.repository.cairn_archive_receipt_blake3 == cairnArchiveReceiptBlake3
    && candidate.governance.identity_revision == producerIdentityRevision
    && candidate.governance.delegates == expectedDelegates
    && candidate.governance.threshold == canonicalThreshold
    && candidate.governance.signed_refs_feature == "parent"
    && candidate.governance.publisher_sigrefs == publisherSigrefs
    && candidate.policy.implementation_revision == policyImplementationRevision
    && candidate.policy.public_rids == expectedPublicRids
    && candidate.policy.private_rids == [ privateFixtureRid ]
    && candidate.policy.https_rids == expectedPublicRids
    && candidate.policy.ci_rids == [ boundedExecRid ]
    && candidate.deployment.aspen_closure == expectedAspenClosure
    && candidate.deployment.desktop_closure == expectedDesktopClosure
    && candidate.deployment.native_desired_count == nativeDesiredCount
    && candidate.deployment.public_https_count == publicHttpsCount
    && candidate.deployment.runtime_overrides == "absent"
    && candidate.deployment.desktop_bootstrap_transport == "private-ssh-checksum-verified"
    && candidate.probes.aspen_native == "verified"
    && candidate.probes.desktop_native == "verified"
    && candidate.probes.https == "verified"
    && candidate.probes.unknown_rid == "rejected"
    && candidate.probes.receive_pack == "rejected"
    && candidate.probes.wrong_service == "rejected"
    && candidate.probes.missing_object == "rejected"
    && candidate.authority_boundary.seed_credentials == [ "machine-scoped-radicle-node-key" ]
    && candidate.authority_boundary.delegate_credentials_absent
    && candidate.authority_boundary.protect_home
    && candidate.authority_boundary.no_new_privileges
    && candidate.authority_boundary.capability_bounding_set_empty
    && builtins.all (claim: builtins.elem claim candidate.non_claims) requiredNonClaims
    && builtins.all (path: !(lib.hasPrefix "/" path)) candidate.evidence;
  negativeReceipts = [
    (receipt // { status = "staged"; })
    (
      receipt
      // {
        governance = receipt.governance // {
          delegates = [ ];
          threshold = 0;
        };
      }
    )
    (
      receipt
      // {
        policy = receipt.policy // {
          public_rids = expectedPublicRids ++ [ durableFilePublicationRid ];
        };
      }
    )
    (
      receipt
      // {
        policy = receipt.policy // {
          public_rids = [
            boundedExecRid
            artifactAuthRid
            executionGraphRid
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
            durableFilePublicationRid
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
        deployment = receipt.deployment // {
          desktop_bootstrap_transport = "radicle-only";
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
    (
      receipt
      // {
        authority_boundary = receipt.authority_boundary // {
          delegate_credentials_absent = false;
        };
      }
    )
    (receipt // { non_claims = [ ]; })
    (receipt // { evidence = [ "/tmp/ambient-evidence" ]; })
  ];
in
{
  checks.radicle-durable-file-publication-source-admission =
    assert lib.assertMsg policyDerivationValid
      "durable-file-publication is not derived into both native policies and exact read-only HTTPS routes";
    assert lib.assertMsg (
      receipt == receiptJson
    ) "durable-file-publication admission Nickel and JSON evidence differ";
    assert lib.assertMsg (receiptAccepted receipt)
      "accepted durable-file-publication admission evidence failed validation";
    assert lib.assertMsg (builtins.all (
      candidate: !(receiptAccepted candidate)
    ) negativeReceipts) "unsafe durable-file-publication admission evidence was accepted";
    pkgs.runCommand "radicle-durable-file-publication-source-admission"
      {
        nativeBuildInputs = [ pkgs.b3sum ];
      }
      ''
        actual_hash="$(b3sum ${receiptJsonPath} | cut -d ' ' -f 1)"
        test "$actual_hash" = ${lib.escapeShellArg expectedReceiptHash}
        printf '%s\n' \
          'policy_derivation=accepted' \
          'receipt=accepted' \
          'negative_receipts=rejected' \
          'receipt_blake3=${expectedReceiptHash}' \
          > "$out"
      '';
}
