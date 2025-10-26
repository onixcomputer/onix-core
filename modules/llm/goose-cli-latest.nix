{ pkgs }:

# Custom goose-cli with latest version (1.9.3) to fix streaming issues
pkgs.rustPlatform.buildRustPackage rec {
  pname = "goose-cli";
  version = "1.9.3";

  src = pkgs.fetchFromGitHub {
    owner = "block";
    repo = "goose";
    rev = "v${version}";
    hash = "sha256-cw4iGvfgJ2dGtf6om0WLVVmieeVGxSPPuUYss1rYcS8=";
  };

  cargoHash = "sha256-/HaxjQDrBYKLP5lamx7TIbYUtIdCfbqZ5oQ1rK4T8uA=";

  nativeBuildInputs = with pkgs; [
    pkg-config
    protobuf
  ];

  buildInputs = with pkgs; [ dbus ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.xorg.libxcb ];

  doCheck = false; # Tests require network access

  meta = {
    description = "Open-source, extensible AI agent";
    homepage = "https://github.com/block/goose";
    license = pkgs.lib.licenses.asl20;
    mainProgram = "goose";
  };
}
