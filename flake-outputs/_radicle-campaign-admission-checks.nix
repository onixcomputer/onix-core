# r[verify onix.campaign_source.policy]
# This check proves declared source scope, not deployment or source availability.
{
  self,
  pkgs,
  lib,
  system,
  ...
}:
let
  campaign = "rad:z2scC9MCm3pxk9mX4FEidRKabQ5LN";
  boundedExec = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo";
  unknown = "rad:z3gqcJUoA1n9HaHKufZs5FCSGazv5";
  existingPublic = [
    boundedExec
    "rad:z4JGYYW7WsesXUq7MXVdx16Fawu2f"
    "rad:z2oYsb9jGTyp68BKYhzpivY1eK58a"
    "rad:zL2ncTUeASVYwcoGkEXv9JKgGbAF"
    "rad:z3tAR4For7qw8ZirkJzoDw1VNDDLM"
    "rad:z2JQ8ihZZ6wraULQPzFWMh25B29rZ"
  ];
  expectedPublic = existingPublic ++ [ campaign ];
  expectedPrivate = [
    "rad:z3t9ykR1HfG9UkyKoQQg5ikkzrTxg"
    "rad:z3xXXCQXCTquvAawh41YYs8yC8xmk"
    "rad:z3hRCegTsS8jpJVgxYfb9psEzxHpG"
    "rad:z2QJLUqyAZnnHPiZQ1BFjLsX9ush3"
  ];
  signedRefs = "parent";
  wasm = import ../lib/wasm.nix {
    plugins = self.packages.${system}.wasm-plugins;
  };
  inventory = wasm.evalNickelFile ../inventory/services/services.ncl;
  settings = instance: host: inventory.instances.${instance}.roles.default.machines.${host}.settings;
  primary = settings "radicle-forge-bootstrap" "aspen1";
  desktop = settings "radicle-forge-secondary-seed" "britton-desktop";
  aspen3 = settings "radicle-forge-aspen3-seed" "aspen3";
  ci = settings "radicle-forge-ci" "aspen1";
  project = value: {
    public = value.seedRepositories;
    private = value.privateSeedRepositories;
    signedRefs = value.minimumSignedRefsFeature;
  };
  actual = {
    primary = project primary;
    desktop = project desktop;
    aspen3 = project aspen3;
    https = primary.httpsGitRepositories;
    ci = ci.rid;
    ciSignedRefs = ci.signedRefsFeature;
  };
  validateNode = import ../modules/radicle-node/validate-settings.nix { inherit lib; };
  validateReplica = import ../modules/radicle-seed-replica/validate-settings.nix { inherit lib; };
  packageVersion = self.packages.${system}.radicle-node.version;
  applyScope =
    base: candidate:
    base
    // {
      seedRepositories = candidate.public;
      privateSeedRepositories = candidate.private;
      minimumSignedRefsFeature = candidate.signedRefs;
    };
  moduleDiagnostics =
    candidate:
    validateNode {
      inherit packageVersion;
      actualHost = "aspen1";
      settings = (applyScope primary candidate.primary) // {
        httpsGitRepositories = candidate.https;
      };
    }
    ++ validateReplica {
      inherit packageVersion;
      actualHost = "britton-desktop";
      settings = applyScope desktop candidate.desktop;
    }
    ++ validateReplica {
      inherit packageVersion;
      actualHost = "aspen3";
      settings = applyScope aspen3 candidate.aspen3;
    };
  seedAccepted =
    candidate:
    candidate.public == expectedPublic
    && candidate.private == expectedPrivate
    && candidate.signedRefs == signedRefs;
  accepted =
    candidate:
    builtins.all seedAccepted [
      candidate.primary
      candidate.desktop
      candidate.aspen3
    ]
    && candidate.https == expectedPublic
    && candidate.ci == boundedExec
    && candidate.ciSignedRefs == signedRefs;
  seedMutations = [
    { public = existingPublic; }
    { public = expectedPublic ++ [ campaign ]; }
    { public = expectedPublic ++ [ unknown ]; }
    { public = expectedPublic ++ expectedPrivate; }
    { private = expectedPrivate ++ [ campaign ]; }
    { private = [ ]; }
    { signedRefs = "root"; }
  ];
  negativeSeeds =
    lib.concatMap
      (host: map (mutation: actual // { ${host} = actual.${host} // mutation; }) seedMutations)
      [
        "primary"
        "desktop"
        "aspen3"
      ];
  negativeHttpRoutes = [
    (actual // { https = existingPublic; })
    (actual // { https = expectedPublic ++ [ campaign ]; })
    (actual // { https = expectedPublic ++ [ unknown ]; })
    (actual // { https = expectedPublic ++ expectedPrivate; })
  ];
  negativeCiRoutes = [
    (actual // { ci = campaign; })
    (actual // { ci = ""; })
    (actual // { ciSignedRefs = "root"; })
  ];
  negativeRoutes = negativeHttpRoutes ++ negativeCiRoutes;
in
{
  checks.radicle-campaign-source-scope =
    assert lib.assertMsg (
      moduleDiagnostics actual == [ ]
    ) "actual module validators rejected Campaign admission";
    assert lib.assertMsg (builtins.all (candidate: moduleDiagnostics candidate != [ ]) (
      negativeSeeds ++ negativeHttpRoutes
    )) "actual module validators accepted unsafe seed or HTTPS scope";
    assert lib.assertMsg (accepted actual) "Campaign source scope differs from its exact admission";
    assert lib.assertMsg (builtins.all (candidate: !(accepted candidate)) (
      negativeSeeds ++ negativeRoutes
    )) "unsafe Campaign source scope passed admission";
    pkgs.writeText "radicle-campaign-source-scope" ''
      declared_source_scope=accepted
      negative_seed_cases=${toString (builtins.length negativeSeeds)}
      negative_route_cases=${toString (builtins.length negativeRoutes)}
      deployment=not-claimed
      source_availability=not-claimed
    '';
}
