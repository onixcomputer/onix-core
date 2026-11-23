# grafana.ncl's interface.packages names onix-core-grafana: onix-core's
# Grafana with BLAKE3-checked email templates, the package Clan's grafana
# service sets as services.grafana.package. Same file and source tree as the
# Clan build, so the derivation is identical.
_: {
  overlays = [
    (final: _prev: {
      onix-core-grafana = import ../../modules/grafana/package.nix {
        inherit (final) lib;
        pkgs = final;
      };
    })
  ];
}
