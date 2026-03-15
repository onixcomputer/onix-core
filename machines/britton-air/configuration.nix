{
  inputs,
  ...
}:
{
  imports = [
    # Shared cross-platform modules
    ../../inventory/tags/common/shared-nix.nix
    ../../inventory/tags/common/shared-users.nix
    ../../inventory/tags/common/shared-dev.nix

    # nix-index + comma
    inputs.nix-index-database.darwinModules.nix-index
  ];

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

  # nix-darwin's power.sleep only affects AC (via systemsetup).
  # Explicitly set battery sleep via pmset so the Mac doesn't sleep
  # after 1 minute on battery (macOS default).
  system.activationScripts.postActivation.text = ''
    pmset -b sleep 15
    pmset -b displaysleep 5
  '';

  # SSH — allow root login with key only (for clan deploys)
  services.openssh.extraConfig = ''
    PermitRootLogin prohibit-password
  '';

  # Enable touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # nix-index + comma
  programs.nix-index-database.comma.enable = true;
  programs.direnv.enable = true;

  # Linux builder VM for aarch64-linux builds on Apple Silicon
  # Uses Apple Virtualization.framework via nix-darwin
  nix.linux-builder = {
    enable = true;
    ephemeral = true; # Wipe VM state on restart for clean build environment
    maxJobs = 4;
    config = {
      virtualisation = {
        darwin-builder = {
          diskSize = 40 * 1024; # 40 GB
          memorySize = 8 * 1024; # 8 GB
        };
        cores = 6;
      };
    };
  };
}
