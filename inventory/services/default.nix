{ inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;

  services = {
    tailscale = import ./tailscale.nix { inherit inputs; };
    tailscale-traefik = import ./tailscale-traefik.nix { inherit inputs; };
    static-server = import ./static-server.nix { inherit inputs; };
    sshd = import ./sshd.nix { inherit inputs; };
    calibre-server = import ./calibre-server.nix { inherit inputs; };
    prometheus = import ./prometheus.nix { inherit inputs; };
    grafana = import ./grafana.nix { inherit inputs; };
    loki = import ./loki.nix { inherit inputs; };
    vaultwarden = import ./vaultwarden.nix { inherit inputs; };
    homepage-dashboard = import ./homepage-dashboard.nix { inherit inputs; };
    cloudflare-tunnel = import ./cloudflare-tunnel.nix { inherit inputs; };
    llm = import ./llm.nix { inherit inputs; };

    upmpdcli = import ./upmpdcli.nix { inherit inputs; };
    nix-gc = import ./nix-gc.nix { inherit inputs; };
    ollama = import ./ollama.nix { inherit inputs; };
    clonadic = import ./clonadic.nix { inherit inputs; };
    iroh-ssh = import ./iroh-ssh.nix { inherit inputs; };
    llm-agents = import ./llm-agents.nix { inherit inputs; };
    harmonia = import ./harmonia.nix { inherit inputs; };
    borgbackup = import ./borgbackup.nix { inherit inputs; };
    matrix-synapse = import ./matrix-synapse.nix { inherit inputs; };
    buildbot = import ./buildbot.nix { inherit inputs; };
  };
in
lib.foldr lib.recursiveUpdate { } (lib.attrValues services)
