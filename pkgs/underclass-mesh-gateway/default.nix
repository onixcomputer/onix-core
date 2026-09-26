{
  lib,
  python3,
  stdenvNoCC,
  makeWrapper,
}:
stdenvNoCC.mkDerivation {
  pname = "underclass-mesh-gateway";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./gateway.py
      ./test_gateway.py
    ];
  };

  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [ (python3.withPackages (ps: [ ps.pytest ])) ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    python3 -B -m pytest -q -p no:cacheprovider test_gateway.py
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 gateway.py "$out/libexec/underclass-mesh-gateway/gateway.py"
    makeWrapper ${python3.interpreter} "$out/bin/underclass-mesh-gateway" \
      --add-flags "-I -B $out/libexec/underclass-mesh-gateway/gateway.py"
    runHook postInstall
  '';

  meta = {
    description = "Loopback chat-completions gateway exposing an Underclass Codex pool to Mesh-LLM";
    license = lib.licenses.asl20;
    mainProgram = "underclass-mesh-gateway";
    platforms = lib.platforms.linux;
  };
}
