{
  lib,
  rustPlatform,
  pkg-config,
  git,
  openssl,
  sqlite,
}:
rustPlatform.buildRustPackage {
  pname = "radicle-ci-runner";
  version = "0.1.0";
  src = ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
      "bounded-exec-0.1.0" = "sha256-BVmqyUYyoNpY6LfOABxwPO3DY88ZtXeKNg3TPoGCcL0=";
      "bounded-exec-core-0.1.0" = "sha256-BVmqyUYyoNpY6LfOABxwPO3DY88ZtXeKNg3TPoGCcL0=";
    };
  };

  nativeBuildInputs = [
    git
    pkg-config
  ];
  buildInputs = [
    openssl
    sqlite
  ];

  strictDeps = true;
  doCheck = true;

  meta = {
    description = "Least-authority exact-object Radicle CI scanner, runner, and status publisher";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "radicle-ci-runner";
    platforms = lib.platforms.linux;
  };
}
