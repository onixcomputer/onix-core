{
  lib,
  python3,
  nix-eval-jobs,
  makeWrapper,
}:

python3.pkgs.buildPythonApplication {
  pname = "nix-eval-warnings";
  version = "0.1.0";

  src = ./.;

  pyproject = true;

  build-system = [ python3.pkgs.hatchling ];

  nativeBuildInputs = [ makeWrapper ];

  # Tests not vendored
  doCheck = false;

  postFixup = ''
    wrapProgram $out/bin/nix-eval-warnings \
      --prefix PATH : ${lib.makeBinPath [ nix-eval-jobs ]}
  '';

  meta = {
    description = "Tool to extract nix evaluation warnings with stack traces";
    mainProgram = "nix-eval-warnings";
    license = lib.licenses.mit;
  };
}
