{
  python3,
  openssh,
  gitMinimal,
  nixVersions,
  gh,
  tea,
  coreutils,
  nix,
  lib,
  makeWrapper,
  buildbot-pr-check,
}:
let
  runtimeDeps = [
    gitMinimal
    nixVersions.latest
    nix
    coreutils
    gh
    tea
    buildbot-pr-check
  ];
in
python3.pkgs.buildPythonApplication {
  pname = "merge-when-green";
  version = "0.3.0";
  src = ./.;
  format = "other";

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    install -D -m 0755 merge-when-green.py $out/bin/merge-when-green
    wrapProgram $out/bin/merge-when-green \
      --prefix PATH : ${lib.makeBinPath runtimeDeps} --suffix PATH : ${lib.makeBinPath [ openssh ]}
  '';

  meta = {
    description = "Merge a PR when the CI is green (supports GitHub and Gitea)";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
    mainProgram = "merge-when-green";
  };
}
