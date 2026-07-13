{ lib }:
{
  package,
  settings,
  configPath,
  nodeName,
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
  settings.meshBindAddress
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
++ lib.optionals (settings.mode == "joiner") [ "--join" ]
