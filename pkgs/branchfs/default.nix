{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  fuse,
}:

rustPlatform.buildRustPackage (_finalAttrs: {
  pname = "branchfs";
  version = "0-unstable-2026-03-29";

  src = fetchFromGitHub {
    owner = "multikernel";
    repo = "branchfs";
    rev = "d7f672f370c759cf3eba914fd21cc2d764950d7a";
    hash = "sha256-+NNNtcoB0IUe0JJ5XpP/grk/LanRMeoxBOQTB0bWyq4=";
  };

  cargoHash = "sha256-pI2A1++ASaURF+edAhcWPNBaEAOrHmgCYOdMSEwDYD8=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ fuse ];

  meta = {
    description = "BranchFS is a FUSE-based filesystem that provides lightweight, atomic speculative branching on top of any existing filesystem";
    homepage = "https://github.com/multikernel/branchfs";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "branchfs";
    platforms = lib.platforms.linux;
  };
})
