{
  config,
  lib,
  pkgs,
  ...
}:
{
  clan.core.state = {
    networkmanager = lib.mkIf config.networking.networkmanager.enable {
      folders = [ "/etc/NetworkManager" ];
    };
    system.folders = [
      "/home"
      "/var"
      "/root"
    ];
  };

  services.borgbackup.jobs = {
    aspen1 = {
      preHook = lib.optionalString config.networking.networkmanager.enable ''
        # Wait for unmetered network (bounded: 30 attempts × 60s = 30 min max).
        # If network never becomes available/unmetered, skip this backup run —
        # the next timer invocation will retry.
        network_ready=false
        for _attempt in $(seq 1 30); do
          if ${pkgs.networkmanager}/bin/nm-online --quiet 2>/dev/null &&
             ! ${pkgs.networkmanager}/bin/nmcli --terse --fields GENERAL.METERED dev show 2>/dev/null | grep --quiet "yes"; then
            network_ready=true
            break
          fi
          echo "Waiting for unmetered network... ($_attempt/30)"
          sleep 60
        done

        if [ "$network_ready" = "false" ]; then
          echo "Timed out waiting for unmetered network after 30 minutes, skipping backup"
          exit 0
        fi
      '';
      exclude = [
        "*.pyc"
        "*.o"
        "*/node_modules/*"
        "/home/*/.direnv"
        "/home/*/.cache"
        "/home/*/.cargo"
        "/home/*/.npm"
        "/home/*/.m2"
        "/home/*/.gradle"
        "/home/*/.clangd"
        "/home/*/go/"
        "/home/*/.local/share/Steam"
        "/home/*/.config/chromium"
        "/home/*/.mozilla/firefox/*/storage"
        "/var/lib/docker/"
        "/var/lib/containerd"
        "/var/log/journal"
        "/var/lib/systemd"
        "/var/cache"
        "/var/tmp"
        "/var/log"
        "/var/lib/postgresql"
      ];
    };
  };
}
