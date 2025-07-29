{ pkgs, ... }:
{
  programs.light.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services = {
    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
    };
    blueman.enable = true;
    # power-profiles-daemon.enable = true;
    # upower.enable = true;

    libinput = {
      enable = true;
      touchpad = {
        tapping = true;
        naturalScrolling = true;
        disableWhileTyping = false;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    xdg-utils
    desktop-file-utils
    shared-mime-info
    powertop
    acpi
  ];
}
