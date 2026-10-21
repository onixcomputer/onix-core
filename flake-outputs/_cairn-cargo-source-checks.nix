# Exercise the real Home Manager adapter without network fetches.
{
  self,
  pkgs,
  lib,
}:
let
  inputs = self.inputs // {
    inherit self;
  };
  fallback = args: {
    inherit args;
    kind = "fallback";
  };
  testPkgs = pkgs // {
    fetchgit = fallback;
    callPackage =
      path: args:
      if lib.hasSuffix "/import-cargo-lock.nix" (toString path) then
        lockArgs: {
          inherit lockArgs;
          inherit (args) fetchgit;
        }
      else
        pkgs.callPackage path args;
  };
  home = import ../inventory/home-profiles/brittonr/dev/tools.nix {
    inherit inputs lib;
    pkgs = testPkgs;
  };
  package = lib.findFirst (p: (p.pname or "") == "cairn") null home.home.packages;
  adapter = package.cargoDeps;
  sourceInputs = inputs.cairn.inputs;
  expectedSources = {
    artifact-auth-core = sourceInputs.artifact;
    artifact-auth-ed25519 = sourceInputs.artifact;
    inherit (sourceInputs) bounded-exec;
    bounded-exec-core = sourceInputs.bounded-exec;
    cap-root-core = sourceInputs.cap-root;
    inherit (sourceInputs) durable-file-publication;
    inherit (sourceInputs) kiln-core;
    inherit (sourceInputs) mantle-build-contract;
    nickel-export-core = sourceInputs.nickel-export;
  };
  lock = builtins.fromTOML (builtins.readFile "${inputs.cairn}/Cargo.lock");
  gitPackages = lib.filter (p: lib.hasPrefix "git+" (p.source or "")) lock.package;
  checksFor =
    p:
    let
      parts = builtins.match "git\\+(.+)\\?.+#(.+)" p.source;
      args = {
        url = builtins.head parts;
        rev = builtins.elemAt parts 1;
        sha256 = adapter.lockArgs.outputHashes."${p.name}-${p.version}";
      };
      expected = expectedSources.${p.name} or null;
      selected = adapter.fetchgit args;
      wrongUrl = args // {
        url = "https://invalid.example/not-admitted.git";
      };
      wrongRev = args // {
        rev = "wrong-revision";
      };
      wrongHash = args // {
        sha256 = lib.fakeHash;
      };
    in
    [
      {
        name = "positive: ${p.name} uses its admitted source or fixed-output fallback";
        condition =
          if expected == null then
            selected == fallback args
          else
            selected.outPath == expected.outPath && args.sha256 == expected.narHash;
      }
      {
        name = "negative: ${p.name} does not substitute a different URL";
        condition = adapter.fetchgit wrongUrl == fallback wrongUrl;
      }
      {
        name = "negative: ${p.name} does not substitute a different revision";
        condition = adapter.fetchgit wrongRev == fallback wrongRev;
      }
    ]
    ++ lib.optionals (expected != null) [
      {
        name = "negative: ${p.name} rejects a mismatched uploaded-source hash";
        condition = !(builtins.tryEval (adapter.fetchgit wrongHash)).success;
      }
      {
        name = "negative: ${p.name} rejects a missing uploaded-source hash";
        condition = !(builtins.tryEval (adapter.fetchgit (builtins.removeAttrs args [ "sha256" ]))).success;
      }
    ];
in
[
  {
    name = "positive: the locked Cairn Git source set is not empty";
    condition = gitPackages != [ ];
  }
  {
    name = "negative: the Cairn adapter does not enable built-in Git fetching";
    condition = !(adapter.lockArgs.allowBuiltinFetchGit or false);
  }
]
++ lib.concatMap checksFor gitPackages
