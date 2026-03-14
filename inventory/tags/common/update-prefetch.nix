# Hourly prefetch of the next system closure from CI cache.
#
# Curls the store path from buildbot's output index, then downloads
# the closure from harmonia. No local eval or build — if CI hasn't
# built this machine or the network is down, the timer just retries
# next hour.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  buildbotOutputsBase = "https://buildbot.blr.dev/nix-outputs";
  owner = "onixcomputer";
  repo = "onix-core";
  branch = "main";

  hostname = config.networking.hostName;
  inherit (pkgs.stdenv.hostPlatform) system;
in
{
  systemd.timers.update-prefetch = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
      RandomizedDelaySec = "15min";
    };
  };

  systemd.services.update-prefetch = {
    description = "Pre-fetch next system closure from CI cache";

    path = [
      config.nix.package
      pkgs.curl
      pkgs.iproute2
    ];

    script = ''
      set -eux -o pipefail

      # Skip if no default route (offline)
      if ! ip r g 8.8.8.8 > /dev/null 2>&1; then
        echo "No network — skipping"
        exit 0
      fi

      store_path="$(curl -sfL "${buildbotOutputsBase}/${owner}/${repo}/${branch}/${system}.nixos-${hostname}")"
      nix-store --add-root /run/next-system -r "$store_path"
    '';

    serviceConfig = {
      Type = "oneshot";
      CPUSchedulingPolicy = lib.mkForce "idle";
      IOSchedulingClass = "idle";
    };
  };
}
