{
  inputs,
  pkgs,
  ...
}:
let
  grubWallpaper = pkgs.fetchurl {
    name = "nixos-grub-wallpaper.jpg";
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/nix-grub-3840x2160.png";
    sha256 = "sha256-d+sXYC74KL90wh06bLYTgebF6Ai7ac6Qsd+6qj57yyE=";
  };
in
{
  imports = [
    inputs.grub2-themes.nixosModules.default
  ];

  networking = {
    hostName = "britton-desktop";
    networkmanager.enable = true;
    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];
  };

  time.timeZone = "America/New_York";

  environment.systemPackages = with pkgs; [
    imagemagick # required for grub2-theme
    claude-code
    nix-output-monitor
    gh
  ];

  boot.loader = {
    timeout = 1;
    grub = {
      timeoutStyle = "menu";
    };
    grub2-theme = {
      enable = true;
      theme = "stylish";
      footer = true;
      customResolution = "3840x2160";
      splashImage = grubWallpaper;
    };
  };

  services = {

    gnome.gnome-keyring.enable = true;

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
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
          user = "greeter";
        };
      };
    };

  };

  home-manager.backupFileExtension = "backup";

  security = {
    rtkit.enable = true;
    pam.services = {
      login.enableGnomeKeyring = true;
      greetd.enableGnomeKeyring = true;
      sudo.fprintAuth = false;
    };
  };

  system.stateVersion = "25.05";
}
