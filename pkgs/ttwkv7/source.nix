{ fetchFromGitHub }:
let
  version = "unstable-2026-06-22";
  revision = "84d8b6a44729cc358f163e7ab9614b0a1b8ddc09";
  hash = "sha256-zhGN99BPbVES7jVK/tKWeNeNbsDaU2yw/7XUg7YzEyw=";
in
{
  inherit version revision;
  upstream = fetchFromGitHub {
    owner = "marty1885";
    repo = "ttWKV7";
    rev = revision;
    inherit hash;
  };
}
