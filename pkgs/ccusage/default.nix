{
  writeShellApplication,
  nodejs,
}:

writeShellApplication {
  name = "ccusage";
  runtimeInputs = [ nodejs ];
  text = ''
    exec npx ccusage@latest "$@"
  '';
}
