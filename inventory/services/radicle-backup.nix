# Role-specific bounded backup mechanics for the Radicle Borg instance.
{
  instances.radicle-forge-backup.roles = {
    client.extraModules = [ ../../modules/radicle-node/backup-source.nix ];
    server.extraModules = [ ../../modules/radicle-node/backup-target.nix ];
  };
}
