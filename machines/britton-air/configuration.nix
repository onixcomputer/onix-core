{
  pkgs,
  ...
}:
{
  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  system = {
    stateVersion = 6;
    primaryUser = "brittonr";

    # macOS system preferences
    defaults = {
      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        InitialKeyRepeat = 15;
        KeyRepeat = 2;
      };
      dock = {
        autohide = true;
        show-recents = false;
        tilesize = 48;
      };
      finder = {
        AppleShowAllExtensions = true;
        FXPreferredViewStyle = "Nlsv"; # List view
        ShowPathbar = true;
        ShowStatusBar = true;
      };
      trackpad = {
        Clicking = true; # Tap to click
        TrackpadThreeFingerDrag = true;
      };
    };

    # Keyboard remapping — Caps Lock to Escape
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };
  };

  # Prevent sleep when plugged in (keep available as remote builder)
  power.sleep.computer = "never";
  power.sleep.display = 15; # display off after 15 min, but machine stays awake

  # Nix settings
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "brittonr"
      ];
    };
    optimise.automatic = true;
    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 2;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };
  };

  # Enable touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # System packages
  environment.systemPackages = with pkgs; [
    claude-code
    comma
    gh
    nixpkgs-review
    nix-output-monitor
    jujutsu
    btop
    tree
  ];

  # Shell
  programs.fish.enable = true;

  # SSH authorized keys
  users.users.brittonr.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYzh3yIsSTOYXkJMFHBKzkakoDfonm3/RED5rqMqhIO britton@framework"
  ];

  # Linux builder VM for aarch64-linux builds on Apple Silicon
  # M4 Air: 10 cores (4P+6E), 24GB RAM — give the VM 16GB and 8 cores
  nix.linux-builder = {
    enable = true;
    maxJobs = 8;
    config = {
      virtualisation = {
        darwin-builder.memorySize = 16384;
        cores = 8;
      };
    };
  };

}
