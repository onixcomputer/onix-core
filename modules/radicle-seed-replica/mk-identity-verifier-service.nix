# r[impl onix.radicle_replica.configuration]
# r[impl onix.radicle_replica.authority]
{ lib }:
{
  identityVerifier,
  expectedFingerprint,
  publicKeyPath,
  privateKeyPath,
}:
let
  privateCredentialName = "dev.radicle.node.secret";
  privateUmask = "0077";
  identityVerifierCommand = lib.escapeShellArgs [
    "${identityVerifier}/bin/radicle-replica-identity-verify"
    expectedFingerprint
    publicKeyPath
  ];
in
{
  description = "Verify the pinned Radicle replica identity before node start";
  before = [ "radicle-node.service" ];
  serviceConfig = {
    AmbientCapabilities = [ ];
    CapabilityBoundingSet = "";
    ExecStart = identityVerifierCommand;
    Group = "radicle";
    InaccessiblePaths = [ "/run/secrets" ];
    LoadCredential = [ "${privateCredentialName}:${privateKeyPath}" ];
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
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
    ProtectProc = "invisible";
    ProtectSystem = "strict";
    RemoveIPC = true;
    RestrictAddressFamilies = [ "AF_UNIX" ];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
    SystemCallErrorNumber = "EPERM";
    SystemCallFilter = [ "@system-service" ];
    Type = "oneshot";
    UMask = privateUmask;
    User = "radicle";
  };
}
