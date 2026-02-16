{
  lib,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "iroh-ssh";
  version = "0.2.8";

  src = fetchFromGitHub {
    owner = "rustonbsd";
    repo = "iroh-ssh";
    tag = finalAttrs.version;
    hash = "sha256-jKJ0dathwsFif2N/X4CnMAG74h0h/5hnuWWwbJrbU18=";
  };

  cargoHash = "sha256-KZu4HA5E9R4sdBW5cdhyA5E2bo2YN2TPSKDlJuzDGnU=";

  nativeBuildInputs = [
    installShellFiles
  ];

  meta = {
    description = "SSH to any machine without public IP, port forwarding, or VPN";
    homepage = "https://github.com/rustonbsd/iroh-ssh";
    license = lib.licenses.mit;
    mainProgram = "iroh-ssh";
  };
})
