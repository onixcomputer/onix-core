{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";

  manifest = {
    name = "llm-agents";
    description = "LLM coding agents from numtide/llm-agents.nix";
    readme = "Installs terminal-based AI coding agents (pi, claude-code, opencode, etc.)";
    categories = [
      "AI/ML"
      "Development"
    ];
  };

  roles.default = {
    description = "Machine with LLM coding agent tools installed";
    interface = mkSettings.mkInterface schema.default;

    perInstance =
      { extendSettings, ... }:
      {
        nixosModule =
          {
            pkgs,
            inputs,
            lib,
            ...
          }:
          let
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            cfg = extendSettings (ms.mkDefaults schema.default);
            agentPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
          in
          {
            environment.systemPackages = map (name: agentPkgs.${name}) cfg.packages;
          };
      };
  };
}
