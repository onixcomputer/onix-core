{
  lib,
  stdenv,
  fetchurl,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  autoPatchelfHook,
  openssl,
}:
let
  meshVersion = "0.72.2";
  pluginVersion = "0.1.2";

  releaseArtifacts = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-gnu";
      hash = "sha256-SyTMvqzpbNr7dNzhWbwa6heHlSWY6Mej006SWN69t1Y=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-fTFBhw/BrES+L2whY+r+3IgHyPSETsDUjo4BuMQrTrI=";
    };
  };

  releaseArtifact =
    releaseArtifacts.${stdenv.hostPlatform.system}
      or (throw "mesh-llm: unsupported platform ${stdenv.hostPlatform.system}");

  meshArchive = fetchurl {
    url = "https://github.com/Mesh-LLM/mesh-llm/releases/download/v${meshVersion}/mesh-llm-${releaseArtifact.target}.tar.gz";
    inherit (releaseArtifact) hash;
  };

  openaiEndpointSource = fetchFromGitHub {
    owner = "Mesh-LLM";
    repo = "openai-endpoint";
    rev = pluginVersion;
    hash = "sha256-GWNI98iDOU4oyO4nEXiXLx+aEnXbURp1Zj+k/Wka7cE=";
  };

  openaiEndpoint = rustPlatform.buildRustPackage {
    pname = "openai-endpoint";
    version = pluginVersion;
    src = openaiEndpointSource;

    cargoHash = "sha256-KCNv9oI7+CvvV7AXHaM2ZRdSiztSlNCDkqA0Avmu77Y=";

    nativeBuildInputs = [ pkg-config ];
    buildInputs = [ openssl ];

    doCheck = false;

    postInstall = ''
      install -Dm644 plugin.toml "$out/share/openai-endpoint/plugin.toml"
    '';
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
    install -m755 ${openaiEndpoint}/bin/openai-endpoint "$out/bin/openai-endpoint"
    install -m644 ${openaiEndpoint}/share/openai-endpoint/plugin.toml "$out/share/mesh-llm/plugins/openai-endpoint/plugin.toml"

    runHook postInstall
  '';

  passthru = {
    inherit openaiEndpoint pluginVersion;
    releaseTarget = releaseArtifact.target;
  };

  meta = {
    description = "Private mesh gateway for local OpenAI-compatible inference endpoints";
    homepage = "https://github.com/Mesh-LLM/mesh-llm";
    license = lib.licenses.asl20;
    mainProgram = "mesh-llm";
    platforms = builtins.attrNames releaseArtifacts;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
