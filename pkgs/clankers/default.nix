# Clankers — terminal coding agent (CLI binary only).
#
# The clankers workspace has path deps on sibling repos (subwayrat).
# The upstream flake's unit2nix IFD can't resolve cross-repo path deps
# in sandbox. This package builds from source using
# rustPlatform.buildRustPackage with all sources assembled.
#
# The clanker-router binary is built separately by the upstream flake
# (inputs.clankers.packages.${system}.clanker-router) — it has no
# path dep issues since it's a standalone repo.
#
# openspec is skipped (has no git remote, feature is optional).
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
  rustPlatform,
  rustc,
  cargo,
}:
let
  clankersRev = "5a767f656fdbffeee16becebbd6de35b757a1ac9";
  subwayratRev = "d4f7db8d0b6d251f6860b9c216bdb1bc806fefde";

  clankersSource = fetchFromGitHub {
    owner = "brittonr";
    repo = "clankers";
    rev = clankersRev;
    hash = "sha256-L3Ba3IxtbPwZ9oowJ6LOGZq7u1psddnVPMGU8a1MdVg=";
  };

  subwayratSource = fetchFromGitHub {
    owner = "brittonr";
    repo = "subwayrat";
    rev = subwayratRev;
    hash = "sha256-OqX9V0CgoGkZCgfMXt3blJ9J9IJBQI5M6djReFQMLWE=";
  };
in
rustPlatform.buildRustPackage {
  pname = "clankers";
  version = "0.1.0-dev";

  src = clankersSource;

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

  env.AWS_LC_SYS_CMAKE_BUILDER = "1";

  doCheck = false;

  meta = {
    description = "Terminal coding agent in Rust";
    homepage = "https://github.com/brittonr/clankers";
    license = lib.licenses.agpl3Plus;
    mainProgram = "clankers";
  };
}
