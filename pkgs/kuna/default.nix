{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  gcc-unwrapped,
  makeWrapper,
}:

let
  version = "1.10";

  sources = {
    x86_64-linux = {
      releaseName = "kuna-v${version}-linux-x86_64";
      hash = "sha256-EtLWl8dN8xSuvbk9g+KDnSs8LV1pZjRWmIeHptOOgyM=";
    };
    aarch64-darwin = {
      releaseName = "kuna-v${version}-macos-arm64";
      hash = "sha256-XAq/gcUmgQizwNzPntLHKOospLcicsqxJ1IFxbUcmU4=";
    };
    x86_64-darwin = {
      releaseName = "kuna-v${version}-macos-x86_64";
      hash = "sha256-8Hb3TDwURjV2++Aj3w7vXCPc4AIagkOB5XJkWz/h93o=";
    };
  };

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  specs = fetchurl {
    url = "https://github.com/Noelo-Lab/kuna/releases/download/v${version}/kuna-v${version}-specs.tar.gz";
    hash = "sha256-+xDK1oMpOIiLDxx3IM5iXEfWFRg8cWuqUdLgfxGKQb4=";
  };
in
stdenv.mkDerivation {
  pname = "kuna";
  inherit version specs;

  src = fetchurl {
    url = "https://github.com/Noelo-Lab/kuna/releases/download/v${version}/${source.releaseName}.tar.gz";
    inherit (source) hash;
  };

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ gcc-unwrapped.lib ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 ${source.releaseName}/kuna $out/bin/kuna
    install -Dm755 ${source.releaseName}/decomp_dbg $out/bin/decomp_dbg
    install -Dm755 ${source.releaseName}/slacomp $out/bin/slacomp
    install -Dm644 ${source.releaseName}/LICENSE $out/share/licenses/kuna/LICENSE
    install -Dm644 ${source.releaseName}/NOTICE $out/share/licenses/kuna/NOTICE

    mkdir -p $out/share/kuna
    tar -xzf $specs -C $out/share/kuna

    wrapProgram $out/bin/kuna --set-default KUNA_SPECS $out/share/kuna/specs
    wrapProgram $out/bin/decomp_dbg --set-default KUNA_SPECS $out/share/kuna/specs

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    versionOutput="$($out/bin/kuna --version)"
    if [ "$versionOutput" != "kuna ${version}" ]; then
      echo "positive: expected kuna ${version}, got $versionOutput" >&2
      exit 1
    fi

    if $out/bin/kuna invalid-subcommand >/dev/null 2>&1; then
      echo "negative: kuna must reject an invalid subcommand" >&2
      exit 1
    fi

    runHook postInstallCheck
  '';

  meta = {
    description = "Agent-first decompiler with tunable analysis phases";
    homepage = "https://github.com/Noelo-Lab/kuna";
    license = lib.licenses.asl20;
    mainProgram = "kuna";
    platforms = builtins.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
