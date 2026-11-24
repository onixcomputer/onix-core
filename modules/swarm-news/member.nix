# A NixOS machine tagged `swarm-news`: a clan-vars endpoint key whose public
# id the server allowlists, an NNTP password shared only with the server, and
# the swarm-news client that uses both.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  swarm = import ./lib.nix {
    inherit lib;
    inherit (inputs) self;
  };
  irohNews = inputs.renews.packages.${pkgs.stdenv.hostPlatform.system}.iroh-news;
  generators = config.clan.core.vars.generators;
  password = swarm.passwordGenerator config.networking.hostName;
in
{
  imports = [ ./client.nix ];

  clan.core.vars.generators = {
    ${swarm.identityGenerator} = swarm.mkKeyGenerator {
      inherit pkgs irohNews;
      owner = swarm.user;
    };
    ${password} = swarm.mkPasswordGenerator pkgs;
  };

  onix.swarmNews = {
    enable = true;
    secretKeyFile = generators.${swarm.identityGenerator}.files.secret-key.path;
    passwordFile = generators.${password}.files.password.path;
  };
}
