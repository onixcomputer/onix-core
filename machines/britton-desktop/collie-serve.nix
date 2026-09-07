# Collie tailnet front door (root-owned).
#
# Collie (the Herdr phone web bridge) is published on the tailnet HTTPS root of
# this host's MagicDNS name. `tailscale serve` needs elevation to serve a path,
# and this host already manages its serve mounts as root (/wiki/), so publication
# lives here as a declarative root unit. The package controller rejects
# publication changes and cannot remove the host-owned mapping.
#
# `tailscale serve --bg` is idempotent and persistent: once the mapping exists it
# survives reboots, and re-running it only updates/recreates the same root mount.
{
  pkgs,
  ...
}:
let
  bridgePort = 8787;
  httpsPort = 443;
  restartDelay = "10s";
  startLimitSeconds = 1200;
  startLimitAttempts = 30;
in
{
  systemd.services.collie-serve = {
    description = "Collie tailnet front door";
    after = [
      "tailscaled.service"
      "network-online.target"
    ];
    wants = [
      "tailscaled.service"
      "network-online.target"
    ];
    wantedBy = [ "multi-user.target" ];
    startLimitIntervalSec = startLimitSeconds;
    startLimitBurst = startLimitAttempts;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --https=${toString httpsPort} --set-path=/ ${toString bridgePort}";
      Restart = "on-failure";
      RestartSec = restartDelay;
    };
  };
}
