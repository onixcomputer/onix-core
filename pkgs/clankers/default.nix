# Clankers — terminal coding agent.
#
# Clankers has path deps on sibling repos (subwayrat, openspec).
# The upstream flake uses unit2nix auto mode which breaks on these
# cross-repo path deps in IFD. This package builds from source
# using rustPlatform.buildRustPackage with all sources assembled.
#
# openspec is skipped (has no git remote, feature is optional).
#
# Requires the rust-overlay overlay for nightly toolchain access.
# Caller must pass `rust-bin` (from rust-overlay).
{
  lib,
  fetchFromGitHub,
  pkg-config,
  clang,
  mold,
  openssl,
  sqlite,
  libgit2,
  libssh2,
  zlib,
  zstd,
  cmake,
  go,
  perl,
  makeWrapper,
  # Caller provides these (rust-overlay applied pkgs)
  rustPlatform,
  rustc,
  cargo,
}:
let
  clankersRev = "5a298beb0452a69e9fa95854d48234f25ef57b33";
  subwayratRev = "66147cb60f8168c9fa71d79cf1b5ae604b6429f1";

  clankersSource = fetchFromGitHub {
    owner = "brittonr";
    repo = "clankers";
    rev = clankersRev;
    hash = "sha256-8Dgtawjri7bkSJDzx/kN4FlnTtQnzfN8/uz6F6j0/zM=";
  };

  subwayratSource = fetchFromGitHub {
    owner = "brittonr";
    repo = "subwayrat";
    rev = subwayratRev;
    hash = "sha256-r16AbcS7TJqZffrrq1v7RoPTuUK/KyHnD74YeNCwjUA=";
  };
in
rustPlatform.buildRustPackage {
  pname = "clankers";
  version = "0.1.0-dev";

  src = clankersSource;

  # Nightly Rust (edition 2024)
  inherit rustc cargo;

  # Place sibling repos where Cargo.toml path deps expect them.
  # openspec has no git remote — provide a stub crate so Cargo can
  # resolve the path dep at manifest parse time, and strip it from
  # clankers-agent's default features so nothing actually compiles it.
  postUnpack = ''
    cp -r ${subwayratSource} subwayrat
    chmod -R u+w subwayrat

    mkdir -p openspec/src
    cat > openspec/Cargo.toml <<'EOF'
    [package]
    name = "openspec"
    version = "0.1.0"
    edition = "2024"
    [dependencies]
    EOF
    echo "" > openspec/src/lib.rs

    # Disable openspec in clankers-agent default features
    substituteInPlace source/crates/clankers-agent/Cargo.toml \
      --replace-fail 'default = ["openspec"]' 'default = []'
  '';

  cargoLock = {
    lockFile = "${clankersSource}/Cargo.lock";
    allowBuiltinFetchGit = true;
  };

  # Skip openspec (no git remote, optional feature)
  buildNoDefaultFeatures = true;
  buildFeatures = [
    "tui-validate"
    "zellij-share"
  ];

  nativeBuildInputs = [
    pkg-config
    clang
    mold
    cmake
    go
    perl
    makeWrapper
  ];

  buildInputs = [
    openssl
    sqlite
    libgit2
    libssh2
    zlib
    zstd
  ];

  # aws-lc-rs needs cmake + go in build environment
  env.AWS_LC_SYS_CMAKE_BUILDER = "1";

  # Integration tests need CARGO_BIN_EXE env vars
  doCheck = false;

  meta = {
    description = "Terminal coding agent in Rust";
    homepage = "https://github.com/brittonr/clankers";
    license = lib.licenses.agpl3Plus;
    mainProgram = "clankers";
  };
}
