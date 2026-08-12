{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";

  manifest = {
    name = "llamacpp-server";
    readme = "Direct llama.cpp OpenAI-compatible inference server";
    description = "Runs llama-server directly with a selected Nix-built llama.cpp backend";
    categories = [
      "AI/ML"
      "Inference"
    ];
  };

  roles.server = {
    description = "Direct llama.cpp server that exposes an OpenAI-compatible API";
    interface = mkSettings.mkInterface schema.server;

    perInstance =
      { instanceName, extendSettings, ... }:
      {
        nixosModule =
          {
            inputs,
            pkgs,
            lib,
            ...
          }:
          let
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            settings = extendSettings (ms.mkDefaults schema.server);
          in
          import ./mk-nixos-config.nix {
            inherit
              inputs
              instanceName
              lib
              pkgs
              settings
              ;
          };
      };
  };
}
