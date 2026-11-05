{ config, inputs, pkgs, ... }:
{
  imports = [ inputs.herdr-iroh.nixosModules.herdr-iroh ];

  services.herdr-iroh = {
    enable = true;
    # Herdr socket and saved-machine/SSH configuration belong to this account.
    user = "brittonr";
    herdrPackage = pkgs.herdr;
    allowedPeers.britton-grok.endpointId = "8f9a3e1c7b464c60cce5bccf653b043ff444c2fa524828a2f7a66d0495153311";
  };

  environment.systemPackages = [ config.services.herdr-iroh.package ];
}
