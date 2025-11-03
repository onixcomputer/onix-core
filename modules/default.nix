{ inputs }:
let

  module_definitions = {
    "tailscale" = import ./tailscale;
    "tailscale-traefik" = import ./tailscale-traefik;
    "static-server" = import ./static-server;
    "prometheus" = import ./prometheus;
    "grafana" = import ./grafana;
    "harmonia" = import ./harmonia;
    "loki" = import ./loki;
    "vaultwarden" = import ./vaultwarden;
    "homepage-dashboard" = import ./homepage-dashboard;
    "pixiecore" = import ./pixiecore;
    "seaweedfs" = import ./seaweedfs;
    "wiki-js" = import ./wiki-js;
    "buildbot" = import ./buildbot;
    "cloudflare-tunnel" = import ./cloudflare-tunnel;
    "gitlab-runner" = import ./gitlab-runner;
    "llm" = import ./llm;
    "keycloak" = import ./keycloak { inherit inputs; };
  };

in
module_definitions
