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
  reviewedCommit = "29dac88ecded94457572db3fdfaaaab95fa91525";
  policyBlake3 = "091e57f4409f79db14465ccc26e730bf1181209fe45c28d7dd1259393e93f740";
  botNodeId = "z6MknopLULJensBT5KGkC8h9KaHTNY5muZ9UffqroErX7Rni";
  productionSeedNodeId = "z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8";
  productionSeedAddress = "100.100.103.95:8776";
  productionSeedCidr = "100.100.103.95/32";
  botUser = "radicle-ci-bot";
  runnerUser = "radicle-ci-runner";
  exchangeState = "/var/lib/radicle-ci-exchange";
  runnerState = "/var/lib/radicle-ci-runner";
  botState = "/var/lib/radicle-ci-bot";
  acceptedTimeoutMs = 900000;
  acceptedMemoryBytes = 8589934592;
  acceptedCpuQuota = "200%";
  expectedAllowedInputUris = 2;
  expectedIdentityGenerator = "radicle-ci-bot-radicle-forge-ci";

  fixtureConfig = self.nixosConfigurations.${expectedHost}.config;
  unexpectedConfig = self.nixosConfigurations.${unexpectedHost}.config;
  failedAssertions = builtins.filter (assertion: !assertion.assertion) fixtureConfig.assertions;
  scannerService = fixtureConfig.systemd.services.radicle-ci-scan;
  hydratorService = fixtureConfig.systemd.services.radicle-ci-input-hydrator;
  runnerService = fixtureConfig.systemd.services.radicle-ci-runner;
  publisherService = fixtureConfig.systemd.services.radicle-ci-publisher;
  probeService = fixtureConfig.systemd.services.radicle-ci-isolation-probe;
  nodeService = fixtureConfig.systemd.services.radicle-ci-node;
  syncService = fixtureConfig.systemd.services.radicle-ci-sync;
  identityGenerator = fixtureConfig.clan.core.vars.generators.${expectedIdentityGenerator};
  runnerCommand = runnerService.serviceConfig.ExecStart;
  runnerConfigPath = lib.last (lib.splitString " " runnerCommand);
  runnerReadOnly = lib.toList (runnerService.serviceConfig.ReadOnlyPaths or [ ]);
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
  servicesAbsentFromUnexpectedHost =
    builtins.all (name: !(builtins.hasAttr name unexpectedConfig.systemd.services))
      [
        "radicle-ci-node"
        "radicle-ci-sync"
        "radicle-ci-scan"
        "radicle-ci-input-hydrator"
        "radicle-ci-runner"
        "radicle-ci-isolation-probe"
        "radicle-ci-publisher"
      ];
  modulePolicyValid =
    failedAssertions == [ ]
    && servicesAbsentFromUnexpectedHost
    && schemaValidationValid
    && scannerService.serviceConfig.User == botUser
    && hydratorService.serviceConfig.User == runnerUser
    && hydratorCredentialInputs == [ ]
    && builtins.elem "/run/secrets" hydratorService.serviceConfig.InaccessiblePaths
    && builtins.elem "/var/lib/radicle" hydratorService.serviceConfig.InaccessiblePaths
    && builtins.elem botState hydratorService.serviceConfig.InaccessiblePaths
    && !(hydratorService.serviceConfig.PrivateNetwork or false)
    && !(hydratorService.serviceConfig.RestrictNamespaces or false)
    && runnerService.serviceConfig.User == runnerUser
    && publisherService.serviceConfig.User == botUser
    && probeService.serviceConfig.User == runnerUser
    && probeService.serviceConfig.PrivateNetwork
    && runnerService.serviceConfig.PrivateNetwork
    && runnerService.serviceConfig.RestrictNamespaces
    && runnerService.serviceConfig.MemoryMax == acceptedMemoryBytes
    && runnerService.serviceConfig.CPUQuota == acceptedCpuQuota
    && runnerService.serviceConfig.TimeoutStartSec == "${toString acceptedTimeoutMs}ms"
    && runnerCredentialInputs == [ ]
    && builtins.elem "/run/secrets" runnerInaccessible
    && builtins.elem "/var/lib/radicle" runnerInaccessible
    && builtins.elem botState runnerInaccessible
    && builtins.elem exchangeState runnerReadWrite
    && builtins.elem runnerState runnerReadWrite
    && builtins.elem "/nix/store" runnerReadOnly
    && nodeService.serviceConfig.IPAddressDeny == "any"
    && publisherService.serviceConfig.IPAddressDeny == "any"
    && builtins.elem productionSeedCidr botAllowedAddresses
    && builtins.elem productionSeedCidr publisherAllowedAddresses
    && lib.hasInfix "radicle-ci-sync" syncService.serviceConfig.ExecStart
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
                  hydratorCredentialInputs
                  runnerCredentialInputs
                  runnerInaccessible
                  runnerReadOnly
                  runnerReadWrite
                  botAllowedAddresses
                  publisherAllowedAddresses
                  ;
              }
            )
          } >&2
          exit 1
        ''}

        actual_policy_hash="$(b3sum ${../modules/radicle-ci-runner/ci-policy-v1.json} | cut -d ' ' -f1)"
        test "$actual_policy_hash" = ${lib.escapeShellArg policyBlake3}

        radicle-ci-runner validate-config ${runnerConfigPath}
        test "$(jq -r .rid ${runnerConfigPath})" = ${lib.escapeShellArg pilotRid}
        test "$(jq -r .reviewed_commit ${runnerConfigPath})" = ${lib.escapeShellArg reviewedCommit}
        test "$(jq -r .policy_blake3 ${runnerConfigPath})" = ${lib.escapeShellArg policyBlake3}
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

        grep -Fq ${lib.escapeShellArg reviewedCommit} ${../pkgs/radicle-ci-runner/Cargo.lock}
        grep -Fq 'git+https://git.onix.computer/z2CpqLFpdP36fZXYUK5ZNWxMibpCo.git' ${../pkgs/radicle-ci-runner/Cargo.lock}

        touch "$out"
      '';
}
