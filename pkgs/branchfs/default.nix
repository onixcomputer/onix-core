{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage (_finalAttrs: {
  pname = "branchfs";
  version = "0-unstable-2026-03-05";

  src = fetchFromGitHub {
    owner = "multikernel";
    repo = "branchfs";
    rev = "aaa7ed706ece6719ba406f139372d905f344f3e3";
    hash = "sha256-l/snlg+QFOfnF3/FvOYglwe614PnT7izpa68xY5WC/A=";
  };

  cargoHash = "sha256-H+sS7Wes3zNZOzFhjGMuV6ktws4Vt6TFq8u7fTxR++U=";

  meta = {
    description = "BranchFS is a FUSE-based filesystem that provides lightweight, atomic speculative branching on top of any existing filesystem";
    homepage = "https://github.com/multikernel/branchfs";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "branchfs";
  };
})
