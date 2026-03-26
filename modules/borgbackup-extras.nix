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
        # Wait for unmetered network (bounded: 30 attempts = 30 minutes max).
        # If network never becomes available/unmetered, skip this backup run —
        # the next timer invocation will retry.
        attempts=0
        max_attempts=30
        while ! ${pkgs.networkmanager}/bin/nm-online --quiet || ${pkgs.networkmanager}/bin/nmcli --terse --fields GENERAL.METERED dev show 2>/dev/null | grep --quiet "yes"; do
          attempts=$((attempts + 1))
          if [ "$attempts" -ge "$max_attempts" ]; then
            echo "Timed out waiting for unmetered network after $max_attempts minutes, skipping backup"
            exit 0
          fi
          sleep 60
        done
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
