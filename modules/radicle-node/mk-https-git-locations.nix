# r[impl onix.radicle_node.exposure]
{ lib }:
{
  backend,
  repositoryIds,
  publishers ? { },
}:
let
  infoRefsSuffix = "/info/refs";
  uploadPackSuffix = "/git-upload-pack";
  deniedStatus = 404;
  validPublishers = builtins.all (
    rid:
    builtins.elem rid repositoryIds
    && builtins.match "rad:z[1-9A-HJ-NP-Za-km-z]+" rid != null
    && builtins.isString publishers.${rid}
    && builtins.match "z6Mk[1-9A-HJ-NP-Za-km-z]+" publishers.${rid} != null
  ) (builtins.attrNames publishers);
  readServiceQuery = "service=git-upload-pack";

  ridPath = rid: lib.removePrefix "rad:" rid;
  routesFor = path: [
    (lib.nameValuePair "= /${path}${infoRefsSuffix}" {
      proxyPass = backend;
      recommendedProxySettings = true;
      extraConfig = ''
        if ($args != "${readServiceQuery}") { return ${toString deniedStatus}; }
        limit_except GET { deny all; }
      '';
    })
    (lib.nameValuePair "= /${path}${uploadPackSuffix}" {
      proxyPass = backend;
      recommendedProxySettings = true;
      extraConfig = ''
        if ($args != "") { return ${toString deniedStatus}; }
        limit_except POST { deny all; }
      '';
    })
  ];
  paths = map (rid: "${ridPath rid}.git") repositoryIds;
  publisherPaths = map (rid: "${ridPath rid}.git/${publishers.${rid}}") (
    builtins.attrNames publishers
  );
in
assert lib.assertMsg validPublishers
  "HTTPS Git publishers require an admitted RID and a path-safe NID";
{
  default = {
    return = deniedStatus;
  };
  repositories = lib.listToAttrs (lib.concatMap routesFor (paths ++ publisherPaths));
}
