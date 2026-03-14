{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "sendme";
  version = "0.31.0";

  src = fetchFromGitHub {
    owner = "n0-computer";
    repo = "sendme";
    rev = "v${version}";
    hash = "sha256-zh0YYJoljcOQz0ltAk+UBScSGZhsoSqIa+F0Qm4/3iw=";
  };

  cargoHash = "sha256-G7b1BBlVMPtfEWfIXIMH4N+Avt9vtEcCG1ctrja5Ttc=";

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
