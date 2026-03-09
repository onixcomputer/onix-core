_:
let

  module_definitions = {
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
    "clonadic" = import ./clonadic;
    "iroh-ssh" = import ./iroh-ssh;
    "llm-agents" = import ./llm-agents;
  };

in
module_definitions
