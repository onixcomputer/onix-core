{ lib, ... }:

{
  # yubikey-agent takes over SSH auth — disable the generic ssh-agent
  services.ssh-agent.enable = lib.mkForce false;

  services.yubikey-agent = {
    enable = true;
  };

  # Point SSH at the yubikey-agent socket
  programs.ssh = {
    extraConfig = ''
      IdentityAgent ''${XDG_RUNTIME_DIR}/yubikey-agent/yubikey-agent.sock
    '';
  };
}
