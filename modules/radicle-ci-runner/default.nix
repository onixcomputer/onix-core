# r[impl onix.radicle_ci.configuration]
# r[impl onix.radicle_ci.isolation]
{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
  generatorPrefix = "radicle-ci-bot-";
in
{
  _class = "clan.service";
  manifest = {
    name = "radicle-ci-runner";
    description = "Least-authority exact-object Radicle CI bot, runner, and publisher";
    categories = [ "system" ];
    readme = "Non-delegate Radicle CI bot plus credentialless exact-object bounded runner";
  };

  roles.default = {
    description = "Dedicated Radicle CI bot and credentialless runner";
    interface = mkSettings.mkInterface schema.default;

    perInstance =
      { instanceName, extendSettings, ... }:
      {
        nixosModule =
          {
            config,
            pkgs,
            lib,
            ...
          }:
          let
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            settings = extendSettings (ms.mkDefaults schema.default);
            generatorName = "${generatorPrefix}${instanceName}";
            privateKeyFileName = "node-private-key";
            publicKeyFileName = "node-public-key";
            privateKeyMode = "0400";
            publicKeyMode = "0444";
            botUser = "radicle-ci-bot";
            runnerUser = "radicle-ci-runner";
            exchangeGroup = "radicle-ci-exchange";
            botState = "/var/lib/radicle-ci-bot";
            botStorage = "${botState}/storage";
            exchangeState = "/var/lib/radicle-ci-exchange";
            runnerState = "/var/lib/radicle-ci-runner";
            artifactState = "/var/lib/radicle-ci-artifacts";
            localStoreRoot = "${runnerState}/local-store";
            botListenAddress = "127.0.0.1";
            botAlias = "aspen1-ci-bot";
            runnerPackage = pkgs.callPackage ../../pkgs/radicle-ci-runner { };
            nodePackage = pkgs.radicle-node;
            policyReconciler = import ../radicle-node/policy-reconciler.nix { inherit pkgs; };
            identityFiles = config.clan.core.vars.generators.${generatorName}.files;
            privateKeyPath = identityFiles.${privateKeyFileName}.path;
            publicKeyPath = identityFiles.${publicKeyFileName}.path;
            productionSeed = "${settings.productionSeedNodeId}@${settings.productionSeedAddress}";
            acceptedPolicyBlake3 = lib.removeSuffix "\n" (builtins.readFile ./ci-policy-v1.blake3);
            runnerTasksMax = 256;
            stdinMaxBytes = 1;
            acceptedMaxParallelJobs = 2;
            acceptedTimeoutMs = 900000;
            productionSeedHost = builtins.head (lib.splitString ":" settings.productionSeedAddress);
            serviceStartTimeout = "2m";
            serviceRestartDelay = "10s";
            timerInitialDelay = "2m";
            timerJitter = "15s";
            privateDirectoryMode = "0700";
            exchangeDirectoryMode = "2770";
            exchangeQueueNames = [
              "incoming"
              "processing"
              "outbox"
              "published"
              "rejected"
              "ledger"
              "staging"
            ];
            privateUmask = "0077";
            exchangeUmask = "0007";
            botConfig = pkgs.writeText "radicle-ci-bot-config.json" (
              builtins.toJSON {
                node = {
                  alias = botAlias;
                  relay = "never";
                  seedingPolicy.default = "block";
                };
                preferredSeeds = [ productionSeed ];
                web.pinned.repositories = [ ];
              }
            );
            runnerConfig = pkgs.writeText "radicle-ci-runner-config.json" (
              builtins.toJSON {
                schema = "onix.radicle-ci-runner.v1";
                inherit (settings) rid delegates;
                reviewed_commit = settings.reviewedCommit;
                signed_refs_feature = settings.signedRefsFeature;
                production_seed = productionSeed;
                production_seed_node_id = settings.productionSeedNodeId;
                production_seed_address = settings.productionSeedAddress;
                policy_blake3 = settings.policyBlake3;
                bot_public_key = settings.expectedBotPublicKey;
                bot_node_id = settings.expectedBotNodeId;
                bot_fingerprint = settings.expectedBotFingerprint;
                expected_locks = {
                  cargo_toml_blake3 = settings.cargoTomlBlake3;
                  cargo_lock_blake3 = settings.cargoLockBlake3;
                  flake_nix_blake3 = settings.flakeNixBlake3;
                  flake_lock_blake3 = settings.flakeLockBlake3;
                };
                command_program = "${pkgs.nix}/bin/nix";
                command_arguments = [
                  "build"
                  "--no-link"
                  "--no-update-lock-file"
                  "--option"
                  "allow-import-from-derivation"
                  "false"
                  "--option"
                  "restrict-eval"
                  "true"
                  ".#checks.x86_64-linux.cargo-test"
                ];
                git_program = "${pkgs.gitMinimal}/bin/git";
                nix_program = "${pkgs.nix}/bin/nix";
                tar_program = "${pkgs.gnutar}/bin/tar";
                rad_program = "${nodePackage}/bin/rad";
                ssh_program = "${pkgs.openssh}/bin/ssh";
                storage_path = botStorage;
                bot_state_path = botState;
                exchange_path = exchangeState;
                runner_state_path = runnerState;
                artifact_path = artifactState;
                local_store_root = localStoreRoot;
                limits = {
                  timeout_ms = settings.timeoutMs;
                  stdin_max_bytes = stdinMaxBytes;
                  stdout_max_bytes = settings.stdoutMaxBytes;
                  stderr_max_bytes = settings.stderrMaxBytes;
                  poll_interval_ms = settings.pollIntervalMs;
                  teardown_timeout_ms = settings.teardownTimeoutMs;
                  artifact_max_bytes = settings.artifactMaxBytes;
                  memory_max_bytes = settings.memoryMaxBytes;
                  cpu_quota_percent = settings.cpuQuotaPercent;
                  max_parallel_jobs = settings.maxParallelJobs;
                };
              }
            );
            commonHardening = {
              CapabilityBoundingSet = "";
              LockPersonality = true;
              NoNewPrivileges = true;
              PrivateDevices = true;
              PrivateTmp = true;
              ProtectClock = true;
              ProtectControlGroups = true;
              ProtectHome = true;
              ProtectHostname = true;
              ProtectKernelLogs = true;
              ProtectKernelModules = true;
              ProtectKernelTunables = true;
              ProtectSystem = "strict";
              RemoveIPC = true;
              RestrictNamespaces = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              SystemCallArchitectures = "native";
            };
            botNetworkHardening = commonHardening // {
              InaccessiblePaths = [
                "/run/secrets"
                "/var/lib/radicle"
                "-/var/lib/harmonia"
                "/root"
                "/home"
              ];
              IPAddressDeny = "any";
              IPAddressAllow = [
                "127.0.0.0/8"
                "${productionSeedHost}/32"
              ];
              RestrictAddressFamilies = [
                "AF_INET"
                "AF_UNIX"
              ];
            };
            scannerHardening = commonHardening // {
              InaccessiblePaths = [
                "/run/secrets"
                "/var/lib/radicle"
                "-/var/lib/harmonia"
                "/root"
                "/home"
                "/etc/ssh"
              ];
              PrivateNetwork = true;
              RestrictAddressFamilies = [ "AF_UNIX" ];
              SocketBindDeny = "any";
            };
            offlineHardening = commonHardening // {
              InaccessiblePaths = [
                "/run/secrets"
                "/var/lib/radicle"
                botState
                "-/var/lib/harmonia"
                "/root"
                "/home"
                "/etc/ssh"
              ];
              PrivateNetwork = true;
              RestrictAddressFamilies = [ "AF_UNIX" ];
              SocketBindDeny = "any";
            };
            identitySetup = pkgs.writeShellApplication {
              name = "radicle-ci-identity-setup";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.openssh
                nodePackage
              ];
              text = ''
                set -eu
                install -d -m ${privateDirectoryMode} ${botState}/keys
                install -m ${privateKeyMode} "$CREDENTIALS_DIRECTORY/radicle-ci-private" ${botState}/keys/radicle
                install -m ${publicKeyMode} "$CREDENTIALS_DIRECTORY/radicle-ci-public" ${botState}/keys/radicle.pub
                install -m ${publicKeyMode} ${botConfig} ${botState}/config.json
                touch ${botState}/.gitconfig

                derived_public="$(ssh-keygen -y -f ${botState}/keys/radicle)"
                expected_public=${lib.escapeShellArg settings.expectedBotPublicKey}
                if test "$derived_public" != "$expected_public"; then
                  echo "generated CI bot private/public key pair does not match the pinned public key" >&2
                  exit 1
                fi
                fingerprint="$(printf '%s\n' "$derived_public" | ssh-keygen -lf - | cut -d ' ' -f2)"
                if test "$fingerprint" != ${lib.escapeShellArg settings.expectedBotFingerprint}; then
                  echo "generated CI bot fingerprint does not match the pinned fingerprint" >&2
                  exit 1
                fi
                node_id="$(HOME=${botState} RAD_HOME=${botState} ${nodePackage}/bin/rad self --nid)"
                if test "$node_id" != ${lib.escapeShellArg settings.expectedBotNodeId}; then
                  echo "generated CI bot node ID does not match the pinned node ID" >&2
                  exit 1
                fi
              '';
            };
            syncCommand = pkgs.writeShellApplication {
              name = "radicle-ci-sync";
              runtimeInputs = [
                nodePackage
                policyReconciler
              ];
              text = ''
                set -eu
                ${policyReconciler}/bin/radicle-policy-reconciler ${nodePackage}/bin/rad ${lib.escapeShellArg settings.rid}
                ${nodePackage}/bin/rad sync --fetch --seed ${lib.escapeShellArg settings.productionSeedNodeId} --signed-refs-feature-level ${lib.escapeShellArg settings.signedRefsFeature} ${lib.escapeShellArg settings.rid}
              '';
            };
          in
          {
            assertions = [
              {
                assertion = config.networking.hostName == settings.expectedHost;
                message = "radicle-ci-${instanceName}: service escaped its admitted host";
              }
              {
                assertion = settings.policyBlake3 == acceptedPolicyBlake3;
                message = "radicle-ci-${instanceName}: portable policy BLAKE3 drifted";
              }
              {
                assertion = settings.expectedBotNodeId != settings.productionSeedNodeId;
                message = "radicle-ci-${instanceName}: CI bot reused the production seed identity";
              }
              {
                assertion =
                  !(builtins.any (delegate: lib.hasSuffix settings.expectedBotNodeId delegate) settings.delegates);
                message = "radicle-ci-${instanceName}: CI bot identity is a project delegate";
              }
              {
                assertion = settings.signedRefsFeature == "parent";
                message = "radicle-ci-${instanceName}: signed-reference feature weakened";
              }
              {
                assertion = settings.maxParallelJobs <= acceptedMaxParallelJobs;
                message = "radicle-ci-${instanceName}: parallel-job bound exceeds accepted policy";
              }
              {
                assertion = settings.timeoutMs <= acceptedTimeoutMs;
                message = "radicle-ci-${instanceName}: timeout exceeds accepted policy";
              }
            ];

            clan.core.vars.generators.${generatorName} = {
              files = {
                ${privateKeyFileName} = {
                  secret = true;
                  deploy = true;
                  owner = "root";
                  group = "root";
                  mode = privateKeyMode;
                };
                ${publicKeyFileName} = {
                  secret = false;
                  deploy = true;
                  owner = "root";
                  group = "root";
                  mode = privateKeyMode;
                };
              };
              runtimeInputs = [
                pkgs.coreutils
                pkgs.openssh
              ];
              script = ''
                private_key="$out/${privateKeyFileName}"
                generated_public="$private_key.pub"
                public_key="$out/${publicKeyFileName}"
                ssh-keygen -q -t ed25519 -N "" -C "" -f "$private_key"
                cut -d ' ' -f 1-2 "$generated_public" > "$public_key"
                rm "$generated_public"
                chmod ${privateKeyMode} "$private_key"
                chmod ${publicKeyMode} "$public_key"
              '';
            };

            users.groups = {
              ${botUser} = { };
              ${runnerUser} = { };
              ${exchangeGroup} = { };
            };
            users.users = {
              ${botUser} = {
                description = "Non-delegate Radicle CI status bot";
                group = botUser;
                extraGroups = [ exchangeGroup ];
                home = botState;
                isSystemUser = true;
              };
              ${runnerUser} = {
                description = "Credentialless bounded Radicle CI runner";
                group = runnerUser;
                extraGroups = [ exchangeGroup ];
                home = runnerState;
                isSystemUser = true;
              };
            };

            systemd = {
              tmpfiles.rules = [
                "d ${botState} ${privateDirectoryMode} ${botUser} ${botUser} - -"
                "d ${exchangeState} ${exchangeDirectoryMode} ${botUser} ${exchangeGroup} - -"
                "d ${runnerState} ${privateDirectoryMode} ${runnerUser} ${runnerUser} - -"
                "d ${artifactState} ${exchangeDirectoryMode} ${runnerUser} ${exchangeGroup} - -"
              ]
              ++ builtins.map (
                name: "d ${exchangeState}/${name} ${exchangeDirectoryMode} ${botUser} ${exchangeGroup} - -"
              ) exchangeQueueNames;

              services = {
                radicle-ci-identity = {
                  description = "Verify and materialize the pinned Radicle CI bot identity";
                  wantedBy = [ "multi-user.target" ];
                  before = [ "radicle-ci-node.service" ];
                  serviceConfig = commonHardening // {
                    ExecStart = "${identitySetup}/bin/radicle-ci-identity-setup";
                    Group = botUser;
                    InaccessiblePaths = [
                      "/run/secrets"
                      "/var/lib/radicle"
                      "-/var/lib/harmonia"
                      "/home"
                    ];
                    LoadCredential = [
                      "radicle-ci-private:${privateKeyPath}"
                      "radicle-ci-public:${publicKeyPath}"
                    ];
                    PrivateNetwork = true;
                    ReadWritePaths = [ botState ];
                    RemainAfterExit = true;
                    Type = "oneshot";
                    UMask = privateUmask;
                    User = botUser;
                    WorkingDirectory = botState;
                  };
                };

                radicle-ci-node = {
                  description = "Loopback-only non-delegate Radicle CI bot node";
                  wantedBy = [ "multi-user.target" ];
                  after = [
                    "network-online.target"
                    "radicle-ci-identity.service"
                  ];
                  requires = [ "radicle-ci-identity.service" ];
                  wants = [ "network-online.target" ];
                  environment = {
                    HOME = botState;
                    RAD_HOME = botState;
                    RUST_LOG = "info";
                  };
                  path = [ pkgs.gitMinimal ];
                  serviceConfig = botNetworkHardening // {
                    ExecStart = "${nodePackage}/bin/radicle-node --force --listen ${botListenAddress}:${toString settings.botListenPort}";
                    Group = botUser;
                    ReadWritePaths = [ botState ];
                    Restart = "on-failure";
                    RestartSec = serviceRestartDelay;
                    SocketBindAllow = "tcp:${toString settings.botListenPort}";
                    SocketBindDeny = "any";
                    StateDirectory = "radicle-ci-bot";
                    StateDirectoryMode = privateDirectoryMode;
                    UMask = privateUmask;
                    User = botUser;
                    WorkingDirectory = botState;
                  };
                };

                radicle-ci-sync = {
                  description = "Synchronize only the admitted Radicle CI repository";
                  after = [ "radicle-ci-node.service" ];
                  requires = [ "radicle-ci-node.service" ];
                  unitConfig.OnSuccess = [ "radicle-ci-scan.service" ];
                  environment = {
                    HOME = botState;
                    RAD_HOME = botState;
                  };
                  path = [ pkgs.gitMinimal ];
                  serviceConfig = botNetworkHardening // {
                    ExecStart = "${syncCommand}/bin/radicle-ci-sync";
                    Group = botUser;
                    ReadWritePaths = [ botState ];
                    TimeoutStartSec = serviceStartTimeout;
                    Type = "oneshot";
                    UMask = privateUmask;
                    User = botUser;
                    WorkingDirectory = botState;
                  };
                };

                radicle-ci-scan = {
                  description = "Export exact local Radicle objects into the bounded CI spool";
                  after = [ "radicle-ci-sync.service" ];
                  unitConfig.OnSuccess = [ "radicle-ci-runner.service" ];
                  serviceConfig = scannerHardening // {
                    ExecStart = "${runnerPackage}/bin/radicle-ci-runner scan ${runnerConfig}";
                    Group = botUser;
                    ReadOnlyPaths = [
                      runnerConfig
                      botStorage
                    ];
                    ReadWritePaths = [ exchangeState ];
                    Type = "oneshot";
                    UMask = exchangeUmask;
                    User = botUser;
                    WorkingDirectory = botState;
                  };
                };

                radicle-ci-runner = {
                  description = "Execute one credentialless exact-object bounded Nix job";
                  after = [ "radicle-ci-scan.service" ];
                  unitConfig.OnSuccess = [ "radicle-ci-publisher.service" ];
                  serviceConfig = offlineHardening // {
                    CPUQuota = "${toString settings.cpuQuotaPercent}%";
                    ExecStart = "${runnerPackage}/bin/radicle-ci-runner run-next ${runnerConfig}";
                    Group = runnerUser;
                    MemoryMax = settings.memoryMaxBytes;
                    ReadOnlyPaths = [
                      runnerConfig
                      "/nix/store"
                      "/nix/var/nix/daemon-socket/socket"
                    ];
                    ReadWritePaths = [
                      exchangeState
                      runnerState
                      artifactState
                    ];
                    TasksMax = runnerTasksMax;
                    TimeoutStartSec = "${toString settings.timeoutMs}ms";
                    Type = "oneshot";
                    UMask = exchangeUmask;
                    User = runnerUser;
                    WorkingDirectory = runnerState;
                  };
                };

                radicle-ci-isolation-probe = {
                  description = "Probe the credentialless runner authority boundary";
                  serviceConfig = offlineHardening // {
                    CPUQuota = "${toString settings.cpuQuotaPercent}%";
                    ExecStart = "${runnerPackage}/bin/radicle-ci-runner probe-isolation ${runnerConfig}";
                    Group = runnerUser;
                    MemoryMax = settings.memoryMaxBytes;
                    ReadOnlyPaths = [
                      runnerConfig
                      "/nix/store"
                    ];
                    ReadWritePaths = [ runnerState ];
                    TasksMax = runnerTasksMax;
                    Type = "oneshot";
                    UMask = privateUmask;
                    User = runnerUser;
                    WorkingDirectory = runnerState;
                  };
                };

                radicle-ci-publisher = {
                  description = "Publish bounded CI status under the non-delegate bot identity";
                  after = [ "radicle-ci-runner.service" ];
                  requires = [ "radicle-ci-node.service" ];
                  environment = {
                    HOME = botState;
                    RAD_HOME = botState;
                  };
                  path = [
                    pkgs.gitMinimal
                    pkgs.openssh
                  ];
                  serviceConfig = botNetworkHardening // {
                    ExecStart = "${runnerPackage}/bin/radicle-ci-runner publish-next ${runnerConfig}";
                    Group = botUser;
                    ReadOnlyPaths = [ runnerConfig ];
                    ReadWritePaths = [
                      botState
                      exchangeState
                    ];
                    TimeoutStartSec = serviceStartTimeout;
                    Type = "oneshot";
                    UMask = exchangeUmask;
                    User = botUser;
                    WorkingDirectory = botState;
                  };
                };
              };

              timers.radicle-ci-sync = {
                description = "Periodically synchronize and scan the admitted Radicle repository";
                wantedBy = [ "timers.target" ];
                timerConfig = {
                  OnBootSec = timerInitialDelay;
                  OnCalendar = settings.scanSchedule;
                  Persistent = true;
                  RandomizedDelaySec = timerJitter;
                  Unit = "radicle-ci-sync.service";
                };
              };
            };

            services.prometheus.rules = lib.mkIf config.services.prometheus.enable [
              (builtins.toJSON {
                groups = [
                  {
                    name = "radicle-ci";
                    rules = [
                      {
                        alert = "RadicleCiUnitFailed";
                        expr = ''node_systemd_unit_state{name=~"radicle-ci-(node|sync|scan|runner|publisher)\\.service",state="failed"} == 1'';
                        for = "5m";
                        labels.severity = "critical";
                        annotations.summary = "Radicle CI unit failed on {{ $labels.instance }}";
                      }
                    ];
                  }
                ];
              })
            ];
          };
      };
  };
}
