{
  lib,
  pkgs,
  ...
}:
let
  # nixpkgs builds these against the exact nushell version in the same tree,
  # which is the only plugin-compatibility rule that matters (a mismatched
  # plugin protocol freezes the shell).
  nuPlugins = with pkgs.nushellPlugins; [
    query
    polars
    formats
  ];
in
{
  home.packages =
    with pkgs;
    [
      carapace
      zoxide
    ]
    ++ nuPlugins;

  programs = {
    nushell = {
      enable = true;
      extraConfig = ''
        # Rendered grids: keep terminal tables compact in ptyZZZ panes.
        $env.config.table.mode = "compact"
      '';
    };

    zoxide = {
      enable = true;
      enableNushellIntegration = true;
    };

    carapace = {
      enable = true;
      enableNushellIntegration = true;
    };
  };

  # `plugin add` writes each plugin into nu's plugin registry, from which
  # every later nu session (including ptyZZZ-spawned shells) loads them.
  # Activation runs on each home-manager switch, so re-adding is idempotent.
  home.activation.registerNushellPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    lib.concatMapStringsSep "\n" (plugin: ''
      ${pkgs.nushell}/bin/nu -c "plugin add '${lib.getExe plugin}'" || true
    '') nuPlugins
  );
}
