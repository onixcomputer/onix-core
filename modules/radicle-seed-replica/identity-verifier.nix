{ pkgs }:
let
  source = ./identity-verifier.rs;
  rustEdition = "2021";
  rustOptimizationLevel = 2;
  binary =
    pkgs.runCommand "radicle-replica-identity-verify-unwrapped"
      {
        nativeBuildInputs = [
          pkgs.rustc
          pkgs.stdenv.cc
        ];
      }
      ''
        mkdir -p "$out/bin"
        rustc --edition ${rustEdition} -C opt-level=${toString rustOptimizationLevel} -D warnings \
          ${source} \
          -o "$out/bin/radicle-replica-identity-verify"
      '';
in
pkgs.runCommand "radicle-replica-identity-verify"
  {
    nativeBuildInputs = [ pkgs.makeWrapper ];
  }
  ''
    mkdir -p "$out/bin"
    makeWrapper ${binary}/bin/radicle-replica-identity-verify \
      "$out/bin/radicle-replica-identity-verify" \
      --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.openssh ]}
  ''
