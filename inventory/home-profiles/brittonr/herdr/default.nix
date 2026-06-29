# Desktop-local Herdr profile.
#
# Keep typed data in ./lib/ so root-level .nix files stay real HM modules.
{ inputs, pkgs, ... }:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  profileData = wasm.evalNickelFile ./lib/config.ncl;

  mkPluginCommand = binding: {
    inherit (binding) key command description;
    type = binding.actionType;
  };

  pluginCommands = map mkPluginCommand profileData.plugins.jjWorkspace.commands;
  herdrConfig = profileData.config // {
    keys = profileData.config.keys // {
      command = pluginCommands;
    };
  };

  tomlFormat = pkgs.formats.toml { };
  herdrConfigFile = tomlFormat.generate "herdr-config.toml" herdrConfig;
in
{
  xdg.configFile."herdr/config.toml".source = herdrConfigFile;
}
