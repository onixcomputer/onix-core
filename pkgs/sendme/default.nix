{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "sendme";
  version = "0.32.0";

  src = fetchFromGitHub {
    owner = "n0-computer";
    repo = "sendme";
    rev = "v${version}";
    hash = "sha256-Yi0GM9gNQ1lEuuwS49asbhA1b2iUfBDnT06sPX7UuKM=";
  };

  cargoHash = "sha256-Nkr/8KoNZCTPWcpnqdfB+D3VpL4ABRlvi5nxhMuCw1U=";

  # Tests require network access (iroh relay connections)
  doCheck = false;

  meta = {
    description = "Send files and directories over iroh with blake3-verified streaming and resume";
    homepage = "https://github.com/n0-computer/sendme";
    license = with lib.licenses; [
      asl20
      mit
    ];
    mainProgram = "sendme";
  };
}
