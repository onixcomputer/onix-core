{ inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;

  services = {
    tailscale = import ./tailscale.nix { inherit inputs; };
    tailscale-traefik = import ./tailscale-traefik.nix { inherit inputs; };
    static-server = import ./static-server.nix { inherit inputs; };
    sshd = import ./sshd.nix { inherit inputs; };
    prometheus = import ./prometheus.nix { inherit inputs; };
    grafana = import ./grafana.nix { inherit inputs; };
    harmonia = import ./harmonia.nix { inherit inputs; };
    loki = import ./loki.nix { inherit inputs; };
    vaultwarden = import ./vaultwarden.nix { inherit inputs; };
    homepage-dashboard = import ./homepage-dashboard.nix { inherit inputs; };
    pixiecore = import ./pixiecore.nix { inherit inputs; };
    seaweedfs = import ./seaweedfs.nix { inherit inputs; };
    wiki-js = import ./wiki-js.nix { inherit inputs; };
    buildbot = import ./buildbot.nix { inherit inputs; };
    cloudflare-tunnel = import ./cloudflare-tunnel.nix { inherit inputs; };
  };
in
lib.foldr lib.recursiveUpdate { } (lib.attrValues services)
