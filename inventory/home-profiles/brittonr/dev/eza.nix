{
  programs.eza = {
    enable = true;

    # Enable colors in output
    colors = "auto";

    # Show git status
    git = true;

    # Display icons
    icons = "auto";

    # Enable shell integrations
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;

    # Extra options
    extraOptions = [
      "--group-directories-first"
      "--header"
    ];

    # Theme is managed by Noctalia at runtime via a user template that
    # writes the correctly-structured YAML (filekinds/perms/size/git
    # sections) to ~/.config/eza/theme.yml.  Don't set programs.eza.theme
    # here — it would create a read-only HM symlink that blocks Noctalia.
  };

  programs.fish.shellAliases = {
    ls = "eza --icons";
    l = "eza -l --icons";
    la = "eza -la --icons";
    ll = "eza -la --icons --git";
    lt = "eza --tree --icons";
  };
}
