{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  cmake,
  ninja,
  python3,
  dbus,
  openssl,
}:
let
  meshVersion = "0.72.2";
  pluginVersion = "0.1.2";

  releaseTargets = {
    x86_64-linux = "x86_64-unknown-linux-gnu";
    aarch64-linux = "aarch64-unknown-linux-gnu";
  };

  releaseTarget =
    releaseTargets.${stdenv.hostPlatform.system}
      or (throw "mesh-llm: unsupported platform ${stdenv.hostPlatform.system}");

  meshSource = fetchFromGitHub {
    owner = "Mesh-LLM";
    repo = "mesh-llm";
    rev = "v${meshVersion}";
    hash = "sha256-9PJhO15NKU3Cd2sDKMUlr7by2BXs4S8s0o8pteS1xf4=";
  };

  llamaRevision = "86b94708f22478f900b76ca02e316f4f3418faff";
  llamaSource = fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    rev = llamaRevision;
    hash = "sha256-GHMmGHPphkbAWh82xmo96DbQh/1vIzzbkBsRF/bIr5Y=";
  };
  llamaPatchNames = [
    "0001-Add-Skippy-ABI-and-package-writer-foundation.patch"
    "0002-Add-early-staged-model-family-and-chat-support.patch"
    "0003-Add-staged-sampling-checkpoints-and-part-loading.patch"
    "0004-Add-lanes-external-media-and-chat-grammar-support.patch"
    "0005-Add-resident-prefix-cache-and-session-refinements.patch"
    "0006-Expand-staged-execution-across-dense-and-recurrent-f.patch"
    "0007-Expand-staged-execution-across-VL-and-broad-model-fa.patch"
    "0008-Add-external-decode-media-prefill-and-newer-family-s.patch"
    "0009-Add-chat-grammar-device-enumeration-and-runtime-even.patch"
    "0010-Add-MTP-execution-support-and-sampling-cleanup.patch"
  ];
  patchedLlama = stdenv.mkDerivation {
    pname = "mesh-llm-patched-llama";
    version = llamaRevision;
    src = llamaSource;

    patches = map (name: "${meshSource}/third_party/llama.cpp/patches/${name}") llamaPatchNames;
    nativeBuildInputs = [
      cmake
      ninja
    ];

    cmakeFlags = [
      (lib.cmakeBool "BUILD_SHARED_LIBS" false)
      (lib.cmakeBool "GGML_NATIVE" false)
      (lib.cmakeBool "LLAMA_BUILD_EXAMPLES" false)
      (lib.cmakeBool "LLAMA_BUILD_SERVER" false)
      (lib.cmakeBool "LLAMA_BUILD_TESTS" false)
      (lib.cmakeBool "LLAMA_CURL" false)
      (lib.cmakeBool "CMAKE_POSITION_INDEPENDENT_CODE" true)
    ];

    buildPhase = ''
      runHook preBuild
      cmake --build . --parallel "$NIX_BUILD_CORES" --target llama llama-common mtmd
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      find . -type f -name '*.a' -exec cp --parents '{}' "$out" ';'
      install -Dm644 CMakeCache.txt "$out/CMakeCache.txt"
      runHook postInstall
    '';
  };

  meshBinary = rustPlatform.buildRustPackage {
    pname = "mesh-llm";
    version = meshVersion;
    src = meshSource;

    # Upstream accepts invite tokens in argv. This patch adds a file-backed path.
    patches = [ ../../patches/mesh-llm-join-file.patch ];
    cargoHash = "sha256-yQlt4F4T+UVsPJskcvVsf0bSHLsj2RuE4LKE4RybaFU=";

    nativeBuildInputs = [
      pkg-config
      python3
    ];
    buildInputs = [
      dbus
      openssl
    ];

    LLAMA_STAGE_BUILD_DIR = patchedLlama;
    SKIPPY_LLAMA_AUTO_BUILD = "0";

    cargoBuildFlags = [
      "-p"
      "mesh-llm"
      "--no-default-features"
    ];

    checkPhase = ''
      runHook preCheck
      cargo test --offline -p mesh-llm-cli join_file
      cargo test --offline -p mesh-llm --no-default-features join_token_file
      runHook postCheck
    '';
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

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/share/mesh-llm/plugins/openai-endpoint"
    install -m755 ${meshBinary}/bin/mesh-llm "$out/bin/mesh-llm"
    install -m755 ${openaiEndpoint}/bin/openai-endpoint "$out/bin/openai-endpoint"
    install -m644 ${openaiEndpoint}/share/openai-endpoint/plugin.toml "$out/share/mesh-llm/plugins/openai-endpoint/plugin.toml"

    runHook postInstall
  '';

  passthru = {
    inherit
      llamaRevision
      meshBinary
      openaiEndpoint
      patchedLlama
      pluginVersion
      releaseTarget
      ;
  };

  meta = {
    description = "Private mesh gateway with file-based join credentials and a local OpenAI endpoint";
    homepage = "https://github.com/Mesh-LLM/mesh-llm";
    license = lib.licenses.asl20;
    mainProgram = "mesh-llm";
    platforms = builtins.attrNames releaseTargets;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
}
