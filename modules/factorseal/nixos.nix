# The upstream module owns TPM access, lifecycle, and native service wiring.
{ factorseal }:
{
  config,
  lib,
  ...
}:
{
  imports = [ factorseal.nixosModules.factorseal ];

  options.services.factorseal.acceptUnauditedPrototype = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Accept Factorseal for disposable evaluation secrets, not production secrets.";
  };

  config.assertions = lib.mkIf config.services.factorseal.enable [
    {
      assertion = config.services.factorseal.acceptUnauditedPrototype;
      message = "Factorseal is an unaudited prototype. Set services.factorseal.acceptUnauditedPrototype only for disposable evaluation secrets.";
    }
  ];
}
