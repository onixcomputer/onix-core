{
  buildPythonApplication,
  hatchling,
}:

buildPythonApplication {
  pname = "claude-md";
  version = "0.1.0";
  src = ./.;
  pyproject = true;

  build-system = [ hatchling ];

  meta = {
    description = "Centralize Claude Code configuration (projects, skills, commands) across repositories";
    mainProgram = "claude-md";
  };
}
