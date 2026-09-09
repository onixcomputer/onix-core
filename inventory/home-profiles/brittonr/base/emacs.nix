{
  pkgs,
  ...
}:
let
  # Emacs Bedrock 2.0: a minimal, well-commented Emacs init. It hard-requires
  # Emacs 31+ (init.el errors out otherwise), which nixpkgs emacs-pgtk
  # satisfies. Optional extras (dev, org, vim-like, …) stay opt-in through the
  # commented load-file lines in init.el.
  bedrock = pkgs.fetchFromGitea {
    domain = "codeberg.org";
    owner = "ashton314";
    repo = "emacs-bedrock";
    rev = "f14cc2d59003b2089529271c9c17f51e79e35801";
    hash = "sha256-TT18OLmQg6alSfi5Gm+EmmIMpzvIAgzBCBXJa34Bh2Y=";
  };
in
{
  programs.emacs = {
    enable = true;
    # Pure GTK build: native Wayland under niri, still fine with -nw on
    # headless hosts.
    package = pkgs.emacs-pgtk;
  };

  # Deploy Bedrock's files into ~/.emacs.d. Everything here is a read-only
  # store symlink — treat this module as the source of truth and edit
  # options here rather than the live files. Emacs writes its own state
  # (elpa/, eln-cache/, backups) alongside them, which home-manager ignores.
  home.file = {
    ".emacs.d/init.el".source = "${bedrock}/init.el";
    ".emacs.d/early-init.el".source = "${bedrock}/early-init.el";
    ".emacs.d/extras".source = "${bedrock}/extras";
  };
}
