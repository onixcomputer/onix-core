{
  programs.fish.shellInit = ''
    # Source clan-core completions if available
    if test -e ~/dev/clan-core/pkgs/clan-cli/completions/clan.fish
      source ~/dev/clan-core/pkgs/clan-cli/completions/clan.fish
    end
  '';

  programs.zsh.initExtra = ''
    # Source clan-core completions if available
    if [ -e ~/dev/clan-core/pkgs/clan-cli/completions/clan.zsh ]; then
      source ~/dev/clan-core/pkgs/clan-cli/completions/clan.zsh
    fi
  '';
}
