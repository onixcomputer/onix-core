_:

{
  services.yubikey-agent = {
    enable = true;

    # Use the default yubikey-agent package
    # package = pkgs.yubikey-agent;
  };

  # Additional SSH configuration to use yubikey-agent
  programs.ssh = {
    extraConfig = ''
      # Use YubiKey for SSH authentication
      IdentityAgent ~/.cache/yubikey-agent/yubikey-agent.sock
    '';
  };
}
