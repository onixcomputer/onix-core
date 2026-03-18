_: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;

    # Custom direnv stdlib with zellij helper
    stdlib = ''
      # Set zellij session name based on project
      # Usage in .envrc: use_zellij_session [custom-name]
      use_zellij_session() {
        local session_name="''${1:-$(basename "$PWD" | tr '.' '_' | tr '[:upper:]' '[:lower:]')}"
        export ZELLIJ_SESSION_NAME="$session_name"
        log_status "Zellij session: $session_name"
      }
    '';
  };
}
