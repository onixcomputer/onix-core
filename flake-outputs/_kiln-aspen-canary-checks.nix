{
  self,
  pkgs,
  lib,
  ...
}:
let
  desktopConfig = self.nixosConfigurations.britton-desktop.config;
  runtimeName = "kiln-aspen-canary";
  hostServiceName = "${runtimeName}-host";
  latticeServiceName = "${runtimeName}-lattice";
  latticeUnit = "${latticeServiceName}.service";
  acceptedServiceName = "${runtimeName}-accepted";
  rejectedServiceName = "${runtimeName}-rejected";
  unavailableServiceName = "${runtimeName}-unavailable";
  rollbackServiceName = "${runtimeName}-rollback-lattice";
  uncertainServiceName = "${runtimeName}-uncertain";
  hostService = desktopConfig.systemd.services.${hostServiceName};
  latticeService = desktopConfig.systemd.services.${latticeServiceName};
  acceptedService = desktopConfig.systemd.services.${acceptedServiceName};
  rejectedService = desktopConfig.systemd.services.${rejectedServiceName};
  unavailableService = desktopConfig.systemd.services.${unavailableServiceName};
  rollbackService = desktopConfig.systemd.services.${rollbackServiceName};
  uncertainService = desktopConfig.systemd.services.${uncertainServiceName};
  hostConfig = hostService.serviceConfig;
  latticeConfig = latticeService.serviceConfig;
  hostStaleSocketGuard = hostConfig.ExecStartPre;
  latticePreStart = latticeConfig.ExecStartPre;
  latticeStaleSocketGuard = builtins.elemAt latticePreStart 0;
  latticePrepareCommand = builtins.elemAt latticePreStart 1;
  hostUser = "${runtimeName}-host";
  latticeUser = "${runtimeName}-lattice";
  hostState = "/var/lib/kiln-aspen-canary/host";
  latticeState = "/var/lib/kiln-aspen-canary/lattice";
  runtimeDirectory = "/run/kiln-aspen-canary";
  aspenSocket = "${runtimeDirectory}/aspen.sock";
  latticeSocket = "${runtimeDirectory}/lattice.sock";
  expectedHostUid = 970;
  expectedLatticeUid = 971;
  expectedMaximumRequests = 64;
  dispatchConnectionsPerEffect = 1;
  maximumLatticeConnections = 65536;
  expectedProviderConnections = builtins.div maximumLatticeConnections expectedMaximumRequests;
  expectedProviderPolls = expectedProviderConnections - dispatchConnectionsPerEffect;
  expectedLatticeConnections = expectedMaximumRequests * expectedProviderConnections;
  expectedAspenRevision = "22f8ded26ca1907c29948e08b53f35df23080733";
  expectedKilnHostRevision = "69c0a6ac454d7291e4aed12fd72a6f2c31636e76";
  expectedKilnProtocolRevision = "42eabcb21385a436ddc044fb7034b8cdaec7b8a0";
  expectedLatticeRuntimeRevision = "c513d94d89e901ffa56ae67f375f973e55958e42";
  expectedLatticeContractRevision = "70496e67c7fd4a8b05914161a8e09de2759bebc8";
  kilnInput = self.lib.inputs.kiln-canary;
  latticeInput = self.lib.inputs.lattice;
  kilnPackage = kilnInput.packages.${pkgs.stdenv.hostPlatform.system}.kiln;
  hostPackage = kilnInput.packages.${pkgs.stdenv.hostPlatform.system}.kiln-aspen-host;
  latticePackage = latticeInput.packages.${pkgs.stdenv.hostPlatform.system}.lattice;
  brokerSettings = desktopConfig.services.radicle.ci.broker.settings;
  brokerCommand = brokerSettings.adapters.kiln.command;
  brokerTriggers = builtins.toJSON brokerSettings.triggers;
  aspenProfileSource = builtins.readFile "${kilnInput}/config/aspen-runtime-profile.ncl";
  radicleProfileSource = builtins.readFile "${kilnInput}/config/radicle-workflow-shell.ncl";
  hostManifest = builtins.readFile "${kilnInput}/runtime/kiln-aspen-host/Cargo.toml";
  hostReadme = builtins.readFile "${kilnInput}/runtime/kiln-aspen-host/README.md";
  hostLockPath = "${kilnInput}/runtime/kiln-aspen-host/Cargo.lock";
  positivePolicyValid =
    hostConfig.User == hostUser
    && latticeConfig.User == latticeUser
    && desktopConfig.users.users.${hostUser}.uid == expectedHostUid
    && desktopConfig.users.users.${latticeUser}.uid == expectedLatticeUid
    && desktopConfig.users.users.${hostUser}.group == runtimeName
    && desktopConfig.users.users.${latticeUser}.group == runtimeName
    && hostConfig.PrivateNetwork
    && latticeConfig.PrivateNetwork
    && hostConfig.RestrictAddressFamilies == [ "AF_UNIX" ]
    && latticeConfig.RestrictAddressFamilies == [ "AF_UNIX" ]
    && hostConfig.Restart == "no"
    && latticeConfig.Restart == "on-failure"
    && builtins.length latticePreStart == 2
    && builtins.elem latticeUnit hostService.after
    && builtins.elem latticeUnit hostService.requires
    && builtins.elem hostState hostConfig.ReadWritePaths
    && !(builtins.elem latticeState hostConfig.ReadWritePaths)
    && builtins.elem latticeState latticeConfig.ReadWritePaths
    && !(builtins.elem hostState latticeConfig.ReadWritePaths)
    && builtins.elem runtimeDirectory hostConfig.ReadWritePaths
    && builtins.elem runtimeDirectory latticeConfig.ReadWritePaths
    && acceptedService.wantedBy == [ ]
    && rejectedService.wantedBy == [ ]
    && unavailableService.wantedBy == [ ]
    && rollbackService.wantedBy == [ ]
    && uncertainService.wantedBy == [ ]
    && uncertainService.serviceConfig.User == hostUser
    && uncertainService.serviceConfig.Group == runtimeName;
  revisionsValid =
    kilnInput.rev == expectedKilnHostRevision
    && latticeInput.rev == expectedLatticeRuntimeRevision
    && lib.hasInfix expectedLatticeContractRevision radicleProfileSource
    && lib.hasInfix expectedAspenRevision aspenProfileSource
    && lib.hasInfix expectedKilnProtocolRevision hostReadme
    && lib.hasInfix "refs/namespaces/" hostManifest;
  existingRouteSeparate =
    !(lib.hasInfix aspenSocket brokerCommand)
    && !(lib.hasInfix "--runtime aspen" brokerCommand)
    && !(lib.hasInfix "kiln-aspen-private-canary" brokerTriggers);
  settingsEvaluator = import ../modules/kiln-aspen-canary/settings.nix { inherit lib; };
  baseSettings = {
    enable = true;
    runtimeName = runtimeName;
    hostStateDir = hostState;
    latticeStateDir = latticeState;
    hostUid = expectedHostUid;
    latticeUid = expectedLatticeUid;
    maximumRequests = expectedMaximumRequests;
    timeoutMilliseconds = 30000;
  };
  allAssertionsPass = result: builtins.all (assertion: assertion.assertion) result.assertions;
  anyAssertionFails = result: builtins.any (assertion: !assertion.assertion) result.assertions;
  settingsChecksValid =
    expectedLatticeConnections <= maximumLatticeConnections
    && allAssertionsPass (settingsEvaluator baseSettings)
    && anyAssertionFails (settingsEvaluator (baseSettings // { latticeStateDir = hostState; }))
    && anyAssertionFails (settingsEvaluator (baseSettings // { latticeUid = expectedHostUid; }))
    && anyAssertionFails (settingsEvaluator (baseSettings // { maximumRequests = 0; }))
    && anyAssertionFails (settingsEvaluator (baseSettings // { hostStateDir = "relative"; }));
  positiveRadicleProfile = pkgs.writeText "kiln-aspen-canary-positive-radicle.ncl" ''
    let make_profile = import ${builtins.toJSON ../modules/kiln-aspen-canary/profiles/radicle-profile.ncl} in
    make_profile {
      host_uid = ${toString expectedHostUid},
      socket_path = ${builtins.toJSON latticeSocket},
      replay_database_path = ${builtins.toJSON "${hostState}/radicle-replay.sqlite"},
      maximum_polls = ${toString expectedProviderPolls},
    }
  '';
  positiveHandlerProfile = pkgs.writeText "kiln-aspen-canary-positive-handler.ncl" ''
    let make_profile = import ${builtins.toJSON ../modules/kiln-aspen-canary/profiles/lattice-handler-profile.ncl} in
    make_profile {
      host_uid = ${toString expectedHostUid},
      socket_path = ${builtins.toJSON latticeSocket},
      maximum_connections = ${toString expectedLatticeConnections},
    }
  '';
  positiveLatticeConfig = pkgs.writeText "kiln-aspen-canary-positive-lattice.ncl" ''
    let make_config = import ${builtins.toJSON ../modules/kiln-aspen-canary/profiles/lattice-config.ncl} in
    make_config {
      data_dir = ${builtins.toJSON latticeState},
      shell = ${builtins.toJSON pkgs.runtimeShell},
    }
  '';
in
{
  checks = {
    # r[verify onix.kiln_aspen_canary.preflight.accepted]
    # r[verify onix.kiln_aspen_canary.authority.accepted]
    # r[verify onix.kiln_aspen_canary.failure.accepted]
    kiln-aspen-canary-module =
      assert lib.assertMsg positivePolicyValid
        "Kiln Aspen canary users, service order, state roots, or authority bounds drifted";
      assert lib.assertMsg revisionsValid
        "Kiln Aspen canary dependency revisions differ from the reviewed cohort";
      assert lib.assertMsg existingRouteSeparate
        "Kiln Aspen canary changed or captured the existing Seaglass broker route";
      assert lib.assertMsg settingsChecksValid
        "Kiln Aspen canary positive or negative settings fixtures did not classify correctly";
      pkgs.runCommand "kiln-aspen-canary-module-check" { } ''
        test -x ${lib.escapeShellArg "${hostPackage}/bin/kiln-aspen-host"}
        test -x ${lib.escapeShellArg "${kilnPackage}/bin/kiln-aspen-extension"}
        test -x ${lib.escapeShellArg "${kilnPackage}/bin/kiln-adapter-radicle"}
        test -x ${lib.escapeShellArg "${latticePackage}/bin/lattice"}
        test -x ${lib.escapeShellArg hostStaleSocketGuard}
        test -x ${lib.escapeShellArg latticeStaleSocketGuard}
        test -x ${lib.escapeShellArg latticePrepareCommand}
        grep -F -- ${lib.escapeShellArg aspenSocket} ${lib.escapeShellArg hostStaleSocketGuard} >/dev/null
        grep -F -- 'test ! -S "$socket"' ${lib.escapeShellArg hostStaleSocketGuard} >/dev/null
        grep -F -- 'rm -f -- "$socket"' ${lib.escapeShellArg hostStaleSocketGuard} >/dev/null
        if grep -F -- ${lib.escapeShellArg latticeSocket} ${lib.escapeShellArg hostStaleSocketGuard} >/dev/null; then
          echo "Aspen stale-socket guard targets the Lattice socket" >&2
          exit 1
        fi
        grep -F -- ${lib.escapeShellArg latticeSocket} ${lib.escapeShellArg latticeStaleSocketGuard} >/dev/null
        grep -F -- 'test ! -S "$socket"' ${lib.escapeShellArg latticeStaleSocketGuard} >/dev/null
        grep -F -- 'rm -f -- "$socket"' ${lib.escapeShellArg latticeStaleSocketGuard} >/dev/null
        if grep -F -- ${lib.escapeShellArg aspenSocket} ${lib.escapeShellArg latticeStaleSocketGuard} >/dev/null; then
          echo "Lattice stale-socket guard targets the Aspen socket" >&2
          exit 1
        fi
        grep -F -- ${lib.escapeShellArg expectedKilnProtocolRevision} ${lib.escapeShellArg hostLockPath} >/dev/null

        accepted=${lib.escapeShellArg acceptedService.serviceConfig.ExecStart}
        unavailable=${lib.escapeShellArg unavailableService.serviceConfig.ExecStart}
        rollback=${lib.escapeShellArg rollbackService.serviceConfig.ExecStart}
        uncertain=${lib.escapeShellArg uncertainService.serviceConfig.ExecStart}
        grep -F -- '--runtime aspen' "$accepted" >/dev/null
        if grep -F -- '--runtime lattice' "$accepted" >/dev/null; then
          echo "accepted canary client contains an automatic Lattice fallback" >&2
          exit 1
        fi
        grep -F -- '--runtime aspen' "$unavailable" >/dev/null
        grep -F -- '"fallback":"none"' "$unavailable" >/dev/null
        grep -F -- '--runtime lattice' "$rollback" >/dev/null
        if grep -F -- '--aspen-socket' "$rollback" >/dev/null; then
          echo "explicit Lattice rollback still contains Aspen selection" >&2
          exit 1
        fi
        grep -F -- '--runtime aspen' "$uncertain" >/dev/null
        grep -F -- 'aspen_ingress_unknown' "$uncertain" >/dev/null
        grep -F -- '"classification":"unknown_after_write"' "$uncertain" >/dev/null
        grep -F -- 'socat -u' "$uncertain" >/dev/null
        if grep -F -- 'runuser' "$uncertain" >/dev/null; then
          echo "uncertainty drill retains avoidable root impersonation" >&2
          exit 1
        fi
        touch "$out"
      '';

    # r[verify onix.kiln_aspen_canary.composition.accepted]
    # r[verify onix.kiln_aspen_canary.composition.rejected]
    kiln-aspen-canary-profiles =
      pkgs.runCommand "kiln-aspen-canary-profile-check"
        {
          nativeBuildInputs = [ pkgs.nickel ];
        }
        ''
          nickel format --check \
            ${../modules/kiln-aspen-canary/schema.ncl} \
            ${../modules/kiln-aspen-canary/profiles/lattice-config.ncl} \
            ${../modules/kiln-aspen-canary/profiles/lattice-handler-profile.ncl} \
            ${../modules/kiln-aspen-canary/profiles/lattice-workflow.ncl} \
            ${../modules/kiln-aspen-canary/profiles/radicle-profile.ncl} \
            ${../modules/kiln-aspen-canary/profiles/fixtures/negative-handler-relative-socket.ncl} \
            ${../modules/kiln-aspen-canary/profiles/fixtures/negative-handler-overbound-connections.ncl} \
            ${../modules/kiln-aspen-canary/profiles/fixtures/negative-lattice-relative-state.ncl} \
            ${../modules/kiln-aspen-canary/profiles/fixtures/negative-radicle-zero-uid.ncl}
          nickel typecheck ${../modules/kiln-aspen-canary/profiles/lattice-config.ncl}
          nickel typecheck ${../modules/kiln-aspen-canary/profiles/lattice-handler-profile.ncl}
          nickel typecheck ${../modules/kiln-aspen-canary/profiles/lattice-workflow.ncl}
          nickel typecheck ${../modules/kiln-aspen-canary/profiles/radicle-profile.ncl}
          nickel export --format json ${positiveRadicleProfile} >/dev/null
          nickel export --format json ${positiveHandlerProfile} >/dev/null
          nickel export --format json ${positiveLatticeConfig} >/dev/null
          nickel export --format json \
            ${../modules/kiln-aspen-canary/profiles/lattice-workflow.ncl} >/dev/null
          for fixture in \
            ${../modules/kiln-aspen-canary/profiles/fixtures/negative-handler-relative-socket.ncl} \
            ${../modules/kiln-aspen-canary/profiles/fixtures/negative-handler-overbound-connections.ncl} \
            ${../modules/kiln-aspen-canary/profiles/fixtures/negative-lattice-relative-state.ncl} \
            ${../modules/kiln-aspen-canary/profiles/fixtures/negative-radicle-zero-uid.ncl}; do
            if nickel export --format json "$fixture" >/dev/null 2>&1; then
              echo "negative Kiln Aspen canary profile passed: $fixture" >&2
              exit 1
            fi
          done
          touch "$out"
        '';
  };
}
