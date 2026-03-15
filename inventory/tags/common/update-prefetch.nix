# Hourly prefetch of the next system closure from CI cache.
#
# Curls the store path from buildbot's output index, then downloads
# the closure. Primary path: harmonia HTTP cache on aspen1. Fallback:
# nix copy over iroh-ssh (works through NAT when harmonia is
# unreachable). Also runs on boot so machines that were offline
# catch up immediately.
#
# After fetching, auto-switches to the new closure if it differs
# from the running system (pull-deploy for offline machines).
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
      # Run shortly after boot so offline machines catch up without
      # racing the switch-to-configuration that just activated us.
      OnBootSec = "2min";
    };
  };

  systemd.services.update-prefetch = {
    description = "Pre-fetch next system closure from CI cache";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    path = [
      config.nix.package
      pkgs.curl
      pkgs.iproute2
    ];

    script = ''
      set -eu -o pipefail

      # Skip if no default route (offline)
      if ! ip r g 8.8.8.8 > /dev/null 2>&1; then
        echo "No network — skipping"
        exit 0
      fi

      # Fetch the target store path from buildbot
      store_path="$(curl -sfL "${buildbotOutputsBase}/${owner}/${repo}/${branch}/${system}.nixos-${hostname}" 2>/dev/null)" || {
        echo "Could not reach buildbot — skipping"
        exit 0
      }

      if [ -z "$store_path" ]; then
        echo "Empty store path — CI hasn't built this machine yet"
        exit 0
      fi

      # Already have this closure?
      if [ -e "$store_path" ]; then
        echo "Already have $store_path"
      else
        echo "Fetching $store_path ..."

        # Primary: harmonia HTTP cache
        if nix-store --add-root /run/next-system -r "$store_path" 2>/dev/null; then
          echo "Fetched via harmonia"
        # Fallback: nix copy over iroh-ssh (works through NAT)
        elif nix copy --from ssh://iroh-aspen1 "$store_path" 2>/dev/null; then
          nix-store --add-root /run/next-system -r "$store_path"
          echo "Fetched via iroh-ssh fallback"
        else
          echo "All fetch methods failed for $store_path"
          exit 1
        fi
      fi

      # Pull-deploy: switch if the fetched closure is newer than running system
      current="$(readlink -f /run/current-system 2>/dev/null || echo "")"
      target="$(readlink -f "$store_path" 2>/dev/null || echo "")"

      if [ -n "$current" ] && [ -n "$target" ] && [ "$current" != "$target" ]; then
        echo "New system available: $target (current: $current)"

        # Bail if another switch-to-configuration is already running
        if systemctl is-active --quiet nixos-rebuild-switch-to-configuration.service 2>/dev/null; then
          echo "Another switch is in progress — skipping (will retry next cycle)"
          exit 0
        fi

        echo "Switching..."
        nix-env --profile /nix/var/nix/profiles/system --set "$target"
        "$target/bin/switch-to-configuration" switch
        echo "Switched to $target"
      else
        echo "System is up to date"
      fi
    '';

    serviceConfig = {
      Type = "oneshot";
      CPUSchedulingPolicy = lib.mkForce "idle";
      IOSchedulingClass = "idle";
    };
  };
}
