{
  inputs,
  pkgs,
  ...
}:
let
  tridactyl = pkgs.fetchFirefoxAddon {
    name = "tridactyl";
    url = "https://addons.mozilla.org/firefox/downloads/file/4549492/tridactyl_vim-1.24.4.xpi";
    hash = "sha256:9ba7d6bc3be555631c981c3acdd25cab6942c1f4a6f0cb511bbe8fa81d79dd9d";
    fixedExtid = "tridactyl.vim@cmcaine.co.uk";
  };

  wrappedFirefox =
    (inputs.wrappers.wrapperModules.firefox.apply {
      inherit pkgs;

      extensions = [ tridactyl ];

      nativeMessagingHosts = [ pkgs.tridactyl-native ];

      settings = {
        # Hardware acceleration - WebRender
        "gfx.webrender.all" = true;
        "layers.acceleration.force-enabled" = true;

        # VA-API hardware video decoding (Firefox 137+)
        "media.hardware-video-decoding.force-enabled" = true;
        "media.rdd-ffmpeg.enabled" = true;

        # Wayland-native settings
        "widget.dmabuf.force-enabled" = false;
        "gfx.x11-egl.force-enabled" = false;
      };
    }).wrapper;
in
{
  home.packages = [ wrappedFirefox ];

  # Prevent mimeapps.list backup conflict during home-manager activation
  xdg.configFile."mimeapps.list".force = true;

  xdg.configFile."tridactyl/tridactylrc".text = ''
    " Reset to defaults
    sanitise tridactyllocal tridactylsync

    " --- Visual mode (Helix-like select-then-act) ---
    " v enters visual, hjkl/w/b/e extend selection, y yanks, o swaps cursor end
    " These are built-in defaults that match Helix already.
    " Extend with Helix-style binds:
    bind --mode=visual x js document.getSelection().modify("extend","forward","line")
    bind --mode=visual d composite js document.getSelection().toString() | clipboard yank | js document.getSelection().empty()

    " --- Helix-inspired goto (g prefix) ---
    bind ge scrollto 100           " ge = bottom (Helix: ge = end of file)
    bind gg scrollto 0             " gg = top (same in both)
    bind gt tabnext                " gt = next tab
    bind gT tabprev                " gT = prev tab

    " --- Space leader (matching user's Helix config) ---
    bind <Space>f fillcmdline tabopen    " open URL (like file_picker)
    bind <Space>/ fillcmdline find       " search page
    bind <Space>b fillcmdline buffer     " switch tab (buffer picker)
    bind <Space>d tabclose               " close tab

    " --- Tab navigation ---
    bind J tabprev
    bind K tabnext

    " --- General settings ---
    set smoothscroll true
    set hintchars neiohtsrad
  '';
}
