# Pure positive and negative controls over the actual inventory binding.
{
  lib,
  settings,
  packageVersion,
}:
let
  campaign = "rad:z2scC9MCm3pxk9mX4FEidRKabQ5LN";
  publisher = "z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx";
  unknown = "rad:z3gqcJUoA1n9HaHKufZs5FCSGazv5";
  otherPublisher = "z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8";
  privateRepository = "rad:z2QJLUqyAZnnHPiZQ1BFjLsX9ush3";
  deniedStatus = 404;
  backend = "http://127.0.0.1";
  binding = {
    ${campaign} = publisher;
  };
  build = import ./mk-https-git-locations.nix { inherit lib; };
  validate = import ./validate-settings.nix { inherit lib; };
  routes =
    publishers:
    build {
      inherit backend publishers;
      repositoryIds = settings.httpsGitRepositories;
    };
  admitted = routes settings.httpsGitPublishers;
  old = routes { };
  path = "/${lib.removePrefix "rad:" campaign}.git/${publisher}";
  info = "= ${path}/info/refs";
  upload = "= ${path}/git-upload-pack";
  expectedNames = lib.sort builtins.lessThan (
    (builtins.attrNames old.repositories)
    ++ [
      info
      upload
    ]
  );
  policyAccepts =
    candidate:
    validate {
      inherit packageVersion;
      actualHost = "aspen1";
      settings = candidate;
    } == [ ];
  invalidBindings = [
    { ${unknown} = publisher; }
    { ${privateRepository} = publisher; }
    { ${campaign} = otherPublisher; }
    { ${campaign} = ""; }
    { ${campaign} = "../info"; }
    { ${campaign} = "${publisher}?service=git-receive-pack"; }
    { ${campaign} = "${publisher}/git-receive-pack"; }
    { ${campaign} = null; }
    { ${campaign} = [ publisher ]; }
    (binding // { ${unknown} = publisher; })
  ];
  malformedBindings = [
    { ${unknown} = publisher; }
    { ${campaign} = "../info"; }
    { ${campaign} = "${publisher}?x"; }
    { ${campaign} = null; }
  ];
  rejectedByBuilder =
    candidate: !(builtins.tryEval (builtins.deepSeq (routes candidate) true)).success;
in
assert settings.httpsGitPublishers == binding;
assert policyAccepts settings;
assert policyAccepts (settings // { httpsGitPublishers = { }; });
assert builtins.all (
  value: !(policyAccepts (settings // { httpsGitPublishers = value; }))
) invalidBindings;
assert
  !(policyAccepts (
    settings
    // {
      httpsEnabled = false;
      httpsGitRepositories = [ ];
    }
  ));
assert builtins.all rejectedByBuilder malformedBindings;
assert builtins.attrNames admitted.repositories == expectedNames;
assert builtins.all (name: admitted.repositories.${name} == old.repositories.${name}) (
  builtins.attrNames old.repositories
);
assert admitted.default.return == deniedStatus;
assert admitted.repositories.${info}.proxyPass == backend;
assert admitted.repositories.${upload}.proxyPass == backend;
assert lib.hasInfix ''if ($args != "service=git-upload-pack")''
  admitted.repositories.${info}.extraConfig;
assert lib.hasInfix "limit_except GET" admitted.repositories.${info}.extraConfig;
assert lib.hasInfix ''if ($args != "")'' admitted.repositories.${upload}.extraConfig;
assert lib.hasInfix "limit_except POST" admitted.repositories.${upload}.extraConfig;
assert !(builtins.hasAttr "= ${path}/git-receive-pack" admitted.repositories);
true
