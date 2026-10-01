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
            researchEndpoints = pkgs.writeText "omp-research-endpoints.json" (
              builtins.toJSON {
                mesh = cfg.ompResearchUrl;
              }
            );
            researchExtension = pkgs.runCommand "omp-research-tools" { } ''
              mkdir -p "$out"
              cp ${./research-tools.ts} "$out/index.ts"
              cp ${./arxiv-multi-search.ts} "$out/arxiv-multi-search.ts"
              cp ${./arxiv-rerank.ts} "$out/arxiv-rerank.ts"
              cp ${./laya-predict.ts} "$out/laya-predict.ts"
              cp ${./laya-batch.ts} "$out/laya-batch.ts"
              cp ${./laya-advisory.ts} "$out/laya-advisory.ts"
              cp ${./laya-failure-triage.ts} "$out/laya-failure-triage.ts"
              cp ${./laya-diff-triage.ts} "$out/laya-diff-triage.ts"
              cp ${./laya-duplicate-check.ts} "$out/laya-duplicate-check.ts"
              cp ${./laya-evidence-match.ts} "$out/laya-evidence-match.ts"
              cp ${./laya-completion-check.ts} "$out/laya-completion-check.ts"
              cp ${./laya-context-rank.ts} "$out/laya-context-rank.ts"
              cp ${./laya-test-relevance.ts} "$out/laya-test-relevance.ts"
              cp ${./laya-issue-route.ts} "$out/laya-issue-route.ts"
              cp ${./laya-review-triage.ts} "$out/laya-review-triage.ts"
              cp ${./laya-requirement-conflict.ts} "$out/laya-requirement-conflict.ts"
              cp ${./laya-evaluate.ts} "$out/laya-evaluate.ts"
              cp ${./laya-watch.ts} "$out/laya-watch.ts"
              cp ${researchEndpoints} "$out/endpoints.json"
              cp ${pkgs.mesh-research.src}/operations.json "$out/operations.json"
            '';
          in
          {
            imports = [ (import ./underclass.nix { settings = cfg; }) ];

            # OMP 18.2 requires Bun >=1.4; keep upstream's compiler/runtime pairing.
            # r[impl onix.llm_agents.bun_compiler]
            environment.systemPackages = map (name: agentPkgs.${name}) cfg.packages;
            # r[impl onix.research-tools.omp]
            system.build.omp-research-tools = lib.mkIf cfg.ompResearchTools researchExtension;
            home-manager.users = lib.mkIf cfg.ompResearchTools {
              ${cfg.ompResearchUser}.home.file.".omp/agent/extensions/research-tools".source = researchExtension;
            };
          };
      };
  };
}
