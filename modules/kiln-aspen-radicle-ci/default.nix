# r[impl onix.radicle_ci.aspen_composition]
# r[impl onix.radicle_ci.aspen_authority]
{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";

  manifest = {
    name = "kiln-aspen-radicle-ci";
    description = "Private production Seaglass Radicle CI hosted by durable Kiln-on-Aspen and Lattice";
    categories = [ "system" ];
    readme = "Fail-closed production cohort with exact source, report, socket, and rollback boundaries";
  };

  roles.default = {
    description = "One durable Kiln Aspen host, one exact Lattice workflow, and one bounded Nix provider";
    interface = mkSettings.mkInterface schema.default;

    perInstance =
      { extendSettings, ... }:
      {
        nixosModule =
          {
            config,
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
            kilnPackage = inputs.kiln.packages.${system}.kiln;
            hostPackage = inputs.kiln.packages.${system}.kiln-aspen-host;
            providerPackage = inputs.kiln.packages.${system}.kiln-radicle-nix-provider;
            latticePackage = inputs.lattice.packages.${system}.lattice;
            hostExecutable = lib.getExe' hostPackage "kiln-aspen-host";
            extensionExecutable = lib.getExe' kilnPackage "kiln-aspen-extension";
            adapterExecutable = lib.getExe' kilnPackage "kiln-adapter-radicle";
            providerExecutable = lib.getExe' providerPackage "kiln-radicle-nix-provider";
            providerWorkflowExecutable = "/run/current-system/sw/bin/kiln-radicle-nix-provider";
            providerWorkflowProfile = "/etc/${runtimeName}/provider-profile.json";
            latticeExecutable = lib.getExe' latticePackage "lattice";
            inherit (evaluated)
              aspenSocket
              hostUser
              ingressDirectory
              ingressGroup
              internalDirectory
              internalGroup
              latticeSocket
              latticeUser
              providerWorkDirectory
              replayDatabase
              reportGroup
              reportNamespacePath
              runtimeDirectory
              sourceGroup
              ;
            runtimeName = settings.runtimeName;
            hostServiceName = "${runtimeName}-host";
            latticeServiceName = "${runtimeName}-lattice";
            sourceServiceName = "${runtimeName}-source-admission";
            shadowServiceName = "${runtimeName}-shadow";
            authorityProbeServiceName = "${runtimeName}-authority-probe";
            hostUnit = "${hostServiceName}.service";
            latticeUnit = "${latticeServiceName}.service";
            sourceUnit = "${sourceServiceName}.service";
            privateDirectoryMode = "0700";
            sharedDirectoryMode = "2770";
            traversalDirectoryMode = "0711";
            sourceViewMode = "0550";
            privateFileMode = "0600";
            socketMode = "0660";
            privateUmask = "0077";
            hostMemoryMaximum = "8G";
            latticeMemoryMaximum = "24G";
            sourceMemoryMaximum = "1G";
            shadowMemoryMaximum = "1G";
            hostCpuQuota = "400%";
            latticeCpuQuota = "800%";
            sourceCpuQuota = "200%";
            shadowCpuQuota = "100%";
            hostTasksMaximum = 512;
            latticeTasksMaximum = 1024;
            sourceTasksMaximum = 128;
            shadowTasksMaximum = 64;
            serviceRestartDelay = "5s";
            serviceStopTimeout = "2m";
            serviceStartTimeout = "5m";
            socketReadyAttempts = 200;
            socketReadyDelaySeconds = "0.05";
            dispatchConnectionsPerEffect = 1;
            maximumLatticeConnections = 65536;
            admittedHostRequestDivisor = if settings.maximumRequests > 0 then settings.maximumRequests else 1;
            providerConnectionsPerEffect = builtins.div maximumLatticeConnections admittedHostRequestDivisor;
            maximumProviderPolls = providerConnectionsPerEffect - dispatchConnectionsPerEffect;
            latticeMaximumConnections = settings.maximumRequests * providerConnectionsPerEffect;
            millisecondsPerSecond = 1000;
            subsecondRoundingMilliseconds = millisecondsPerSecond - 1;
            providerOperationTimeoutMilliseconds =
              settings.providerTimeoutMilliseconds + settings.providerTeardownTimeoutMilliseconds;
            observationPollRoundingMilliseconds = maximumProviderPolls - 1;
            observationPollIntervalMilliseconds = builtins.div (
              providerOperationTimeoutMilliseconds + observationPollRoundingMilliseconds
            ) maximumProviderPolls;
            observationPollHorizonMilliseconds = observationPollIntervalMilliseconds * maximumProviderPolls;
            workflowCompletionMarginSeconds = 60;
            providerTimeoutSeconds = builtins.div (
              settings.providerTimeoutMilliseconds + subsecondRoundingMilliseconds
            ) millisecondsPerSecond;
            providerTeardownSeconds = builtins.div (
              settings.providerTeardownTimeoutMilliseconds + subsecondRoundingMilliseconds
            ) millisecondsPerSecond;
            workflowTimeoutSeconds =
              providerTimeoutSeconds + providerTeardownSeconds + workflowCompletionMarginSeconds;
            workflowTimeoutMilliseconds = workflowTimeoutSeconds * millisecondsPerSecond;
            uidOwners =
              uid: lib.attrNames (lib.filterAttrs (_name: user: (user.uid or null) == uid) config.users.users);
            shadowStartTimeout = "${toString workflowTimeoutSeconds}s";
            latticeWorkflowRevision = "b3:616b5d8beb00044accf14e88c3d71b487669535e6dbf54c02fc2c4929fbc3e4a";
            latticeContractRevision = "70496e67c7fd4a8b05914161a8e09de2759bebc8";
            boundedExecRevision = "29dac88ecded94457572db3fdfaaaab95fa91525";
            durablePublicationRevision = "8e05e74e24b45f752d77145c4455385daaf6d6ab";
            commandArgumentCount = 4;
            nclString = value: builtins.toJSON value;
            kilnArtifactSource = inputs.cairn.inputs.artifact;
            providerWrapper = pkgs.writeShellApplication {
              name = "${runtimeName}-nix-wrapper";
              runtimeInputs = [ pkgs.gitMinimal ];
              text = ''
                set -eu
                expected_argument_count=${toString commandArgumentCount}
                if test "$#" -ne "$expected_argument_count"; then
                  echo "provider wrapper received an unexpected argument count" >&2
                  exit 1
                fi
                if test "$1" != "flake" || test "$2" != "check" || test "$3" != "--no-update-lock-file"; then
                  echo "provider wrapper refused an unexpected operation" >&2
                  exit 1
                fi
                export HOME=${lib.escapeShellArg providerWorkDirectory}
                export NIX_CONFIG=${lib.escapeShellArg ''
                  experimental-features = nix-command flakes
                  accept-flake-config = false
                  builders =
                  secret-key-files =
                ''}
                exec ${pkgs.nix}/bin/nix flake check --no-update-lock-file \
                  --override-input cairn/artifact path:${kilnArtifactSource} \
                  "$4"
              '';
            };
            providerWrapperExecutable = lib.getExe providerWrapper;
            providerProfile =
              pkgs.runCommand "${runtimeName}-provider-profile.json"
                {
                  nativeBuildInputs = [
                    pkgs.b3sum
                    pkgs.nickel
                  ];
                }
                ''
                  read -r wrapper_blake3 _ < <(b3sum ${lib.escapeShellArg providerWrapperExecutable})
                  cat > provider-profile.ncl <<'PROFILE_EOF'
                  let make_profile = import ${nclString "${inputs.kiln}/config/radicle-nix-provider.ncl"} in
                  make_profile {
                    allowed_user_id = ${toString settings.latticeUid},
                    repository = ${nclString settings.repository},
                    source_root = ${nclString settings.sourceView},
                    wrapper_path = ${nclString providerWrapperExecutable},
                    wrapper_blake3 = "WRAPPER_BLAKE3_PLACEHOLDER",
                    working_directory = ${nclString providerWorkDirectory},
                    report_root = ${nclString settings.reportView},
                    report_namespace = ${nclString settings.reportNamespace},
                    report_base_url = ${nclString settings.reportBaseUrl},
                    timeout_milliseconds = ${toString settings.providerTimeoutMilliseconds},
                    stdout_max_bytes = ${toString settings.providerStdoutMaxBytes},
                    stderr_max_bytes = ${toString settings.providerStderrMaxBytes},
                    poll_interval_milliseconds = ${toString settings.providerPollMilliseconds},
                    teardown_timeout_milliseconds = ${toString settings.providerTeardownTimeoutMilliseconds},
                    wrapper_max_bytes = ${toString settings.providerWrapperMaxBytes},
                    report_max_bytes = ${toString settings.providerReportMaxBytes},
                    stage_collision_attempts = ${toString settings.providerStageCollisionAttempts},
                  }
                  PROFILE_EOF
                  substituteInPlace provider-profile.ncl \
                    --replace-fail WRAPPER_BLAKE3_PLACEHOLDER "$wrapper_blake3"
                  nickel export --format json provider-profile.ncl > "$out"
                '';
            latticeConfig = pkgs.writeText "${runtimeName}-lattice-config.ncl" ''
              let make_config = import ${nclString ./profiles/lattice-config.ncl} in
              make_config {
                data_dir = ${nclString settings.latticeStateDir},
                shell = ${nclString pkgs.runtimeShell},
                command_timeout_seconds = ${toString workflowTimeoutSeconds},
              }
            '';
            latticeWorkflow = pkgs.writeText "${runtimeName}-workflow.ncl" ''
              let make_workflow = import ${nclString ./profiles/lattice-workflow.ncl} in
              make_workflow {
                provider_executable = ${nclString providerWorkflowExecutable},
                provider_profile = ${nclString providerWorkflowProfile},
                repository = ${nclString settings.repository},
                command_timeout_seconds = ${toString workflowTimeoutSeconds},
              }
            '';
            latticeHandlerProfile = pkgs.writeText "${runtimeName}-lattice-handler.ncl" ''
              let make_profile = import ${nclString ./profiles/lattice-handler-profile.ncl} in
              make_profile {
                host_uid = ${toString settings.hostUid},
                socket_path = ${nclString latticeSocket},
                maximum_connections = ${toString latticeMaximumConnections},
                workflow_revision = ${nclString latticeWorkflowRevision},
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
            aspenProfileSource = pkgs.writeText "${runtimeName}-aspen-profile.ncl" ''
              let base = import ${nclString "${inputs.kiln}/config/aspen-runtime-profile.ncl"} in
              base & {
                bounds.callback_timeout_millis | force = ${toString workflowTimeoutMilliseconds},
              }
            '';
            aspenProfile =
              pkgs.runCommand "${runtimeName}-aspen-profile.json"
                {
                  nativeBuildInputs = [ pkgs.nickel ];
                }
                ''
                  nickel export --format json ${aspenProfileSource} > "$out"
                '';
            latticePreparationMarker = "${settings.latticeStateDir}/workflow-revision";
            quarantineDirectory = "${builtins.dirOf settings.hostStateDir}/quarantine";
            latticePrepare = pkgs.writeShellApplication {
              name = "${runtimeName}-prepare-lattice";
              runtimeInputs = [ pkgs.coreutils ];
              text = ''
                set -eu
                marker=${lib.escapeShellArg latticePreparationMarker}
                expected=${lib.escapeShellArg latticeWorkflowRevision}
                if test -f "$marker"; then
                  test "$(cat "$marker")" = "$expected"
                fi
                ${latticeExecutable} --config ${lib.escapeShellArg latticeConfig} \
                  import ${lib.escapeShellArg latticeWorkflow}
                printf '%s\n' "$expected" \
                  | install -m ${privateFileMode} /dev/stdin "$marker"
              '';
            };
            mkSocketGrant =
              {
                name,
                socketPath,
                socketGroup,
              }:
              pkgs.writeShellApplication {
                inherit name;
                runtimeInputs = [ pkgs.coreutils ];
                text = ''
                  set -eu
                  socket=${lib.escapeShellArg socketPath}
                  for _attempt in $(seq 1 ${toString socketReadyAttempts}); do
                    if test -S "$socket"; then
                      chgrp ${lib.escapeShellArg socketGroup} "$socket"
                      chmod ${socketMode} "$socket"
                      exit 0
                    fi
                    sleep ${socketReadyDelaySeconds}
                  done
                  echo "service socket did not become ready" >&2
                  exit 1
                '';
              };
            grantAspenSocket = mkSocketGrant {
              name = "${runtimeName}-grant-aspen-socket";
              socketPath = aspenSocket;
              socketGroup = ingressGroup;
            };
            grantLatticeSocket = mkSocketGrant {
              name = "${runtimeName}-grant-lattice-socket";
              socketPath = latticeSocket;
              socketGroup = internalGroup;
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
                  rm -f -- "$socket"
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
            sourceAdmission = pkgs.writeShellApplication {
              name = "${runtimeName}-admit-source";
              runtimeInputs = [
                pkgs.acl
                pkgs.coreutils
                pkgs.findutils
                pkgs.gnugrep
              ];
              text = ''
                set -eu
                source=${lib.escapeShellArg settings.sourcePath}
                group=${lib.escapeShellArg sourceGroup}
                test -d "$source"
                if find "$source" -type l -print -quit | grep -q .; then
                  echo "Seaglass source view contains a symbolic link" >&2
                  exit 1
                fi
                if find "$source" -mindepth 1 ! -type d ! -type f -print -quit | grep -q .; then
                  echo "Seaglass source view contains an unsupported file type" >&2
                  exit 1
                fi
                find "$source" -type d \
                  -exec setfacl -m "g:$group:r-x,d:g:$group:r-x" {} +
                find "$source" -type f \
                  -exec setfacl -m "g:$group:r--" {} +
              '';
            };
            shadowTrigger = pkgs.writeText "${runtimeName}-shadow-trigger.json" (
              builtins.toJSON {
                version = 1;
                event = "push";
                repository = settings.repository;
                actor = "did:key:z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx";
                before = "d88cc41b0145d5dc118a6313054c5d3e66efbe19";
                after = "5f659dce24e13b30e996f0aab3419dac4c21f934";
                branch = "master";
                patch = null;
              }
              + "\n"
            );
            aspenAdapter = pkgs.writeShellApplication {
              name = "${runtimeName}-adapter";
              text = ''
                exec ${adapterExecutable} \
                  --profile ${lib.escapeShellArg radicleProfile} \
                  --protocol defelo \
                  --runtime aspen \
                  --aspen-profile ${lib.escapeShellArg aspenProfile} \
                  --aspen-socket ${lib.escapeShellArg aspenSocket}
              '';
            };
            shadowClient = pkgs.writeShellApplication {
              name = "${runtimeName}-shadow";
              text = ''
                exec ${adapterExecutable} \
                  --profile ${lib.escapeShellArg radicleProfile} \
                  --protocol native \
                  --runtime aspen \
                  --aspen-profile ${lib.escapeShellArg aspenProfile} \
                  --aspen-socket ${lib.escapeShellArg aspenSocket} \
                  < ${lib.escapeShellArg shadowTrigger}
              '';
            };
            authorityProbe = pkgs.writeShellApplication {
              name = "${runtimeName}-authority-probe";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.gitMinimal
              ];
              text = ''
                set -eu
                source=${lib.escapeShellArg settings.sourceView}
                report=${lib.escapeShellArg reportNamespacePath}
                expected_revision=5f659dce24e13b30e996f0aab3419dac4c21f934
                temporary="$report/.authority-probe-$$"
                cleanup() {
                  rm -f -- "$temporary"
                }
                trap cleanup EXIT HUP INT TERM
                test -d "$source"
                test -d "$report"
                test -S ${lib.escapeShellArg latticeSocket}
                test ! -e ${lib.escapeShellArg aspenSocket}
                test -S /nix/var/nix/daemon-socket/socket
                git --git-dir="$source" cat-file -e "$expected_revision^{commit}"
                if touch "$source/.authority-probe" 2>/dev/null; then
                  rm -f -- "$source/.authority-probe"
                  echo "source view is writable" >&2
                  exit 1
                fi
                for forbidden in \
                  /var/lib/radicle \
                  /var/lib/radicle-ci \
                  /run/secrets \
                  /root \
                  /home \
                  /etc/ssh \
                  ${lib.escapeShellArg ingressDirectory} \
                  ${lib.escapeShellArg settings.hostStateDir}; do
                  if test -r "$forbidden" || test -x "$forbidden"; then
                    echo "forbidden authority is readable or traversable: $forbidden" >&2
                    exit 1
                  fi
                done
                printf '%s\n' authority-probe > "$temporary"
                test "$(cat "$temporary")" = authority-probe
                printf '%s\n' '{"schema":"onix.kiln-aspen-authority-probe.v1","verdict":"PASS"}'
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
              RestrictNamespaces = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              SystemCallArchitectures = "native";
              UMask = privateUmask;
              InaccessiblePaths = [
                "/run/secrets"
                "/root"
                "/home"
                "/etc/ssh"
              ];
            };
            hostHardening = commonHardening // {
              InaccessiblePaths = commonHardening.InaccessiblePaths ++ [
                "/var/lib/radicle"
                "/var/lib/radicle-ci"
                settings.sourceView
                settings.reportView
                settings.latticeStateDir
              ];
            };
            latticeHardening = commonHardening // {
              BindReadOnlyPaths = [ "${settings.sourcePath}:${settings.sourceView}" ];
              BindPaths = [ "${settings.reportPath}:${settings.reportView}" ];
              InaccessiblePaths = commonHardening.InaccessiblePaths ++ [
                "/var/lib/radicle"
                "/var/lib/radicle-ci"
                ingressDirectory
                settings.hostStateDir
              ];
            };
            shadowHardening = commonHardening // {
              InaccessiblePaths = commonHardening.InaccessiblePaths ++ [
                "/var/lib/radicle"
                "/var/lib/radicle-ci"
                internalDirectory
                settings.hostStateDir
                settings.latticeStateDir
                settings.sourceView
                settings.reportView
              ];
            };
          in
          {
            assertions = evaluated.assertions ++ [
              {
                assertion =
                  maximumProviderPolls > 0
                  && providerConnectionsPerEffect > dispatchConnectionsPerEffect
                  && latticeMaximumConnections <= maximumLatticeConnections
                  && observationPollIntervalMilliseconds > 0
                  && observationPollHorizonMilliseconds >= providerOperationTimeoutMilliseconds
                  && observationPollHorizonMilliseconds < workflowTimeoutMilliseconds;
                message = "Kiln Aspen production poll pacing or Lattice connection budget exceeds the contract bound";
              }
              {
                assertion =
                  uidOwners settings.hostUid == [ hostUser ] && uidOwners settings.latticeUid == [ latticeUser ];
                message = "Kiln Aspen production service UIDs must not alias another system account";
              }
              {
                assertion = inputs.kiln.rev == "330059df57641300baa6c2ae09fd3a4989018d40";
                message = "Kiln Aspen production must use the reviewed durable Kiln revision";
              }
              {
                assertion = lib.hasInfix latticeContractRevision (builtins.readFile ./profiles/radicle-profile.ncl);
                message = "Kiln Aspen production Lattice contract revision drifted";
              }
              {
                assertion =
                  lib.hasInfix boundedExecRevision (
                    builtins.readFile "${inputs.kiln}/config/radicle-nix-provider.ncl"
                  )
                  && lib.hasInfix durablePublicationRevision (
                    builtins.readFile "${inputs.kiln}/config/radicle-nix-provider.ncl"
                  );
                message = "Kiln Aspen production provider mechanism revisions drifted";
              }
            ];

            users.groups = lib.mkIf settings.enable {
              ${hostUser} = { };
              ${latticeUser} = { };
              ${ingressGroup} = { };
              ${internalGroup} = { };
              ${sourceGroup} = { };
              ${reportGroup} = { };
            };
            users.users.${hostUser} = lib.mkIf settings.enable {
              isSystemUser = true;
              uid = settings.hostUid;
              group = hostUser;
              extraGroups = [
                ingressGroup
                internalGroup
              ];
              home = settings.hostStateDir;
              createHome = false;
            };
            users.users.${latticeUser} = lib.mkIf settings.enable {
              isSystemUser = true;
              uid = settings.latticeUid;
              group = latticeUser;
              extraGroups = [
                internalGroup
                sourceGroup
                reportGroup
              ];
              home = settings.latticeStateDir;
              createHome = false;
            };
            users.users.radicle.extraGroups = lib.mkIf settings.enable [
              ingressGroup
              reportGroup
            ];

            systemd.tmpfiles.settings."10-${runtimeName}" = lib.mkIf settings.enable {
              "/var/lib/kiln-aspen-radicle-ci".d = {
                mode = traversalDirectoryMode;
                user = "root";
                group = "root";
              };
              ${settings.hostStateDir}.d = {
                mode = privateDirectoryMode;
                user = hostUser;
                group = hostUser;
              };
              ${quarantineDirectory}.d = {
                mode = privateDirectoryMode;
                user = "root";
                group = "root";
              };
              ${settings.latticeStateDir}.d = {
                mode = privateDirectoryMode;
                user = latticeUser;
                group = latticeUser;
              };
              ${providerWorkDirectory}.d = {
                mode = privateDirectoryMode;
                user = latticeUser;
                group = latticeUser;
              };
              ${builtins.dirOf settings.sourceView}.d = {
                mode = sourceViewMode;
                user = "root";
                group = sourceGroup;
              };
              ${settings.sourceView}.d = {
                mode = sourceViewMode;
                user = "root";
                group = sourceGroup;
              };
              ${settings.reportPath}.d = {
                mode = sharedDirectoryMode;
                user = "radicle";
                group = reportGroup;
              };
              "${settings.reportPath}/${settings.reportNamespace}".d = {
                mode = sharedDirectoryMode;
                user = "radicle";
                group = reportGroup;
              };
              ${settings.reportView}.d = {
                mode = sharedDirectoryMode;
                user = latticeUser;
                group = reportGroup;
              };
              ${reportNamespacePath}.d = {
                mode = sharedDirectoryMode;
                user = latticeUser;
                group = reportGroup;
              };
              ${runtimeDirectory}.d = {
                mode = traversalDirectoryMode;
                user = "root";
                group = "root";
              };
              ${ingressDirectory}.d = {
                mode = sharedDirectoryMode;
                user = hostUser;
                group = ingressGroup;
              };
              ${internalDirectory}.d = {
                mode = sharedDirectoryMode;
                user = latticeUser;
                group = internalGroup;
              };
            };

            systemd.services.${sourceServiceName} = lib.mkIf settings.enable {
              description = "Admit the exact read-only Seaglass repository view for ${runtimeName}";
              after = [ "radicle-node.service" ];
              before = [ latticeUnit ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = lib.getExe sourceAdmission;
                RemainAfterExit = true;
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
                ReadWritePaths = [ settings.sourcePath ];
                CapabilityBoundingSet = [
                  "CAP_DAC_OVERRIDE"
                  "CAP_FOWNER"
                ];
                AmbientCapabilities = [
                  "CAP_DAC_OVERRIDE"
                  "CAP_FOWNER"
                ];
                NoNewPrivileges = false;
                RemoveIPC = true;
                RestrictNamespaces = true;
                RestrictRealtime = true;
                RestrictSUIDSGID = true;
                SystemCallArchitectures = "native";
                MemoryMax = sourceMemoryMaximum;
                CPUQuota = sourceCpuQuota;
                TasksMax = sourceTasksMaximum;
                TimeoutStartSec = serviceStartTimeout;
                InaccessiblePaths = [
                  "/run/secrets"
                  "/root"
                  "/home"
                  "/etc/ssh"
                ];
              };
            };

            systemd.services.${latticeServiceName} = lib.mkIf settings.enable {
              description = "Exact production Lattice workflow exchange for ${runtimeName}";
              wantedBy = [ "multi-user.target" ];
              after = [ sourceUnit ];
              requires = [ sourceUnit ];
              before = [ hostUnit ];
              serviceConfig = latticeHardening // {
                Type = "exec";
                User = latticeUser;
                Group = latticeUser;
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
                ReadOnlyPaths = [ settings.sourceView ];
                ReadWritePaths = [
                  settings.latticeStateDir
                  internalDirectory
                  settings.reportView
                ];
                MemoryMax = latticeMemoryMaximum;
                CPUQuota = latticeCpuQuota;
                TasksMax = latticeTasksMaximum;
                Restart = "on-failure";
                RestartSec = serviceRestartDelay;
                TimeoutStartSec = serviceStartTimeout;
                TimeoutStopSec = serviceStopTimeout;
              };
            };

            systemd.services.${hostServiceName} = lib.mkIf settings.enable {
              description = "Durable production Kiln semantics hosted by Aspen for ${runtimeName}";
              wantedBy = [ "multi-user.target" ];
              after = [ latticeUnit ];
              wants = [ latticeUnit ];
              serviceConfig = hostHardening // {
                Type = "exec";
                User = hostUser;
                Group = hostUser;
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
                  (toString settings.requestTimeoutMilliseconds)
                  "--poll-interval-ms"
                  (toString observationPollIntervalMilliseconds)
                ];
                ExecStartPost = lib.getExe grantAspenSocket;
                ReadWritePaths = [
                  settings.hostStateDir
                  ingressDirectory
                  internalDirectory
                ];
                MemoryMax = hostMemoryMaximum;
                CPUQuota = hostCpuQuota;
                TasksMax = hostTasksMaximum;
                Restart = "always";
                RestartSec = serviceRestartDelay;
                TimeoutStartSec = serviceStartTimeout;
                TimeoutStopSec = serviceStopTimeout;
              };
            };

            # Operator-only direct shadow. It has no wantedBy target and publishes no Radicle status.
            systemd.services.${shadowServiceName} = lib.mkIf settings.enable {
              description = "Run one direct production Kiln Aspen shadow request";
              after = [ hostUnit ];
              requires = [ hostUnit ];
              serviceConfig = shadowHardening // {
                Type = "oneshot";
                User = "radicle";
                Group = "radicle";
                ExecStart = lib.getExe shadowClient;
                MemoryMax = shadowMemoryMaximum;
                CPUQuota = shadowCpuQuota;
                TasksMax = shadowTasksMaximum;
                TimeoutStartSec = shadowStartTimeout;
              };
            };

            # Operator-only least-authority probe. It runs with the Lattice mount namespace policy.
            systemd.services.${authorityProbeServiceName} = lib.mkIf settings.enable {
              description = "Verify the production Lattice source, report, and hidden-path boundary";
              after = [ latticeUnit ];
              requires = [ latticeUnit ];
              serviceConfig = latticeHardening // {
                Type = "oneshot";
                User = latticeUser;
                Group = latticeUser;
                ExecStart = lib.getExe authorityProbe;
                ReadOnlyPaths = [ settings.sourceView ];
                ReadWritePaths = [ settings.reportView ];
                MemoryMax = shadowMemoryMaximum;
                CPUQuota = shadowCpuQuota;
                TasksMax = shadowTasksMaximum;
                TimeoutStartSec = serviceStartTimeout;
              };
            };

            services.radicle.ci.broker.settings.adapters.kiln =
              lib.mkIf (settings.enable && settings.routeMode == "aspen")
                {
                  command = lib.mkForce (lib.getExe aspenAdapter);
                  env = lib.mkForce { };
                };

            environment.systemPackages = lib.mkIf settings.enable [
              aspenAdapter
              providerPackage
              shadowClient
            ];
            environment.etc."${runtimeName}/aspen-profile.json".source = lib.mkIf settings.enable aspenProfile;
            environment.etc."${runtimeName}/radicle-profile.json".source =
              lib.mkIf settings.enable radicleProfile;
            environment.etc."${runtimeName}/provider-profile.json".source =
              lib.mkIf settings.enable providerProfile;
            environment.etc."${runtimeName}/lattice-handler.ncl".source =
              lib.mkIf settings.enable latticeHandlerProfile;
            environment.etc."${runtimeName}/lattice-workflow.ncl".source =
              lib.mkIf settings.enable latticeWorkflow;
          };
      };
  };

  perMachine = _: { nixosModule = _: { }; };
}
