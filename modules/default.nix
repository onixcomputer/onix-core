{ inputs, ... }:
let

  module_definitions = {
    "buildbot" = import ./buildbot { inherit inputs; };
    "tailscale" = import ./tailscale;
    "tailscale-traefik" = import ./tailscale-traefik;
    "static-server" = import ./static-server;
    "prometheus" = import ./prometheus;
    "grafana" = import ./grafana;
    "loki" = import ./loki;
    "vaultwarden" = import ./vaultwarden;
    "homepage-dashboard" = import ./homepage-dashboard;
    "cloudflare-tunnel" = import ./cloudflare-tunnel;
    "calibre-server" = import ./calibre-server;
    "llm" = import ./llm;
    "upmpdcli" = import ./upmpdcli;
    "nix-gc" = import ./nix-gc;
    "ollama" = import ./ollama;
    "clankers" = import ./clankers;
    "cloud-hypervisor-vm" = import ./cloud-hypervisor-vm;
    "iroh-ssh" = import ./iroh-ssh;
    "llm-agents" = import ./llm-agents;
    "home-manager-profiles" = import ./home-manager-profiles;
    "harmonia" = import ./harmonia;
    "llamacpp-rpc" = import ./llamacpp-rpc;
    "syncthing" = import ./syncthing;
  };

  # NOTE: borgbackup-extras and matrix-synapse-cf live under modules/ but are
  # plain NixOS modules loaded via extraModules in inventory/services/, not
  # clan perInstance service definitions.  They are intentionally absent from
  # module_definitions above.

in
module_definitions
