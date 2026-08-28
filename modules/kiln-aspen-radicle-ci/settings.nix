{ lib }:
settings:
let
  minimumSystemUid = 100;
  maximumSystemUid = 999;
  canaryHostUid = 970;
  canaryLatticeUid = 971;
  maximumRuntimeNameCharacters = 16;
  runtimeNamePattern = "^[a-z][a-z0-9-]{0,${toString (maximumRuntimeNameCharacters - 1)}}$";
  repositoryPattern = "^rad:z[1-9A-HJ-NP-Za-km-z]+$";
  safeLabelPattern = "^[A-Za-z0-9_-]+$";
  isAbsoluteSafePath =
    path:
    lib.hasPrefix "/" path && !(lib.hasInfix "/../" path) && !(lib.hasSuffix "/.." path) && path != "/";
  uidIsSystem = uid: uid >= minimumSystemUid && uid <= maximumSystemUid;
  pathContains = parent: child: child == parent || lib.hasPrefix "${parent}/" child;
  pathsAreSeparate = first: second: !(pathContains first second) && !(pathContains second first);
  runtimeDirectory = "/run/${settings.runtimeName}";
  ingressDirectory = "${runtimeDirectory}/ingress";
  internalDirectory = "${runtimeDirectory}/internal";
  hostUser = "${settings.runtimeName}-host";
  latticeUser = "${settings.runtimeName}-lattice";
  ingressGroup = "${settings.runtimeName}-ingress";
  internalGroup = "${settings.runtimeName}-internal";
  sourceGroup = "${settings.runtimeName}-source";
  reportGroup = "${settings.runtimeName}-report";
  storageName = lib.removePrefix "rad:" settings.repository;
  expectedSourcePath = "/var/lib/radicle/storage/${storageName}";
  expectedSourceViewPrefix = "/var/lib/kiln-aspen-radicle-ci/source/";
  expectedReportPathPrefix = "/var/lib/radicle-ci/reports/";
  expectedReportViewPrefix = "/var/lib/kiln-aspen-radicle-ci/";
in
{
  inherit
    hostUser
    ingressDirectory
    ingressGroup
    internalDirectory
    internalGroup
    latticeUser
    reportGroup
    runtimeDirectory
    sourceGroup
    ;
  aspenSocket = "${ingressDirectory}/aspen.sock";
  latticeSocket = "${internalDirectory}/lattice.sock";
  replayDatabase = "${settings.hostStateDir}/radicle-replay.sqlite";
  providerWorkDirectory = "${settings.latticeStateDir}/provider-work";
  reportNamespacePath = "${settings.reportView}/${settings.reportNamespace}";
  assertions = [
    {
      assertion = builtins.match runtimeNamePattern settings.runtimeName != null;
      message = "Kiln Aspen production runtimeName must be a bounded system-name label";
    }
    {
      assertion = builtins.elem settings.routeMode [
        "shadow"
        "aspen"
        "legacy"
      ];
      message = "Kiln Aspen production routeMode must select shadow, aspen, or legacy";
    }
    {
      assertion = builtins.match repositoryPattern settings.repository != null;
      message = "Kiln Aspen production repository must be one canonical Radicle RID";
    }
    {
      assertion = builtins.match safeLabelPattern settings.reportNamespace != null;
      message = "Kiln Aspen production reportNamespace must be a bounded safe label";
    }
    {
      assertion = lib.hasPrefix "https://" settings.reportBaseUrl;
      message = "Kiln Aspen production reportBaseUrl must use HTTPS";
    }
    {
      assertion = builtins.all isAbsoluteSafePath [
        settings.hostStateDir
        settings.latticeStateDir
        settings.sourcePath
        settings.sourceView
        settings.reportPath
        settings.reportView
      ];
      message = "Kiln Aspen production paths must be safe absolute non-root paths";
    }
    {
      assertion = settings.sourcePath == expectedSourcePath;
      message = "Kiln Aspen production sourcePath must name only the admitted repository storage path";
    }
    {
      assertion = lib.hasPrefix expectedSourceViewPrefix settings.sourceView;
      message = "Kiln Aspen production sourceView must stay in its dedicated source boundary";
    }
    {
      assertion = lib.hasPrefix expectedReportPathPrefix settings.reportPath;
      message = "Kiln Aspen production reportPath must stay below the served report root";
    }
    {
      assertion = lib.hasPrefix expectedReportViewPrefix settings.reportView;
      message = "Kiln Aspen production reportView must stay in its dedicated private boundary";
    }
    {
      assertion = builtins.all (path: pathsAreSeparate settings.sourcePath path) [
        settings.hostStateDir
        settings.latticeStateDir
        settings.reportPath
        settings.reportView
      ];
      message = "Kiln Aspen production source authority must remain separate from writable state and reports";
    }
    {
      assertion = pathsAreSeparate settings.hostStateDir settings.latticeStateDir;
      message = "Kiln Aspen production host and Lattice state roots must remain separate";
    }
    {
      assertion = pathsAreSeparate settings.sourceView settings.reportView;
      message = "Kiln Aspen production source and report views must remain separate";
    }
    {
      assertion = uidIsSystem settings.hostUid && uidIsSystem settings.latticeUid;
      message = "Kiln Aspen production service UIDs must stay in the reviewed system range";
    }
    {
      assertion =
        settings.hostUid != settings.latticeUid
        && !(builtins.elem settings.hostUid [
          canaryHostUid
          canaryLatticeUid
        ])
        && !(builtins.elem settings.latticeUid [
          canaryHostUid
          canaryLatticeUid
        ]);
      message = "Kiln Aspen production users must be distinct from each other and the canary";
    }
    {
      assertion = builtins.all (value: value > 0) [
        settings.maximumRequests
        settings.requestTimeoutMilliseconds
        settings.providerTimeoutMilliseconds
        settings.providerStdoutMaxBytes
        settings.providerStderrMaxBytes
        settings.providerReportMaxBytes
        settings.providerWrapperMaxBytes
        settings.providerPollMilliseconds
        settings.providerTeardownTimeoutMilliseconds
        settings.providerStageCollisionAttempts
      ];
      message = "Kiln Aspen production bounds must all be positive";
    }
  ];
}
