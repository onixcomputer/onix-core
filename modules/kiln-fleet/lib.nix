# Names shared by the Kiln fleet coordinator, its agent hosts and the agents'
# MCP registration (docs/kiln-fleet.md). Kiln owns claims and work order; herdr
# runs the agents it dispatches, in one headless session per agent host.
{ lib, self }:
let
  swarm = import ../swarm-news/lib.nix { inherit lib self; };
  publicVar =
    machine: generator: file:
    let
      path = "${self}/vars/per-machine/${machine}/${generator}/${file}/value";
    in
    if builtins.pathExists path then lib.fileContents path else null;
in
rec {
  # Kiln runs as its own account so the agents it dispatches cannot write
  # its ledger or verifier repositories.
  serviceUser = "kiln-fleet";
  # Kiln's fleet service runs beside kiln-web-service on the swarm site host.
  coordinator = swarm.siteMachine;
  coordinatorAddress = swarm.siteTailnetAddress;
  port = 8095;
  serverUrl = "http://${coordinatorAddress}:${toString port}";
  inherit (swarm) user;

  # Machines whose herdr `kiln` session runs dispatched agents. Each needs the
  # agent kinds below and a checkout of every repository it may take work for.
  agentHosts = [
    "britton-desktop"
    "aspen3"
  ];
  herdrSession = "kiln";

  # Saved herdr machines on the coordinator that target each remote host's
  # `kiln` session (`herdr machine add <target> --label <label>
  # --remote-session kiln`), the ssh targets Kiln fetches agent commits
  # from, and the account home on each host.
  herdrMachines = {
    aspen3 = "aspen3-kiln";
  };
  sshTargets = {
    britton-desktop = "${user}@localhost";
    aspen3 = "${user}@aspen3-1";
  };
  homes = lib.genAttrs agentHosts (_: "/home/${user}");
  worktreeRoot = machine: "${homes.${machine}}/.local/state/kiln-fleet/worktrees";

  # Kiln's ssh public key (clan vars `kiln-fleet-ssh` on the coordinator);
  # null until generated.
  sshPublicKey = publicVar coordinator "kiln-fleet-ssh" "id_ed25519.pub";

  # Agent kinds and slots each host offers to dispatched work.
  agents = lib.genAttrs agentHosts (_: [
    {
      kind = "omp";
      slots = 2;
      args = [ ];
    }
  ]);

  # Repositories enrolled for dispatched work, with each host's checkout.
  # A host without a checkout is never chosen for that repository.
  repositories = {
    "brittonr/kiln-fleet-sandbox".checkouts = lib.genAttrs agentHosts (
      host: "${homes.${host}}/git/kiln-fleet-sandbox"
    );
  };

  # Tailscale node names the fleet API accepts, mapped to machine labels.
  peers = {
    "britton-desktop.bison-tailor.ts.net." = "britton-desktop";
    "aspen3-1.bison-tailor.ts.net." = "aspen3";
    "aspen1.bison-tailor.ts.net." = "aspen1";
  };
}
