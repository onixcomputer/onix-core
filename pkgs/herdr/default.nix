{
  lib,
  bash,
  docker-client,
  fetchFromGitHub,
  ghzinga,
  git,
  herdr,
  jq,
  jujutsu,
  openssh,
  pkg-config,
  pueue,
  pkgs,
  runCommand,
  rustPlatform,
  socat,
  wrapperLib,
  zlib,
}:
let
  executableMode = "0755";
  regularFileMode = "0644";
  staticRegistryMode = "0444";

  mkRustBinary =
    {
      pname,
      version,
      src,
      cargoHash,
      cargoBuildFlags ? [ ],
      cargoTestFlags ? [ ],
      doCheck ? false,
      postPatch ? "",
      nativeBuildInputs ? [ ],
      buildInputs ? [ ],
    }:
    rustPlatform.buildRustPackage {
      inherit
        pname
        version
        src
        cargoHash
        cargoBuildFlags
        cargoTestFlags
        doCheck
        postPatch
        nativeBuildInputs
        buildInputs
        ;
    };

  fileViewerSource = fetchFromGitHub {
    owner = "smarzban";
    repo = "herdr-file-viewer";
    rev = "96fcc0a2bdd2727ec88c38f8c8806f97b7ca0ea0";
    hash = "sha256-QJM/w1m7j8B433/klHRCRbJKL51/5tkyp7swm0xG3zE=";
  };
  fileViewerBinary = mkRustBinary {
    pname = "herdr-file-viewer";
    version = "1.14.0";
    src = fileViewerSource;
    cargoHash = "sha256-ZzGvgemjSKUBFr1I6tzgtKopNVQyOsregU51PrV3/rY=";
    postPatch = ''
      substituteInPlace Cargo.toml \
        --replace-fail 'rust-version = "1.96"' 'rust-version = "1.95"'
    '';
  };
  fileViewerPlugin = runCommand "herdr-file-viewer-plugin" { } ''
    install -Dm${regularFileMode} ${fileViewerSource}/herdr-plugin.toml $out/herdr-plugin.toml
    cp -R ${fileViewerSource}/scripts $out/scripts
    install -Dm${executableMode} ${fileViewerBinary}/bin/herdr-file-viewer \
      $out/target/release/herdr-file-viewer
  '';

  reviewrSource = fetchFromGitHub {
    owner = "persiyanov";
    repo = "herdr-reviewr";
    rev = "1068100ec5553f51f7527f60fb08055d7f2fd29e";
    hash = "sha256-t9s1adYL8X8F3NesoTnzJ6QQ2CN/do8COwAZkiksD50=";
  };
  reviewrBinary = mkRustBinary {
    pname = "herdr-reviewr";
    version = "0.26.2";
    src = reviewrSource;
    cargoHash = "sha256-la8/mLaMo663EV9i2+rTe8NSoweS+Wc42xg9yQG4yQ0=";
    postPatch = ''
      substituteInPlace Cargo.toml \
        --replace-fail 'rust-version = "1.97"' 'rust-version = "1.95"'
    '';
    nativeBuildInputs = [ pkg-config ];
    buildInputs = [ zlib ];
  };
  reviewrPlugin = runCommand "herdr-reviewr-plugin" { } ''
    install -Dm${regularFileMode} ${reviewrSource}/herdr-plugin.toml $out/herdr-plugin.toml
    install -Dm${executableMode} ${reviewrSource}/herdr/sidebar.sh $out/herdr/sidebar.sh
    install -Dm${executableMode} ${reviewrBinary}/bin/herdr-reviewr $out/bin/herdr-reviewr
  '';

  vimNavigationSource = fetchFromGitHub {
    owner = "paulbkim-dev";
    repo = "vim-herdr-navigation";
    rev = "548607d0e417fdb30966846fce7436aa05a6738d";
    hash = "sha256-4lFrDzbdZiCIHIdkJ9q2lMlo+RCsu9eBXjK58VEuhDE=";
  };
  vimNavigationPlugin = runCommand "vim-herdr-navigation-plugin" { } ''
    install -Dm${regularFileMode} ${vimNavigationSource}/herdr-plugin.toml $out/herdr-plugin.toml
    install -Dm${executableMode} ${vimNavigationSource}/navigate.sh $out/navigate.sh
  '';

  ghzingaSource = fetchFromGitHub {
    owner = "osolmaz";
    repo = "ghzinga";
    rev = "30cf4ac79c69140cdac1c8bcf7caa54be34f361b";
    hash = "sha256-siIpLSaGUvYJIDx6jjYq7A8lh2bnBzfcBeF+2AzV3E4=";
  };
  ghzingaPlugin = runCommand "ghzinga-herdr-plugin" { } ''
    install -Dm${regularFileMode} ${ghzingaSource}/plugins/herdr/herdr-plugin.toml $out/herdr-plugin.toml
  '';

  mirrorSource = fetchFromGitHub {
    owner = "nikok6";
    repo = "herdr-mirror";
    rev = "8bfc7cfca617ab92b068f8ef21b48c3bed807918";
    hash = "sha256-Ch6S6TndNMBDuM4UMqi9jle7AVidXSL/aXUZ+UzTK/k=";
  };
  mirrorBinary = mkRustBinary {
    pname = "herdr-mirror";
    version = "0.1.14";
    src = mirrorSource;
    cargoHash = "sha256-HnCyKBP2E2SWWAtO3aXSX86zOdMslxT9x2EVOt6BEL8=";
  };
  mirrorPlugin = runCommand "herdr-mirror-plugin" { } ''
    install -Dm${regularFileMode} ${mirrorSource}/herdr-plugin.toml $out/herdr-plugin.toml
    install -Dm${executableMode} ${mirrorBinary}/bin/herdr-mirror $out/target/release/herdr-mirror
  '';

  jjWorkspaceSource = fetchFromGitHub {
    owner = "NathanFlurry";
    repo = "herdr-plugin-jj-workspace";
    rev = "a9f1d3bcdaa2354e336a5173da85cbe4970c0f2e";
    hash = "sha256-xspdQfcwTEdUwZ0nWAfrdvz5IBVNVyMkmpmpzkUl0LE=";
  };
  jjWorkspaceBinary = mkRustBinary {
    pname = "jj-workspace";
    version = "0.1.0";
    src = jjWorkspaceSource;
    cargoHash = "sha256-DhRLJs6ikN1q6TY+D7ghffvWdwCVMhw9YJL4D7TARt4=";
  };
  jjWorkspacePlugin = runCommand "herdr-jj-workspace-plugin" { } ''
    install -Dm${regularFileMode} ${jjWorkspaceSource}/herdr-plugin.toml $out/herdr-plugin.toml
    install -Dm${executableMode} ${jjWorkspaceBinary}/bin/jj-workspace $out/target/release/jj-workspace
  '';

  pueueSource = lib.cleanSource ./vendor/herdr-plugin-pueue;
  pueueBinary = mkRustBinary {
    pname = "herdr-plugin-pueue";
    version = "0.1.0";
    src = pueueSource;
    cargoHash = "sha256-wmEbQfXdU7Q6j2J5j18TcDtp8IURS195KnIo+Ap4yP8=";
    cargoBuildFlags = [
      "--package"
      "herdr-plugin-pueue"
    ];
    cargoTestFlags = [
      "--workspace"
      "--features"
      "test-fixture"
    ];
    doCheck = true;
  };
  pueuePlugin = runCommand "herdr-pueue-plugin" { } ''
    install -Dm${regularFileMode} ${pueueSource}/herdr-plugin.toml $out/herdr-plugin.toml
    install -Dm${executableMode} ${pueueBinary}/bin/herdr-plugin-pueue \
      $out/target/release/herdr-plugin-pueue
  '';

  # r[impl onix.britton-desktop.herdr.wrapper.registry]
  patchedHerdr = herdr.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./static-plugin-registry.patch ];
    doCheck = true;
    checkPhase = ''
      runHook preCheck
      cargo test persist::plugin_registry::tests
      runHook postCheck
    '';
  });

  # r[impl onix.britton-desktop.herdr.wrapper.plugins]
  pluginRoots = [
    fileViewerPlugin
    reviewrPlugin
    vimNavigationPlugin
    ghzingaPlugin
    mirrorPlugin
    jjWorkspacePlugin
    pueuePlugin
  ];
  pluginSources = [
    {
      source = "smarzban/herdr-file-viewer";
      revision = "96fcc0a2bdd2727ec88c38f8c8806f97b7ca0ea0";
    }
    {
      source = "persiyanov/herdr-reviewr";
      revision = "1068100ec5553f51f7527f60fb08055d7f2fd29e";
    }
    {
      source = "paulbkim-dev/vim-herdr-navigation";
      revision = "548607d0e417fdb30966846fce7436aa05a6738d";
    }
    {
      source = "osolmaz/ghzinga/plugins/herdr";
      revision = "30cf4ac79c69140cdac1c8bcf7caa54be34f361b";
    }
    {
      source = "nikok6/herdr-mirror";
      revision = "8bfc7cfca617ab92b068f8ef21b48c3bed807918";
    }
    {
      source = "NathanFlurry/herdr-plugin-jj-workspace";
      revision = "a9f1d3bcdaa2354e336a5173da85cbe4970c0f2e";
    }
    {
      source = "../herdr-plugin-pueue";
      revision = "29b2ba060297ec15909e06ef1311200c17965cbe";
    }
  ];
  expectedPluginIds = [
    "herdr-file-viewer"
    "persiyanov.reviewr"
    "vim-herdr-navigation"
    "dutifuldev.ghzinga"
    "mirror"
    "nathanflurry.jj-workspace"
    "dev.herdr.pueue"
  ];
  requiredPluginArtifacts = [
    "${fileViewerPlugin}/target/release/herdr-file-viewer"
    "${reviewrPlugin}/bin/herdr-reviewr"
    "${vimNavigationPlugin}/navigate.sh"
    "${ghzingaPlugin}/herdr-plugin.toml"
    "${mirrorPlugin}/target/release/herdr-mirror"
    "${jjWorkspacePlugin}/target/release/jj-workspace"
    "${pueuePlugin}/target/release/herdr-plugin-pueue"
  ];
  expectedPluginIdsJson = builtins.toJSON (builtins.sort builtins.lessThan expectedPluginIds);
  expectedPluginCount = builtins.length expectedPluginIds;
  pluginBundle =
    assert builtins.length pluginRoots == expectedPluginCount;
    runCommand "herdr-static-plugin-registry" { nativeBuildInputs = [ jq ]; } ''
      export HOME="$TMPDIR/home"
      export XDG_CONFIG_HOME="$TMPDIR/config"
      export XDG_STATE_HOME="$TMPDIR/state"
      unset HERDR_CLIENT_SOCKET_PATH HERDR_SESSION HERDR_SOCKET_PATH

      ${lib.concatMapStringsSep "\n" (plugin: ''
        ${patchedHerdr}/bin/herdr plugin link ${lib.escapeShellArg (toString plugin)} >/dev/null
      '') pluginRoots}

      registry="$XDG_CONFIG_HOME/herdr/plugins.json"
      test -f "$registry"
      test "$(${jq}/bin/jq 'length' "$registry")" -eq ${toString expectedPluginCount}
      test "$(${jq}/bin/jq -c '[.[].plugin_id] | sort' "$registry")" = ${lib.escapeShellArg expectedPluginIdsJson}
      ${jq}/bin/jq -e 'all(.[]; .plugin_root | startswith("/nix/store/"))' "$registry" >/dev/null
      install -Dm${staticRegistryMode} "$registry" $out/plugins.json
    '';

  runtimePackages = [
    bash
    docker-client
    ghzinga
    git
    jq
    jujutsu
    openssh
    pueue
    socat
  ];
in
# r[impl onix.britton-desktop.herdr.wrapper.install]
# r[impl onix.britton-desktop.herdr.wrapper.ownership]
wrapperLib.wrapPackage {
  inherit pkgs;
  package = patchedHerdr;
  runtimeInputs = runtimePackages;
  env.HERDR_STATIC_PLUGIN_REGISTRY = "${pluginBundle}/plugins.json";
  filesToPatch = [ ];
  passthru = {
    basePackage = herdr;
    patchedPackage = patchedHerdr;
    inherit
      expectedPluginIds
      pluginBundle
      pluginRoots
      pluginSources
      requiredPluginArtifacts
      runtimePackages
      ;
  };
}
