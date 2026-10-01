{
  callPackage,
  clangStdenv,
  nix-grpc-store-src,
  nix-store,
  nix-util,
}:
# Import only the single-version build, not upstream's release dispatcher.
# clangStdenv uses libstdc++ on Linux, matching the fork's GCC-built libraries.
(callPackage "${nix-grpc-store-src}/nix/packages/plugin.nix" {
  stdenv = clangStdenv;
  inherit nix-store nix-util;
  jwt-cpp = callPackage "${nix-grpc-store-src}/nix/packages/jwt-cpp.nix" {
    stdenv = clangStdenv;
  };
}).overrideAttrs
  (old: {
    # This fork has templated derivations with grouped source/derivation inputs.
    patches = (old.patches or [ ]) ++ [ ./nix-2.36-full-inputs.patch ];
  })
