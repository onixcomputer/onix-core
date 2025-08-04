{ inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;

  module_definitions = {
    "tailscale" = import ./tailscale;
    "prometheus" = import ./prometheus;
    "grafana" = import ./grafana;
    "loki" = import ./loki;
    "vaultwarden" = import ./vaultwarden;
    "homepage-dashboard" = import ./homepage-dashboard;
    "pixiecore" = import ./pixiecore;
    "traefik" = import ./traefik;
    "ddclient" = import ./ddclient;
  };

in
lib.foldr lib.recursiveUpdate { } [ module_definitions ]
