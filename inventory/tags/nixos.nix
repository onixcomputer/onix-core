{
  pkgs,
  inputs,
  self,
  ...
}:
{
  imports = [
    inputs.srvos.nixosModules.common
    inputs.srvos.nixosModules.mixins-nix-experimental
    inputs.srvos.nixosModules.mixins-trusted-nix-caches
    inputs.nix-index-database.nixosModules.nix-index
    ./common/fhs-compat.nix
    ./common/zswap.nix
    ./common/nix-signing.nix
    ./common/berkeley-mono-font.nix
    ./common/shared-nix.nix
    ./common/shared-users.nix
    ./common/update-prefetch.nix
    ./common/wasm-lib.nix
  ];

  nixpkgs.config.allowUnfree = true;

  # Stamp every built system with its git revision.
  # Makes `nixos-version --json` show exactly what's deployed.
  system.configurationRevision = self.rev or self.dirtyRev or null;

  clan.core.settings.state-version.enable = true;
  clan.core.sops.defaultGroups = [ "admins" ];

  # nix-index-database: pre-built index for nix-locate (no local indexing).
  # comma: run uninstalled packages with `, htop`.
  # Replaces the broken default command-not-found handler.
  programs.nix-index-database.comma.enable = true;
  programs.command-not-found.enable = false;

  services = {
    # Enable Avahi for mDNS service discovery and .local hostname resolution
    avahi = {
      enable = true;
      nssmdns4 = true;
    };

    # Enable SSH agent forwarding on the server side
    openssh.settings.AllowAgentForwarding = true;

    # IRQ balancing for better multi-core performance
    # Prevents UI freezes during heavy load (compilation, etc.)
    irqbalance.enable = true;
  };

  # RAM-based /tmp (faster, reduces SSD wear, auto-cleanup on reboot)
  boot.tmp.useTmpfs = true;

  boot.kernel.sysctl = {
    # BBR congestion control — better throughput on lossy/high-latency links
    # (Tailscale tunnels, remote deploys). fq qdisc required for BBR pacing.
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";

    # TCP Fast Open — saves a round-trip on repeated connections (client+server)
    "net.ipv4.tcp_fastopen" = 3;

    # inotify limits — default 8192 is too low for IDEs, nix builds, file watchers
    "fs.inotify.max_user_watches" = 1048576;
    "fs.inotify.max_user_instances" = 1024;
  };

  systemd = {
    # Faster shutdown — default 90s timeout is painful when a service hangs.
    # Hung services get SIGKILL after 5s instead of blocking reboot for
    # a minute and a half.
    settings.Manager.DefaultTimeoutStopSec = "5s";

    services = {
      # Redirect Nix builds to /var/tmp (not RAM) to avoid OOM on large builds
      nix-daemon.environment.TMPDIR = "/var/tmp";

      # Nix GC root cleanup — stale gcroots prevent nix-collect-garbage from
      # reclaiming store paths even after the referencing profile is gone.
      nix-cleanup-gcroots.serviceConfig = {
        Type = "oneshot";
        ExecStart = [
          # Delete automatic gcroots older than 30 days
          "${pkgs.findutils}/bin/find /nix/var/nix/gcroots/auto /nix/var/nix/gcroots/per-user -type l -mtime +30 -delete"
          # Clean stale temproots left by nix-collect-garbage
          "${pkgs.findutils}/bin/find /nix/var/nix/temproots -type f -mtime +10 -delete"
          # Remove broken symlinks from gcroots
          "${pkgs.findutils}/bin/find /nix/var/nix/gcroots -xtype l -delete"
        ];
      };
    };

    timers.nix-cleanup-gcroots = {
      timerConfig = {
        OnCalendar = [ "weekly" ];
        Persistent = true;
      };
      wantedBy = [ "timers.target" ];
    };
  };

  # NixOS-specific packages (shared packages live in shared-dev.nix via dev tag)
  environment.systemPackages = with pkgs; [
    kitty.terminfo
    wezterm.terminfo
  ];

  # Don't restart network services during rebuild — prevents SSH disconnects
  # when deploying remotely. Applies whether using networkd or resolved.
  systemd.services.systemd-networkd.stopIfChanged = false;
  systemd.services.systemd-resolved.stopIfChanged = false;

  networking = {
    networkmanager.enable = true;
    useNetworkd = false;

    # nftables replaces iptables — build-time ruleset validation via checkRuleset
    nftables.enable = true;

    # Explicit NTP servers — systemd-timesyncd can't discover them via DHCP
    # when NetworkManager manages interfaces instead of systemd-networkd.
    # Without this, timesyncd never syncs (Server: n/a, Packet count: 0).
    timeServers = [
      "0.nixos.pool.ntp.org"
      "1.nixos.pool.ntp.org"
      "2.nixos.pool.ntp.org"
      "3.nixos.pool.ntp.org"
    ];
  };

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };
}
