{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  gcc-unwrapped,
}:

let
  version = "1.3.0";

  sources = {
    x86_64-linux = {
      url = "https://github.com/bearcove/tracey/releases/download/v${version}/tracey-x86_64-unknown-linux-gnu.tar.xz";
      hash = "sha256-+8DCXEQyjMsJcLJQkJX/KUEvpyy7xrADbEzujBKCH0c=";
    };
    aarch64-linux = {
      url = "https://github.com/bearcove/tracey/releases/download/v${version}/tracey-aarch64-unknown-linux-gnu.tar.xz";
      hash = "sha256-fmTjbT1LXr0j5tv8sWDCitgacZBkGdM2u+uOFG6CYGQ=";
    };
    aarch64-darwin = {
      url = "https://github.com/bearcove/tracey/releases/download/v${version}/tracey-aarch64-apple-darwin.tar.xz";
      hash = "sha256-NltLMFbFiZAVJrVEAbI2NEMKkl/LEyf1zW9TVoY7INU=";
    };
  };

  src =
    fetchurl
      sources.${stdenv.hostPlatform.system}
        or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "tracey";
  inherit version src;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ gcc-unwrapped.lib ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 tracey-*/tracey $out/bin/tracey
    runHook postInstall
  '';

  meta = {
    description = "CLI, Web, LSP, and MCP toolkit to measure spec coverage in codebases";
    homepage = "https://github.com/bearcove/tracey";
    license = with lib.licenses; [
      mit
      asl20
    ];
    platforms = builtins.attrNames sources;
    mainProgram = "tracey";
  };
}
