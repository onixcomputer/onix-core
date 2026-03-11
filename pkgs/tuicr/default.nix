{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage {
  pname = "tuicr";
  version = "0.7.2-unstable-2025-07-13";

  src = fetchFromGitHub {
    owner = "agavra";
    repo = "tuicr";
    rev = "544f8b6f3bbef4577f6b79ded2974684d8a43582";
    hash = "sha256-VEt3lAK7jMVE1mkW2S8RaCd3G19M102pCGR6ge5MBsY=";
  };

  cargoHash = "sha256-11wiYZflDqAJZ4fVefHxRJ9nB5E79d5J/8XjzOOOg7g=";

  # One test (should_return_no_changes_for_clean_repo) requires a real git repo
  # which doesn't exist inside the nix build sandbox
  doCheck = false;

  meta = {
    description = "Review AI-generated diffs like a GitHub pull request from your terminal";
    homepage = "https://github.com/agavra/tuicr";
    license = lib.licenses.mit;
    mainProgram = "tuicr";
  };
}
