# nix-build-farm.ncl sets services.nix-grpc-daemon (nix-grpc-store's
# server.nix at the pinned rev) and uses onix-core's fork-built daemon and
# niks3's push client.
{ self, inputs }:
{
  nixosModules = [ "${inputs.nix-grpc-store}/nixos/server.nix" ];
  overlays = [
    (final: _prev: {
      onix-core-nix-grpc-store = self.packages.${final.stdenv.hostPlatform.system}.nix-grpc-store;
      onix-core-niks3 = inputs.niks3.packages.${final.stdenv.hostPlatform.system}.niks3;
    })
  ];
}
