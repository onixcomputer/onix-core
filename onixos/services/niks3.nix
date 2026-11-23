# niks3.ncl sets services.niks3-auto-upload and uses niks3-hook from the
# pinned niks3 input. The disabled post-build hook is the same no-op script
# Clan's uploader role builds.
{ inputs, ... }:
{
  nixosModules = [ inputs.niks3.nixosModules.niks3-auto-upload ];
  overlays = [
    (final: _prev: {
      onix-core-niks3-hook = inputs.niks3.packages.${final.stdenv.hostPlatform.system}.niks3-hook;
      onix-core-niks3-post-build-upload-disabled = final.writeShellScript "niks3-post-build-upload-disabled" ''
        exit 0
      '';
    })
  ];
}
