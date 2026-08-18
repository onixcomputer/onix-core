{
  lib,
  stdenv,
  stdenvNoCC,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs,
  uv,
  autoPatchelfHook,
}:

let
  version = "0.7.0";

  releaseTarball = fetchurl {
    url = "https://github.com/PrimeIntellect-ai/prime-agent/releases/download/v${version}/prime-agent-${version}.tgz";
    hash = "sha256-iLZXhRjHLNUaglvIDyjg/vmmTGfeSn1v16/Xyhs02gs=";
  };

  releaseSource = stdenvNoCC.mkDerivation {
    pname = "prime-agent-release-source";
    inherit version;
    src = releaseTarball;
    sourceRoot = "package";
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r . $out/
      cp ${./package-lock.json} $out/package-lock.json

      runHook postInstall
    '';
  };

  releaseInstall = buildNpmPackage {
    pname = "prime-agent-release";
    inherit version;
    src = releaseSource;
    npmDepsHash = "sha256-E/ZXdxQBixnayrrnYKFfwCbaGUrQGs5PZVg/DSMZ03s=";
    npmFlags = [
      "--ignore-scripts"
      "--legacy-peer-deps"
    ];
    dontNpmBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/node_modules/prime-agent
      cp -r . $out/lib/node_modules/prime-agent/

      runHook postInstall
    '';
  };
in
stdenv.mkDerivation {
  pname = "prime-agent";
  inherit version;

  dontUnpack = true;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];
  autoPatchelfIgnoreMissingDeps = [
    "libc++.so.9.0"
    "libc++abi.so.6.0"
    "libc.musl-x86_64.so.1"
    "libm.so.10.1"
    "libpthread.so.26.1"
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp -r ${releaseInstall}/. $out/
    chmod -R u+w $out

    makeWrapper ${nodejs}/bin/node $out/bin/prime-agent \
      --add-flags "$out/lib/node_modules/prime-agent/dist/bundle/cli.js" \
      --set PI_PACKAGE_DIR "$out/lib/node_modules/prime-agent" \
      --prefix PATH : ${lib.makeBinPath [ uv ]}

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    versionOutput="$($out/bin/prime-agent --version 2>&1)"
    if [ "$versionOutput" != "${version}" ]; then
      echo "positive: expected ${version}, got $versionOutput" >&2
      exit 1
    fi

    if $out/bin/prime-agent -z >/dev/null 2>&1; then
      echo "negative: prime-agent must reject an unknown option" >&2
      exit 1
    fi

    runHook postInstallCheck
  '';

  meta = {
    description = "Coding and research agent with a persistent Python control environment";
    homepage = "https://github.com/PrimeIntellect-ai/prime-agent";
    license = lib.licenses.mit;
    mainProgram = "prime-agent";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
