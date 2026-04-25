{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
}:

rustPlatform.buildRustPackage {
  pname = "crw";
  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "us";
    repo = "crw";
    rev = "v0.4.0";
    hash = "sha256-Qo0rWQMg0dYhhRzC+QqL23Kw5JWJ5lxU7nO7o1HUnzA=";
  };

  cargoHash = "sha256-Za1vfl1QgcLbkh4kvqzWAjIngPvv3E0bx9PoQiSyQdQ=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];

  cargoBuildFlags = [
    "--package"
    "crw-cli"
    "--package"
    "crw-mcp"
  ];

  doCheck = false;

  meta = {
    description = "Fast web scraper, crawler & MCP server for AI agents";
    homepage = "https://github.com/us/crw";
    license = lib.licenses.agpl3Only;
    mainProgram = "crw";
  };
}
