{ inputs, pkgs, ... }:
let
  grubWallpaper = pkgs.fetchurl {
    name = "nixos-grub-wallpaper.jpg";
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/nix-grub-1920x1200.png";
    sha256 = "sha256-pJ4NAewz7V4wmggPD02fVYKVqr0di/Bky8ZWWqFgBiQ=";
  };
in
{
  imports = [
    inputs.grub2-themes.nixosModules.default
    ../alex-fw/pmods/macrand.nix
  ];

  networking = {
    hostName = "zenith";
    networkmanager.enable = true;
  };

  time.timeZone = "America/New_York";

  environment.systemPackages = with pkgs; [
    imagemagick # required for grub2-theme
    claude-code
    comma
    os-prober
    nix-output-monitor
    gh
  ];

  boot.loader = {
    timeout = 1;
    efi.canTouchEfiVariables = true;
    grub = {
      timeoutStyle = "menu";
      enable = true;
      device = "nodev";
      efiSupport = true;
      useOSProber = true;
    };
    grub2-theme = {
      enable = true;
      theme = "stylish";
      footer = true;
      customResolution = "1920x1200";
      splashImage = grubWallpaper;
    };
  };

  services = {
    gnome.gnome-keyring.enable = true;
    fwupd.enable = true; # framework bios/firmware updates

    # Keyd for dual-function keys (Caps Lock = Esc on tap, Ctrl on hold)
    keyd = {
      enable = true;
      keyboards = {
        default = {
          ids = [ "*" ];
          settings = {
            main = {
              capslock = "overload(control, esc)";
            };
          };
        };
      };
    };

    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
          user = "greeter";
        };
      };
    };
  };

  home-manager = {
    backupFileExtension = "backup";
    sharedModules = [
      {
        wayland.windowManager.hyprland.settings.monitor = [
          "eDP-1, preferred, auto, 1.5"
        ];
      }
    ];
  };

  security.pam.services = {
    login.enableGnomeKeyring = true;
    greetd.enableGnomeKeyring = true;
    hyprlock = { };
  };

  system.stateVersion = "25.05";
}
