{ pkgs, lib, ... }:
{
  nixpkgs.config.allowUnfree = true;

  # Disable clan-core's facter AMD graphics auto-detection — it has a typo
  # ("modesettings" instead of "modesetting") and we manage GPU drivers
  # through our own tag system (amd-gpu, nvidia) anyway.
  facter.detected.graphics.amd.enable = lib.mkForce false;
  clan.core.settings.state-version.enable = true;

  # Modern firewall - nftables replaces iptables
  # Provides build-time ruleset validation via checkRuleset
  networking.nftables.enable = true;

  services = {
    # Enable Avahi for service discovery
    avahi.enable = true;

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
    services = {
      # Redirect Nix builds to /var/tmp (not RAM) to avoid OOM on large builds
      nix-daemon.environment.TMPDIR = "/var/tmp";

      # Prevent nixos-rebuild from tearing down networking mid-deploy.
      # Without this, remote SSH deploys can brick the connection when
      # systemd-networkd or systemd-resolved restarts.
      systemd-networkd.stopIfChanged = false;
      systemd-resolved.stopIfChanged = false;

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

  environment.systemPackages = with pkgs; [
    uutils-coreutils-noprefix
    kitty.terminfo
    btop
    tree
    pstree
    # TUI tools
    systemctl-tui # TUI for managing systemd services
    dua # Fast disk space analyzer
  ];

  networking = {
    networkmanager.enable = true;
    useNetworkd = false;
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
