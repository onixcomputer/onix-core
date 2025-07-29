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
  streetWallpaper = pkgs.fetchurl {
    name = "street-wallpaper.png";
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/street-full.jpg";
    sha256 = "sha256-XlSm8RzGwowJMT/DQBNwfsU4V6QuvP4kvwVm1pzw6SM=";
  };
in
{
  imports = [
    inputs.grub2-themes.nixosModules.default
    inputs.sddm-sugar-candy-nix.nixosModules.default
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
  ];

  # grub menu only lasts 1 sec, press anything to stay on it
  # nixos generations are in the second menu slot collapsed
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

    printing.enable = true;

    # consider desktop tag and common audio file
    # see inventory/tags/common/gui-base.nix reference for common
    pulseaudio.enable = false;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    #custom tokyo night theme
    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      sugarCandyNix = {
        enable = true;
        settings = {
          Background = streetWallpaper;
          ScreenWidth = 3840;
          ScreenHeight = 2160;
          FormPosition = "left";
          HaveFormBackground = true;
          PartialBlur = true;

          MainColor = "white";
          AccentColor = "#668ac4";
          BackgroundColor = "#1a1b26";
          OverrideLoginButtonTextColor = "white";

          HeaderText = "";
          DateFormat = "dddd, MMMM d";
          HourFormat = "HH:mm";

          ForceLastUser = true;
          ForceHideCompletePassword = true;
          ForcePasswordFocus = true;
        };
      };
    };
  };

  home-manager.backupFileExtension = "backup";

  security.rtkit.enable = true;

  system.stateVersion = "25.05";
}
