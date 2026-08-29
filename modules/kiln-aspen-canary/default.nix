# r[impl onix.kiln_aspen_canary.composition]
# r[impl onix.kiln_aspen_canary.authority]
# r[impl onix.kiln_aspen_canary.failure]
{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";

  manifest = {
    name = "kiln-aspen-canary";
    description = "Private operator-only Kiln semantics canary hosted by Aspen and routed through Lattice";
    categories = [ "system" ];
    readme = "Disabled-by-default local Kiln-on-Aspen canary with no automatic fallback";
  };

  roles.default = {
    description = "One private Kiln-on-Aspen host and its exact Lattice workflow exchange";
    interface = mkSettings.mkInterface schema.default;

    perInstance =
      { extendSettings, ... }:
      {
        nixosModule =
          {
            inputs,
            lib,
            pkgs,
            ...
          }:
          let
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            settings = extendSettings (ms.mkDefaults schema.default);
            evaluated = import ./settings.nix { inherit lib; } settings;
            system = pkgs.stdenv.hostPlatform.system;
            kilnPackage = inputs.kiln-canary.packages.${system}.kiln;
            hostPackage = inputs.kiln-canary.packages.${system}.kiln-aspen-host;
            latticePackage = inputs.lattice-canary.packages.${system}.lattice;
            hostExecutable = lib.getExe' hostPackage "kiln-aspen-host";
            extensionExecutable = lib.getExe' kilnPackage "kiln-aspen-extension";
            adapterExecutable = lib.getExe' kilnPackage "kiln-adapter-radicle";
            latticeExecutable = lib.getExe' latticePackage "lattice";
            inherit (evaluated)
              aspenSocket
              hostUser
              latticeSocket
              latticeUser
              replayDatabase
              runtimeDirectory
              socketGroup
              ;
            inherit (settings) runtimeName;
            hostServiceName = "${runtimeName}-host";
            latticeServiceName = "${runtimeName}-lattice";
            hostUnit = "${hostServiceName}.service";
            latticeUnit = "${latticeServiceName}.service";
            privateDirectoryMode = "0700";
            privateFileMode = "0600";
            runtimeDirectoryMode = "0770";
            socketMode = "0660";
            serviceUmask = "0007";
            hostMemoryMaximum = "8G";
            latticeMemoryMaximum = "4G";
            hostCpuQuota = "400%";
            latticeCpuQuota = "200%";
            hostTasksMaximum = 512;
            latticeTasksMaximum = 256;
            serviceRestartDelay = "5s";
            serviceStopTimeout = "45s";
            socketReadyAttempts = 100;
            socketReadyDelaySeconds = "0.05";
            dispatchConnectionsPerEffect = 1;
            maximumLatticeConnections = 65536;
            admittedHostRequestDivisor = if settings.maximumRequests > 0 then settings.maximumRequests else 1;
            providerConnectionsPerEffect = builtins.div maximumLatticeConnections admittedHostRequestDivisor;
            maximumProviderPolls = providerConnectionsPerEffect - dispatchConnectionsPerEffect;
            latticeMaximumConnections = settings.maximumRequests * providerConnectionsPerEffect;
            latticeWorkflowRevision = "b3:1377fce07f3426f87ab7c61d6a716d3f1fc95be71f91ab87699e13f56dbd35b3";
            nclString = value: builtins.toJSON value;
            latticeConfig = pkgs.writeText "${runtimeName}-lattice-config.ncl" ''
              let make_config = import ${nclString ./profiles/lattice-config.ncl} in
              make_config {
                data_dir = ${nclString settings.latticeStateDir},
                shell = ${nclString pkgs.runtimeShell},
              }
            '';
            latticeHandlerProfile = pkgs.writeText "${runtimeName}-lattice-handler.ncl" ''
              let make_profile = import ${nclString ./profiles/lattice-handler-profile.ncl} in
              make_profile {
                host_uid = ${toString settings.hostUid},
                socket_path = ${nclString latticeSocket},
                maximum_connections = ${toString latticeMaximumConnections},
              }
            '';
            radicleProfileSource = pkgs.writeText "${runtimeName}-radicle-profile.ncl" ''
              let make_profile = import ${nclString ./profiles/radicle-profile.ncl} in
              make_profile {
                host_uid = ${toString settings.hostUid},
                socket_path = ${nclString latticeSocket},
                replay_database_path = ${nclString replayDatabase},
                maximum_polls = ${toString maximumProviderPolls},
              }
            '';
            radicleProfile =
              pkgs.runCommand "${runtimeName}-radicle-profile.json"
                {
                  nativeBuildInputs = [ pkgs.nickel ];
                }
                ''
                  nickel export --format json ${radicleProfileSource} > "$out"
                '';
            aspenProfile =
              pkgs.runCommand "${runtimeName}-aspen-profile.json"
                {
                  nativeBuildInputs = [ pkgs.nickel ];
                }
                ''
                  nickel export --format json \
                    ${inputs.kiln-canary}/config/aspen-runtime-profile.ncl > "$out"
                '';
            latticeWorkflow = ./profiles/lattice-workflow.ncl;
            latticePreparationMarker = "${settings.latticeStateDir}/workflow-revision";
            receiptDirectory = "${settings.hostStateDir}/receipts";
            acceptedTrigger = pkgs.writeText "${runtimeName}-accepted-trigger.json" (
              builtins.toJSON {
                version = 1;
                event = "push";
                repository = "rad:kiln-aspen-private-canary";
                actor = "did:key:kiln-aspen-private-canary";
                before = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
                after = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
                branch = "canary";
                patch = null;
              }
              + "\n"
            );
            rejectedTrigger = pkgs.writeText "${runtimeName}-rejected-trigger.json" (
              builtins.toJSON {
                version = 1;
                event = "push";
                repository = "rad:kiln-aspen-private-canary";
                actor = "did:key:kiln-aspen-private-canary";
                before = "cccccccccccccccccccccccccccccccccccccccc";
                after = "cccccccccccccccccccccccccccccccccccccccc";
                branch = "canary";
                patch = null;
              }
              + "\n"
            );
            rollbackTrigger = pkgs.writeText "${runtimeName}-rollback-trigger.json" (
              builtins.toJSON {
                version = 1;
                event = "push";
                repository = "rad:kiln-aspen-private-canary";
                actor = "did:key:kiln-aspen-private-canary";
                before = "dddddddddddddddddddddddddddddddddddddddd";
                after = "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee";
                branch = "canary";
                patch = null;
              }
              + "\n"
            );
            unavailableTrigger = pkgs.writeText "${runtimeName}-unavailable-trigger.json" (
              builtins.toJSON {
                version = 1;
                event = "push";
                repository = "rad:kiln-aspen-private-canary";
                actor = "did:key:kiln-aspen-private-canary";
                before = "ffffffffffffffffffffffffffffffffffffffff";
                after = "9999999999999999999999999999999999999999";
                branch = "canary";
                patch = null;
              }
              + "\n"
            );
            uncertainTrigger = pkgs.writeText "${runtimeName}-uncertain-trigger.json" (
              builtins.toJSON {
                version = 1;
                event = "push";
                repository = "rad:kiln-aspen-private-canary";
                actor = "did:key:kiln-aspen-private-canary";
                before = "7777777777777777777777777777777777777777";
                after = "8888888888888888888888888888888888888888";
                branch = "canary";
                patch = null;
              }
              + "\n"
            );
            latticePrepare = pkgs.writeShellApplication {
              name = "${runtimeName}-prepare-lattice";
              runtimeInputs = [ pkgs.coreutils ];
              text = ''
                set -eu
                marker=${lib.escapeShellArg latticePreparationMarker}
                expected=${lib.escapeShellArg latticeWorkflowRevision}
                if test -f "$marker"; then
                  test "$(${pkgs.coreutils}/bin/cat "$marker")" = "$expected"
                  exit 0
                fi
                ${latticeExecutable} --config ${lib.escapeShellArg latticeConfig} \
                  import ${lib.escapeShellArg latticeWorkflow}
                printf '%s\n' "$expected" \
                  | ${pkgs.coreutils}/bin/install -m ${privateFileMode} \
                    /dev/stdin "$marker"
              '';
            };
            grantLatticeSocket = pkgs.writeShellApplication {
              name = "${runtimeName}-grant-lattice-socket";
              runtimeInputs = [ pkgs.coreutils ];
              text = ''
                set -eu
                for _attempt in $(${pkgs.coreutils}/bin/seq 1 ${toString socketReadyAttempts}); do
                  if test -S ${lib.escapeShellArg latticeSocket}; then
                    ${pkgs.coreutils}/bin/chgrp ${lib.escapeShellArg socketGroup} \
                      ${lib.escapeShellArg latticeSocket}
                    ${pkgs.coreutils}/bin/chmod ${socketMode} \
                      ${lib.escapeShellArg latticeSocket}
                    exit 0
                  fi
                  ${pkgs.coreutils}/bin/sleep ${socketReadyDelaySeconds}
                done
                echo "Lattice workflow socket did not become ready" >&2
                exit 1
              '';
            };
            mkStaleSocketGuard =
              {
                name,
                socketPath,
                socketOwner,
              }:
              pkgs.writeShellApplication {
                inherit name;
                runtimeInputs = [ pkgs.coreutils ];
                text = ''
                  set -eu
                  socket=${lib.escapeShellArg socketPath}
                  if test ! -e "$socket"; then
                    exit 0
                  fi
                  if test ! -S "$socket"; then
                    echo ${lib.escapeShellArg "${socketOwner} socket path exists and is not a socket"} >&2
                    exit 1
                  fi
                  ${pkgs.coreutils}/bin/rm -f -- "$socket"
                '';
              };
            removeStaleAspenSocket = mkStaleSocketGuard {
              name = "${runtimeName}-remove-stale-aspen-socket";
              socketPath = aspenSocket;
              socketOwner = "Aspen";
            };
            removeStaleLatticeSocket = mkStaleSocketGuard {
              name = "${runtimeName}-remove-stale-lattice-socket";
              socketPath = latticeSocket;
              socketOwner = "Lattice";
            };
            mkClient =
              {
                name,
                runtime,
                trigger,
                socket ? aspenSocket,
                expectFailure ? false,
              }:
              let
                runtimeArguments =
                  if runtime == "aspen" then
                    [
                      "--runtime"
                      "aspen"
                      "--aspen-profile"
                      (toString aspenProfile)
                      "--aspen-socket"
                      socket
                    ]
                  else
                    [
                      "--runtime"
                      "lattice"
                    ];
                command = lib.escapeShellArgs (
                  [
                    adapterExecutable
                    "--profile"
                    (toString radicleProfile)
                    "--protocol"
                    "native"
                  ]
                  ++ runtimeArguments
                );
                receipt = "${receiptDirectory}/${name}.jsonl";
              in
              pkgs.writeShellApplication {
                inherit name;
                runtimeInputs = [ pkgs.coreutils ];
                text = ''
                  set -eu
                  temporary="$(${pkgs.coreutils}/bin/mktemp ${lib.escapeShellArg receipt}.XXXXXX)"
                  cleanup() {
                    ${pkgs.coreutils}/bin/rm -f "$temporary"
                  }
                  trap cleanup EXIT HUP INT TERM
                  ${
                    if expectFailure then
                      ''
                        if ${command} < ${lib.escapeShellArg trigger} >"$temporary" 2>&1; then
                          echo "unavailable Aspen endpoint selected a runtime" >&2
                          exit 1
                        fi
                        printf '%s\n' '{"classification":"unavailable","fallback":"none","verdict":"PASS"}' >"$temporary"
                      ''
                    else
                      ''
                        ${command} < ${lib.escapeShellArg trigger} >"$temporary"
                      ''
                  }
                  ${pkgs.coreutils}/bin/install -m ${privateFileMode} \
                    "$temporary" ${lib.escapeShellArg receipt}
                  ${pkgs.coreutils}/bin/cat ${lib.escapeShellArg receipt}
                '';
              };
            acceptedClient = mkClient {
              name = "${runtimeName}-accepted";
              runtime = "aspen";
              trigger = acceptedTrigger;
            };
            rejectedClient = mkClient {
              name = "${runtimeName}-rejected";
              runtime = "aspen";
              trigger = rejectedTrigger;
            };
            unavailableClient = mkClient {
              name = "${runtimeName}-unavailable";
              runtime = "aspen";
              trigger = unavailableTrigger;
              socket = "${runtimeDirectory}/missing.sock";
              expectFailure = true;
            };
            rollbackClient = mkClient {
              name = "${runtimeName}-rollback-lattice";
              runtime = "lattice";
              trigger = rollbackTrigger;
            };
            uncertainReceipt = "${receiptDirectory}/${runtimeName}-uncertain.jsonl";
            uncertainAdapterCommand = lib.escapeShellArgs [
              adapterExecutable
              "--profile"
              (toString radicleProfile)
              "--protocol"
              "native"
              "--runtime"
              "aspen"
              "--aspen-profile"
              (toString aspenProfile)
              "--aspen-socket"
              aspenSocket
            ];
            uncertainClient = pkgs.writeShellApplication {
              name = "${runtimeName}-uncertain";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.gnugrep
                pkgs.socat
              ];
              text = ''
                set -eu
                socket=${lib.escapeShellArg latticeSocket}
                original_socket=${lib.escapeShellArg "${latticeSocket}.active"}
                temporary="$(${pkgs.coreutils}/bin/mktemp ${lib.escapeShellArg uncertainReceipt}.XXXXXX)"
                replay_temporary="$(${pkgs.coreutils}/bin/mktemp ${lib.escapeShellArg uncertainReceipt}.replay.XXXXXX)"
                provider_pid=""
                restore() {
                  if test -n "$provider_pid"; then
                    ${pkgs.coreutils}/bin/kill "$provider_pid" 2>/dev/null || true
                    wait "$provider_pid" 2>/dev/null || true
                  fi
                  ${pkgs.coreutils}/bin/rm -f "$socket"
                  if test -S "$original_socket"; then
                    ${pkgs.coreutils}/bin/mv "$original_socket" "$socket"
                  fi
                  ${pkgs.coreutils}/bin/rm -f "$temporary" "$replay_temporary"
                }
                trap restore EXIT HUP INT TERM
                run_unknown() {
                  output="$1"
                  set +e
                  ${uncertainAdapterCommand} \
                    < ${lib.escapeShellArg uncertainTrigger} >"$output" 2>&1
                  status="$?"
                  set -e
                  test "$status" -ne 0
                  ${pkgs.gnugrep}/bin/grep -F -- 'aspen_ingress_unknown' "$output" >/dev/null
                }
                test -S "$socket"
                test ! -e "$original_socket"
                ${pkgs.coreutils}/bin/mv "$socket" "$original_socket"
                ${pkgs.socat}/bin/socat -u \
                  "UNIX-LISTEN:$socket,mode=${socketMode}" OPEN:/dev/null &
                provider_pid="$!"
                for _attempt in $(${pkgs.coreutils}/bin/seq 1 ${toString socketReadyAttempts}); do
                  if test -S "$socket"; then
                    break
                  fi
                  ${pkgs.coreutils}/bin/sleep ${socketReadyDelaySeconds}
                done
                test -S "$socket"
                ${pkgs.coreutils}/bin/chgrp ${lib.escapeShellArg socketGroup} "$socket"
                ${pkgs.coreutils}/bin/chmod ${socketMode} "$socket"
                run_unknown "$temporary"
                wait "$provider_pid"
                provider_pid=""
                run_unknown "$replay_temporary"
                printf '%s\n' \
                  '{"classification":"unknown_after_write","reconciliation":"required","fallback":"none","replay":"unknown","verdict":"PASS"}' \
                  >"$temporary"
                ${pkgs.coreutils}/bin/install -m ${privateFileMode} \
                  "$temporary" ${lib.escapeShellArg uncertainReceipt}
                ${pkgs.coreutils}/bin/cat ${lib.escapeShellArg uncertainReceipt}
              '';
            };
            commonHardening = {
              CapabilityBoundingSet = "";
              AmbientCapabilities = "";
              LockPersonality = true;
              NoNewPrivileges = true;
              PrivateDevices = true;
              PrivateNetwork = true;
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
              RestrictAddressFamilies = [ "AF_UNIX" ];
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              SystemCallArchitectures = "native";
              UMask = serviceUmask;
              InaccessiblePaths = [
                "/run/secrets"
                "/var/lib/radicle"
                "/var/lib/radicle-ci"
                "/root"
                "/home"
              ];
            };
            mkOperatorService =
              {
                description,
                executable,
                requiresHost,
              }:
              {
                inherit description;
                after = [ latticeUnit ] ++ lib.optional requiresHost hostUnit;
                requires = [ latticeUnit ] ++ lib.optional requiresHost hostUnit;
                serviceConfig = commonHardening // {
                  Type = "oneshot";
                  User = hostUser;
                  Group = socketGroup;
                  ExecStart = lib.getExe executable;
                  ReadWritePaths = [ settings.hostStateDir ];
                  MemoryMax = hostMemoryMaximum;
                  CPUQuota = hostCpuQuota;
                  TasksMax = hostTasksMaximum;
                  TimeoutStartSec = serviceStopTimeout;
                };
              };
          in
          {
            assertions = evaluated.assertions ++ [
              {
                assertion = maximumProviderPolls > 0 && latticeMaximumConnections <= maximumLatticeConnections;
                message = "Kiln Aspen canary poll or Lattice connection budget exceeds the contract bound";
              }
            ];

            users.groups.${socketGroup} = lib.mkIf settings.enable { };
            users.users.${hostUser} = lib.mkIf settings.enable {
              isSystemUser = true;
              uid = settings.hostUid;
              group = socketGroup;
              home = settings.hostStateDir;
              createHome = false;
            };
            users.users.${latticeUser} = lib.mkIf settings.enable {
              isSystemUser = true;
              uid = settings.latticeUid;
              group = socketGroup;
              home = settings.latticeStateDir;
              createHome = false;
            };

            systemd.tmpfiles.settings."10-${runtimeName}" = lib.mkIf settings.enable {
              ${settings.hostStateDir}.d = {
                mode = privateDirectoryMode;
                user = hostUser;
                group = socketGroup;
              };
              ${receiptDirectory}.d = {
                mode = privateDirectoryMode;
                user = hostUser;
                group = socketGroup;
              };
              ${settings.latticeStateDir}.d = {
                mode = privateDirectoryMode;
                user = latticeUser;
                group = socketGroup;
              };
              ${runtimeDirectory}.d = {
                mode = runtimeDirectoryMode;
                user = latticeUser;
                group = socketGroup;
              };
            };

            # r[impl onix.kiln_aspen_canary.composition.accepted]
            systemd.services.${latticeServiceName} = lib.mkIf settings.enable {
              description = "Exact Lattice workflow exchange for ${runtimeName}";
              wantedBy = [ "multi-user.target" ];
              before = [ hostUnit ];
              serviceConfig = commonHardening // {
                Type = "exec";
                User = latticeUser;
                Group = socketGroup;
                WorkingDirectory = settings.latticeStateDir;
                ExecStartPre = [
                  (lib.getExe removeStaleLatticeSocket)
                  (lib.getExe latticePrepare)
                ];
                ExecStart = lib.escapeShellArgs [
                  latticeExecutable
                  "--config"
                  (toString latticeConfig)
                  "workflow-exchange"
                  "serve"
                  "--profile"
                  (toString latticeHandlerProfile)
                ];
                ExecStartPost = lib.getExe grantLatticeSocket;
                ReadWritePaths = [
                  settings.latticeStateDir
                  runtimeDirectory
                ];
                MemoryMax = latticeMemoryMaximum;
                CPUQuota = latticeCpuQuota;
                TasksMax = latticeTasksMaximum;
                Restart = "on-failure";
                RestartSec = serviceRestartDelay;
                TimeoutStopSec = serviceStopTimeout;
              };
            };

            # r[impl onix.kiln_aspen_canary.completion.accepted]
            systemd.services.${hostServiceName} = lib.mkIf settings.enable {
              description = "Kiln semantics hosted by Aspen for ${runtimeName}";
              wantedBy = [ "multi-user.target" ];
              after = [ latticeUnit ];
              requires = [ latticeUnit ];
              serviceConfig = commonHardening // {
                Type = "exec";
                User = hostUser;
                Group = socketGroup;
                WorkingDirectory = settings.hostStateDir;
                ExecStartPre = lib.getExe removeStaleAspenSocket;
                ExecStart = lib.escapeShellArgs [
                  hostExecutable
                  "--aspen-profile"
                  (toString aspenProfile)
                  "--radicle-profile"
                  (toString radicleProfile)
                  "--socket"
                  aspenSocket
                  "--extension"
                  extensionExecutable
                  "--state-root"
                  settings.hostStateDir
                  "--max-requests"
                  (toString settings.maximumRequests)
                  "--timeout-ms"
                  (toString settings.timeoutMilliseconds)
                ];
                ReadWritePaths = [
                  settings.hostStateDir
                  runtimeDirectory
                ];
                MemoryMax = hostMemoryMaximum;
                CPUQuota = hostCpuQuota;
                TasksMax = hostTasksMaximum;
                Restart = "no";
                TimeoutStopSec = serviceStopTimeout;
              };
            };

            # Operator-only units have no wantedBy target and cannot receive broker events.
            systemd.services."${runtimeName}-accepted" = lib.mkIf settings.enable (mkOperatorService {
              description = "Run one accepted Kiln-on-Aspen private canary";
              executable = acceptedClient;
              requiresHost = true;
            });
            systemd.services."${runtimeName}-rejected" = lib.mkIf settings.enable (mkOperatorService {
              description = "Run one denied Kiln-on-Aspen private canary";
              executable = rejectedClient;
              requiresHost = true;
            });
            systemd.services."${runtimeName}-unavailable" = lib.mkIf settings.enable (mkOperatorService {
              description = "Prove an unavailable Aspen endpoint fails without fallback";
              executable = unavailableClient;
              requiresHost = false;
            });
            systemd.services."${runtimeName}-rollback-lattice" = lib.mkIf settings.enable (mkOperatorService {
              description = "Run the explicit operator-selected Lattice rollback path";
              executable = rollbackClient;
              requiresHost = false;
            });

            # r[impl onix.kiln_aspen_canary.failure.unknown]
            systemd.services."${runtimeName}-uncertain" = lib.mkIf settings.enable {
              description = "Prove disconnect after provider request write remains Unknown";
              after = [
                latticeUnit
                hostUnit
              ];
              requires = [
                latticeUnit
                hostUnit
              ];
              serviceConfig = commonHardening // {
                Type = "oneshot";
                User = hostUser;
                Group = socketGroup;
                ExecStart = lib.getExe uncertainClient;
                ReadWritePaths = [
                  settings.hostStateDir
                  runtimeDirectory
                ];
                MemoryMax = hostMemoryMaximum;
                CPUQuota = hostCpuQuota;
                TasksMax = hostTasksMaximum;
                TimeoutStartSec = serviceStopTimeout;
              };
            };
          };
      };
  };

  perMachine = _: { nixosModule = _: { }; };
}
