{ inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;

  module_definitions = {
    "tailscale" = import ./tailscale;
    "prometheus" = import ./prometheus;
    "grafana" = import ./grafana;
  };

in
lib.foldr lib.recursiveUpdate { } [ module_definitions ]
