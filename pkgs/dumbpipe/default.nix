{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "dumbpipe";
  version = "0.34.0";

  src = fetchFromGitHub {
    owner = "n0-computer";
    repo = "dumbpipe";
    rev = "v${version}";
    hash = "sha256-9fhtPnmRmKpIhTh3lQgkcATWxXdVtCkCYyCv3K8RTp4=";
  };

  cargoHash = "sha256-KSkkNGNp+gTHIxKnoqOsyKegYcNf2iRN2lOc/oJLTnU=";

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
