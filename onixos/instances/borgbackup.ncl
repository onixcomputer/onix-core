# Clan instance borgbackup (inventory/services/services.ncl): every machine
# tagged backup backs up to aspen1, whose server role keeps the repositories
# under /var/lib/borg (server role not ported; aspen1 stays on Clan).
# state, wait_for_unmetered_network and exclude are what
# modules/borgbackup-extras adds to every client through the Clan instance's
# extraModules (inventory/services/borgbackup.nix). The extras apply the
# NetworkManager parts only when NetworkManager is enabled, which
# inventory/tags/nixos.nix does on every NixOS machine.
{
  borgbackup = {
    service = "borgbackup",
    roles.client = {
      tags = ["backup"],
      settings = {
        server = "aspen1",
        server_directory = "/var/lib/borg",
        state = {
          networkmanager.folders = ["/etc/NetworkManager"],
          system.folders = ["/home", "/var", "/root"],
        },
        wait_for_unmetered_network = true,
        exclude = [
          "*.pyc",
          "*.o",
          "*/node_modules/*",
          "/home/*/.direnv",
          "/home/*/.cache",
          "/home/*/.cargo",
          "/home/*/.npm",
          "/home/*/.m2",
          "/home/*/.gradle",
          "/home/*/.clangd",
          "/home/*/go/",
          "/home/*/.local/share/Steam",
          "/home/*/.config/chromium",
          "/home/*/.mozilla/firefox/*/storage",
          "/var/lib/docker/",
          "/var/lib/containerd",
          "/var/log/journal",
          "/var/lib/systemd",
          "/var/cache",
          "/var/tmp",
          "/var/log",
          "/var/lib/postgresql",
        ],
      },
    },
  },
}
