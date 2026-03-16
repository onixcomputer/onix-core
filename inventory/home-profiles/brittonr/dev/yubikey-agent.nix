_:

{
  services.yubikey-agent = {
    enable = true;

    # Use the default yubikey-agent package
    # package = pkgs.yubikey-agent;
  };

  # Additional SSH configuration to use yubikey-agent
  # The HM service places the socket in $XDG_RUNTIME_DIR/yubikey-agent/
  programs.ssh = {
    extraConfig = ''
      # Use YubiKey for SSH authentication (socket in XDG_RUNTIME_DIR)
      # OpenSSH 10.x dropped %t — use environment variable expansion instead
      IdentityAgent ''${XDG_RUNTIME_DIR}/yubikey-agent/yubikey-agent.sock
    '';
  };
}
