{ pkgs, ... }:
{
  programs.direnv.enable = true;
  environment.systemPackages = with pkgs; [
    claude-code-bin
    codex
    comma
    gh
    # Screen recording tool - requires GStreamer plugins for encoding
    # Wrap kooha with required GStreamer plugins for NVIDIA hardware encoding
    (pkgs.symlinkJoin {
      name = "kooha-wrapped";
      paths = [ kooha ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/kooha \
          --prefix GST_PLUGIN_PATH : "${
            pkgs.lib.makeSearchPath "lib/gstreamer-1.0" [
              gst_all_1.gstreamer
              gst_all_1.gst-plugins-base
              gst_all_1.gst-plugins-good
              gst_all_1.gst-plugins-bad
              gst_all_1.gst-plugins-ugly
              gst_all_1.gst-vaapi
            ]
          }"
      '';
    })
    nixpkgs-review
    goose-cli
    net-tools
    nix-output-monitor
    nmap
    pamtester
    usbmuxd
    usbutils
    radicle-node
    socat
    lsof
    jujutsu
    socat
    lsof
    jujutsu
    socat
    lsof
    jujutsu
    # GStreamer plugins for screen recording and video encoding
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad # Contains nvcodec for NVIDIA hardware encoding
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-vaapi # VAAPI support for hardware encoding
  ];
}
