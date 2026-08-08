# Focused personal Radicle supervision checks.
# r[verify onix.radicle_replica.personal_supervision]
# r[verify onix.radicle_replica.personal_persistence]
# r[verify onix.radicle_replica.personal_listener]
# r[verify onix.radicle_replica.personal_signer]
# r[verify onix.radicle_replica.personal_validation]
{
  self,
  pkgs,
  lib,
  system,
  ...
}:
let
  serviceName = "radicle-personal-node";
  userName = "brittonr";
  expectedHome = "/home/${userName}/.radicle";
  expectedSocket = "${expectedHome}/node/control.sock";
  expectedListenAddress = "127.0.0.1:0";
  expectedRestartDelay = "10s";
  expectedSignerEnvironment = "SSH_AUTH_SOCK=%t/yubikey-agent/yubikey-agent.sock";
  managedNodePort = 8776;
  managedNodeBindRule = "tcp:${toString managedNodePort}";

  desktopConfig = self.nixosConfigurations.britton-desktop.config;
  desktopHome = desktopConfig.home-manager.users.${userName};
  laptopHome = self.nixosConfigurations.aspen3.config.home-manager.users.${userName};
  serverHome = self.nixosConfigurations.aspen1.config.home-manager.users.${userName};
  desktopServicePresent = builtins.hasAttr serviceName desktopHome.systemd.user.services;
  desktopService =
    desktopHome.systemd.user.services.${serviceName} or {
      Unit = { };
      Service = { };
      Install = { };
    };
  personalPackage = lib.findFirst (
    package: package.onixRadicleDesktop or false
  ) null desktopHome.home.packages;
  desktopUserUid = desktopConfig.users.users.${userName}.uid;
  desktopUserSliceName = "user-${toString desktopUserUid}";
  desktopUserSlice = desktopConfig.systemd.slices.${desktopUserSliceName} or { sliceConfig = { }; };
  socketBindDeny = lib.toList (desktopUserSlice.sliceConfig.SocketBindDeny or [ ]);
  serviceEnvironment = lib.toList (desktopService.Service.Environment or [ ]);
  serviceAfter = desktopService.Unit.After or [ ];
  serviceWants = desktopService.Unit.Wants or [ ];
  serviceWantedBy = desktopService.Install.WantedBy or [ ];
  serviceCommands = lib.toList (desktopService.Service.ExecStart or [ ]);
  expectedServiceCommand =
    if personalPackage == null then
      "/missing-personal-radicle-package/bin/radicle-node --force"
    else
      "${personalPackage}/bin/radicle-node --force";

  assertions = [
    {
      name = "positive: britton-desktop declares the personal Radicle service";
      condition = desktopServicePresent;
    }
    {
      name = "positive: personal package preserves the personal home and socket";
      condition =
        personalPackage != null
        && personalPackage.desktopHome == expectedHome
        && personalPackage.desktopSocket == expectedSocket;
    }
    {
      name = "positive: personal package forces an ephemeral loopback listener";
      condition = personalPackage != null && personalPackage.nodeListenAddress == expectedListenAddress;
    }
    {
      name = "positive: service starts the reviewed wrapper with force recovery";
      condition = personalPackage != null && serviceCommands == [ expectedServiceCommand ];
    }
    {
      name = "positive: service waits for the YubiKey agent";
      condition =
        builtins.elem "yubikey-agent.service" serviceAfter
        && builtins.elem "yubikey-agent.service" serviceWants;
    }
    {
      name = "positive: service restarts after clean external termination";
      condition =
        (desktopService.Service.Restart or null) == "always"
        && (desktopService.Service.RestartSec or null) == expectedRestartDelay
        && (desktopService.Unit.StartLimitIntervalSec or null) == 0;
    }
    {
      name = "positive: service starts with the user default target";
      condition = builtins.elem "default.target" serviceWantedBy;
    }
    {
      name = "positive: service selects the runtime-relative YubiKey agent socket";
      condition = builtins.elem expectedSignerEnvironment serviceEnvironment;
    }
    {
      name = "positive: britton-desktop enables user lingering";
      condition = desktopConfig.users.users.${userName}.linger or false;
    }
    {
      name = "positive: desktop user slice denies the managed replica port";
      condition = builtins.elem managedNodeBindRule socketBindDeny;
    }
    {
      name = "negative: personal service does not use machine replica state";
      condition =
        !lib.any (command: lib.hasInfix "/var/lib/radicle" command) serviceCommands
        && !lib.any (command: lib.hasInfix "/run/credentials" command) serviceCommands;
    }
    {
      name = "negative: service does not embed a numeric runtime user path";
      condition = !lib.any (entry: lib.hasInfix "/run/user/" entry) serviceEnvironment;
    }
    {
      name = "negative: laptop profile excludes personal node supervision";
      condition = !(builtins.hasAttr serviceName laptopHome.systemd.user.services);
    }
    {
      name = "negative: server profile excludes personal node supervision";
      condition = !(builtins.hasAttr serviceName serverHome.systemd.user.services);
    }
  ];
  failedAssertions = builtins.filter (assertion: !assertion.condition) assertions;
  failedNames = lib.concatMapStringsSep "; " (assertion: assertion.name) failedAssertions;
  report = builtins.toFile "personal-radicle-node-supervision-report.txt" ''
    Personal Radicle node supervision check

    Assertions:
    ${lib.concatMapStringsSep "\n" (
      assertion: "- ${assertion.name}: ${if assertion.condition then "PASS" else "FAIL"}"
    ) assertions}
  '';
in
{
  checks = lib.optionalAttrs (system == "x86_64-linux") {
    personal-radicle-node-supervision =
      if failedAssertions == [ ] then
        pkgs.runCommand "personal-radicle-node-supervision" { inherit report; } ''
          cp "$report" "$out"
        ''
      else
        throw "personal-radicle-node-supervision failed: ${failedNames}";
  };
}
