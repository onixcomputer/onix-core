{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  openssl,
}:
let
  meshVersion = "0.72.2";
  pluginVersion = "0.1.2";
  target = "x86_64-unknown-linux-gnu";

  meshArchive = fetchurl {
    url = "https://github.com/Mesh-LLM/mesh-llm/releases/download/v${meshVersion}/mesh-llm-${target}.tar.gz";
    hash = "sha256-SyTMvqzpbNr7dNzhWbwa6heHlSWY6Mej006SWN69t1Y=";
  };

  pluginArchive = fetchurl {
    url = "https://github.com/Mesh-LLM/openai-endpoint/releases/download/${pluginVersion}/openai-endpoint-${pluginVersion}-${target}.tar.gz";
    hash = "sha256-xKoS5dcFSz+jhZpaBjemK385BRHG80hGKEtt3jb92RA=";
  };
in
stdenv.mkDerivation {
  pname = "mesh-llm";
  version = meshVersion;

  dontUnpack = true;

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    openssl
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/share/mesh-llm/plugins/openai-endpoint"

    tar -xzf ${meshArchive}
    install -m755 mesh-bundle/mesh-llm "$out/bin/mesh-llm"

    tar -xzf ${pluginArchive}
    install -m755 openai-endpoint/openai-endpoint "$out/bin/openai-endpoint"
    install -m644 openai-endpoint/plugin.toml "$out/share/mesh-llm/plugins/openai-endpoint/plugin.toml"

    runHook postInstall
  '';

  passthru = {
    inherit pluginVersion;
  };

  meta = {
    description = "Private mesh gateway for local OpenAI-compatible inference endpoints";
    homepage = "https://github.com/Mesh-LLM/mesh-llm";
    license = lib.licenses.asl20;
    mainProgram = "mesh-llm";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
