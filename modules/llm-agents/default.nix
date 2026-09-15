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
            config,
            pkgs,
            inputs,
            lib,
            ...
          }:
          let
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            cfg = extendSettings (ms.mkDefaults schema.default);
            agentPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};

            # llm-agents writes the `omp` coding agent into the bun 1.3.14
            # runtime template it pins, using the `bun` and the bun2nix build
            # hook of the consumer's nixpkgs. nixpkgs bun 1.4.x writes that
            # template with an empty embedded prelude, so the compiled agent
            # fails its own smoke test. Compile that one agent with the
            # multiverse-pinned 1.3.x bun, and rebuild the bun2nix helper
            # against the same bun so the hook uses it too.
            # r[impl onix.llm_agents.bun_compiler]
            pinnedBunPkgs = pkgs.extend (_final: _previous: { bun = config.multiverse.locked.bun; });
            pinnedBun2nixLib =
              (inputs.llm-agents.inputs.bun2nix.overlays.default pinnedBunPkgs pinnedBunPkgs).bun2nix;
            agentSources = {
              omp = agentPkgs.omp.override {
                bun = config.multiverse.locked.bun;
                bun2nixLib = pinnedBun2nixLib;
              };
            };
            agentSource = name: agentSources.${name} or agentPkgs.${name};
          in
          {
            environment.systemPackages = map agentSource cfg.packages;
          };
      };
  };
}
