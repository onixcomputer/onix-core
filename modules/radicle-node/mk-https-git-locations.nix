# r[impl onix.radicle_node.exposure]
{ lib }:
{
  backend,
  repositoryIds,
}:
let
  infoRefsSuffix = ".git/info/refs";
  uploadPackSuffix = ".git/git-upload-pack";
  readServiceQuery = "service=git-upload-pack";

  ridPath = rid: lib.removePrefix "rad:" rid;
  routesFor =
    rid:
    let
      path = ridPath rid;
    in
    [
      (lib.nameValuePair "= /${path}${infoRefsSuffix}" {
        proxyPass = backend;
        recommendedProxySettings = true;
        extraConfig = ''
          if ($args != "${readServiceQuery}") { return 404; }
          limit_except GET { deny all; }
        '';
      })
      (lib.nameValuePair "= /${path}${uploadPackSuffix}" {
        proxyPass = backend;
        recommendedProxySettings = true;
        extraConfig = ''
          if ($args != "") { return 404; }
          limit_except POST { deny all; }
        '';
      })
    ];
in
{
  default = {
    return = 404;
  };
  repositories = lib.listToAttrs (lib.concatMap routesFor repositoryIds);
}
