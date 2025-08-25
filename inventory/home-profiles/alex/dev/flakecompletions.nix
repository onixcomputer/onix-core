let
  # Change this to your local clan-core directory path
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
}
