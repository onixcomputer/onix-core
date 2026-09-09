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

  # Helix-flavored modal editing. Meow provides the Kakoune/Helix model
  # (selections first, verbs after); this keymap carries over the Helix keys
  # that translate cleanly to Emacs. Deliberately not emulated: Helix's
  # selection-first motion mode (every motion extends), multiple cursors,
  # and view/space command palette — meow's keypad (SPC) covers discovery.
  helixLikeEl = ''
    ;;; helix-like.el --- Helix-style modal editing via meow -*- lexical-binding: t; -*-
    ;;
    ;; Fleet default on top of Bedrock. Modest and explicit on purpose: the
    ;; keys below are the Helix set that maps 1:1 onto meow commands, so the
    ;; muscle memory transfers. Everything else keeps its Emacs behavior.

    (require 'meow)

    ;; Motion state: buffers where modal editing makes no sense still get
    ;; plain j/k/l movement.
    (meow-motion-define-key
     '("j" . meow-next)
     '("k" . meow-prev)
     '("<escape>" . ignore))

    (meow-leader-define-key
     '("?" . meow-cheatsheet)
     '("SPC" . meow-keypad))

    (meow-normal-define-key
     '("h" . meow-left)
     '("l" . meow-right)
     '("j" . meow-next)
     '("k" . meow-prev)
     '("0" . meow-beginning-of-line)
     '("$" . meow-end-of-line)
     '("w" . meow-next-word)
     '("W" . meow-next-symbol)
     '("b" . meow-back-word)
     '("B" . meow-back-symbol)
     '("e" . meow-mark-word)
     '("x" . meow-line)
     '("%" . meow-mark-whole-buffer)
     '("f" . meow-find)
     '("t" . meow-till)
     '("m" . meow-match-symbol)
     '("/" . meow-search)
     '(";" . meow-reverse)
     '("d" . meow-kill)
     '("c" . meow-change)
     '("s" . meow-change)
     '("r" . meow-replace)
     '("y" . meow-save)
     '("p" . meow-yank)
     '("u" . meow-undo)
     '("U" . meow-redo)
     '("<escape>" . meow-keypad-quit))

    (meow-global-mode 1)

    ;;; helix-like.el ends here
  '';
in
{
  programs.emacs = {
    enable = true;
    # Pure GTK build: native Wayland under niri, still fine with -nw on
    # headless hosts. Meow comes from the same nixpkgs tree as Emacs — not
    # ELPA at first launch — so helix-like.el works from the first keystroke.
    package = (pkgs.emacsPackagesFor pkgs.emacs-pgtk).withPackages (epkgs: [
      epkgs.meow
    ]);
  };

  # Deploy Bedrock's files into ~/.emacs.d. Everything here is a read-only
  # store symlink — treat this module as the source of truth and edit
  # options here rather than the live files. Emacs writes its own state
  # (elpa/, eln-cache/, backups) alongside them, which home-manager ignores.
  #
  # init.el is Bedrock's verbatim, with helix-like.el appended so the modal
  # keymap is active by default; remove the appended form to go back to
  # vanilla Bedrock.
  home.file = {
    ".emacs.d/init.el".text = builtins.readFile "${bedrock}/init.el" + ''

      ;;; Fleet default: Helix-style modal editing.
      (load (expand-file-name "helix-like.el" user-emacs-directory))
    '';
    ".emacs.d/helix-like.el".text = helixLikeEl;
    ".emacs.d/early-init.el".source = "${bedrock}/early-init.el";
    ".emacs.d/extras".source = "${bedrock}/extras";
  };
}
