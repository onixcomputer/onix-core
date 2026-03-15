# iroh-ssh SSH config — generates ProxyCommand entries for each machine
# whose iroh-ssh node-id exists in the vars directory.
#
# After running `clan vars generate --machine <machine>`, the node-id
# file appears at vars/per-machine/<machine>/iroh-ssh/node-id/value.
# This module reads those files at eval time and creates SSH Host
# entries that route through iroh-ssh's QUIC tunnel.
{ inputs, pkgs, ... }:
let
  flakeSrc = inputs.self;

  # Machines that run iroh-ssh (tagged tailnet-brittonr in inventory)
  irohMachines = [
    "britton-fw"
    "britton-gpd"
    "bonsai"
    "aspen1"
    "aspen2"
    "pine"
    "utm-vm"
  ];

  iroh-ssh = pkgs.callPackage "${flakeSrc}/pkgs/iroh-ssh" { };

  # Read node-id from vars if the file exists
  getNodeId =
    machine:
    let
      path = flakeSrc + "/vars/per-machine/${machine}/iroh-ssh/node-id/value";
    in
    if builtins.pathExists path then builtins.readFile path else null;

  # Build matchBlocks for machines with known endpoint IDs
  irohMatchBlocks = builtins.listToAttrs (
    builtins.filter (entry: entry != null) (
      map (
        machine:
        let
          nodeId = getNodeId machine;
        in
        if nodeId == null then
          null
        else
          {
            name = "iroh-${machine}";
            value = {
              hostname = machine;
              user = "root";
              proxyCommand = "${iroh-ssh}/bin/iroh-ssh proxy ${nodeId}";
            };
          }
      ) irohMachines
    )
  );
in
{
  home.packages = [ iroh-ssh ];

  programs.ssh.matchBlocks = irohMatchBlocks;
}
