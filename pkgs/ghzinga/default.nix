{
  lib,
  rustPlatform,
  fetchFromGitHub,
  git,
}:

rustPlatform.buildRustPackage rec {
  pname = "ghzinga";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "osolmaz";
    repo = "ghzinga";
    rev = "30cf4ac79c69140cdac1c8bcf7caa54be34f361b";
    hash = "sha256-siIpLSaGUvYJIDx6jjYq7A8lh2bnBzfcBeF+2AzV3E4=";
  };

  cargoHash = "sha256-GkdiMyDeRdTymowKRMYR+B1pv38dY25EaMzkZwqxzKk=";

  nativeCheckInputs = [ git ];
  preCheck = ''
    patchShebangs plugins/herdr/test
  '';

  meta = {
    description = "Terminal UI for GitHub pull requests and issues";
    homepage = "https://github.com/osolmaz/ghzinga";
    license = lib.licenses.mit;
    mainProgram = "gzg";
    platforms = lib.platforms.unix;
  };
}
