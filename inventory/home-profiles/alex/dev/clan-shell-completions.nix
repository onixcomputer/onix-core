let
  localClanCorePath = "~/dev/clan-core";
in
{
  programs.fish.shellInit = ''
    # Source clan-core completions from local dev checkout if available (takes priority)
    if test -e ${localClanCorePath}/pkgs/clan-cli/completions/clan.fish
      source ${localClanCorePath}/pkgs/clan-cli/completions/clan.fish
    else
      # Fallback: ensure nix store completions are loaded
      # This forces loading even if fish's auto-loading isn't working properly
      for dir in $fish_complete_path
        if test -e $dir/clan.fish
          source $dir/clan.fish
          break
        end
      end
    end
  '';

  programs.zsh.initContent = ''
    # Source clan-core completions from local dev checkout if available (takes priority)
    if [ -e ${localClanCorePath}/pkgs/clan-cli/completions/clan.zsh ]; then
      source ${localClanCorePath}/pkgs/clan-cli/completions/clan.zsh
    else
      # Fallback: try to load from nix store
      for dir in /nix/store/*/share/zsh/vendor-completions /run/current-system/sw/share/zsh/vendor-completions; do
        if [ -e "$dir/_clan" ] || [ -e "$dir/clan.zsh" ]; then
          source "$dir/_clan" 2>/dev/null || source "$dir/clan.zsh" 2>/dev/null
          break
        fi
      done
    fi
  '';
}
