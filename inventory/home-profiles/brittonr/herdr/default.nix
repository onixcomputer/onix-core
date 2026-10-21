# Desktop-local Herdr profile.
#
# Keep typed data in ./lib/ so root-level .nix files stay real HM modules.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  profileData = wasm.evalNickelFile ./lib/config.ncl;
  inherit (pkgs) ghzinga;
  vimHerdrNavigationSource = pkgs.fetchFromGitHub {
    owner = "paulbkim-dev";
    repo = "vim-herdr-navigation";
    rev = "548607d0e417fdb30966846fce7436aa05a6738d";
    hash = "sha256-4lFrDzbdZiCIHIdkJ9q2lMlo+RCsu9eBXjK58VEuhDE=";
  };

  mkPluginCommand = binding: {
    inherit (binding) key command description;
    type = binding.actionType;
  };

  # r[impl onix.britton-desktop.herdr.pueue.bindings]
  # r[impl onix.britton-desktop.herdr.workflow_plugins.bindings]
  pluginCommands = map mkPluginCommand (
    profileData.plugins.jjWorkspace.commands
    ++ profileData.plugins.pueueDashboard.commands
    ++ profileData.plugins.fileViewer.commands
    ++ profileData.plugins.reviewr.commands
    ++ profileData.plugins.vimNavigation.commands
  );
  herdrConfig = profileData.config // {
    keys = profileData.config.keys // {
      command = pluginCommands;
    };
  };

  tomlFormat = pkgs.formats.toml { };
  herdrConfigFile = tomlFormat.generate "herdr-config.toml" herdrConfig;
in
{
  # r[impl onix.britton-desktop.herdr.workflow_plugins.ghzinga]
  # r[impl onix.britton-desktop.herdr.wrapper.ownership]
  # r[impl onix.britton-desktop.herdr.wrapper.ownership.activation]
  home.packages = [
    ghzinga
  ];

  xdg.configFile = {
    "herdr/config.toml".source = herdrConfigFile;
    # r[impl onix.britton-desktop.herdr.workflow_plugins.bindings]
    "nvim/after/plugin/herdr_nav.lua".source = "${vimHerdrNavigationSource}/editor/nvim.lua";
  };

  # r[impl onix.britton-desktop.herdr.collie.service]
  # r[impl onix.britton-desktop.herdr.collie.config]
  # Collie 1.x (AltanS/collie, installed with `nix profile`) owns its user unit,
  # its .env and its crew state: every crew verb rewrites and restarts
  # ~/.config/systemd/user/collie.service, so this profile declares none of them.
  # sd-switch stops a unit that leaves the generation, and the retired 0.24.1
  # unit had the same name, so start Collie's own unit again after the reload.
  home.activation.startCollie = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
    collieUnit="$HOME/.config/systemd/user/collie.service"
    if [[ -f $collieUnit && ! -L $collieUnit ]]; then
      if ! run env XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
        ${config.systemd.user.systemctlPath} --user start collie.service; then
        warnEcho "collie.service did not start; run: collie restart"
      fi
    fi
  '';
}
