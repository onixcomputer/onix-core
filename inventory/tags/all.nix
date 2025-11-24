{ pkgs, ... }:
{
  services.avahi.enable = true;
  nixpkgs.config.allowUnfree = true;
  clan.core.settings.state-version.enable = true;

  # Enable SSH agent forwarding on the server side
  services.openssh.settings.AllowAgentForwarding = true;

  environment.systemPackages = with pkgs; [
    kitty.terminfo
    btop
    tree
    pstree
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
