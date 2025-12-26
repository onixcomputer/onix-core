{
  config,
  pkgs,
  ...
}:
# let
# grubWallpaper = pkgs.fetchurl {
#   name = "nixos-grub-wallpaper.jpg";
#   url = "https://raw.githubusercontent.com/adeci/wallpapers/main/nix-grub-3840x2160.png";
#   sha256 = "sha256-d+sXYC74KL90wh06bLYTgebF6Ai7ac6Qsd+6qj57yyE=";
#   };
# in
{
  # imports = [
  #   inputs.grub2-themes.nixosModules.default
  # ];
  boot.kernelPackages = pkgs.linuxPackages_6_17;

  networking = {
    hostName = "britton-desktop";
    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];
  };

  time.timeZone = "America/New_York";
  time.hardwareClockInLocalTime = true; # Prevent time sync issues with Windows

  environment.systemPackages = with pkgs; [
    imagemagick # required for grub2-theme
    os-prober
    nirius # niri compositor utilities
    displaylink # DisplayLink for Wayland
  ];

  boot = {
    # DisplayLink support for Wayland (evdi module)
    extraModulePackages = [ config.boot.kernelPackages.evdi ];
    kernelModules = [ "evdi" ];

    loader = {
      timeout = 1;
      grub = {
        timeoutStyle = "menu";
        enable = true;
        device = "nodev";
        efiSupport = true;
        useOSProber = true;
        configurationLimit = 5; # Limit boot entries to reduce /boot usage
        extraConfig = ''
          GRUB_DISABLE_OS_PROBER=false
        '';
        extraEntries = ''
          menuentry "Reboot" {
            reboot
          }
        '';
        # extraEntries = ''
        #   menuentry "Windows (Manual)" {
        #     insmod part_gpt
        #     insmod ntfs
        #     insmod search_fs_uuid
        #     insmod chain
        #     search --fs-uuid --set=root 12EA42E8EA42C825
        #     chainloader +1
        #   }
        # '';
      };
    };
    # grub2-theme = {
    #   enable = true;
    #   theme = "stylish";
    #   footer = true;
    #   customResolution = "3840x2160";
    #   splashImage = grubWallpaper;
    # };
  };

  services = {

    gnome.gnome-keyring.enable = true;

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

    printing.enable = true;

    pulseaudio.enable = false;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd /etc/profiles/per-user/brittonr/bin/niri-session";
          user = "greeter";
        };
      };
    };

    # greetd = {
    #   enable = true;
    #   settings = {
    #     default_session = {
    #       command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
    #       user = "greeter";
    #     };
    #   };
    # };

  };

  # DisplayLink Manager service
  systemd.services.dlm = {
    description = "DisplayLink Manager Service";
    after = [ "display-manager.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.displaylink}/bin/DisplayLinkManager";
      Restart = "always";
      RestartSec = 5;
      LogsDirectory = "displaylink";
    };
  };

  security = {
    rtkit.enable = true;
    pam.services = {
      login.enableGnomeKeyring = true;
      greetd.enableGnomeKeyring = true;
      sudo.fprintAuth = false;
      hyprlock = { };
    };
  };
}
