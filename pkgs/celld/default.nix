{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  gzip,
  stdenv,
}:
let
  sources = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-gnu";
      hash = "sha256-y/z6X211UbUxb29MnXdRx0GpuiojBd3o1ctNGzf7NKY=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-iKNQcBRECPkCA2B2t/iN84VIzk3aBz//J6bdH20rrig=";
    };
  };
  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "celld: unsupported platform ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "celld";
  version = "0.3.0";

  src = fetchurl {
    url = "https://github.com/denoland/celld/releases/download/v${finalAttrs.version}/celld-${source.target}.gz";
    inherit (source) hash;
  };

  licenseFile = fetchurl {
    url = "https://raw.githubusercontent.com/denoland/celld/v${finalAttrs.version}/LICENSE";
    hash = "sha256-z8d0m5b2O9McPEK1xHG/dWgUBT6EfBDz6wA0F7xSPTA=";
  };

  dontUnpack = true;
  strictDeps = true;

  nativeBuildInputs = [
    autoPatchelfHook
    gzip
  ];

  buildInputs = [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall

    install -d "$out/bin" "$out/share/licenses/celld"
    gzip -dc "$src" > "$out/bin/celld"
    chmod 0555 "$out/bin/celld"
    install -m 0444 "$licenseFile" "$out/share/licenses/celld/LICENSE"

    runHook postInstall
  '';

  meta = {
    description = "Self-hosted distributed Durable Objects runtime";
    homepage = "https://celld.dev";
    changelog = "https://github.com/denoland/celld/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "celld";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
