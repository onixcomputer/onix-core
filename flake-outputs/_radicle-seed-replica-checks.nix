# r[verify onix.radicle_replica.configuration]
# r[verify onix.radicle_replica.validation]
# r[verify onix.radicle_replica.authority]
{
  self,
  pkgs,
  lib,
  system,
  ...
}:
let
  reviewedNodeVersion = "1.9.1";
  rustEdition = "2021";
  rejectedNodeVersion = "1.9.0";
  expectedHost = "britton-desktop";
  unexpectedHost = "aspen1";
  deploymentTarget = "root@100.110.43.11";
  nodeAddress = "100.110.43.11";
  nodePort = 8776;
  wrongNodePort = 8777;
  nodeInterface = "tailscale0";
  stateDirectory = "/var/lib/radicle";
  stateDataset = "datapool/radicle-seed";
  stateQuotaGiB = 64;
  oversizedStateQuotaGiB = 65;
  expectedNodeFingerprint = "SHA256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
  bootstrapNodeFingerprint = "SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE";
  pilotRepository = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo";
  artifactAuthRepository = "rad:z4JGYYW7WsesXUq7MXVdx16Fawu2f";
  executionGraphRepository = "rad:z2oYsb9jGTyp68BKYhzpivY1eK58a";
  governedRepositories = [
    pilotRepository
    artifactAuthRepository
    executionGraphRepository
  ];
  expectedCommit = "29dac88ecded94457572db3fdfaaaab95fa91525";
  absentObject = "1111111111111111111111111111111111111111";
  inheritedRepository = "rad:z3gqcJUoA1n9HaHKufZs5FCSGazv5";
  privateCredentialName = "dev.radicle.node.secret";
  loopbackAddress = "127.0.0.1";
  disabledHttpPort = 8080;
  disabledHttpsOriginPort = 8081;

  nodePackage = self.packages.${system}.radicle-node;
  httpdPackage = self.packages.${system}.radicle-httpd;
  policyReconciler = import ../modules/radicle-node/policy-reconciler.nix { inherit pkgs; };
  validateSettings = import ../modules/radicle-seed-replica/validate-settings.nix { inherit lib; };
  mkNixosConfig = import ../modules/radicle-node/mk-nixos-config.nix { inherit lib; };
  mkIdentityVerifierService =
    import ../modules/radicle-seed-replica/mk-identity-verifier-service.nix
      { inherit lib; };

  positiveSettings = {
    inherit
      expectedHost
      deploymentTarget
      expectedNodeFingerprint
      stateDirectory
      stateDataset
      stateQuotaGiB
      ;
    alias = "britton-desktop-radicle";
    failureDomain = "britton-desktop-workstation";
    monitoringRequired = true;
    nodeListenAddress = nodeAddress;
    nodeListenPort = nodePort;
    nodeFirewallInterface = nodeInterface;
    externalAddress = "${nodeAddress}:${toString nodePort}";
    seedRepositories = governedRepositories;
    minimumSignedRefsFeature = "parent";
  };

  validate =
    settings: packageVersion: actualHost:
    validateSettings { inherit settings packageVersion actualHost; };

  positiveValidationErrors = validate positiveSettings nodePackage.version expectedHost;
  negativeCases = [
    {
      name = "old-package";
      settings = positiveSettings;
      packageVersion = rejectedNodeVersion;
      actualHost = expectedHost;
      expected = reviewedNodeVersion;
    }
    {
      name = "wrong-host";
      settings = positiveSettings // {
        expectedHost = unexpectedHost;
      };
      packageVersion = nodePackage.version;
      actualHost = unexpectedHost;
      expected = "only on britton-desktop";
    }
    {
      name = "wrong-target";
      settings = positiveSettings // {
        deploymentTarget = "root@britton-desktop.local";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = deploymentTarget;
    }
    {
      name = "primary-failure-domain";
      settings = positiveSettings // {
        failureDomain = "aspen-primary-site";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "reviewed desktop failure domain";
    }
    {
      name = "missing-alias";
      settings = positiveSettings // {
        alias = "";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "alias must not be empty";
    }
    {
      name = "monitoring-disabled";
      settings = positiveSettings // {
        monitoringRequired = false;
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "monitoring must remain required";
    }
    {
      name = "wildcard-listener";
      settings = positiveSettings // {
        nodeListenAddress = "0.0.0.0";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = nodeAddress;
    }
    {
      name = "wrong-port";
      settings = positiveSettings // {
        nodeListenPort = wrongNodePort;
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = toString nodePort;
    }
    {
      name = "wrong-interface";
      settings = positiveSettings // {
        nodeFirewallInterface = "eth0";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = nodeInterface;
    }
    {
      name = "wrong-advertised-address";
      settings = positiveSettings // {
        externalAddress = "${loopbackAddress}:${toString nodePort}";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "reviewed listener";
    }
    {
      name = "malformed-rid";
      settings = positiveSettings // {
        seedRepositories = [ "not-a-rid" ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "canonical public rad:z IDs";
    }
    {
      name = "duplicate-rid";
      settings = positiveSettings // {
        seedRepositories = [
          pilotRepository
          pilotRepository
        ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "must not contain duplicates";
    }
    {
      name = "missing-bounded-exec-rid";
      settings = positiveSettings // {
        seedRepositories = [
          artifactAuthRepository
          executionGraphRepository
        ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "exactly the governed Bounded Exec, artifact-auth, and execution-graph RIDs";
    }
    {
      name = "missing-artifact-auth-rid";
      settings = positiveSettings // {
        seedRepositories = [
          pilotRepository
          executionGraphRepository
        ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "exactly the governed Bounded Exec, artifact-auth, and execution-graph RIDs";
    }
    {
      name = "missing-execution-graph-rid";
      settings = positiveSettings // {
        seedRepositories = [
          pilotRepository
          artifactAuthRepository
        ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "exactly the governed Bounded Exec, artifact-auth, and execution-graph RIDs";
    }
    {
      name = "undeclared-fourth-rid";
      settings = positiveSettings // {
        seedRepositories = governedRepositories ++ [ inheritedRepository ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "exactly the governed Bounded Exec, artifact-auth, and execution-graph RIDs";
    }
    {
      name = "wrong-state-directory";
      settings = positiveSettings // {
        stateDirectory = "/var/lib/radicle-shared";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = stateDirectory;
    }
    {
      name = "wrong-dataset";
      settings = positiveSettings // {
        stateDataset = "datapool/radicle-backup";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = stateDataset;
    }
    {
      name = "oversized-quota";
      settings = positiveSettings // {
        stateQuotaGiB = oversizedStateQuotaGiB;
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "no greater than ${toString stateQuotaGiB} GiB";
    }
    {
      name = "weak-signed-refs";
      settings = positiveSettings // {
        minimumSignedRefsFeature = "leaf";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "must remain parent";
    }
    {
      name = "malformed-fingerprint";
      settings = positiveSettings // {
        expectedNodeFingerprint = "not-a-fingerprint";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "OpenSSH SHA256 fingerprint";
    }
    {
      name = "bootstrap-key-reuse";
      settings = positiveSettings // {
        expectedNodeFingerprint = bootstrapNodeFingerprint;
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "must not reuse the Aspen1 node identity";
    }
  ];
  negativeCasesValid = builtins.all (
    case:
    let
      errors = validate case.settings case.packageVersion case.actualHost;
    in
    errors != [ ] && builtins.any (error: lib.hasInfix case.expected error) errors
  ) negativeCases;

  loweredConfig = mkNixosConfig {
    settings = {
      inherit (positiveSettings)
        alias
        externalAddress
        nodeListenAddress
        nodeListenPort
        nodeFirewallInterface
        seedRepositories
        ;
      httpdEnabled = false;
      httpListenAddress = loopbackAddress;
      httpListenPort = disabledHttpPort;
      httpsEnabled = false;
      httpsServerName = null;
      httpsTransport = "cloudflare-tunnel";
      httpsOriginListenAddress = loopbackAddress;
      httpsOriginListenPort = disabledHttpsOriginPort;
      httpsGitRepositories = [ ];
      pinnedRepositories = [ ];
    };
    inherit nodePackage httpdPackage policyReconciler;
    privateKeyPath = "/run/credentials/radicle-node.service/${privateCredentialName}";
    publicKeyPath = "/var/lib/radicle/keys/radicle.pub";
    configFile = "/var/lib/radicle/config.json";
  };
  nativeOnlyObservations = {
    httpdDisabled = loweredConfig.services.radicle.httpd.enable == false;
    nativeListenerAddressExact = loweredConfig.services.radicle.node.listenAddress == nodeAddress;
    nativeListenerPortExact = loweredConfig.services.radicle.node.listenPort == nodePort;
    defaultBlock = loweredConfig.services.radicle.settings.node.seedingPolicy.default == "block";
    firewallInterfaceExact =
      loweredConfig.networking.firewall.interfaces.${nodeInterface}.allowedTCPPorts == [ nodePort ];
    homeProtected = loweredConfig.systemd.services.radicle-node.serviceConfig.ProtectHome;
    privilegeEscalationDenied =
      loweredConfig.systemd.services.radicle-node.serviceConfig.NoNewPrivileges;
    reconcilerNetworkDenied =
      loweredConfig.systemd.services.radicle-policy-reconcile.serviceConfig.RestrictAddressFamilies
      == [ "AF_UNIX" ];
  };
  nativeOnlyPolicyValid = builtins.all lib.id (builtins.attrValues nativeOnlyObservations);

  identityVerifierService = mkIdentityVerifierService {
    identityVerifier = "/identity-verifier";
    expectedFingerprint = expectedNodeFingerprint;
    publicKeyPath = "/public-key";
    privateKeyPath = "/private-key";
  };
  identityVerifierServiceObservations = {
    capabilityBoundingSetEmpty = identityVerifierService.serviceConfig.CapabilityBoundingSet == "";
    privateNetworkEnabled = identityVerifierService.serviceConfig.PrivateNetwork;
    homeProtected = identityVerifierService.serviceConfig.ProtectHome;
    privilegeEscalationDenied = identityVerifierService.serviceConfig.NoNewPrivileges;
    addressFamiliesLocalOnly =
      identityVerifierService.serviceConfig.RestrictAddressFamilies == [ "AF_UNIX" ];
    credentialExact =
      identityVerifierService.serviceConfig.LoadCredential == [
        "${privateCredentialName}:/private-key"
      ];
  };
  identityVerifierServicePolicyValid = builtins.all lib.id (
    builtins.attrValues identityVerifierServiceObservations
  );

  plugins = self.packages.${system}.wasm-plugins;
  wasm = import ../lib/wasm.nix { inherit plugins; };
  schemaValidation = wasm.evalNickelFile ../inventory/services/fixtures/radicle-seed-replica-validation.ncl;
  schemaExpectedNegativeFields = builtins.attrNames positiveSettings;
  missingSchemaNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) schemaValidation.negative)
  ) schemaExpectedNegativeFields;
  schemaValidationValid = schemaValidation.positive == [ ] && missingSchemaNegativeFields == [ ];

  replicaReceiptSource = ../evidence/radicle/secondary-seed-v1.ncl;
  replicaReceiptJsonPath = ../evidence/radicle/secondary-seed-v1.json;
  replicaReceiptHashPath = ../evidence/radicle/secondary-seed-v1.blake3;
  replicaReceipt = wasm.evalNickelFile replicaReceiptSource;
  replicaReceiptJson = builtins.fromJSON (builtins.readFile replicaReceiptJsonPath);
  replicaReceiptExpectedHash = lib.removeSuffix "\n" (builtins.readFile replicaReceiptHashPath);
  receiptSchemaVersion = 1;
  expectedPersistentSeedCount = 2;
  singleSeedCount = 1;
  expectedHttpsMissingRevisionStatus = 500;
  expectedReplicaPolicyRevision = "3855bd216beb12c910a4c5e7c5920d4de34ea06e";
  expectedReplicaNodeId = "z6MkkQCj5EczNiVzDzCkX9ewHNJ7NDEXSKbuRiS1x7o72yeG";
  expectedReplicaFingerprint = "SHA256:JHQTPqoMr4kLqBsrAPSRNXUuzETiHAoiKBM/VWftmEg";
  expectedStateQuotaBytes = 68719476736;
  expectedStateRecordsizeBytes = 131072;
  expectedNodeStorePath = "/nix/store/r2hjw60rdpb3faxa6xglywxl77rx9ql2-radicle-node-1.9.1";
  expectedReconcilerStorePath = "/nix/store/9zqa4y0vlh39qfca4rz6a9vn85l75nrl-radicle-policy-reconciler";
  expectedIdentityVerifierStorePath = "/nix/store/i0ah82cdjqpch0fjwi37m4vlfnpvc0rk-radicle-replica-identity-verify";
  expectedReplicaClosure = "/nix/store/p6p9sm4c1ghfwczcyzykvbzsb8q6kg3b-nixos-system-britton-desktop-26.11.20260629.7a1a647";
  expectedReplicaAddress = "${nodeAddress}:${toString nodePort}";
  expectedSourceArchiveBlake3 = "4fbbf8f0749262469f00748e04c775180488dba800303f139172656d25931927";
  expectedReplicaTopFields = lib.sort lib.lessThan [
    "authority_boundary"
    "availability"
    "evidence"
    "identity"
    "machine"
    "monitoring"
    "network"
    "non_claims"
    "observed_date"
    "package"
    "policy"
    "receipt_type"
    "recovery"
    "rejection_probes"
    "repository"
    "schema_version"
    "services"
    "state"
    "status"
  ];
  requiredReplicaNonClaims = [
    "second-public-https-origin"
    "automatic-https-failover"
    "geographic-or-building-power-independence"
    "host-root-isolation"
    "private-repository-confidentiality"
    "secondary-seed-destructive-restore"
    "repository-source-correctness"
    "ci-correctness"
    "canonical-ref-enforcement-by-seed"
    "release-readiness"
    "whole-stack-github-independence"
  ];
  validateReplicaReceipt =
    receipt:
    let
      rejectUnless = condition: message: lib.optional (!condition) message;
      actualTopFields = lib.sort lib.lessThan (builtins.attrNames receipt);
      hasRequiredTopFields = builtins.all (
        field: builtins.hasAttr field receipt
      ) expectedReplicaTopFields;
    in
    if !hasRequiredTopFields then
      [ "replica receipt is missing required top-level fields" ]
    else
      lib.concatLists [
        (rejectUnless (
          actualTopFields == expectedReplicaTopFields
        ) "replica receipt top-level field set must be exact and secret-free")
        (rejectUnless (
          receipt.schema_version == receiptSchemaVersion
          && receipt.receipt_type == "onix.radicle.replica.v1"
          && receipt.status == "accepted"
          && receipt.observed_date == "2026-07-25"
        ) "replica receipt identity or acceptance status is invalid")
        (rejectUnless (
          receipt.policy.source_revision == expectedReplicaPolicyRevision
          && receipt.policy.check == "checks.x86_64-linux.radicle-seed-replica"
          && lib.versionAtLeast receipt.policy.minimum_node_version reviewedNodeVersion
          && receipt.policy.minimum_signed_refs_feature == "parent"
        ) "replica receipt policy revision, check, package bound, or signed refs is invalid")
        (rejectUnless (
          receipt.package.node_version == reviewedNodeVersion
          && receipt.package.node_store_path == expectedNodeStorePath
          && receipt.package.reconciler_store_path == expectedReconcilerStorePath
          && receipt.package.identity_verifier_store_path == expectedIdentityVerifierStorePath
        ) "replica receipt package identity is invalid")
        (rejectUnless (
          receipt.machine.host == expectedHost
          && receipt.machine.deployment_target == deploymentTarget
          && receipt.machine.address == nodeAddress
          && receipt.machine.failure_domain == "britton-desktop-workstation"
          && receipt.machine.primary_failure_domain == "aspen-primary-site"
          && receipt.machine.failure_domain != receipt.machine.primary_failure_domain
          && receipt.machine.independent_machine_and_storage
          && receipt.machine.system_closure == expectedReplicaClosure
        ) "replica receipt machine or failure-domain evidence is invalid")
        (rejectUnless (
          receipt.identity.node_id == expectedReplicaNodeId
          && receipt.identity.ssh_fingerprint == expectedReplicaFingerprint
          && receipt.identity.distinct_from_primary
          && receipt.identity.key_custody == "clan-encrypted-machine-variable"
          && receipt.identity.startup_verification == "private-public-pair-and-pinned-fingerprint"
        ) "replica receipt identity or key-custody evidence is invalid")
        (rejectUnless (
          receipt.repository.rid == pilotRepository
          && receipt.repository.visibility == "public"
          && receipt.repository.default_branch == "main"
          && receipt.repository.expected_commit == expectedCommit
          && receipt.repository.observed_commit == expectedCommit
          && receipt.repository.object_type == "commit"
          && receipt.repository.source_archive_blake3 == expectedSourceArchiveBlake3
        ) "replica receipt repository identity, object, or source hash is invalid")
        (rejectUnless (
          receipt.network.native_address == expectedReplicaAddress
          && receipt.network.firewall_interface == nodeInterface
          && !receipt.network.wildcard_listener
          && !receipt.network.http_enabled
          && !receipt.network.https_enabled
          && !receipt.network.public_ingress_enabled
        ) "replica receipt network evidence widens the native-only boundary")
        (rejectUnless (
          receipt.state.directory == stateDirectory
          && receipt.state.dataset == stateDataset
          && receipt.state.quota_bytes == expectedStateQuotaBytes
          && receipt.state.recordsize_bytes == expectedStateRecordsizeBytes
          && receipt.state.migration_source_records == receipt.state.migration_target_records
          && receipt.state.migration_checksum_comparison == "verified"
          && receipt.state.migration_cleanup == "verified"
        ) "replica receipt storage bound or migration evidence is invalid")
        (rejectUnless (
          receipt.services.node == "active-and-enabled"
          && receipt.services.policy_timer == "active-and-enabled"
          && receipt.services.identity_verifier == "verified-before-each-observed-start"
          && receipt.services.restart_continuity == "verified"
          && receipt.services.reconciled_repository_count == 1
        ) "replica receipt service or restart evidence is invalid")
        (rejectUnless (
          receipt.authority_boundary.allowed_credentials == [ "machine-scoped-radicle-node-key" ]
          && receipt.authority_boundary.forbidden_authorities_absent
          && receipt.authority_boundary.home_protected
          && receipt.authority_boundary.secret_tree_inaccessible
          && receipt.authority_boundary.node_capability_bounding_set_empty
          && receipt.authority_boundary.verifier_capability_bounding_set_empty
        ) "replica receipt least-authority evidence is invalid")
        (rejectUnless (
          receipt.availability.persistent_seed_count == expectedPersistentSeedCount
          && builtins.length receipt.availability.distinct_failure_domains == expectedPersistentSeedCount
          &&
            lib.unique receipt.availability.distinct_failure_domains
            == receipt.availability.distinct_failure_domains
          && builtins.elem "aspen-primary-site" receipt.availability.distinct_failure_domains
          && builtins.elem "britton-desktop-workstation" receipt.availability.distinct_failure_domains
          && receipt.availability.primary_node_stopped
          && receipt.availability.operator_node_stopped
          && receipt.availability.primary_node_restored
          && receipt.availability.client_egress_allowlist == [ "${nodeAddress}/32" ]
          && receipt.availability.signed_refs_feature == "parent"
          && receipt.availability.commit == expectedCommit
          && receipt.availability.source_archive_blake3 == expectedSourceArchiveBlake3
          && receipt.availability.public_fallback_blocked
          && receipt.availability.primary_fallback_blocked
        ) "replica receipt independent-availability evidence is invalid")
        (rejectUnless (
          receipt.rejection_probes.native_undeclared_rid == "rejected"
          && receipt.rejection_probes.native_missing_object == "rejected"
          && receipt.rejection_probes.https_missing_revision == "rejected"
          && receipt.rejection_probes.https_missing_revision_status == expectedHttpsMissingRevisionStatus
          && receipt.rejection_probes.storage_access == "blocked"
          && receipt.rejection_probes.secret_access == "blocked"
        ) "replica receipt negative-probe evidence is invalid")
        (rejectUnless (
          receipt.monitoring.prometheus == "active"
          && receipt.monitoring.systemd_exporter == "active"
          && receipt.monitoring.node_metric == "present"
          && receipt.monitoring.policy_metric == "present"
        ) "replica receipt monitoring evidence is invalid")
        (rejectUnless (
          receipt.recovery.machine_key_encrypted_at_rest
          && receipt.recovery.state_reconstructible_from_primary
          && !receipt.recovery.destructive_restore_exercised
          && receipt.recovery.primary_full_restore_receipt == "onix.radicle.bootstrap.v1"
        ) "replica receipt recovery boundary is invalid")
        (rejectUnless (builtins.all (
          claim: builtins.elem claim receipt.non_claims
        ) requiredReplicaNonClaims) "replica receipt omits required non-claims")
        (rejectUnless (builtins.all (
          path: !(lib.hasPrefix "/" path)
        ) receipt.evidence) "replica receipt evidence paths must be repository-relative")
      ];
  replicaReceiptValidationErrors = validateReplicaReceipt replicaReceipt;
  negativeReplicaReceiptCases = [
    {
      name = "single-seed";
      receipt = replicaReceipt // {
        availability = replicaReceipt.availability // {
          persistent_seed_count = singleSeedCount;
        };
      };
      expected = "independent-availability";
    }
    {
      name = "same-failure-domain";
      receipt = replicaReceipt // {
        availability = replicaReceipt.availability // {
          distinct_failure_domains = [
            "aspen-primary-site"
            "aspen-primary-site"
          ];
        };
      };
      expected = "independent-availability";
    }
    {
      name = "public-http";
      receipt = replicaReceipt // {
        network = replicaReceipt.network // {
          http_enabled = true;
        };
      };
      expected = "native-only boundary";
    }
    {
      name = "weak-signed-refs";
      receipt = replicaReceipt // {
        policy = replicaReceipt.policy // {
          minimum_signed_refs_feature = "leaf";
        };
      };
      expected = "signed refs";
    }
    {
      name = "changed-commit";
      receipt = replicaReceipt // {
        repository = replicaReceipt.repository // {
          observed_commit = absentObject;
        };
      };
      expected = "repository identity";
    }
    {
      name = "authority-present";
      receipt = replicaReceipt // {
        authority_boundary = replicaReceipt.authority_boundary // {
          forbidden_authorities_absent = false;
        };
      };
      expected = "least-authority";
    }
    {
      name = "primary-not-restored";
      receipt = replicaReceipt // {
        availability = replicaReceipt.availability // {
          primary_node_restored = false;
        };
      };
      expected = "independent-availability";
    }
    {
      name = "missing-non-claim";
      receipt = replicaReceipt // {
        non_claims = builtins.filter (
          claim: claim != "geographic-or-building-power-independence"
        ) replicaReceipt.non_claims;
      };
      expected = "required non-claims";
    }
    {
      name = "secret-field";
      receipt = replicaReceipt // {
        private_key = "forbidden";
      };
      expected = "secret-free";
    }
  ];
  negativeReplicaReceiptCasesValid = builtins.all (
    case:
    let
      errors = validateReplicaReceipt case.receipt;
    in
    errors != [ ] && builtins.any (error: lib.hasInfix case.expected error) errors
  ) negativeReplicaReceiptCases;

  identityVerifierTests =
    pkgs.runCommand "radicle-replica-identity-verifier-tests"
      {
        nativeBuildInputs = [
          pkgs.rustc
          pkgs.stdenv.cc
        ];
      }
      ''
        rustc --edition ${rustEdition} -D warnings --test \
          ${../modules/radicle-seed-replica/identity-verifier.rs} \
          -o identity-verifier-tests
        ./identity-verifier-tests
        touch "$out"
      '';
in
{
  checks = {
    radicle-seed-replica =
      assert lib.assertMsg (
        positiveValidationErrors == [ ]
      ) "positive replica settings failed: ${builtins.toJSON positiveValidationErrors}";
      assert lib.assertMsg (
        builtins.length negativeCases > 0 && negativeCasesValid
      ) "one or more unsafe replica settings did not fail with the expected diagnostic";
      assert lib.assertMsg nativeOnlyPolicyValid
        "native-only replica lowering failed: ${builtins.toJSON nativeOnlyObservations}";
      assert lib.assertMsg schemaValidationValid
        "replica Nickel contract missed fields: ${builtins.toJSON missingSchemaNegativeFields}";
      assert lib.assertMsg identityVerifierServicePolicyValid
        "replica identity verifier hardening failed: ${builtins.toJSON identityVerifierServiceObservations}";
      assert lib.assertMsg (
        replicaReceipt == replicaReceiptJson
      ) "replica Nickel receipt and exported JSON differ";
      assert lib.assertMsg (
        replicaReceiptValidationErrors == [ ]
      ) "accepted replica receipt failed: ${builtins.toJSON replicaReceiptValidationErrors}";
      assert lib.assertMsg (
        builtins.length negativeReplicaReceiptCases > 0 && negativeReplicaReceiptCasesValid
      ) "one or more unsafe replica receipts did not fail with the expected diagnostic";
      pkgs.runCommand "radicle-seed-replica-check"
        {
          nativeBuildInputs = [ pkgs.b3sum ];
        }
        ''
            actual_receipt_hash="$(b3sum ${replicaReceiptJsonPath} | cut -d ' ' -f 1)"
            test "$actual_receipt_hash" = ${lib.escapeShellArg replicaReceiptExpectedHash}
            test -e ${identityVerifierTests}
          printf '%s\n' \
            'positive_validation=passed' \
            'negative_validation=passed' \
            'native_only_policy=passed' \
            'nickel_contract=passed' \
            'identity_verifier_service_policy=passed' \
            'identity_verifier_tests=passed' \
            'replica_receipt=passed' \
            'replica_receipt_negative_cases=passed' \
            'replica_receipt_blake3=${replicaReceiptExpectedHash}' \
            > "$out"
        '';
  };
}
