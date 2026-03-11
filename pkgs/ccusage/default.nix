{
  writeShellScriptBin,
  nodejs,
}:

writeShellScriptBin "ccusage" ''
  export PATH="${nodejs}/bin:$PATH"
  exec ${nodejs}/bin/npx ccusage@latest "$@"
''
