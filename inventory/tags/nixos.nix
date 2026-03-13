{ pkgs, inputs, ... }:
{
  imports = [
    inputs.srvos.nixosModules.common
    inputs.srvos.nixosModules.mixins-nix-experimental
    inputs.srvos.nixosModules.mixins-trusted-nix-caches
    ./common/fhs-compat.nix
    ./common/zswap.nix
  ];

  nixpkgs.config.allowUnfree = true;

  clan.core.settings.state-version.enable = true;

  # Modern firewall - nftables replaces iptables
  # Provides build-time ruleset validation via checkRuleset
  networking.nftables.enable = true;

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
    services = {
      # Redirect Nix builds to /var/tmp (not RAM) to avoid OOM on large builds
      nix-daemon.environment.TMPDIR = "/var/tmp";

      # systemd-networkd.stopIfChanged and systemd-resolved.stopIfChanged
      # are now set by srvos common module.

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

  # User configuration — UID, shell, SSH keys, primary group.
  # Password generation and extra groups are handled by the upstream
  # clan-core users module (inventory/core/users.nix).
  users = {
    users.brittonr = {
      uid = 1555;
      group = "brittonr";
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYzh3yIsSTOYXkJMFHBKzkakoDfonm3/RED5rqMqhIO britton@framework"
      ];
    };
    groups.brittonr = { };
    users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYzh3yIsSTOYXkJMFHBKzkakoDfonm3/RED5rqMqhIO britton@framework"
    ];
  };

  programs.fish.enable = true;

  security.sudo.wheelNeedsPassword = false;
}
