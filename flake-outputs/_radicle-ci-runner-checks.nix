# r[verify onix.radicle_ci.configuration]
# r[verify onix.radicle_ci.validation]
# r[verify onix.radicle_ci.isolation]
{
  self,
  pkgs,
  lib,
  system,
  ...
}:
let
  expectedHost = "aspen1";
  unexpectedHost = "aspen2";
  pilotRid = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo";
  artifactAuthRid = "rad:z4JGYYW7WsesXUq7MXVdx16Fawu2f";
  reviewedCommit = "29dac88ecded94457572db3fdfaaaab95fa91525";
  policyBlake3 = "091e57f4409f79db14465ccc26e730bf1181209fe45c28d7dd1259393e93f740";
  checkName = "onix/ci/v1";
  botNodeId = "z6MknopLULJensBT5KGkC8h9KaHTNY5muZ9UffqroErX7Rni";
  productionSeedNodeId = "z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8";
  productionSeedAddress = "100.100.103.95:8776";
  productionSeedCidr = "100.100.103.95/32";
  botUser = "radicle-ci-bot";
  runnerUser = "radicle-ci-runner";
  exchangeState = "/var/lib/radicle-ci-exchange";
  runnerState = "/var/lib/radicle-ci-runner";
  botState = "/var/lib/radicle-ci-bot";
  botControlSocket = "${botState}/node/control.sock";
  nodeReadinessAttempts = 60;
  nodeReadinessDelaySeconds = 1;
  acceptedTimeoutMs = 900000;
  acceptedMemoryBytes = 8589934592;
  acceptedCpuQuota = "200%";
  expectedAllowedInputUris = 2;
  expectedIdentityGenerator = "radicle-ci-bot-radicle-forge-ci";
  guardPolicyDir = ../modules/radicle-forge-guard;

  fixtureConfig = self.nixosConfigurations.${expectedHost}.config;
  unexpectedConfig = self.nixosConfigurations.${unexpectedHost}.config;
  failedAssertions = builtins.filter (assertion: !assertion.assertion) fixtureConfig.assertions;
  scannerService = fixtureConfig.systemd.services.radicle-ci-scan;
  hydratorService = fixtureConfig.systemd.services.radicle-ci-input-hydrator;
  runnerService = fixtureConfig.systemd.services.radicle-ci-runner;
  publisherService = fixtureConfig.systemd.services.radicle-ci-publisher;
  probeService = fixtureConfig.systemd.services.radicle-ci-isolation-probe;
  boundsProbeService = fixtureConfig.systemd.services.radicle-ci-bounds-probe;
  nodeService = fixtureConfig.systemd.services.radicle-ci-node;
  syncService = fixtureConfig.systemd.services.radicle-ci-sync;
  identityGenerator = fixtureConfig.clan.core.vars.generators.${expectedIdentityGenerator};
  syncCommand = syncService.serviceConfig.ExecStart;
  scannerCommand = scannerService.serviceConfig.ExecStart;
  runnerCommand = runnerService.serviceConfig.ExecStart;
  publisherCommand = publisherService.serviceConfig.ExecStart;
  runnerConfigPath = lib.last (lib.splitString " " runnerCommand);
  runnerReadOnly = lib.toList (runnerService.serviceConfig.ReadOnlyPaths or [ ]);
  runnerBindPaths = lib.toList (runnerService.serviceConfig.BindPaths or [ ]);
  runnerBindReadOnlyPaths = lib.toList (runnerService.serviceConfig.BindReadOnlyPaths or [ ]);
  runnerTemporaryFileSystems = lib.toList (runnerService.serviceConfig.TemporaryFileSystem or [ ]);
  runnerReadWrite = lib.toList (runnerService.serviceConfig.ReadWritePaths or [ ]);
  runnerInaccessible = lib.toList (runnerService.serviceConfig.InaccessiblePaths or [ ]);
  botAllowedAddresses = lib.toList (nodeService.serviceConfig.IPAddressAllow or [ ]);
  publisherAllowedAddresses = lib.toList (publisherService.serviceConfig.IPAddressAllow or [ ]);
  hydratorCredentialInputs =
    lib.toList (hydratorService.serviceConfig.LoadCredential or [ ])
    ++ lib.toList (hydratorService.serviceConfig.ImportCredential or [ ]);
  runnerCredentialInputs =
    lib.toList (runnerService.serviceConfig.LoadCredential or [ ])
    ++ lib.toList (runnerService.serviceConfig.ImportCredential or [ ]);
  boundsProbeCredentialInputs =
    lib.toList (boundsProbeService.serviceConfig.LoadCredential or [ ])
    ++ lib.toList (boundsProbeService.serviceConfig.ImportCredential or [ ]);
  runnerPackage = self.packages.${system}.radicle-ci-runner;
  plugins = self.packages.${system}.wasm-plugins;
  wasm = import ../lib/wasm.nix { inherit plugins; };
  schemaValidation = wasm.evalNickelFile ../inventory/services/fixtures/radicle-ci-runner-validation.ncl;
  schemaExpectedNegativeFields = [
    "expectedHost"
    "deploymentTarget"
    "rid"
    "signedRefsFeature"
    "productionSeedNodeId"
    "productionSeedAddress"
    "reviewedCommit"
    "policyBlake3"
    "checkName"
    "expectedBotPublicKey"
    "expectedBotNodeId"
    "expectedBotFingerprint"
    "delegates"
    "cargoTomlBlake3"
    "cargoLockBlake3"
    "flakeNixBlake3"
    "flakeLockBlake3"
    "botListenPort"
    "scanSchedule"
    "timeoutMs"
    "stdoutMaxBytes"
    "stderrMaxBytes"
    "artifactMaxBytes"
    "memoryMaxBytes"
    "cpuQuotaPercent"
    "maxParallelJobs"
    "pollIntervalMs"
    "teardownTimeoutMs"
  ];
  missingSchemaNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) schemaValidation.negative)
  ) schemaExpectedNegativeFields;
  schemaValidationValid = schemaValidation.positive == [ ] && missingSchemaNegativeFields == [ ];
  deploymentReceiptSource = ../evidence/radicle/ci-deployment-v1.ncl;
  deploymentReceiptJsonPath = ../evidence/radicle/ci-deployment-v1.json;
  deploymentReceiptHashPath = ../evidence/radicle/ci-deployment-v1.blake3;
  deploymentReceipt = wasm.evalNickelFile deploymentReceiptSource;
  deploymentReceiptJson = builtins.fromJSON (builtins.readFile deploymentReceiptJsonPath);
  deploymentReceiptExpectedHash = lib.removeSuffix "\n" (builtins.readFile deploymentReceiptHashPath);
  archivedCiEvidence = ../.cairn/archive/2026-07-25-deploy-radicle-forge-ci-runner/evidence;
  patchEventPath = archivedCiEvidence + "/patch-event-v1.json";
  patchResultPath = archivedCiEvidence + "/patch-result-v1.json";
  patchArtifactPath = archivedCiEvidence + "/patch-artifact-v1.json";
  canonicalEventPath = archivedCiEvidence + "/canonical-event-v1.json";
  canonicalResultPath = archivedCiEvidence + "/canonical-result-v1.json";
  isolationProbePath = archivedCiEvidence + "/isolation-probe-v1.json";
  boundsProbePath = archivedCiEvidence + "/bounds-probe-v1.json";
  patchEvent = builtins.fromJSON (builtins.readFile patchEventPath);
  patchResult = builtins.fromJSON (builtins.readFile patchResultPath);
  patchArtifact = builtins.fromJSON (builtins.readFile patchArtifactPath);
  canonicalEvent = builtins.fromJSON (builtins.readFile canonicalEventPath);
  canonicalResult = builtins.fromJSON (builtins.readFile canonicalResultPath);
  isolationProbe = builtins.fromJSON (builtins.readFile isolationProbePath);
  boundsProbe = builtins.fromJSON (builtins.readFile boundsProbePath);
  receiptAccepted =
    receipt:
    receipt.schema_version == 1
    && receipt.receipt_type == "onix.radicle-ci-deployment.v1"
    && receipt.status == "accepted"
    && receipt.policy.policy_blake3 == policyBlake3
    && receipt.policy.reviewed_bounded_exec_revision == reviewedCommit
    && receipt.bot_identity.node_id == botNodeId
    && receipt.bot_identity.delegate == false
    && receipt.repository.rid == pilotRid
    && receipt.repository.object_oid == patchEvent.object_oid
    && receipt.repository.object_oid == patchResult.object_oid
    && receipt.repository.object_oid == patchArtifact.object_oid
    && receipt.repository.object_oid == canonicalEvent.object_oid
    && receipt.repository.object_oid == canonicalResult.object_oid
    && receipt.jobs.patch.job_id == patchEvent.job_id
    && receipt.jobs.patch.job_id == patchResult.job_id
    && receipt.jobs.patch.job_id == patchArtifact.job_id
    && receipt.jobs.patch.disposition == patchResult.disposition
    && receipt.jobs.patch.artifact_blake3 == patchResult.artifact_blake3
    && patchArtifact.stdout_blake3 == patchResult.stdout_blake3
    && patchArtifact.stderr_blake3 == patchResult.stderr_blake3
    && receipt.jobs.canonical.job_id == canonicalEvent.job_id
    && receipt.jobs.canonical.job_id == canonicalResult.job_id
    && receipt.jobs.canonical.disposition == canonicalResult.disposition
    && receipt.jobs.canonical.artifact_blake3 == canonicalResult.artifact_blake3
    && receipt.probes.isolation_schema == isolationProbe.schema
    && receipt.probes.protected_path_access == isolationProbe.protected_path_access
    && receipt.probes.production_seed_network == isolationProbe.production_seed_network
    && receipt.probes.bounds_schema == boundsProbe.schema
    && receipt.probes.timeout == boundsProbe.timeout
    && receipt.probes.output_flood == boundsProbe.output_flood
    && receipt.probes.output_limit_bytes == boundsProbe.output_limit_bytes
    && receipt.probes.output_observed_bytes == boundsProbe.output_observed_bytes
    && receipt.restart.result_mtime_before == receipt.restart.result_mtime_after
    && receipt.restart.comments_before == receipt.restart.comments_after
    && receipt.restart.ledger_entries_before == receipt.restart.ledger_entries_after
    && receipt.restart.deduplication == "verified"
    && builtins.elem "mandatory-ci-merge-enforcement" receipt.non_claims
    && builtins.elem "private-repository-confidentiality" receipt.non_claims
    && builtins.elem "release-readiness" receipt.non_claims;
  deploymentReceiptPositiveValid =
    deploymentReceipt == deploymentReceiptJson && receiptAccepted deploymentReceiptJson;
  deploymentReceiptNegativeValid =
    !(receiptAccepted (deploymentReceiptJson // { status = "rejected"; }));
  servicesAbsentFromUnexpectedHost =
    builtins.all (name: !(builtins.hasAttr name unexpectedConfig.systemd.services))
      [
        "radicle-ci-node"
        "radicle-ci-sync"
        "radicle-ci-scan"
        "radicle-ci-input-hydrator"
        "radicle-ci-runner"
        "radicle-ci-isolation-probe"
        "radicle-ci-bounds-probe"
        "radicle-ci-publisher"
      ];
  modulePolicyValid =
    failedAssertions == [ ]
    && servicesAbsentFromUnexpectedHost
    && schemaValidationValid
    && deploymentReceiptPositiveValid
    && deploymentReceiptNegativeValid
    && scannerService.serviceConfig.User == botUser
    && hydratorService.serviceConfig.User == runnerUser
    && hydratorCredentialInputs == [ ]
    && builtins.elem "/run/secrets" hydratorService.serviceConfig.InaccessiblePaths
    && builtins.elem "/var/lib/radicle" hydratorService.serviceConfig.InaccessiblePaths
    && builtins.elem botState hydratorService.serviceConfig.InaccessiblePaths
    && !(hydratorService.serviceConfig.PrivateNetwork or false)
    && hydratorService.serviceConfig.RestrictNamespaces
    && runnerService.serviceConfig.User == runnerUser
    && publisherService.serviceConfig.User == botUser
    && probeService.serviceConfig.User == runnerUser
    && probeService.serviceConfig.PrivateNetwork
    && boundsProbeService.serviceConfig.User == runnerUser
    && boundsProbeService.serviceConfig.PrivateNetwork
    && boundsProbeCredentialInputs == [ ]
    && builtins.elem "${runnerState}/local-store/nix/store:/nix/store" (
      lib.toList boundsProbeService.serviceConfig.BindPaths
    )
    && runnerService.serviceConfig.PrivateNetwork
    && runnerService.serviceConfig.RestrictNamespaces
    && runnerService.serviceConfig.MemoryMax == acceptedMemoryBytes
    && runnerService.serviceConfig.CPUQuota == acceptedCpuQuota
    && runnerService.serviceConfig.TimeoutStartSec == "${toString acceptedTimeoutMs}ms"
    && runnerCredentialInputs == [ ]
    && builtins.elem "/run/secrets" runnerInaccessible
    && builtins.elem "/var/lib/radicle" runnerInaccessible
    && builtins.elem botState runnerInaccessible
    && builtins.elem "/nix/var/nix/daemon-socket" runnerInaccessible
    && builtins.elem exchangeState runnerReadWrite
    && builtins.elem runnerState runnerReadWrite
    && builtins.elem "${runnerState}/local-store/nix/store:/nix/store" runnerBindPaths
    && builtins.any (path: lib.hasSuffix "/bin/sh:/bin/sh" path) runnerBindReadOnlyPaths
    && builtins.elem "/bin:ro" runnerTemporaryFileSystems
    && !(builtins.elem "/nix/store" runnerReadOnly)
    && nodeService.serviceConfig.IPAddressDeny == "any"
    && publisherService.serviceConfig.IPAddressDeny == "any"
    && builtins.elem productionSeedCidr botAllowedAddresses
    && builtins.elem productionSeedCidr publisherAllowedAddresses
    && lib.hasInfix "radicle-ci-sync" syncService.serviceConfig.ExecStart
    && !(lib.hasInfix " guard " syncCommand)
    && !(lib.hasInfix " guard " scannerCommand)
    && !(lib.hasInfix " guard " runnerCommand)
    && !(lib.hasInfix " guard " publisherCommand)
    && builtins.elem "/var/lib/radicle" scannerService.serviceConfig.InaccessiblePaths
    && builtins.elem "/var/lib/radicle" runnerService.serviceConfig.InaccessiblePaths
    && identityGenerator.files.node-private-key.secret
    && !identityGenerator.files.node-public-key.secret
    && identityGenerator.files.node-public-key.mode == "0400";
in
{
  checks.radicle-ci-runner-policy =
    pkgs.runCommand "radicle-ci-runner-policy"
      {
        nativeBuildInputs = [
          pkgs.b3sum
          pkgs.coreutils
          pkgs.jq
          pkgs.nickel
          runnerPackage
        ];
      }
      ''
        set -eu

        ${lib.optionalString (!modulePolicyValid) ''
          echo "Radicle CI module isolation or typed policy check failed" >&2
          echo ${
            lib.escapeShellArg (
              builtins.toJSON {
                inherit
                  failedAssertions
                  servicesAbsentFromUnexpectedHost
                  schemaValidationValid
                  missingSchemaNegativeFields
                  deploymentReceiptPositiveValid
                  deploymentReceiptNegativeValid
                  hydratorCredentialInputs
                  runnerCredentialInputs
                  boundsProbeCredentialInputs
                  runnerInaccessible
                  runnerReadOnly
                  runnerBindPaths
                  runnerBindReadOnlyPaths
                  runnerTemporaryFileSystems
                  runnerReadWrite
                  botAllowedAddresses
                  publisherAllowedAddresses
                  ;
              }
            )
          } >&2
          exit 1
        ''}

        nickel typecheck ${guardPolicyDir}/profile.ncl
        nickel export --format json ${guardPolicyDir}/profile.ncl > "$TMPDIR/guard-policy.json"
        cmp "$TMPDIR/guard-policy.json" ${guardPolicyDir}/generated/profile.json
        for fixture in ${guardPolicyDir}/fixtures/pass/*.ncl; do
          nickel export "$fixture" >/dev/null
        done
        for fixture in ${guardPolicyDir}/fixtures/fail/*.ncl; do
          if nickel export "$fixture" >/dev/null 2>"$TMPDIR/guard-policy-error.log"; then
            echo "expected canonical guard policy fixture to fail: $fixture" >&2
            exit 1
          fi
        done

        actual_policy_hash="$(b3sum ${../modules/radicle-ci-runner/ci-policy-v1.json} | cut -d ' ' -f1)"
        test "$actual_policy_hash" = ${lib.escapeShellArg policyBlake3}
        actual_receipt_hash="$(b3sum ${deploymentReceiptJsonPath} | cut -d ' ' -f1)"
        test "$actual_receipt_hash" = ${lib.escapeShellArg deploymentReceiptExpectedHash}
        test "$(b3sum ${patchEventPath} | cut -d ' ' -f1)" = ${lib.escapeShellArg deploymentReceiptJson.jobs.patch.event_blake3}
        test "$(b3sum ${patchResultPath} | cut -d ' ' -f1)" = ${lib.escapeShellArg deploymentReceiptJson.jobs.patch.result_blake3}
        test "$(b3sum ${patchArtifactPath} | cut -d ' ' -f1)" = ${lib.escapeShellArg deploymentReceiptJson.evidence_hashes.patch_artifact_json}
        test "$(b3sum ${canonicalEventPath} | cut -d ' ' -f1)" = ${lib.escapeShellArg deploymentReceiptJson.jobs.canonical.event_blake3}
        test "$(b3sum ${canonicalResultPath} | cut -d ' ' -f1)" = ${lib.escapeShellArg deploymentReceiptJson.jobs.canonical.result_blake3}
        test "$(b3sum ${isolationProbePath} | cut -d ' ' -f1)" = ${lib.escapeShellArg deploymentReceiptJson.evidence_hashes.isolation_probe_json}
        test "$(b3sum ${boundsProbePath} | cut -d ' ' -f1)" = ${lib.escapeShellArg deploymentReceiptJson.evidence_hashes.bounds_probe_json}

        radicle-ci-runner validate-config ${runnerConfigPath}
        test "$(jq -r .rid ${runnerConfigPath})" = ${lib.escapeShellArg pilotRid}
        ! grep -Fq ${lib.escapeShellArg artifactAuthRid} ${runnerConfigPath}
        ! grep -Fq ${lib.escapeShellArg artifactAuthRid} ${../modules/radicle-ci-runner/ci-policy-v1.json}
        test "$(jq -r .reviewed_commit ${runnerConfigPath})" = ${lib.escapeShellArg reviewedCommit}
        test "$(jq -r .policy_blake3 ${runnerConfigPath})" = ${lib.escapeShellArg policyBlake3}
        test "$(jq -r .check_name ${runnerConfigPath})" = ${lib.escapeShellArg checkName}
        test "$(jq -r .bot_node_id ${runnerConfigPath})" = ${lib.escapeShellArg botNodeId}
        test "$(jq -r .production_seed_address ${runnerConfigPath})" = ${lib.escapeShellArg productionSeedAddress}
        test "$(jq -r .production_seed_node_id ${runnerConfigPath})" = ${lib.escapeShellArg productionSeedNodeId}
        test "$(jq -r '.command_arguments | index("--no-update-lock-file") != null' ${runnerConfigPath})" = true
        test "$(jq -r '.command_arguments | index(".#checks.x86_64-linux.cargo-test") != null' ${runnerConfigPath})" = true
        test "$(jq -r '.allowed_input_uris | length' ${runnerConfigPath})" = ${toString expectedAllowedInputUris}
        test "$(jq -r '.allowed_input_uris | index("github:NixOS/nixpkgs/61b7c44c4073f0b827768aff0049561b5110ea5a?narHash=sha256-12KrbMiWLcf8m7pCvAtZh1ZrgF85ZXDXvfR/fWTKy84%3D") != null' ${runnerConfigPath})" = true
        test "$(jq -r '.allowed_input_uris | index("github:oxalica/rust-overlay/3c38e1e1ba9c8d7030f7b5a801398ea7d8a6fdc0?narHash=sha256-OstzLWL5t7Xe14xEC6GIMJCp0PrYNTSA0El7GG2av88%3D") != null' ${runnerConfigPath})" = true
        test "$(jq -r .limits.timeout_ms ${runnerConfigPath})" = ${toString acceptedTimeoutMs}
        test "$(jq -r '.delegates | index("did:key:${botNodeId}") == null' ${runnerConfigPath})" = true
        nix_conf_dir="$(jq -r .nix_conf_dir ${runnerConfigPath})"
        test -f "$nix_conf_dir/nix.conf"
        grep -Fqx 'trusted-users = ${runnerUser}' "$nix_conf_dir/nix.conf"
        grep -Fqx 'system-features =' "$nix_conf_dir/nix.conf"
        grep -Fqx 'secret-key-files =' "$nix_conf_dir/nix.conf"

        grep -Fq ${lib.escapeShellArg reviewedCommit} ${../pkgs/radicle-ci-runner/Cargo.lock}
        grep -Fq 'git+https://git.onix.computer/z2CpqLFpdP36fZXYUK5ZNWxMibpCo.git' ${../pkgs/radicle-ci-runner/Cargo.lock}

        grep -Fq ${lib.escapeShellArg botControlSocket} ${syncCommand}
        grep -Fq ${lib.escapeShellArg "attempts_remaining=${toString nodeReadinessAttempts}"} ${syncCommand}
        grep -Fq ${lib.escapeShellArg "sleep ${toString nodeReadinessDelaySeconds}"} ${syncCommand}
        grep -Fq 'if test "$attempts_remaining" -eq 0' ${syncCommand}

        touch "$out"
      '';
}
