{ inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;

  module_definitions = {
    "tailscale" = import ./tailscale;
    "tailscale-traefik" = import ./tailscale-traefik;
    "static-server" = import ./static-server;
    "prometheus" = import ./prometheus;
    "grafana" = import ./grafana;
    "loki" = import ./loki;
    "vaultwarden" = import ./vaultwarden;
    "homepage-dashboard" = import ./homepage-dashboard;
    "pixiecore" = import ./pixiecore;
    "security-acme" = import ./security-acme;
  };

in
lib.foldr lib.recursiveUpdate { } [ module_definitions ]
