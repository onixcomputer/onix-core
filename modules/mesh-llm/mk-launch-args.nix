{ lib }:
{
  package,
  settings,
  configPath,
  nodeName,
  meshBindAddress ? settings.meshBindAddress,
  # Invite token files in join order; mesh-llm tries them in turn at startup
  # and re-dials every one of them each minute afterwards.
  joinTokenFiles ? [ ],
}:
[
  "${package}/bin/mesh-llm"
  "--config"
  configPath
  "--model"
  settings.proxyActivationModel
  "--ctx-size"
  (toString settings.proxyActivationContextSize)
  "--headless"
  "--mesh-discovery-mode"
  "mdns"
  "--bind-ip"
  meshBindAddress
  "--bind-port"
  (toString settings.meshPort)
  "--port"
  (toString settings.apiPort)
  "--console"
  (toString settings.consolePort)
  "--mesh-name"
  settings.meshName
  "--name"
  nodeName
  "--log-format"
  "json"
]
++ lib.concatMap (file: [
  "--join-file"
  file
]) joinTokenFiles
