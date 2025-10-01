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
    #    harmonia = import ./harmonia.nix { inherit inputs; };
    loki = import ./loki.nix { inherit inputs; };
    vaultwarden = import ./vaultwarden.nix { inherit inputs; };
    homepage-dashboard = import ./homepage-dashboard.nix { inherit inputs; };
    pixiecore = import ./pixiecore.nix { inherit inputs; };
    seaweedfs = import ./seaweedfs.nix { inherit inputs; };
    wiki-js = import ./wiki-js.nix { inherit inputs; };
    cloudflare-tunnel = import ./cloudflare-tunnel.nix { inherit inputs; };
    #gitlab-runner = import ./gitlab-runner.nix { inherit inputs; };
    #keycloak = import ./keycloak.nix { inherit inputs; };
    #buildbot = import ./buildbot.nix { inherit inputs; };
    microvm = import ./microvm.nix { inherit inputs; };
    microvm-clan = import ./microvm-clan.nix { inherit inputs; };
    # Note: MicroVMs can now be configured declaratively via the clan service module
    # See inventory/services/microvm.nix for example configurations
    # microvm-clan service uses clan.nixosModules for complete clan machine deployment
  };
in
lib.foldr lib.recursiveUpdate { } (lib.attrValues services)
