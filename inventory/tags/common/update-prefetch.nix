# Background system prefetch — builds the next system closure hourly.
#
# After `git pull` on the flake repo, the next `clan machines update` is
# fast because the closure is already in the store. Runs at idle priority
# so it doesn't interfere with interactive work or builds.
#
# Without a CI/build server this evaluates + builds locally. With CI,
# adapt the script to curl a store path URL instead of building.
#
# Adapted from Mic92/dotfiles nixosModules/update-prefetch.nix.
{
  config,
  pkgs,
  ...
}:
let
  flakeDir = "/home/brittonr/git/onix-core";
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
    description = "Pre-build next system closure in the background";

    script = ''
      set -eux -o pipefail

      # Skip if no default route (offline)
      if ! ${pkgs.iproute2}/bin/ip r g 8.8.8.8 > /dev/null 2>&1; then
        echo "No network — skipping prefetch"
        exit 0
      fi

      # Skip if flake dir doesn't exist
      if [ ! -d "${flakeDir}" ]; then
        echo "Flake directory ${flakeDir} not found — skipping"
        exit 0
      fi

      cd "${flakeDir}"

      # Pull latest if it's a git repo
      if [ -d .git ]; then
        ${pkgs.gitMinimal}/bin/git pull --ff-only || true
      fi

      # Build the current machine's system closure and pin as GC root
      hostname=$(${pkgs.hostname}/bin/hostname)
      store_path=$(${config.nix.package}/bin/nix build \
        ".#nixosConfigurations.$hostname.config.system.build.toplevel" \
        --no-link --print-out-paths 2>/dev/null) || {
        echo "Build failed for $hostname — skipping"
        exit 0
      }

      ${config.nix.package}/bin/nix-store --add-root /run/next-system -r "$store_path"
      echo "Prefetched: $store_path"
    '';

    serviceConfig = {
      Type = "oneshot";
      # Run at lowest priority — never steal resources from real work
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
      Nice = 19;
      # Don't clog the journal on frequent runs
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };
}
