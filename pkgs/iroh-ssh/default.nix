{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
}:

rustPlatform.buildRustPackage rec {
  pname = "iroh-ssh";
  version = "0.2.9";

  src = fetchFromGitHub {
    owner = "rustonbsd";
    repo = "iroh-ssh";
    rev = version;
    hash = "sha256-0G2RZbxyxi96FpVPEamfcTrOgPxpFYHmyYg1kQfo7TQ=";
  };

  cargoHash = "sha256-2/hc1K6zUyQlWorZh34HP9PCdV4YD1ob9l1DFiW7c1Y=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [ openssl ];

  meta = with lib; {
    description = "SSH server and client built on Iroh networking";
    homepage = "https://github.com/rustonbsd/iroh-ssh";
    license = with licenses; [
      mit
      asl20
    ];
    mainProgram = "iroh-ssh";
  };
}
