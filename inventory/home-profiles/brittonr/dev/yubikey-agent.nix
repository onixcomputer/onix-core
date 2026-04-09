{ lib, ... }:

{
  # yubikey-agent takes over SSH auth — disable the generic ssh-agent
  services.ssh-agent.enable = lib.mkForce false;

  services.yubikey-agent = {
    enable = true;
  };

  # Home Manager's yubikey-agent module currently emits bash-style
  # ${XDG_RUNTIME_DIR:-...} expansion for fish, which fish rejects.
  sshAuthSock.initialization.fish = lib.mkForce ''
    if set -q XDG_RUNTIME_DIR; and test -n "$XDG_RUNTIME_DIR"
      set -x SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/yubikey-agent/yubikey-agent.sock"
    else
      set -x SSH_AUTH_SOCK "/run/user/(id -u)/yubikey-agent/yubikey-agent.sock"
    end
  '';

  # Point SSH at the yubikey-agent socket
  programs.ssh = {
    extraConfig = ''
      IdentityAgent ''${XDG_RUNTIME_DIR}/yubikey-agent/yubikey-agent.sock
    '';
  };
}
