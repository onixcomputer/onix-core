{ inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;

  services = {
    tailscale = import ./tailscale.nix { inherit inputs; };
    sshd = import ./sshd.nix { inherit inputs; };
    prometheus = import ./prometheus.nix { inherit inputs; };
    grafana = import ./grafana.nix { inherit inputs; };
    loki = import ./loki.nix { inherit inputs; };
  };
in
lib.foldr lib.recursiveUpdate { } (lib.attrValues services)
