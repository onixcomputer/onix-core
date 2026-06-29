{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:
let
  version = "1.9.2";
  releaseTag = "v${version}";
  releaseBaseUrl = "https://github.com/tenstorrent/ttsim/releases/download/${releaseTag}";
  executableMode = "0755";
  libraryMode = "0644";

  assets = [
    {
      name = "libttsim_bh.so";
      hash = "sha256-Y8kLMIHrirZAJCBCABYNxDp8OHj7T1Dn/wNzIZnp49U=";
      executable = false;
    }
    {
      name = "libttsim_bh_x2.so";
      hash = "sha256-4Q3wpCCazxQ1oIjOlFaDuZg2iqvZxNug6YXCexY4OeQ=";
      executable = false;
    }
    {
      name = "libttsim_bh_x32.so";
      hash = "sha256-USk4GpCf1Zy95jn0KEDkZ08DyEvWe05Mm781xIjBaxM=";
      executable = false;
    }
    {
      name = "libttsim_qsr.so";
      hash = "sha256-PpJzWFB4/6YBSKc1LUpjkcNigiJp5uP3YLRccj2NOYo=";
      executable = false;
    }
    {
      name = "libttsim_wh.so";
      hash = "sha256-Qgh3wkwdD+cpEJbzW0ORRAOuUjwWReph+VAuXHluiPA=";
      executable = false;
    }
    {
      name = "libttsim_wh_x2.so";
      hash = "sha256-/nRil/amdwXs9qpS2083b0bsTorkqRbWg+7en45sjwc=";
      executable = false;
    }
    {
      name = "libttsim_wh_x32.so";
      hash = "sha256-fydp5CWv9yDm8U8+es6t2nQR22gjgeaRhpaevSEpNI0=";
      executable = false;
    }
    {
      name = "libttsim_wh_x8.so";
      hash = "sha256-C6D+9iW9UUIuTcz4rpwsz2c0XbuG9cBg1Uw1e5+e3ec=";
      executable = false;
    }
    {
      name = "ttsim";
      hash = "sha256-aBWKUPcCzQP7BztPFhSSSXKe2QkC+re6k2MJbQGwAkw=";
      executable = true;
    }
  ];

  fetchAsset =
    asset:
    asset
    // {
      src = fetchurl {
        url = "${releaseBaseUrl}/${asset.name}";
        inherit (asset) hash;
      };
    };
  fetchedAssets = map fetchAsset assets;

  installAsset =
    asset:
    if asset.executable then
      ''
        install -m ${executableMode} ${asset.src} $out/bin/${asset.name}
      ''
    else
      ''
        install -m ${libraryMode} ${asset.src} $out/lib/ttsim/${asset.name}
      '';
in
stdenv.mkDerivation {
  pname = "ttsim";
  inherit version;

  dontUnpack = true;

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall

    install -d $out/bin $out/lib $out/lib/ttsim
    ${lib.concatMapStringsSep "\n" installAsset fetchedAssets}

    for simulator in $out/lib/ttsim/*.so; do
      ln -s "$simulator" "$out/lib/$(basename "$simulator")"
    done

    runHook postInstall
  '';

  meta = {
    description = "Fast full-system simulator of Tenstorrent hardware";
    homepage = "https://github.com/tenstorrent/ttsim";
    license = lib.licenses.asl20;
    mainProgram = "ttsim";
    platforms = [ "x86_64-linux" ];
  };
}
