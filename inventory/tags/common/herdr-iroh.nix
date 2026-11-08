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

  # The saved-machine gateway runs ssh as this user. The user's ssh config
  # expands ${XDG_RUNTIME_DIR} for the yubikey-agent IdentityAgent, and ssh
  # rejects the whole config when that variable is unset, as it is in a system
  # unit. Point the relay at the user's runtime directory (kept by lingering).
  systemd.services.herdr-iroh.environment.XDG_RUNTIME_DIR =
    "/run/user/${toString config.users.users.${config.services.herdr-iroh.user}.uid}";

  environment.systemPackages = [ config.services.herdr-iroh.package ];
}
