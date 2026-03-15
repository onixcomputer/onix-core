{
  lib,
  python3,
}:

python3.pkgs.buildPythonApplication {
  pname = "buildbot-pr-check";
  version = "0.1.0";

  src = ./.;

  pyproject = true;

  build-system = [ python3.pkgs.hatchling ];

  # No runtime dependencies, only stdlib

  nativeCheckInputs = with python3.pkgs; [
    pytest
    vcrpy
    pytest-vcr
  ];

  checkPhase = ''
    runHook preCheck
    pytest tests/
    runHook postCheck
  '';

  # Skip tests by default — cassettes are recorded against external buildbot instances
  doCheck = false;

  meta = {
    description = "Check Buildbot CI status for GitHub and Gitea pull requests";
    mainProgram = "buildbot-pr-check";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
