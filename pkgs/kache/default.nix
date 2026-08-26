{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
}:

rustPlatform.buildRustPackage rec {
  pname = "kache";
  version = "0.16.0";

  src = fetchFromGitHub {
    owner = "kunobi-ninja";
    repo = "kache";
    rev = "v${version}";
    hash = "sha256-mrd4hlV0UXWLuo6GQXz44w1q0rrwzqvqlgcex9BHA4Q=";
  };

  cargoHash = "sha256-VQJB5kGyXUjmfcKMeD2ggllbloeKXOpwjWOCVVsb0Rk=";

  nativeBuildInputs = [ pkg-config ];

  cargoBuildFlags = [
    "--package"
    "kache"
  ];

  # The upstream test suite includes daemon/service and scenario-style tests that
  # are better exercised outside package builds. Keep the package build focused
  # on producing the wrapper binary for the desktop pilot.
  doCheck = false;

  meta = {
    description = "Zero-copy, content-addressed build cache for Rust and C/C++ object compiles";
    homepage = "https://github.com/kunobi-ninja/kache";
    license = lib.licenses.asl20;
    mainProgram = "kache";
  };
}
