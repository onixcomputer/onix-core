# Every swarm member's agents reach Kiln's fleet API: the `kiln-fleet` CLI
# with KILN_FLEET_SERVER set, and the `kiln` stdio MCP server registered with
# OMP, Claude Code, Codex and Antigravity through the swarm client.
{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  fleet = import ./lib.nix {
    inherit lib;
    inherit (inputs) self;
  };
  kilnFleet = inputs.kiln-fleet.packages.${pkgs.stdenv.hostPlatform.system}.kiln-fleet;
in
{
  environment.systemPackages = [ kilnFleet ];
  environment.variables.KILN_FLEET_SERVER = fleet.serverUrl;

  # A stable path, so the agents' own files survive generations.
  onix.swarmNews.agentMcpServers.kiln = {
    command = "/run/current-system/sw/bin/kiln-fleet";
    args = [
      "mcp"
      "--server"
      fleet.serverUrl
    ];
  };
}
