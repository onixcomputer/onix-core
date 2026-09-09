{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  wayland,
}:

# ssh-clipboard: native, encrypted clipboard sync over direct peer-to-peer SSH.
# Distributed upstream as an npm package wrapping prebuilt Rust binaries; here
# we build the same Rust source reproducibly so the flake owns the binary.
rustPlatform.buildRustPackage rec {
  pname = "ssh-clipboard";
  version = "0.2.11";

  src = fetchFromGitHub {
    owner = "standardagents";
    repo = "ssh-clipboard";
    rev = "677dd65f88a3b39b56b6e2236d7b040d17d96fe8";
    hash = "sha256-iXfEk9oir4OlKWGUZAH/czGn+A1kO/1+v3rOaEKwLxM=";
  };

  cargoHash = "sha256-Oq5Wbs62+Zolp7ZpQb0LhWIdQGbQE1IWGNZuETHVRM4=";

  nativeBuildInputs = [ pkg-config ];
  # The Linux clipboard backend is Wayland-only (Cargo.toml sets
  # default-features = false with the wayland feature), so it links libwayland.
  buildInputs = lib.optionals stdenv.isLinux [ wayland ];

  # The daemon/tests that probe a live system clipboard are exercised at
  # runtime; avoid flaky in-build graphical checks.
  doCheck = false;

  meta = {
    description = "Native, encrypted clipboard sync over SSH";
    homepage = "https://github.com/standardagents/ssh-clipboard";
    license = lib.licenses.mit;
    mainProgram = "ssh-clipboard";
    platforms = lib.platforms.unix;
  };
}
