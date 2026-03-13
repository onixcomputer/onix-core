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
        # wait until network is available and not metered
        while ! ${pkgs.networkmanager}/bin/nm-online --quiet || ${pkgs.networkmanager}/bin/nmcli --terse --fields GENERAL.METERED dev show 2>/dev/null | grep --quiet "yes"; do
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
