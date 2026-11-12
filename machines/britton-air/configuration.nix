{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # Herdr's desktop app and the herdr-core it drives come from the pinned
  # llm-agents package set, as on aspen3. The wrapped `herdr` below stays the
  # fleet terminal multiplexer and plugin source.
  herdrAppPackage = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr-app;
in
{
  imports = [
    # Shared cross-platform modules
    ../../inventory/tags/common/shared-nix.nix
    ../../inventory/tags/common/shared-users.nix
    ../../inventory/tags/common/shared-dev.nix
    ../../inventory/tags/common/herdr-iroh.nix

    # nix-index + comma
    inputs.nix-index-database.darwinModules.nix-index

    # Package pinning through nixpkgs-multiverse (see AGENTS.md)
    inputs.multiverse.darwinModules.default
  ];

  # Per-package pins maintained by `mvs lock`; installs nothing until
  # `multiverse.enable = true` is set (see AGENTS.md "Package pinning").
  multiverse.lock = ../../multiverse.lock;

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  # The account predates the shared Darwin uid (555); nix-darwin cannot
  # change an existing uid, and Home Manager refuses to activate when its
  # home.uid differs from the account. Declare the actual uid for this host.
  users.users.brittonr.uid = lib.mkForce 501;

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

  # Closing the lid on a MacBook forces sleep regardless of the
  # power.sleep.computer = "never" setting (which only sets the idle
  # timer via systemsetup). `disablesleep 1` is the only pmset knob
  # that prevents lid-close sleep. Required so the Mac stays
  # reachable as a remote nix builder with the lid shut.
  system.activationScripts.postActivation.text = ''
    pmset -c disablesleep 1
    pmset -c tcpkeepalive 1
    pmset -b sleep 15
    pmset -b displaysleep 5
  '';

  # SSH — allow root login with key only (for clan deploys)
  services.openssh.extraConfig = ''
    PermitRootLogin prohibit-password
  '';

  # Enable touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # Distrust the roots behind the eight compromised eMudhra intermediates
  # (CVE-2026-111943). This is the nix-darwin#1876 + #1882 list; the locked
  # nix-darwin (f0ec2b3) predates both, so drop this once the lock carries them.
  # NSS 3.131.1 removes the emSign roots itself, and buildcatrust fails on
  # blacklisted names that are absent, hence the version guard.
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
  ]
  ++ lib.optionals (lib.versionOlder pkgs.cacert.version "3.131.1") [
    "emSign ECC Root CA - G3"
    "emSign Root CA - C1"
    "emSign ECC Root CA - C3"
  ];

  # nix-index + comma
  programs.nix-index-database.comma.enable = true;
  programs.direnv.enable = true;

  # The wrapped Herdr core (fleet plugin bundle + Nickel-rendered config from
  # the herdr Home Manager profile) and the desktop app. aspen3 installs the
  # core system-wide and the app in the user profile; britton-air matches it.
  environment.systemPackages = [ pkgs.herdr ];

  home-manager.users.brittonr = {
    home.packages = [ herdrAppPackage ];

    # Saved-machine targets shared with aspen3. The laptop reaches the two LAN
    # Macs by their mDNS names; instantfill-vm stays the tailnet name and is
    # reachable once Tailscale joins this host.
    programs.ssh = {
      enable = true;
      settings = {
        britton-desktop = {
          HostName = "britton-desktop.local";
          User = "brittonr";
          IdentityFile = "~/.ssh/framework";
          IdentitiesOnly = true;
        };
        cproof-brittonr = {
          HostName = "cproof-brittonr.local";
          User = "brittonr";
          IdentityFile = "~/.ssh/framework";
          IdentitiesOnly = true;
        };
        instantfill-vm = {
          HostName = "instantfill-vm.tailc6809.ts.net";
          User = "britton";
          IdentityFile = "~/.ssh/framework";
          IdentitiesOnly = true;
        };
      };
    };
  };

  # Linux builder VM for aarch64-linux builds on Apple Silicon
  # Uses Apple Virtualization.framework via nix-darwin
  nix.settings.trusted-users = [
    "root"
    "brittonr"
    "@admin"
    "@wheel"
  ];

  nix.linux-builder = {
    enable = true;
    ephemeral = true; # Wipe VM state on restart for clean build environment
    maxJobs = 4;
    # Default is [ "kvm" "benchmark" "big-parallel" ]; add nixos-test
    # so NixOS VM integration tests can run here.
    supportedFeatures = [
      "kvm"
      "benchmark"
      "big-parallel"
      "nixos-test"
    ];
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
