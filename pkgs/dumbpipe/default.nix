{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "dumbpipe";
  version = "0.35.0";

  src = fetchFromGitHub {
    owner = "n0-computer";
    repo = "dumbpipe";
    rev = "v${version}";
    hash = "sha256-Oo97v2afVotFCDaJT0bJXLfcKVxBoRUH2nO6StsJc34=";
  };

  cargoHash = "sha256-P6NFYqlyZiZ7hAz9W4nOPlGvwECv6/oG98ey7T0a2O8=";

  # Tests require network access (iroh relay connections)
  doCheck = false;

  meta = {
    description = "Cross-device unix pipe over iroh P2P QUIC with NAT hole-punching";
    homepage = "https://github.com/n0-computer/dumbpipe";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "dumbpipe";
  };
}
