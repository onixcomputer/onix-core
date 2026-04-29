{ pkgs, inputs, ... }:
let
  cutterPythonEnabledFlags = [
    "-DCUTTER_ENABLE_PYTHON=ON"
    "-DCUTTER_ENABLE_PYTHON_BINDINGS=ON"
  ];
  cutterPythonDisabledFlags = [
    "-DCUTTER_ENABLE_PYTHON=OFF"
    "-DCUTTER_ENABLE_PYTHON_BINDINGS=OFF"
  ];
  cutterWithoutPythonBindings = pkgs.cutter.overrideAttrs (old: {
    # Cutter 2.4.1's generated Shiboken bindings reference stale enum names
    # with current PySide. Keep the GUI available and skip the broken bindings.
    cmakeFlags =
      builtins.filter (flag: !(builtins.elem flag cutterPythonEnabledFlags)) (old.cmakeFlags or [ ])
      ++ cutterPythonDisabledFlags;
  });
in
{
  imports = [
    inputs.nix-index-database.nixosModules.nix-index
    ./common/shared-dev.nix
  ];

  # Pre-built nix-index database — no local indexing needed.
  # comma (`, htop`) runs any nixpkgs binary without installing it.
  programs.nix-index-database.comma.enable = true;

  programs.direnv.enable = true;

  # NixOS-specific dev tools (shared tools from shared-dev.nix)
  environment.systemPackages = with pkgs; [
    # Coding agents
    codex
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
    net-tools
    nmap
    pamtester
    # Reverse engineering & binary analysis
    radare2
    python3Packages.r2pipe
    cutterWithoutPythonBindings
    ghidra
    iaito
    imhex
    binwalk
    hexyl
    capstone
    elfutils
    patchelf
    gdb
    strace
    ltrace
    yara
    volatility3
    usbmuxd
    usbutils
    socat
    lsof
    # TUI tools
    television # Fast general-purpose fuzzy finder
    bandwhich # Per-process network bandwidth monitor
    trippy # Visual traceroute / network diagnostics
    scooter # Interactive find-and-replace across files
    # GStreamer plugins for screen recording and video encoding
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad # Contains nvcodec for NVIDIA hardware encoding
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-vaapi # VAAPI support for hardware encoding
  ];
}
