# Nix path stub — data lives in services.ncl.
# extraModules requires a Nix path that can't be expressed in Nickel.
{
  instances.borgbackup.roles.client = {
    extraModules = [ ../../modules/borgbackup-extras ];
  };
}
