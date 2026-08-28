{
  self,
  pkgs,
  lib,
  ...
}:
let
  desktopConfig = self.nixosConfigurations.britton-desktop.config;
  runtimeName = "kiln-aspen-ci";
  hostServiceName = "${runtimeName}-host";
  latticeServiceName = "${runtimeName}-lattice";
  sourceServiceName = "${runtimeName}-source-admission";
  shadowServiceName = "${runtimeName}-shadow";
  authorityProbeServiceName = "${runtimeName}-authority-probe";
  hostUnit = "${hostServiceName}.service";
  latticeUnit = "${latticeServiceName}.service";
  sourceUnit = "${sourceServiceName}.service";
  hostService = desktopConfig.systemd.services.${hostServiceName};
  latticeService = desktopConfig.systemd.services.${latticeServiceName};
  sourceService = desktopConfig.systemd.services.${sourceServiceName};
  shadowService = desktopConfig.systemd.services.${shadowServiceName};
  authorityProbeService = desktopConfig.systemd.services.${authorityProbeServiceName};
  hostConfig = hostService.serviceConfig;
  latticeConfig = latticeService.serviceConfig;
  sourceConfig = sourceService.serviceConfig;
  shadowConfig = shadowService.serviceConfig;
  authorityProbeConfig = authorityProbeService.serviceConfig;
  hostUser = "${runtimeName}-host";
  latticeUser = "${runtimeName}-lattice";
  ingressGroup = "${runtimeName}-ingress";
  internalGroup = "${runtimeName}-internal";
  sourceGroup = "${runtimeName}-source";
  reportGroup = "${runtimeName}-report";
  hostState = "/var/lib/kiln-aspen-radicle-ci/host";
  latticeState = "/var/lib/kiln-aspen-radicle-ci/lattice";
  sourcePath = "/var/lib/radicle/storage/z3xXXCQXCTquvAawh41YYs8yC8xmk";
  sourceView = "/var/lib/kiln-aspen-radicle-ci/source/seaglass.git";
  reportPath = "/var/lib/radicle-ci/reports/aspen";
  reportView = "/var/lib/kiln-aspen-radicle-ci/report-view";
  runtimeDirectory = "/run/${runtimeName}";
  ingressDirectory = "${runtimeDirectory}/ingress";
  internalDirectory = "${runtimeDirectory}/internal";
  aspenSocket = "${ingressDirectory}/aspen.sock";
  latticeSocket = "${internalDirectory}/lattice.sock";
  expectedHostUid = 974;
  expectedLatticeUid = 975;
  expectedMaximumRequests = 64;
  expectedKilnRevision = "ccf6c64e8cba1d77299eab1386788426fa63e43e";
  expectedLegacyRevision = "8821e9adf15ad28838025bfbdd2e09c8d76fe5db";
  expectedLatticeRuntimeRevision = "c513d94d89e901ffa56ae67f375f973e55958e42";
  expectedLatticeContractRevision = "70496e67c7fd4a8b05914161a8e09de2759bebc8";
  expectedWorkflowRevision = "b3:8f3706acd56e69145affe40a15aa1536599a88111f3905bc3a5a047a4d5deda2";
  dispatchConnectionsPerEffect = 1;
  maximumLatticeConnections = 65536;
  expectedProviderConnections = builtins.div maximumLatticeConnections expectedMaximumRequests;
  expectedProviderPolls = expectedProviderConnections - dispatchConnectionsPerEffect;
  expectedLatticeConnections = expectedMaximumRequests * expectedProviderConnections;
  kilnInput = self.lib.inputs.kiln;
  legacyInput = self.lib.inputs.kiln-ci-legacy;
  legacyPackage = legacyInput.packages.${pkgs.stdenv.hostPlatform.system}.default;
  expectedLegacyCommand = "${legacyPackage}/bin/kiln-adapter-radicle";
  latticeInput = self.lib.inputs.lattice;
  kilnPackage = kilnInput.packages.${pkgs.stdenv.hostPlatform.system}.kiln;
  hostPackage = kilnInput.packages.${pkgs.stdenv.hostPlatform.system}.kiln-aspen-host;
  providerPackage = kilnInput.packages.${pkgs.stdenv.hostPlatform.system}.kiln-radicle-nix-provider;
  latticePackage = latticeInput.packages.${pkgs.stdenv.hostPlatform.system}.lattice;
  aspenAdapterPackage =
    lib.findFirst (package: (package.name or "") == "${runtimeName}-adapter")
      (throw "Kiln Aspen production adapter package is missing")
      desktopConfig.environment.systemPackages;
  aspenAdapterCommand = "${aspenAdapterPackage}/bin/${runtimeName}-adapter";
  providerProfile = desktopConfig.environment.etc."${runtimeName}/provider-profile.json".source;
  workflowProfile = desktopConfig.environment.etc."${runtimeName}/lattice-workflow.ncl".source;
  handlerProfile = desktopConfig.environment.etc."${runtimeName}/lattice-handler.ncl".source;
  sourceAdmissionCommand = sourceConfig.ExecStart;
  authorityProbeCommand = authorityProbeConfig.ExecStart;
  shadowCommand = shadowConfig.ExecStart;
  hostPreStart = hostConfig.ExecStartPre;
  latticePreStart = latticeConfig.ExecStartPre;
  hostSocketGrant = hostConfig.ExecStartPost;
  latticeSocketGrant = latticeConfig.ExecStartPost;
  brokerSettings = desktopConfig.services.radicle.ci.broker.settings;
  brokerCommand = brokerSettings.adapters.kiln.command;
  hostGroups = desktopConfig.users.users.${hostUser}.extraGroups;
  latticeGroups = desktopConfig.users.users.${latticeUser}.extraGroups;
  radicleGroups = desktopConfig.users.users.radicle.extraGroups;
  commonHiddenPaths = [
    "/run/secrets"
    "/root"
    "/home"
    "/etc/ssh"
  ];
  machinePolicyValid =
    hostConfig.User == hostUser
    && hostConfig.Group == hostUser
    && latticeConfig.User == latticeUser
    && latticeConfig.Group == latticeUser
    && desktopConfig.users.users.${hostUser}.uid == expectedHostUid
    && desktopConfig.users.users.${latticeUser}.uid == expectedLatticeUid
    && builtins.all (path: builtins.elem path hostConfig.InaccessiblePaths) (
      commonHiddenPaths
      ++ [
        "/var/lib/radicle"
        "/var/lib/radicle-ci"
        sourceView
        reportView
        latticeState
      ]
    )
    && builtins.all (path: builtins.elem path latticeConfig.InaccessiblePaths) (
      commonHiddenPaths
      ++ [
        "/var/lib/radicle"
        "/var/lib/radicle-ci"
        ingressDirectory
        hostState
      ]
    )
    && hostConfig.PrivateNetwork
    && latticeConfig.PrivateNetwork
    && shadowConfig.PrivateNetwork
    && hostConfig.RestrictAddressFamilies == [ "AF_UNIX" ]
    && latticeConfig.RestrictAddressFamilies == [ "AF_UNIX" ]
    && hostConfig.Restart == "always"
    && latticeConfig.Restart == "on-failure"
    && builtins.elem latticeUnit hostService.after
    && builtins.elem latticeUnit hostService.wants
    && !(builtins.elem latticeUnit hostService.requires)
    && builtins.elem sourceUnit latticeService.after
    && builtins.elem sourceUnit latticeService.requires
    && builtins.elem latticeUnit sourceService.before
    &&
      hostConfig.ReadWritePaths == [
        hostState
        ingressDirectory
        internalDirectory
      ]
    &&
      latticeConfig.ReadWritePaths == [
        latticeState
        internalDirectory
        reportView
      ]
    && latticeConfig.BindReadOnlyPaths == [ "${sourcePath}:${sourceView}" ]
    && latticeConfig.BindPaths == [ "${reportPath}:${reportView}" ]
    && sourceConfig.ReadWritePaths == [ sourcePath ]
    &&
      sourceConfig.CapabilityBoundingSet == [
        "CAP_DAC_OVERRIDE"
        "CAP_FOWNER"
      ]
    &&
      hostGroups == [
        ingressGroup
        internalGroup
      ]
    &&
      latticeGroups == [
        internalGroup
        sourceGroup
        reportGroup
      ]
    && builtins.elem ingressGroup radicleGroups
    && builtins.elem reportGroup radicleGroups
    && !(builtins.elem internalGroup radicleGroups)
    && !(builtins.elem sourceGroup radicleGroups)
    && !(builtins.elem reportGroup hostGroups)
    && !(builtins.elem sourceGroup hostGroups)
    && shadowService.wantedBy == [ ]
    && shadowConfig.User == "radicle"
    && authorityProbeService.wantedBy == [ ]
    && authorityProbeConfig.User == latticeUser
    && authorityProbeConfig.BindReadOnlyPaths == [ "${sourcePath}:${sourceView}" ]
    && authorityProbeConfig.BindPaths == [ "${reportPath}:${reportView}" ]
    && authorityProbeConfig.ReadWritePaths == [ reportView ];
  revisionsValid =
    kilnInput.rev == expectedKilnRevision
    && legacyInput.rev == expectedLegacyRevision
    && latticeInput.rev == expectedLatticeRuntimeRevision
    && lib.hasInfix expectedLatticeContractRevision (
      builtins.readFile ../modules/kiln-aspen-radicle-ci/profiles/radicle-profile.ncl
    );
  routeStillLegacy =
    brokerCommand == expectedLegacyCommand
    && !(lib.hasInfix aspenSocket brokerCommand)
    && !(lib.hasInfix "--runtime aspen" brokerCommand);
  settingsEvaluator = import ../modules/kiln-aspen-radicle-ci/settings.nix { inherit lib; };
  baseSettings = {
    enable = true;
    runtimeName = runtimeName;
    routeMode = "shadow";
    hostStateDir = hostState;
    latticeStateDir = latticeState;
    inherit
      reportPath
      reportView
      sourcePath
      sourceView
      ;
    repository = "rad:z3xXXCQXCTquvAawh41YYs8yC8xmk";
    reportNamespace = "seaglass";
    reportBaseUrl = "https://ci.onix.computer/reports/aspen";
    hostUid = expectedHostUid;
    latticeUid = expectedLatticeUid;
    maximumRequests = expectedMaximumRequests;
    requestTimeoutMilliseconds = 30000;
    providerTimeoutMilliseconds = 7200000;
    providerStdoutMaxBytes = 8388608;
    providerStderrMaxBytes = 8388608;
    providerReportMaxBytes = 16777216;
    providerWrapperMaxBytes = 262144;
    providerPollMilliseconds = 100;
    providerTeardownTimeoutMilliseconds = 30000;
    providerStageCollisionAttempts = 8;
  };
  allAssertionsPass = result: builtins.all (assertion: assertion.assertion) result.assertions;
  anyAssertionFails = result: builtins.any (assertion: !assertion.assertion) result.assertions;
  settingsChecksValid =
    expectedLatticeConnections <= maximumLatticeConnections
    && allAssertionsPass (settingsEvaluator baseSettings)
    && anyAssertionFails (settingsEvaluator (baseSettings // { routeMode = "fallback"; }))
    && anyAssertionFails (settingsEvaluator (baseSettings // { sourcePath = "/var/lib/radicle"; }))
    && anyAssertionFails (settingsEvaluator (baseSettings // { reportView = sourceView; }))
    && anyAssertionFails (settingsEvaluator (baseSettings // { hostUid = 970; }))
    && anyAssertionFails (settingsEvaluator (baseSettings // { providerTimeoutMilliseconds = 0; }))
    && anyAssertionFails (settingsEvaluator (baseSettings // { reportPath = "/tmp/reports"; }));
  positiveRadicleProfile = pkgs.writeText "kiln-aspen-ci-positive-radicle.ncl" ''
    let make_profile = import ${builtins.toJSON ../modules/kiln-aspen-radicle-ci/profiles/radicle-profile.ncl} in
    make_profile {
      host_uid = ${toString expectedHostUid},
      socket_path = ${builtins.toJSON latticeSocket},
      replay_database_path = ${builtins.toJSON "${hostState}/radicle-replay.sqlite"},
      maximum_polls = ${toString expectedProviderPolls},
    }
  '';
  positiveHandlerProfile = pkgs.writeText "kiln-aspen-ci-positive-handler.ncl" ''
    let make_profile = import ${builtins.toJSON ../modules/kiln-aspen-radicle-ci/profiles/lattice-handler-profile.ncl} in
    make_profile {
      host_uid = ${toString expectedHostUid},
      socket_path = ${builtins.toJSON latticeSocket},
      maximum_connections = ${toString expectedLatticeConnections},
      workflow_revision = ${builtins.toJSON expectedWorkflowRevision},
    }
  '';
  positiveLatticeConfig = pkgs.writeText "kiln-aspen-ci-positive-lattice.ncl" ''
    let make_config = import ${builtins.toJSON ../modules/kiln-aspen-radicle-ci/profiles/lattice-config.ncl} in
    make_config {
      data_dir = ${builtins.toJSON latticeState},
      shell = ${builtins.toJSON pkgs.runtimeShell},
      command_timeout_seconds = 7290,
    }
  '';
  positiveWorkflow = pkgs.writeText "kiln-aspen-ci-positive-workflow.ncl" ''
    let make_workflow = import ${builtins.toJSON ../modules/kiln-aspen-radicle-ci/profiles/lattice-workflow.ncl} in
    make_workflow {
      provider_executable = "/nix/store/provider/bin/kiln-radicle-nix-provider",
      provider_profile = "/nix/store/provider-profile.json",
      repository = "rad:z3xXXCQXCTquvAawh41YYs8yC8xmk",
      command_timeout_seconds = 7290,
    }
  '';
in
{
  checks = {
    # r[verify onix.radicle_ci.aspen_composition.accepted]
    # r[verify onix.radicle_ci.aspen_authority.accepted]
    kiln-aspen-radicle-ci-module =
      assert lib.assertMsg machinePolicyValid
        "Kiln Aspen production users, sockets, service order, state roots, or authority bounds drifted";
      assert lib.assertMsg revisionsValid
        "Kiln Aspen production dependency revisions differ from the reviewed cohort";
      assert lib.assertMsg routeStillLegacy
        "Kiln Aspen production staging changed the active legacy broker route";
      assert lib.assertMsg settingsChecksValid
        "Kiln Aspen production positive or negative settings fixtures did not classify correctly";
      pkgs.runCommand "kiln-aspen-radicle-ci-module-check"
        {
          nativeBuildInputs = [
            pkgs.b3sum
            pkgs.jq
          ];
        }
        ''
          test -x ${lib.escapeShellArg "${hostPackage}/bin/kiln-aspen-host"}
          test -x ${lib.escapeShellArg "${kilnPackage}/bin/kiln-aspen-extension"}
          test -x ${lib.escapeShellArg "${kilnPackage}/bin/kiln-adapter-radicle"}
          test -x ${lib.escapeShellArg "${providerPackage}/bin/kiln-radicle-nix-provider"}
          test -x ${lib.escapeShellArg "${latticePackage}/bin/lattice"}
          test -f ${lib.escapeShellArg providerProfile}
          test -f ${lib.escapeShellArg workflowProfile}
          test -f ${lib.escapeShellArg handlerProfile}

          jq -e \
            --arg source ${lib.escapeShellArg sourceView} \
            --arg report ${lib.escapeShellArg reportView} \
            --arg repository 'rad:z3xXXCQXCTquvAawh41YYs8yC8xmk' \
            --argjson uid ${toString expectedLatticeUid} \
            '.schema == "kiln.radicle-nix-provider.v1"
             and .source_root == $source
             and .report_root == $report
             and .repository == $repository
             and .allowed_user_id == $uid' \
            ${lib.escapeShellArg providerProfile} >/dev/null
          wrapper="$(jq -r .wrapper_path ${lib.escapeShellArg providerProfile})"
          expected_wrapper="$(jq -r .wrapper_blake3 ${lib.escapeShellArg providerProfile})"
          observed_wrapper="$(b3sum "$wrapper" | cut -d' ' -f1)"
          test "$observed_wrapper" = "$expected_wrapper"
          grep -F -- '--override-input cairn/artifact' "$wrapper" >/dev/null
          grep -F -- 'accept-flake-config = false' "$wrapper" >/dev/null
          grep -F -- 'builders =' "$wrapper" >/dev/null

          test -x ${lib.escapeShellArg aspenAdapterCommand}
          grep -F -- '--protocol defelo' ${lib.escapeShellArg aspenAdapterCommand} >/dev/null
          grep -F -- '--runtime aspen' ${lib.escapeShellArg aspenAdapterCommand} >/dev/null
          if grep -F -- '--runtime lattice' ${lib.escapeShellArg aspenAdapterCommand} >/dev/null; then
            echo "production adapter contains an automatic Lattice fallback" >&2
            exit 1
          fi
          grep -F -- '--protocol native' ${lib.escapeShellArg shadowCommand} >/dev/null
          grep -F -- '--runtime aspen' ${lib.escapeShellArg shadowCommand} >/dev/null
          if grep -F -- '--runtime lattice' ${lib.escapeShellArg shadowCommand} >/dev/null; then
            echo "shadow command contains an automatic Lattice fallback" >&2
            exit 1
          fi
          grep -F -- ${lib.escapeShellArg sourcePath} ${lib.escapeShellArg sourceAdmissionCommand} >/dev/null
          grep -F -- 'type l' ${lib.escapeShellArg sourceAdmissionCommand} >/dev/null
          grep -F -- 'd:g:$group:r-x' ${lib.escapeShellArg sourceAdmissionCommand} >/dev/null
          if grep -E -- 'curl|wget|ssh ' ${lib.escapeShellArg sourceAdmissionCommand} >/dev/null; then
            echo "source admission gained network tooling" >&2
            exit 1
          fi
          grep -F -- ${lib.escapeShellArg sourceView} ${lib.escapeShellArg authorityProbeCommand} >/dev/null
          grep -F -- ${lib.escapeShellArg reportView} ${lib.escapeShellArg authorityProbeCommand} >/dev/null
          grep -F -- '5f659dce24e13b30e996f0aab3419dac4c21f934' ${lib.escapeShellArg authorityProbeCommand} >/dev/null
          grep -F -- '/var/lib/radicle-ci' ${lib.escapeShellArg authorityProbeCommand} >/dev/null
          grep -F -- 'source view is writable' ${lib.escapeShellArg authorityProbeCommand} >/dev/null

          grep -F -- ${lib.escapeShellArg aspenSocket} ${lib.escapeShellArg hostPreStart} >/dev/null
          grep -F -- ${lib.escapeShellArg latticeSocket} ${lib.escapeShellArg (builtins.elemAt latticePreStart 0)} >/dev/null
          grep -F -- ${lib.escapeShellArg ingressGroup} ${lib.escapeShellArg hostSocketGrant} >/dev/null
          grep -F -- ${lib.escapeShellArg internalGroup} ${lib.escapeShellArg latticeSocketGrant} >/dev/null
          touch "$out"
        '';

    # r[verify onix.radicle_ci.aspen_composition.rejected]
    # r[verify onix.radicle_ci.aspen_authority.rejected]
    kiln-aspen-radicle-ci-profiles =
      pkgs.runCommand "kiln-aspen-radicle-ci-profile-check"
        {
          nativeBuildInputs = [ pkgs.nickel ];
        }
        ''
          nickel format --check \
            ${../modules/kiln-aspen-radicle-ci/schema.ncl} \
            ${../modules/kiln-aspen-radicle-ci/profiles/lattice-config.ncl} \
            ${../modules/kiln-aspen-radicle-ci/profiles/lattice-handler-profile.ncl} \
            ${../modules/kiln-aspen-radicle-ci/profiles/lattice-workflow.ncl} \
            ${../modules/kiln-aspen-radicle-ci/profiles/radicle-profile.ncl} \
            ${../modules/kiln-aspen-radicle-ci/profiles/fixtures/negative-handler-revision.ncl} \
            ${../modules/kiln-aspen-radicle-ci/profiles/fixtures/negative-workflow-relative-provider.ncl}
          nickel typecheck ${../modules/kiln-aspen-radicle-ci/profiles/lattice-config.ncl}
          nickel typecheck ${../modules/kiln-aspen-radicle-ci/profiles/lattice-handler-profile.ncl}
          nickel typecheck ${../modules/kiln-aspen-radicle-ci/profiles/lattice-workflow.ncl}
          nickel typecheck ${../modules/kiln-aspen-radicle-ci/profiles/radicle-profile.ncl}
          nickel export --format json ${positiveRadicleProfile} >/dev/null
          nickel export --format json ${positiveHandlerProfile} >/dev/null
          nickel export --format json ${positiveLatticeConfig} >/dev/null
          nickel export --format json ${positiveWorkflow} >/dev/null
          for fixture in \
            ${../modules/kiln-aspen-radicle-ci/profiles/fixtures/negative-handler-revision.ncl} \
            ${../modules/kiln-aspen-radicle-ci/profiles/fixtures/negative-workflow-relative-provider.ncl}; do
            if nickel export --format json "$fixture" >/dev/null 2>&1; then
              echo "negative Kiln Aspen production profile passed: $fixture" >&2
              exit 1
            fi
          done
          touch "$out"
        '';
  };
}
