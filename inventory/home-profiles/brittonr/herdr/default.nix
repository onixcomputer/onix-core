# Desktop-local Herdr profile.
#
# Keep typed data in ./lib/ so root-level .nix files stay real HM modules.
{
  inputs,
  lib,
  osConfig ? { },
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  profileData = wasm.evalNickelFile ./lib/config.ncl;
  ghzinga = inputs.self.packages.${system}.ghzinga;
  vimHerdrNavigationSource = pkgs.fetchFromGitHub {
    owner = "paulbkim-dev";
    repo = "vim-herdr-navigation";
    rev = "548607d0e417fdb30966846fce7436aa05a6738d";
    hash = "sha256-4lFrDzbdZiCIHIdkJ9q2lMlo+RCsu9eBXjK58VEuhDE=";
  };

  # r[impl onix.britton-desktop.herdr.collie.service]
  # Home Manager owns the bridge. The host owns the Tailscale Serve mapping.
  # The package controller changes runtime state without rewriting either owner.
  # This profile also applies to Aspen3, but this deployment is desktop-only.
  collieEnabled = (osConfig.networking.hostName or null) == "britton-desktop";
  collie = inputs.self.packages.${system}.collie-herdr;
  inherit (pkgs) bun;
  collieEnv = ./collie.env;

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
  imports = [ ./lib/collie-aspen3.nix ];

  # r[impl onix.britton-desktop.herdr.workflow_plugins.ghzinga]
  # r[impl onix.britton-desktop.herdr.wrapper.ownership]
  # r[impl onix.britton-desktop.herdr.wrapper.ownership.activation]
  home.packages = [
    ghzinga
  ]
  ++ lib.optionals collieEnabled [
    collie
    bun
  ];

  xdg.configFile = {
    "herdr/config.toml".source = herdrConfigFile;
    # r[impl onix.britton-desktop.herdr.workflow_plugins.bindings]
    "nvim/after/plugin/herdr_nav.lua".source = "${vimHerdrNavigationSource}/editor/nvim.lua";
  }
  // lib.optionalAttrs collieEnabled {
    # r[impl onix.britton-desktop.herdr.collie.config]
    # Keep the legacy CLI location compatible with the canonical plugin config.
    "collie/.env".source = collieEnv;
    "herdr/plugins/config/herdr.collie/.env".source = collieEnv;
  };

  # r[impl onix.britton-desktop.herdr.collie.service]
  systemd.user.services = lib.optionalAttrs collieEnabled {
    collie = {
      Unit = {
        Description = "Collie";
        StartLimitIntervalSec = 60;
        StartLimitBurst = 5;
      };
      Service = {
        Type = "simple";
        WorkingDirectory = "${collie}";
        ExecStart = "${bun}/bin/bun run ${collie}/bridge/index.ts";
        Restart = "on-failure";
        RestartSec = "5s";
        NoNewPrivileges = true;
        PrivateTmp = true;
        Environment = [
          "HERDR_SOCKET_PATH=%h/.config/herdr/herdr.sock"
          "HERDR_PLUGIN_CONFIG_DIR=%h/.config/herdr/plugins/config/herdr.collie"
          "HERDR_PLUGIN_STATE_DIR=%h/.local/state/collie"
        ];
        EnvironmentFile = [ "%h/.config/herdr/plugins/config/herdr.collie/.env" ];
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
