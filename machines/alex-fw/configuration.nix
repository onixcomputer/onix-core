{ inputs, pkgs, ... }:
let
  grubWallpaper = pkgs.fetchurl {
    name = "nixos-grub-wallpaper.jpg";
    url = "https://github.com/adeci/wallpapers/blob/main/nix-grub-2880x1920.jpg";
    sha256 = "005mcwzqwsq61c8v2gv05j68j370fkn4s7dj3kca8bz4qwbwpk4j";
  };
  streetWallpaper = pkgs.fetchurl {
    name = "street-wallpaper.png";
    url = "https://github.com/adeci/wallpapers/blob/main/street-full.jpg";
    sha256 = "1zv32lgnk3ivb0nf666bnmqhs9kzfzzb5gixa6bsn75khl9mwxbw";
  };
in
{
  imports = [
    inputs.grub2-themes.nixosModules.default
    inputs.sddm-sugar-candy-nix.nixosModules.default
  ];

  networking = {
    hostName = "alex-fw";
    networkmanager.enable = true;
  };

  time.timeZone = "America/New_York";

  environment.systemPackages = with pkgs; [
    imagemagick # required for grub2-theme
    claude-code
  ];

  home-manager.backupFileExtension = "backup";

  boot.loader = {
    timeout = 1;
    grub = {
      timeoutStyle = "menu";
    };
    grub2-theme = {
      enable = true;
      theme = "stylish";
      footer = true;
      customResolution = "2880x1920";
      splashImage = grubWallpaper;
    };
  };

  services = {
    #custom tokyo night theme
    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      sugarCandyNix = {
        enable = true;
        settings = {
          Background = streetWallpaper;
          ScreenWidth = 2880;
          ScreenHeight = 1920;
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

    fwupd.enable = true; # framework bios/firmware updates
  };

  system.stateVersion = "25.05";
}
