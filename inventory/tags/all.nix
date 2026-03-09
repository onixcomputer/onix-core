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

  # Redirect Nix builds to /var/tmp (not RAM) to avoid OOM on large builds
  systemd.services.nix-daemon.environment.TMPDIR = "/var/tmp";

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
