{ pkgs, ... }:
{
  # Put completions directly in fish's completions directory where they'll be auto-loaded
  home.file.".config/fish/completions/clan.fish" = {
    text = ''
      # Dynamically generate clan completions if clan is available
      if command -q clan
        ${pkgs.python3Packages.argcomplete}/bin/register-python-argcomplete --shell fish clan | source
      end
    '';
  };
}
