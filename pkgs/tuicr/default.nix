{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "tuicr";
  version = "0.10.0";

  src = fetchFromGitHub {
    owner = "agavra";
    repo = "tuicr";
    rev = "v${version}";
    hash = "sha256-Hu58R7LOsTSArZuqrmH7G5NwJI8NnSxMXbdqCqbxIxs=";
  };

  cargoHash = "sha256-tuYlErRt0ifKcAWWHy+aTwwss8Y6PJedpiKMJZUC6Yo=";

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
