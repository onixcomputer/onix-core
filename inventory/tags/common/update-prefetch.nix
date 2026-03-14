# Background system prefetch — downloads the next system closure hourly.
#
# Fetches the store path from buildbot's outputsPath index, then downloads
# the closure from the harmonia binary cache on aspen2. No local eval or
# build needed — the entire closure is pre-built by CI.
#
# Fallback: if the buildbot index is unreachable (offline, CI hasn't run
# yet, branch not built), falls back to a local build from the flake repo.
#
# Adapted from Mic92/dotfiles nixosModules/update-prefetch.nix.
{
  config,
  pkgs,
  ...
}:
let
  # Buildbot writes store paths to this URL after successful builds.
  # Format: <base>/<owner>/<repo>/<branch>/<system>.<attr>
  buildbotOutputsBase = "https://buildbot.blr.dev/nix-outputs";

  # GitHub owner/repo for this flake
  owner = "brittonr";
  repo = "onix-core";
  branch = "main";

  hostname = config.networking.hostName;
  inherit (pkgs.stdenv.hostPlatform) system;

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
    description = "Pre-fetch next system closure from CI cache";

    script = ''
      set -eux -o pipefail

      # Skip if no default route (offline)
      if ! ${pkgs.iproute2}/bin/ip r g 8.8.8.8 > /dev/null 2>&1; then
        echo "No network — skipping prefetch"
        exit 0
      fi

      # Try fetching store path from buildbot's output index.
      # The file contains just the store path string, e.g. /nix/store/abc...-nixos-system-...
      outputs_url="${buildbotOutputsBase}/${owner}/${repo}/${branch}/${system}.nixos-${hostname}"
      store_path=$(${pkgs.curl}/bin/curl -sfL "$outputs_url" 2>/dev/null) || store_path=""

      if [ -n "$store_path" ] && [[ "$store_path" == /nix/store/* ]]; then
        echo "Got store path from buildbot: $store_path"
        # Download from harmonia cache (or any configured substituter)
        ${config.nix.package}/bin/nix-store --add-root /run/next-system -r "$store_path" && {
          echo "Prefetched from cache: $store_path"
          exit 0
        }
        echo "Cache download failed — falling back to local build"
      else
        echo "Buildbot index unavailable or no build for ${hostname} — falling back to local build"
      fi

      # Fallback: build locally from the flake repo
      if [ ! -d "${flakeDir}" ]; then
        echo "Flake directory ${flakeDir} not found — skipping"
        exit 0
      fi

      cd "${flakeDir}"

      # Pull latest if it's a git repo
      if [ -d .git ]; then
        ${pkgs.gitMinimal}/bin/git pull --ff-only || true
      fi

      store_path=$(${config.nix.package}/bin/nix build \
        ".#nixosConfigurations.${hostname}.config.system.build.toplevel" \
        --no-link --print-out-paths 2>/dev/null) || {
        echo "Local build failed for ${hostname} — skipping"
        exit 0
      }

      ${config.nix.package}/bin/nix-store --add-root /run/next-system -r "$store_path"
      echo "Prefetched (local build): $store_path"
    '';

    serviceConfig = {
      Type = "oneshot";
      # Run at lowest priority — never steal resources from real work
      CPUSchedulingPolicy = "idle";
      IOSchedulingClass = "idle";
      Nice = 19;
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };
}
