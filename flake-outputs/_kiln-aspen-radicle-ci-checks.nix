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
  sourceRefreshServiceName = "${runtimeName}-source-refresh";
  shadowServiceName = "${runtimeName}-shadow";
  authorityProbeServiceName = "${runtimeName}-authority-probe";
  latticeUnit = "${latticeServiceName}.service";
  sourceUnit = "${sourceServiceName}.service";
  hostService = desktopConfig.systemd.services.${hostServiceName};
  latticeService = desktopConfig.systemd.services.${latticeServiceName};
  sourceService = desktopConfig.systemd.services.${sourceServiceName};
  sourceRefreshService = desktopConfig.systemd.services.${sourceRefreshServiceName};
  sourceRefreshPath = desktopConfig.systemd.paths.${sourceRefreshServiceName};
  shadowService = desktopConfig.systemd.services.${shadowServiceName};
  authorityProbeService = desktopConfig.systemd.services.${authorityProbeServiceName};
  hostConfig = hostService.serviceConfig;
  latticeConfig = latticeService.serviceConfig;
  sourceConfig = sourceService.serviceConfig;
  sourceRefreshConfig = sourceRefreshService.serviceConfig;
  sourceRefreshPathConfig = sourceRefreshPath.pathConfig;
  shadowConfig = shadowService.serviceConfig;
  authorityProbeConfig = authorityProbeService.serviceConfig;
  hostUser = "${runtimeName}-host";
  latticeUser = "${runtimeName}-lattice";
  ingressGroup = "${runtimeName}-ingress";
  internalGroup = "${runtimeName}-internal";
  sourceGroup = "${runtimeName}-source";
  reportGroup = "${runtimeName}-report";
  hostState = "/var/lib/kiln-aspen-radicle-ci/host";
  quarantineDirectory = "/var/lib/kiln-aspen-radicle-ci/quarantine";
  latticeState = "/var/lib/kiln-aspen-radicle-ci/lattice";
  sourcePath = "/var/lib/radicle/storage/z3xXXCQXCTquvAawh41YYs8yC8xmk";
  sourceOwnerNodeId = "z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx";
  sourceRefreshUnit = "${sourceRefreshServiceName}.service";
  statusSyncServiceName = "${runtimeName}-status-sync";
  statusSyncService = desktopConfig.systemd.services.${statusSyncServiceName};
  statusSyncPath = desktopConfig.systemd.paths.${statusSyncServiceName};
  statusSyncConfig = statusSyncService.serviceConfig;
  statusSyncPathConfig = statusSyncPath.pathConfig;
  statusSyncUnit = "${statusSyncServiceName}.service";
  ciStatusNamespaceNodeId = "z6MkkQCj5EczNiVzDzCkX9ewHNJ7NDEXSKbuRiS1x7o72yeG";
  brokerPackage = desktopConfig.services.radicle.ci.broker.package;
  radicleStateDirectory = "/var/lib/radicle";
  expectedStatusSyncPaths = [
    "${sourcePath}/refs/namespaces/${ciStatusNamespaceNodeId}/refs/rad/sigrefs"
  ];
  expectedSourceRefreshPaths = [
    "${sourcePath}/objects/pack"
    "${sourcePath}/refs/heads/master"
    "${sourcePath}/refs/namespaces/${sourceOwnerNodeId}/refs/heads/master"
  ];
  sourceView = "/var/lib/kiln-aspen-radicle-ci/source/seaglass.git";
  reportPath = "/var/lib/radicle-ci/reports/aspen";
  reportView = "/var/lib/kiln-aspen-radicle-ci/report-view";
  runtimeDirectory = "/run/${runtimeName}";
  ingressDirectory = "${runtimeDirectory}/ingress";
  internalDirectory = "${runtimeDirectory}/internal";
  aspenSocket = "${ingressDirectory}/aspen.sock";
  latticeSocket = "${internalDirectory}/lattice.sock";
  providerWorkflowExecutable = "/run/current-system/sw/bin/kiln-radicle-nix-provider";
  providerWorkflowProfile = "/etc/${runtimeName}/provider-profile.json";
  expectedHostUid = 974;
  expectedLatticeUid = 975;
  expectedMaximumRequests = 64;
  bytesPerMebibyte = 1024 * 1024;
  expectedProviderOutputMebibytes = 8;
  expectedProviderReportMebibytes = 17;
  expectedProviderOutputBytes = expectedProviderOutputMebibytes * bytesPerMebibyte;
  expectedProviderReportBytes = expectedProviderReportMebibytes * bytesPerMebibyte;
  expectedKilnRevision = "8c9338e5c10a0e16ee3042d11583ccccf6efe7e9";
  expectedLegacyRevision = "8821e9adf15ad28838025bfbdd2e09c8d76fe5db";
  expectedLatticeRuntimeRevision = "feb16b911a23e36d22d1359e44a9bc6b692cc98c";
  expectedLatticeContractRevision = "70496e67c7fd4a8b05914161a8e09de2759bebc8";
  expectedWorkflowRevision = "b3:616b5d8beb00044accf14e88c3d71b487669535e6dbf54c02fc2c4929fbc3e4a";
  dispatchConnectionsPerEffect = 1;
  maximumLatticeConnections = 65536;
  expectedProviderConnections = builtins.div maximumLatticeConnections expectedMaximumRequests;
  expectedProviderPolls = expectedProviderConnections - dispatchConnectionsPerEffect;
  expectedLatticeConnections = expectedMaximumRequests * expectedProviderConnections;
  expectedProviderTimeoutMilliseconds = 7200000;
  expectedProviderTeardownMilliseconds = 30000;
  expectedSourceRevisionHexLength = 40;
  expectedSourceReadyTimeoutSeconds = 60;
  expectedSourceReadyDelayMilliseconds = 50;
  expectedSourceReadyAttempts = builtins.div (
    expectedSourceReadyTimeoutSeconds * expectedMillisecondsPerSecond
  ) expectedSourceReadyDelayMilliseconds;
  expectedSourceReadyDelaySeconds = "0.05";
  expectedSourceReadyHorizonMilliseconds =
    expectedSourceReadyAttempts * expectedSourceReadyDelayMilliseconds;
  sourceReadinessBoundsValid =
    expectedSourceReadyAttempts > 0
    && expectedSourceReadyDelayMilliseconds > 0
    &&
      expectedSourceReadyHorizonMilliseconds
      >= expectedSourceReadyTimeoutSeconds * expectedMillisecondsPerSecond;
  invalidSourceRevision = builtins.concatStringsSep "" (
    builtins.genList (_index: "0") expectedSourceRevisionHexLength
  );
  expectedProviderOperationMilliseconds =
    expectedProviderTimeoutMilliseconds + expectedProviderTeardownMilliseconds;
  expectedWorkflowCompletionMarginMilliseconds = 60000;
  expectedWorkflowTimeoutMilliseconds =
    expectedProviderOperationMilliseconds + expectedWorkflowCompletionMarginMilliseconds;
  expectedMillisecondsPerSecond = 1000;
  expectedWorkflowTimeoutSeconds = builtins.div expectedWorkflowTimeoutMilliseconds expectedMillisecondsPerSecond;
  expectedObservationPollRoundingMilliseconds = expectedProviderPolls - 1;
  expectedObservationPollMilliseconds = builtins.div (
    expectedProviderOperationMilliseconds + expectedObservationPollRoundingMilliseconds
  ) expectedProviderPolls;
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
  aspenProfile = desktopConfig.environment.etc."${runtimeName}/aspen-profile.json".source;
  providerProfile = desktopConfig.environment.etc."${runtimeName}/provider-profile.json".source;
  workflowProfile = desktopConfig.environment.etc."${runtimeName}/lattice-workflow.ncl".source;
  handlerProfile = desktopConfig.environment.etc."${runtimeName}/lattice-handler.ncl".source;
  sourceAdmissionCommand = sourceConfig.ExecStart;
  authorityProbeCommand = authorityProbeConfig.ExecStart;
  shadowCommand = shadowConfig.ExecStart;
  hostStartCommand = hostConfig.ExecStart;
  hostPreStart = hostConfig.ExecStartPre;
  latticePreStart = latticeConfig.ExecStartPre;
  latticePrepareCommand = builtins.elemAt latticePreStart 1;
  hostSocketGrant = hostConfig.ExecStartPost;
  latticeSocketGrant = latticeConfig.ExecStartPost;
  brokerSettings = desktopConfig.services.radicle.ci.broker.settings;
  brokerCommand = brokerSettings.adapters.kiln.command;
  brokerEnvironment = brokerSettings.adapters.kiln.env;
  hostGroups = desktopConfig.users.users.${hostUser}.extraGroups;
  latticeGroups = desktopConfig.users.users.${latticeUser}.extraGroups;
  radicleGroups = desktopConfig.users.users.radicle.extraGroups;
  tmpfileSettings = desktopConfig.systemd.tmpfiles.settings."10-${runtimeName}";
  reportTmpfile = tmpfileSettings.${reportPath}.d;
  quarantineTmpfile = tmpfileSettings.${quarantineDirectory}.d;
  reportNamespaceTmpfile = tmpfileSettings."${reportPath}/seaglass".d;
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
    && sourceConfig.User == "root"
    && sourceConfig.Group == "root"
    && sourceConfig.PrivateNetwork
    && sourceConfig.ReadWritePaths == [ sourcePath ]
    &&
      sourceConfig.CapabilityBoundingSet == [
        "CAP_DAC_OVERRIDE"
        "CAP_FOWNER"
      ]
    && sourceRefreshConfig.User == "root"
    && sourceRefreshConfig.Group == "root"
    && sourceRefreshConfig.PrivateNetwork
    && sourceRefreshConfig.ReadWritePaths == [ sourcePath ]
    && sourceRefreshConfig.CapabilityBoundingSet == sourceConfig.CapabilityBoundingSet
    && builtins.elem sourceUnit sourceRefreshService.after
    && builtins.elem sourceUnit sourceRefreshService.requires
    && sourceRefreshPath.wantedBy == [ "multi-user.target" ]
    && builtins.elem sourceUnit sourceRefreshPath.after
    && builtins.elem sourceUnit sourceRefreshPath.wants
    && sourceRefreshPathConfig.Unit == sourceRefreshUnit
    && sourceRefreshPathConfig.PathModified == expectedSourceRefreshPaths
    && statusSyncPath.wantedBy == [ "multi-user.target" ]
    && builtins.elem "radicle-node.service" statusSyncPath.after
    && statusSyncPathConfig.Unit == statusSyncUnit
    && statusSyncPathConfig.PathChanged == expectedStatusSyncPaths
    && statusSyncConfig.Type == "oneshot"
    && statusSyncConfig.User == "radicle"
    && statusSyncConfig.Group == "radicle"
    &&
      statusSyncConfig.Environment == [
        "HOME=${radicleStateDirectory}"
        "RAD_HOME=${radicleStateDirectory}"
      ]
    && statusSyncConfig.RuntimeMaxSec == "3m"
    && statusSyncConfig.RestrictAddressFamilies == [ "AF_UNIX" ]
    && !(builtins.elem "AF_INET" statusSyncConfig.RestrictAddressFamilies)
    && !(builtins.elem "AF_INET6" statusSyncConfig.RestrictAddressFamilies)
    && builtins.elem "radicle-node.service" statusSyncService.after
    &&
      builtins.match ".*rad sync --timeout 45s rad:z3xXXCQXCTquvAawh41YYs8yC8xmk" statusSyncConfig.ExecStart
      != null
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
    && builtins.length brokerPackage.patches == 1
    &&
      builtins.match ".*announce-namespace.*" (toString (builtins.elemAt brokerPackage.patches 0)) != null
    && quarantineTmpfile.user == "root"
    && quarantineTmpfile.group == "root"
    && reportTmpfile.user == "radicle"
    && reportTmpfile.group == reportGroup
    && reportNamespaceTmpfile.user == "radicle"
    && reportNamespaceTmpfile.group == reportGroup
    && shadowService.wantedBy == [ ]
    && shadowConfig.User == "radicle"
    && authorityProbeService.wantedBy == [ ]
    && authorityProbeConfig.User == latticeUser
    && authorityProbeConfig.BindReadOnlyPaths == [ "${sourcePath}:${sourceView}" ]
    && authorityProbeConfig.BindPaths == [ "${reportPath}:${reportView}" ]
    && authorityProbeConfig.ReadWritePaths == [ reportView ]
    && lib.hasInfix "--poll-interval-ms ${toString expectedObservationPollMilliseconds}" hostStartCommand;
  revisionsValid =
    kilnInput.rev == expectedKilnRevision
    && legacyInput.rev == expectedLegacyRevision
    && latticeInput.rev == expectedLatticeRuntimeRevision
    && lib.hasInfix expectedLatticeContractRevision (
      builtins.readFile ../modules/kiln-aspen-radicle-ci/profiles/radicle-profile.ncl
    );
  routeUsesAspen = brokerCommand == aspenAdapterCommand && brokerEnvironment == { };
  settingsEvaluator = import ../modules/kiln-aspen-radicle-ci/settings.nix { inherit lib; };
  baseSettings = {
    enable = true;
    inherit runtimeName;
    routeMode = "aspen";
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
    providerTimeoutMilliseconds = expectedProviderTimeoutMilliseconds;
    providerStdoutMaxBytes = expectedProviderOutputBytes;
    providerStderrMaxBytes = expectedProviderOutputBytes;
    providerReportMaxBytes = expectedProviderReportBytes;
    providerWrapperMaxBytes = 262144;
    providerPollMilliseconds = 100;
    providerTeardownTimeoutMilliseconds = expectedProviderTeardownMilliseconds;
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
      command_timeout_seconds = ${toString expectedWorkflowTimeoutSeconds},
    }
  '';
  positiveWorkflow = pkgs.writeText "kiln-aspen-ci-positive-workflow.ncl" ''
    let make_workflow = import ${builtins.toJSON ../modules/kiln-aspen-radicle-ci/profiles/lattice-workflow.ncl} in
    make_workflow {
      provider_executable = "/nix/store/provider/bin/kiln-radicle-nix-provider",
      provider_profile = "/nix/store/provider-profile.json",
      repository = "rad:z3xXXCQXCTquvAawh41YYs8yC8xmk",
      command_timeout_seconds = ${toString expectedWorkflowTimeoutSeconds},
    }
  '';
in
{
  checks = {
    # r[verify onix.radicle_ci.aspen_composition.accepted]
    # r[verify onix.radicle_ci.aspen_authority.accepted]
    # r[verify onix.radicle_ci.aspen_authority.source_readiness]
    # r[verify onix.radicle_ci.aspen_authority.refresh_quiescence]
    # r[verify onix.radicle_ci.aspen_authority.refresh_quiescence.scenario.current]
    # r[verify onix.radicle_ci.aspen_authority.refresh_quiescence.scenario.missing-entry]
    # r[verify onix.radicle_ci.aspen_authority.refresh_quiescence.scenario.self-trigger]
    kiln-aspen-radicle-ci-module =
      assert lib.assertMsg machinePolicyValid
        "Kiln Aspen production users, sockets, service order, state roots, or authority bounds drifted";
      assert lib.assertMsg revisionsValid
        "Kiln Aspen production dependency revisions differ from the reviewed cohort";
      assert lib.assertMsg routeUsesAspen
        "Kiln Aspen production cutover did not select the explicit Aspen route";
      assert lib.assertMsg settingsChecksValid
        "Kiln Aspen production positive or negative settings fixtures did not classify correctly";
      assert lib.assertMsg sourceReadinessBoundsValid
        "Kiln Aspen production source-readiness attempts do not cover the named timeout";
      pkgs.runCommand "kiln-aspen-radicle-ci-module-check"
        {
          nativeBuildInputs = [
            pkgs.b3sum
            pkgs.jq
          ];
        }
        ''
          test -x ${lib.escapeShellArg expectedLegacyCommand}
          test -x ${lib.escapeShellArg "${hostPackage}/bin/kiln-aspen-host"}
          test -x ${lib.escapeShellArg "${kilnPackage}/bin/kiln-aspen-extension"}
          test -x ${lib.escapeShellArg "${kilnPackage}/bin/kiln-adapter-radicle"}
          test -x ${lib.escapeShellArg "${providerPackage}/bin/kiln-radicle-nix-provider"}
          test -x ${lib.escapeShellArg "${latticePackage}/bin/lattice"}
          test -f ${lib.escapeShellArg aspenProfile}
          test -f ${lib.escapeShellArg providerProfile}
          test -f ${lib.escapeShellArg workflowProfile}
          test -f ${lib.escapeShellArg handlerProfile}
          grep -F -- ${lib.escapeShellArg providerWorkflowExecutable} ${lib.escapeShellArg workflowProfile} >/dev/null
          grep -F -- ${lib.escapeShellArg providerWorkflowProfile} ${lib.escapeShellArg workflowProfile} >/dev/null

          jq -e \
            --argjson callback_timeout ${toString expectedWorkflowTimeoutMilliseconds} \
            '.bounds.callback_timeout_millis == $callback_timeout' \
            ${lib.escapeShellArg aspenProfile} >/dev/null

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
          grep -F -- ${lib.escapeShellArg "${pkgs.coreutils}/bin"} "$wrapper" >/dev/null
          grep -F -- ${lib.escapeShellArg "${pkgs.gitMinimal}/bin"} "$wrapper" >/dev/null
          grep -F -- ${lib.escapeShellArg "git --git-dir=${sourceView}"} "$wrapper" >/dev/null
          grep -F -- ${lib.escapeShellArg "expected_revision_length=${toString expectedSourceRevisionHexLength}"} "$wrapper" >/dev/null
          grep -F -- ${lib.escapeShellArg "attempt_limit=${toString expectedSourceReadyAttempts}"} "$wrapper" >/dev/null
          grep -F -- ${lib.escapeShellArg "delay_seconds=${expectedSourceReadyDelaySeconds}"} "$wrapper" >/dev/null
          invalid_source_diagnostic="$TMPDIR/invalid-source.err"
          if "$wrapper" flake check --no-update-lock-file \
            ${lib.escapeShellArg "git+file:///invalid-source?rev=${invalidSourceRevision}"} \
            >"$TMPDIR/invalid-source.out" 2>"$invalid_source_diagnostic"; then
            echo "provider wrapper accepted an unexpected source view" >&2
            exit 1
          fi
          grep -F -- 'provider wrapper refused an unexpected source view' \
            "$invalid_source_diagnostic" >/dev/null

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
          grep -F -- 'getfacl -cp' ${lib.escapeShellArg sourceAdmissionCommand} >/dev/null
          grep -F -- 'if ! directory_acl_is_current' ${lib.escapeShellArg sourceAdmissionCommand} >/dev/null
          grep -F -- 'if ! file_acl_is_current' ${lib.escapeShellArg sourceAdmissionCommand} >/dev/null
          if grep -F -- '-exec setfacl' ${lib.escapeShellArg sourceAdmissionCommand} >/dev/null; then
            echo "source admission still rewrites every ACL unconditionally" >&2
            exit 1
          fi
          if grep -E -- 'curl|wget|ssh ' ${lib.escapeShellArg sourceAdmissionCommand} >/dev/null; then
            echo "source admission gained network tooling" >&2
            exit 1
          fi
          grep -F -- ${lib.escapeShellArg sourceView} ${lib.escapeShellArg authorityProbeCommand} >/dev/null
          grep -F -- ${lib.escapeShellArg reportView} ${lib.escapeShellArg authorityProbeCommand} >/dev/null
          grep -F -- '5f659dce24e13b30e996f0aab3419dac4c21f934' ${lib.escapeShellArg authorityProbeCommand} >/dev/null
          grep -F -- '/var/lib/radicle-ci' ${lib.escapeShellArg authorityProbeCommand} >/dev/null
          grep -F -- 'source view is writable' ${lib.escapeShellArg authorityProbeCommand} >/dev/null
          grep -F -- 'forbidden authority is readable or traversable' ${lib.escapeShellArg authorityProbeCommand} >/dev/null

          grep -F -- ${lib.escapeShellArg aspenSocket} ${lib.escapeShellArg hostPreStart} >/dev/null
          grep -F -- ${lib.escapeShellArg latticeSocket} ${lib.escapeShellArg (builtins.elemAt latticePreStart 0)} >/dev/null
          grep -F -- ' import ' ${lib.escapeShellArg latticePrepareCommand} >/dev/null
          if grep -F -- 'exit 0' ${lib.escapeShellArg latticePrepareCommand} >/dev/null; then
            echo "Lattice preparation trusts its marker without re-importing the exact workflow" >&2
            exit 1
          fi
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
