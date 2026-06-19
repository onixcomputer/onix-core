{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
}:

rustPlatform.buildRustPackage rec {
  pname = "kache";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "kunobi-ninja";
    repo = "kache";
    rev = "v${version}";
    hash = "sha256-bOls4m1SVuIxoeF2/kCtIU+f11AO/1BFrxcWFXvGHIE=";
  };

  cargoHash = "sha256-XV7DRPaodZx5bL/neJj9KbjHVGZktD9Rumq1z55A8lM=";

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
