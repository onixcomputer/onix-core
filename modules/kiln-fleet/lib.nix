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
  consoleUrl = "https://${coordinator}.bison-tailor.ts.net:9443";
  inherit (swarm) user;
  enrolledActors = [
    "operator"
    user
  ];

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

  # Repositories enrolled for read-only Cairn snapshot intake and GitHub issue
  # polling into the Fleet implementation ledger without granting automatic
  # agent dispatch placement (they have no checkouts in inventory.json until
  # explicitly promoted to `repositories`).
  observedRepositories = {
    "OnixResearch/kiln" = {
      project = "kiln";
      checkout = "${homes.${coordinator}}/git/OnixResearch/kiln";
      cairnPolicy = "cairn-policy/generated/cairn-policy.json";
      githubId = 1421187104;
    };
    "OnixResearch/mantle" = {
      project = "mantle";
      checkout = "${homes.${coordinator}}/git/OnixResearch/mantle";
      githubId = 1201634195;
    };
    "OnixResearch/mneme" = {
      project = "mneme";
      checkout = "${homes.${coordinator}}/git/OnixResearch/mneme";
      githubId = 1453167197;
    };
    "OnixResearch/lattice" = {
      project = "lattice";
      checkout = "${homes.${coordinator}}/git/OnixResearch/lattice";
      githubId = 1310001165;
    };
    "OnixResearch/valence" = {
      project = "valence";
      checkout = "${homes.${coordinator}}/git/OnixResearch/valence";
      githubId = 1292615383;
    };
    "OnixResearch/cairn" = {
      project = "cairn";
      checkout = "${homes.${coordinator}}/git/OnixResearch/cairn";
      cairnPolicy = "cairn-policy/generated/cairn-policy.json";
      githubId = 1242548311;
    };
    "OnixResearch/noble-lang" = {
      project = "noble-lang";
      checkout = "${homes.${coordinator}}/git/OnixResearch/noble-lang";
      githubId = 1375233933;
    };
    "OnixResearch/octet" = {
      project = "octet";
      checkout = "${homes.${coordinator}}/git/OnixResearch/octet";
      githubId = 1189448989;
    };
    "OnixResearch/bounded-exec" = {
      project = "bounded-exec";
      checkout = "${homes.${coordinator}}/git/OnixResearch/bounded-exec";
      githubId = 1310004939;
    };
    "OnixResearch/onix-artifact" = {
      project = "onix-artifact";
      checkout = "${homes.${coordinator}}/git/OnixResearch/artifact";
      githubId = 1305844778;
    };
    "onixcomputer/onix-core" = {
      project = "onix-core";
      checkout = "${homes.${coordinator}}/git/onix-core";
      githubId = 1022760605;
    };
    "onixcomputer/onix-modules" = {
      project = "onixos";
      checkout = "${homes.${coordinator}}/git/OnixResearch/onixos";
      githubId = 1198850128;
    };
    "brittonr/aspen" = {
      project = "aspen";
      checkout = "${homes.${coordinator}}/git/OnixResearch/aspen";
      githubId = 816931615;
    };
  };

  # Tailscale node names the fleet API accepts, mapped to machine labels.
  peers = {
    "britton-desktop.bison-tailor.ts.net." = "britton-desktop";
    "aspen3-1.bison-tailor.ts.net." = "aspen3";
    "aspen1.bison-tailor.ts.net." = "aspen1";
  };
}
