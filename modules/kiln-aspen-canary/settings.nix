{ lib }:
settings:
let
  minimumSystemUid = 100;
  maximumSystemUid = 999;
  maximumRuntimeNameCharacters = 20;
  runtimeNamePattern = "^[a-z][a-z0-9-]{0,${toString maximumRuntimeNameCharacters}}$";
  isAbsoluteSafePath =
    path:
    lib.hasPrefix "/" path && !(lib.hasInfix "/../" path) && !(lib.hasSuffix "/.." path) && path != "/";
  uidIsSystem = uid: uid >= minimumSystemUid && uid <= maximumSystemUid;
  runtimeDirectory = "/run/${settings.runtimeName}";
  hostUser = "${settings.runtimeName}-host";
  latticeUser = "${settings.runtimeName}-lattice";
  socketGroup = settings.runtimeName;
in
{
  inherit
    hostUser
    latticeUser
    runtimeDirectory
    socketGroup
    ;
  latticeSocket = "${runtimeDirectory}/lattice.sock";
  aspenSocket = "${runtimeDirectory}/aspen.sock";
  replayDatabase = "${settings.hostStateDir}/radicle-replay.sqlite";
  assertions = [
    {
      assertion = builtins.match runtimeNamePattern settings.runtimeName != null;
      message = "Kiln Aspen canary runtimeName must be a bounded system-name label";
    }
    {
      assertion = isAbsoluteSafePath settings.hostStateDir;
      message = "Kiln Aspen canary hostStateDir must be a safe absolute non-root path";
    }
    {
      assertion = isAbsoluteSafePath settings.latticeStateDir;
      message = "Kiln Aspen canary latticeStateDir must be a safe absolute non-root path";
    }
    {
      assertion = settings.hostStateDir != settings.latticeStateDir;
      message = "Kiln Aspen canary host and Lattice state roots must remain separate";
    }
    {
      assertion = uidIsSystem settings.hostUid && uidIsSystem settings.latticeUid;
      message = "Kiln Aspen canary service UIDs must stay in the reviewed system range";
    }
    {
      assertion = settings.hostUid != settings.latticeUid;
      message = "Kiln Aspen canary host and Lattice users must have distinct UIDs";
    }
    {
      assertion = settings.maximumRequests > 0;
      message = "Kiln Aspen canary maximumRequests must be positive";
    }
    {
      assertion = settings.timeoutMilliseconds > 0;
      message = "Kiln Aspen canary timeoutMilliseconds must be positive";
    }
  ];
}
