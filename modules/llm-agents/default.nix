_: {
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
    interface =
      { lib, ... }:
      {
        freeformType = lib.types.attrsOf lib.types.anything;

        options = {
          packages = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "pi" ];
            description = "Package names to install from llm-agents flake";
          };
        };
      };

    perInstance =
      { settings, ... }:
      {
        nixosModule =
          {
            pkgs,
            inputs,
            ...
          }:
          let
            agentPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
          in
          {
            environment.systemPackages = map (name: agentPkgs.${name}) settings.packages;
          };
      };
  };
}
