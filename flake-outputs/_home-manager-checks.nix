# Focused Home Manager and workstation input checks.
{
  self,
  pkgs,
  lib,
  system,
  ...
}:
let
  targetHomeStateVersion = "26.05";
  legacyHomeStateVersion = "25.11";

  desktopConfig = self.nixosConfigurations.britton-desktop.config;
  desktopHome = desktopConfig.home-manager.users.brittonr;
  aspen3Config = self.nixosConfigurations.aspen3.config;
  aspen3Home = aspen3Config.home-manager.users.brittonr;
  aspen1Config = self.nixosConfigurations.aspen1.config;
  aspen1Home = aspen1Config.home-manager.users.brittonr;
  actualHomeStateVersion = desktopHome.home.stateVersion;
  actualSystemStateVersion = desktopConfig.system.stateVersion;
  neovimConfig = desktopHome.programs.neovim;
  cargoConfigSource = desktopHome.home.file.".cargo/config.toml".source;
  minimumPueueHerdrVersion = "0.7.5";
  pueuePopupActionId = "dev.herdr.pueue.open-dashboard";
  pueueSplitActionId = "dev.herdr.pueue.open-dashboard-split";
  pueuePopupKey = "prefix+p";
  pueueSplitKey = "prefix+shift+p";
  invalidPueueActionId = "dev.herdr.pueue.invalid";
  pueuePluginLinkSource = "/home/brittonr/git/herdr-plugin-pueue";
  pueueStatusToken = "$pueue_status";
  pueueFirstRunningToken = "$pueue_running_1";
  pueueSecondRunningToken = "$pueue_running_2";
  unsafePueueEnvironmentToken = "$pueue_env";
  workflowPluginSources = [
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
  workflowPluginBindings = [
    {
      action = "herdr-file-viewer.open-file-viewer";
      key = "prefix+f";
    }
    {
      action = "herdr-file-viewer.open-file-viewer-tab";
      key = "prefix+shift+f";
    }
    {
      action = "persiyanov.reviewr.toggle";
      key = "prefix+shift+e";
    }
    {
      action = "vim-herdr-navigation.left";
      key = "ctrl+h";
    }
    {
      action = "vim-herdr-navigation.down";
      key = "ctrl+j";
    }
    {
      action = "vim-herdr-navigation.up";
      key = "ctrl+k";
    }
    {
      action = "vim-herdr-navigation.right";
      key = "ctrl+l";
    }
  ];
  expectedGhzingaVersion = "0.5.0";
  invalidWorkflowPluginAction = "invalid.workflow-plugin.action";
  cairnPackageName = "cairn";
  invalidCairnPackageName = "cairn-bogus";
  octetPackageName = "cargo-octet";
  invalidOctetPackageName = "cargo-octet-bogus";
  devenvPackageName = "devenv";
  invalidDevenvPackageName = "devenv-bogus";
  secretSpecPackageName = "secretspec";
  invalidSecretSpecPackageName = "secretspec-bogus";
  packageName = package: package.pname or (lib.getName package);
  usesUploadedCairnArtifactInput =
    package: packageName package == cairnPackageName && (package.usesUploadedArtifactInput or false);
  hasHomePackageNamed =
    expectedName: home: lib.any (package: packageName package == expectedName) home.home.packages;
  brittonrDevHomes = {
    desktop = desktopHome;
    laptop = aspen3Home;
    server = aspen1Home;
  };
  homePackages = desktopHome.home.packages;
  ghzingaPackage = lib.findFirst (package: (package.pname or null) == "ghzinga") null homePackages;
  ghzingaPackageVersion = if ghzingaPackage == null then "missing" else ghzingaPackage.version;
  ghzingaPackagePath = if ghzingaPackage == null then "/missing-ghzinga" else toString ghzingaPackage;
  syncHerdrPluginsPackage = lib.findFirst (
    package: (package.pname or (package.name or null)) == "sync-herdr-plugins"
  ) null homePackages;
  hasBogusGhzingaPackage = lib.any (package: (package.pname or null) == "ghzinga-bogus") homePackages;
  vimHerdrNavigationConfigSource =
    desktopHome.xdg.configFile."nvim/after/plugin/herdr_nav.lua".source;
  fishInteractiveShellInitFile = pkgs.writeText "britton-desktop-fish-init" desktopHome.programs.fish.interactiveShellInit;
  herdrPackage = lib.findFirst (
    package: (package.pname or null) == "herdr"
  ) null desktopConfig.environment.systemPackages;
  herdrPackageVersion = if herdrPackage == null then "missing" else herdrPackage.version;
  herdrPackagePath = if herdrPackage == null then "/missing-herdr" else toString herdrPackage;
  herdrPluginBundle = if herdrPackage == null then null else herdrPackage.pluginBundle or null;
  herdrPluginBundlePath =
    if herdrPluginBundle == null then
      "/missing-herdr-plugin-bundle"
    else
      "${herdrPluginBundle}/plugins.json";
  patchedHerdrPackage = if herdrPackage == null then null else herdrPackage.patchedPackage or null;
  patchedHerdrPackagePath =
    if patchedHerdrPackage == null then "/missing-patched-herdr" else toString patchedHerdrPackage;
  expectedBundledPluginIds =
    if herdrPackage == null then [ ] else herdrPackage.expectedPluginIds or [ ];
  requiredBundledPluginArtifacts =
    if herdrPackage == null then [ ] else herdrPackage.requiredPluginArtifacts or [ ];
  bundledPluginSources = if herdrPackage == null then [ ] else herdrPackage.pluginSources or [ ];
  bundledPluginRuntimePackages =
    if herdrPackage == null then [ ] else herdrPackage.runtimePackages or [ ];
  hasExpectedBundledPluginSources = bundledPluginSources == workflowPluginSources;
  expectedBundledPluginIdsJson = builtins.toJSON (
    builtins.sort builtins.lessThan expectedBundledPluginIds
  );
  expectedBundledPluginCount = builtins.length expectedBundledPluginIds;
  mutableFixturePluginId = "example.mutable";
  duplicateFixturePluginId = "mirror";
  expectedMutablePluginCount = 1;
  expectedMergedPluginCount = expectedBundledPluginCount + expectedMutablePluginCount;
  hasCompatibleHerdrPackage =
    herdrPackage != null && lib.versionAtLeast herdrPackageVersion minimumPueueHerdrVersion;
  herdrConfigSource = desktopHome.xdg.configFile."herdr/config.toml".source;
  activationScripts = lib.mapAttrsToList (_name: entry: entry.data or "") desktopHome.home.activation;
  hasHerdrPluginActivationMutation = lib.any (
    script: lib.hasInfix "herdr plugin link" script || lib.hasInfix "herdr plugin install" script
  ) activationScripts;
  wildcardGestureEdge = "*";
  aspen3TouchpadTapOverride = aspen3Home.input.touchpad.hostOverrides.aspen3.tap or true;
  aspen3SystemTouchpadTapping = aspen3Config.services.libinput.touchpad.tapping;
  aspen3NiriInstallActivation = aspen3Home.home.activation.installNiriConfig.data;
  aspen3NiriInstallActivationFile = pkgs.writeText "aspen3-install-niri-config" aspen3NiriInstallActivation;
  aspen3WildcardMultiFingerBindings = lib.filter (
    binding: binding.fingers > 1 && binding.edge == wildcardGestureEdge
  ) aspen3Home.gestures.lisgd.bindings;

  boolString = value: if value then "true" else "false";

  kacheWrapperWorkspaceWrapperBypass = pkgs.runCommand "kache-wrapper-workspace-wrapper-bypass" { } ''
    set -eu

    cargo_config=${lib.escapeShellArg cargoConfigSource}
    wrapper="$(${pkgs.gnused}/bin/sed -n 's/^rustc-wrapper = "\(.*\)"$/\1/p' "$cargo_config")"
    if [ -z "$wrapper" ]; then
      echo "positive: managed Cargo config must declare rustc-wrapper" >&2
      exit 1
    fi
    if [ ! -x "$wrapper" ]; then
      echo "positive: managed Cargo rustc-wrapper must be executable: $wrapper" >&2
      exit 1
    fi

    rustc=${pkgs.rustc}/bin/rustc
    KACHE_DISABLED=1 "$wrapper" "$rustc" -vV > "$TMPDIR/rustc-version.txt"
    if ! ${pkgs.gnugrep}/bin/grep -Fq "rustc" "$TMPDIR/rustc-version.txt"; then
      echo "positive: normal rustc passthrough did not print rustc version" >&2
      exit 1
    fi

    workspace_wrapper="$TMPDIR/fake-workspace-wrapper"
    workspace_wrapper_log="$TMPDIR/fake-workspace-wrapper.log"
    cat > "$workspace_wrapper" <<'EOF'
    #!${pkgs.runtimeShell}
    set -eu
    printf '%s\n' "$@" > "$FAKE_WORKSPACE_WRAPPER_LOG"
    EOF
    chmod +x "$workspace_wrapper"

    RUSTC_WORKSPACE_WRAPPER="$workspace_wrapper" \
      FAKE_WORKSPACE_WRAPPER_LOG="$workspace_wrapper_log" \
      "$wrapper" "$workspace_wrapper" "$rustc" -vV
    if ! ${pkgs.gnugrep}/bin/grep -Fxq "$rustc" "$workspace_wrapper_log"; then
      echo "positive: workspace-wrapper chain did not receive rustc as first argument" >&2
      exit 1
    fi

    if "$wrapper" > "$TMPDIR/missing-arg.stdout" 2> "$TMPDIR/missing-arg.stderr"; then
      echo "negative: missing rustc argument unexpectedly succeeded" >&2
      exit 1
    fi
    if ! ${pkgs.gnugrep}/bin/grep -Fq "expected rustc path as first argument" "$TMPDIR/missing-arg.stderr"; then
      echo "negative: missing rustc argument did not report the expected error" >&2
      cat "$TMPDIR/missing-arg.stderr" >&2
      exit 1
    fi

    touch $out
  '';

  # Positive and negative coverage for
  # r[verify onix.britton-desktop.herdr.pueue.version],
  # r[verify onix.britton-desktop.herdr.pueue.bindings],
  # r[verify onix.britton-desktop.herdr.pueue.sidebar_overview],
  # r[verify onix.britton-desktop.herdr.pueue.ownership], and
  # r[verify onix.britton-desktop.herdr.pueue.validation].
  herdrPueueDashboard = pkgs.runCommand "herdr-pueue-dashboard" { } ''
    set -eu

    ${lib.optionalString (!hasCompatibleHerdrPackage) ''
      echo "positive: Herdr ${herdrPackageVersion} must be at least ${minimumPueueHerdrVersion}" >&2
      exit 1
    ''}

    herdr_config=${herdrConfigSource}
    if ! ${pkgs.gnugrep}/bin/grep -Fq '${pueuePopupActionId}' "$herdr_config"; then
      echo "positive: rendered Herdr config must contain the Pueue popup action" >&2
      exit 1
    fi
    if ! ${pkgs.gnugrep}/bin/grep -Fq '${pueueSplitActionId}' "$herdr_config"; then
      echo "positive: rendered Herdr config must contain the Pueue split action" >&2
      exit 1
    fi
    if ! ${pkgs.gnugrep}/bin/grep -Fq 'key = "${pueuePopupKey}"' "$herdr_config"; then
      echo "positive: rendered Herdr config must contain the Pueue popup key" >&2
      exit 1
    fi
    if ! ${pkgs.gnugrep}/bin/grep -Fq 'key = "${pueueSplitKey}"' "$herdr_config"; then
      echo "positive: rendered Herdr config must contain the Pueue split key" >&2
      exit 1
    fi
    if ! ${pkgs.gnugrep}/bin/grep -Fq '${pueueStatusToken}' "$herdr_config"; then
      echo "positive: rendered Herdr config must contain the Pueue status token" >&2
      exit 1
    fi
    if ! ${pkgs.gnugrep}/bin/grep -Fq '${pueueFirstRunningToken}' "$herdr_config"; then
      echo "positive: rendered Herdr config must contain the first Pueue running-task token" >&2
      exit 1
    fi
    if ! ${pkgs.gnugrep}/bin/grep -Fq '${pueueSecondRunningToken}' "$herdr_config"; then
      echo "positive: rendered Herdr config must contain the second Pueue running-task token" >&2
      exit 1
    fi
    if ${pkgs.gnugrep}/bin/grep -Fq '${unsafePueueEnvironmentToken}' "$herdr_config"; then
      echo "negative: rendered Herdr config must not request Pueue environment metadata" >&2
      exit 1
    fi
    if ${pkgs.gnugrep}/bin/grep -Fq '${invalidPueueActionId}' "$herdr_config"; then
      echo "negative: rendered Herdr config must reject invalid Pueue actions" >&2
      exit 1
    fi
    if ${pkgs.gnugrep}/bin/grep -Fq '${pueuePluginLinkSource}' "$herdr_config"; then
      echo "negative: runtime plugin link sources must not enter Herdr config" >&2
      exit 1
    fi
    ${lib.optionalString hasHerdrPluginActivationMutation ''
      echo "negative: Home Manager activation must not mutate Herdr plugin state" >&2
      exit 1
    ''}

    touch "$out"
  '';

  # Positive and negative coverage for
  # r[verify onix.britton-desktop.herdr.wrapper.plugins],
  # r[verify onix.britton-desktop.herdr.wrapper.registry],
  # r[verify onix.britton-desktop.herdr.wrapper.install],
  # r[verify onix.britton-desktop.herdr.wrapper.ownership], and
  # r[verify onix.britton-desktop.herdr.wrapper.validation].
  herdrWorkflowPlugins = pkgs.runCommand "herdr-workflow-plugins" { } ''
    set -eu

    ${lib.optionalString (ghzingaPackageVersion != expectedGhzingaVersion) ''
      echo "positive: ghzinga version ${ghzingaPackageVersion} must equal ${expectedGhzingaVersion}" >&2
      exit 1
    ''}
    if [ ! -x '${ghzingaPackagePath}/bin/gzg' ]; then
      echo "positive: ghzinga package must contain gzg" >&2
      exit 1
    fi
    if [ ! -x '${ghzingaPackagePath}/bin/ghzinga' ]; then
      echo "positive: ghzinga package must contain ghzinga" >&2
      exit 1
    fi
    ${lib.optionalString hasBogusGhzingaPackage ''
      echo "negative: Home Manager package list must not contain ghzinga-bogus" >&2
      exit 1
    ''}
    ${lib.optionalString (syncHerdrPluginsPackage != null) ''
      echo "negative: Home Manager must not install sync-herdr-plugins" >&2
      exit 1
    ''}
    ${lib.optionalString (!hasExpectedBundledPluginSources) ''
      echo "negative: bundled plugin source pins must match the reviewed source list" >&2
      exit 1
    ''}
    ${lib.optionalString (!hasCompatibleHerdrPackage) ''
      echo "positive: wrapped Herdr ${herdrPackageVersion} must be at least ${minimumPueueHerdrVersion}" >&2
      exit 1
    ''}
    ${lib.optionalString (herdrPluginBundle == null) ''
      echo "positive: wrapped Herdr must expose its plugin bundle" >&2
      exit 1
    ''}
    ${lib.optionalString (patchedHerdrPackage == null) ''
      echo "positive: wrapped Herdr must expose its patched base package" >&2
      exit 1
    ''}

    wrapper=${lib.escapeShellArg "${herdrPackagePath}/bin/herdr"}
    registry=${lib.escapeShellArg herdrPluginBundlePath}
    if [ ! -x "$wrapper" ]; then
      echo "positive: wrapped Herdr executable must exist" >&2
      exit 1
    fi
    if [ ! -f "$registry" ]; then
      echo "positive: static Herdr plugin registry must exist" >&2
      exit 1
    fi
    if ! ${pkgs.gnugrep}/bin/grep -Fq 'HERDR_STATIC_PLUGIN_REGISTRY' "$wrapper"; then
      echo "positive: Herdr wrapper must select the static plugin registry" >&2
      exit 1
    fi
    if ${pkgs.gnugrep}/bin/grep -Eq 'herdr plugin (install|link)|sync-herdr-plugins' "$wrapper"; then
      echo "negative: Herdr wrapper must not mutate plugin registration" >&2
      exit 1
    fi
    if ${pkgs.gnugrep}/bin/grep -Eq 'XDG_(CONFIG|STATE)_HOME=' "$wrapper"; then
      echo "negative: Herdr wrapper must not replace mutable XDG directories" >&2
      exit 1
    fi
    ${lib.concatMapStringsSep "\n" (runtimePackage: ''
      if ! ${pkgs.gnugrep}/bin/grep -Fq ${lib.escapeShellArg (toString runtimePackage)} "$wrapper"; then
        echo "positive: Herdr wrapper PATH is missing ${runtimePackage.pname or runtimePackage.name}" >&2
        exit 1
      fi
    '') bundledPluginRuntimePackages}

    ${lib.concatMapStringsSep "\n" (artifact: ''
      if [ ! -e ${lib.escapeShellArg artifact} ]; then
        echo "positive: bundled plugin artifact is missing: ${artifact}" >&2
        exit 1
      fi
    '') requiredBundledPluginArtifacts}

    export HOME="$TMPDIR/home"
    export XDG_CONFIG_HOME="$TMPDIR/config"
    export XDG_STATE_HOME="$TMPDIR/state"
    unset HERDR_CLIENT_SOCKET_PATH HERDR_SESSION HERDR_SOCKET_PATH
    mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"

    "$wrapper" plugin list --json > "$TMPDIR/static-plugins.json"
    static_ids="$(${pkgs.jq}/bin/jq -c '[.result.plugins[].plugin_id] | sort' "$TMPDIR/static-plugins.json")"
    if [ "$static_ids" != ${lib.escapeShellArg expectedBundledPluginIdsJson} ]; then
      echo "positive: wrapped Herdr must load the exact bundled plugin ids" >&2
      exit 1
    fi

    mutable_fixture="$TMPDIR/mutable-plugin"
    mkdir -p "$mutable_fixture"
    cat > "$mutable_fixture/herdr-plugin.toml" <<'EOF'
    id = "${mutableFixturePluginId}"
    name = "Mutable fixture"
    version = "0.1.0"
    min_herdr_version = "0.7.0"
    platforms = ["linux"]
    EOF
    "$wrapper" plugin link "$mutable_fixture" >/dev/null
    "$wrapper" plugin list --json > "$TMPDIR/merged-plugins.json"
    merged_count="$(${pkgs.jq}/bin/jq '.result.plugins | length' "$TMPDIR/merged-plugins.json")"
    if [ "$merged_count" -ne ${toString expectedMergedPluginCount} ]; then
      echo "positive: static and mutable plugin registries must load together" >&2
      exit 1
    fi
    ${pkgs.jq}/bin/jq -e \
      '.result.plugins | any(.plugin_id == "${mutableFixturePluginId}")' \
      "$TMPDIR/merged-plugins.json" >/dev/null

    mutable_registry="$XDG_CONFIG_HOME/herdr/plugins.json"
    mutable_count="$(${pkgs.jq}/bin/jq 'length' "$mutable_registry")"
    if [ "$mutable_count" -ne ${toString expectedMutablePluginCount} ]; then
      echo "negative: mutable registry must not persist static plugin entries" >&2
      exit 1
    fi

    duplicate_fixture="$TMPDIR/duplicate-plugin"
    mkdir -p "$duplicate_fixture"
    cat > "$duplicate_fixture/herdr-plugin.toml" <<'EOF'
    id = "${duplicateFixturePluginId}"
    name = "Mutable duplicate"
    version = "99.0.0"
    min_herdr_version = "0.7.0"
    platforms = ["linux"]
    EOF
    "$wrapper" plugin link "$duplicate_fixture" >/dev/null
    "$wrapper" plugin list --json > "$TMPDIR/duplicate-plugins.json"
    ${pkgs.jq}/bin/jq -e \
      '.result.plugins | any(.plugin_id == "${duplicateFixturePluginId}" and .version == "0.1.14")' \
      "$TMPDIR/duplicate-plugins.json" >/dev/null
    ${pkgs.jq}/bin/jq -e \
      'any(.[]; .plugin_id == "${duplicateFixturePluginId}" and .version == "99.0.0")' \
      "$mutable_registry" >/dev/null

    malformed_root="$TMPDIR/malformed"
    malformed_registry="$TMPDIR/malformed-static.json"
    mkdir -p "$malformed_root/herdr"
    ${pkgs.jq}/bin/jq \
      '[.[] | select(.plugin_id == "${mutableFixturePluginId}")]' \
      "$mutable_registry" > "$malformed_root/herdr/plugins.json"
    printf '%s' 'not valid json' > "$malformed_registry"
    HERDR_STATIC_PLUGIN_REGISTRY="$malformed_registry" \
      XDG_CONFIG_HOME="$malformed_root" \
      ${lib.escapeShellArg "${patchedHerdrPackagePath}/bin/herdr"} plugin list --json \
      > "$TMPDIR/malformed-fallback.json"
    ${pkgs.jq}/bin/jq -e \
      '.result.plugins | any(.plugin_id == "${mutableFixturePluginId}")' \
      "$TMPDIR/malformed-fallback.json" >/dev/null
    if [ "$(< "$malformed_registry")" != 'not valid json' ]; then
      echo "negative: malformed static input must remain unchanged" >&2
      exit 1
    fi

    herdr_config=${herdrConfigSource}
    ${lib.concatMapStringsSep "\n" (binding: ''
      if ! ${pkgs.gnugrep}/bin/grep -Fq '${binding.action}' "$herdr_config"; then
        echo "positive: Herdr config must contain ${binding.action}" >&2
        exit 1
      fi
      if ! ${pkgs.gnugrep}/bin/grep -Fq 'key = "${binding.key}"' "$herdr_config"; then
        echo "positive: Herdr config must contain ${binding.key}" >&2
        exit 1
      fi
    '') workflowPluginBindings}
    if ${pkgs.gnugrep}/bin/grep -Fq '${invalidWorkflowPluginAction}' "$herdr_config"; then
      echo "negative: Herdr config must not contain a bogus workflow plugin action" >&2
      exit 1
    fi
    ${lib.concatMapStringsSep "\n" (plugin: ''
      if ${pkgs.gnugrep}/bin/grep -Fq '${plugin.source}' "$herdr_config"; then
        echo "negative: plugin source locations must not enter Herdr config" >&2
        exit 1
      fi
    '') workflowPluginSources}

    nvim_adapter=${lib.escapeShellArg vimHerdrNavigationConfigSource}
    ${lib.concatMapStringsSep "\n"
      (key: ''
        if ! ${pkgs.gnugrep}/bin/grep -Fq 'map("<C-${key}>"' "$nvim_adapter"; then
          echo "positive: Neovim adapter must map Ctrl+${key}" >&2
          exit 1
        fi
      '')
      [
        "h"
        "j"
        "k"
        "l"
      ]
    }
    if ! ${pkgs.gnugrep}/bin/grep -Fq 'HERDR_BIN_PATH' "$nvim_adapter"; then
      echo "positive: Neovim adapter must use the current Herdr binary" >&2
      exit 1
    fi

    fish_init=${lib.escapeShellArg fishInteractiveShellInitFile}
    if ! ${pkgs.gnugrep}/bin/grep -Fq 'set -gu CDPATH . ~/git' "$fish_init"; then
      echo "positive: Fish must keep CDPATH as a non-exported global" >&2
      exit 1
    fi
    if ${pkgs.gnugrep}/bin/grep -Fq 'set -x CDPATH' "$fish_init"; then
      echo "negative: Fish must not export CDPATH to plugin scripts" >&2
      exit 1
    fi

    ${lib.optionalString hasHerdrPluginActivationMutation ''
      echo "negative: Home Manager activation must not mutate Herdr plugin state" >&2
      exit 1
    ''}

    touch "$out"
  '';

  assertions = [
    {
      name = "positive: britton-desktop Home Manager stateVersion is ${targetHomeStateVersion}";
      condition = actualHomeStateVersion == targetHomeStateVersion;
    }
    {
      name = "positive: NixOS system.stateVersion remains ${legacyHomeStateVersion}";
      condition = actualSystemStateVersion == legacyHomeStateVersion;
    }
    {
      name = "positive: Neovim Ruby provider is disabled";
      condition = neovimConfig.withRuby == false;
    }
    {
      name = "positive: Neovim Python provider is disabled";
      condition = neovimConfig.withPython3 == false;
    }
    {
      name = "negative: Home Manager stateVersion no longer matches legacy ${legacyHomeStateVersion}";
      condition = actualHomeStateVersion != legacyHomeStateVersion;
    }
    {
      name = "negative: Neovim Ruby provider no longer preserves the legacy enabled default";
      condition = neovimConfig.withRuby != true;
    }
    {
      name = "negative: Neovim Python provider no longer preserves the legacy enabled default";
      condition = neovimConfig.withPython3 != true;
    }
  ];

  palmAssertions = [
    {
      name = "positive: aspen3 host override disables Niri tap-to-click";
      condition = aspen3TouchpadTapOverride == false;
    }
    {
      name = "positive: aspen3 system libinput tapping is disabled";
      condition = aspen3SystemTouchpadTapping == false;
    }
    {
      name = "negative: aspen3 multi-finger touchscreen gestures do not use wildcard edges";
      condition = aspen3WildcardMultiFingerBindings == [ ];
    }
    {
      name = "negative: aspen3 system libinput tapping no longer preserves the inherited enabled default";
      condition = aspen3SystemTouchpadTapping != true;
    }
  ];

  devToolAssertionsFor =
    expectedName: invalidName:
    lib.concatLists (
      lib.mapAttrsToList (role: home: [
        {
          name = "positive: brittonr ${role} dev profile installs ${expectedName}";
          condition = hasHomePackageNamed expectedName home;
        }
        {
          name = "negative: brittonr ${role} dev profile excludes ${invalidName}";
          condition = !hasHomePackageNamed invalidName home;
        }
      ]) brittonrDevHomes
    );
  cairnSourceAssertions = lib.concatLists (
    lib.mapAttrsToList (role: home: [
      {
        name = "positive: brittonr ${role} Cairn uses the uploaded artifact input";
        condition = lib.any usesUploadedCairnArtifactInput home.home.packages;
      }
      {
        name = "negative: brittonr ${role} excludes Cairn with a remote artifact fetch";
        condition =
          !lib.any (
            package: packageName package == cairnPackageName && !usesUploadedCairnArtifactInput package
          ) home.home.packages;
      }
    ]) brittonrDevHomes
  );
  cairnDevToolAssertions =
    devToolAssertionsFor cairnPackageName invalidCairnPackageName ++ cairnSourceAssertions;
  octetDevToolAssertions = devToolAssertionsFor octetPackageName invalidOctetPackageName;
  globalDevToolAssertions =
    devToolAssertionsFor devenvPackageName invalidDevenvPackageName
    ++ devToolAssertionsFor secretSpecPackageName invalidSecretSpecPackageName;

  failedAssertions = lib.filter (assertion: !assertion.condition) assertions;
  failedNames = lib.concatMapStringsSep "; " (assertion: assertion.name) failedAssertions;
  failedPalmAssertions = lib.filter (assertion: !assertion.condition) palmAssertions;
  failedPalmNames = lib.concatMapStringsSep "; " (assertion: assertion.name) failedPalmAssertions;
  failedCairnDevToolAssertions = lib.filter (assertion: !assertion.condition) cairnDevToolAssertions;
  failedCairnDevToolNames = lib.concatMapStringsSep "; " (
    assertion: assertion.name
  ) failedCairnDevToolAssertions;
  failedOctetDevToolAssertions = lib.filter (assertion: !assertion.condition) octetDevToolAssertions;
  failedOctetDevToolNames = lib.concatMapStringsSep "; " (
    assertion: assertion.name
  ) failedOctetDevToolAssertions;
  failedGlobalDevToolAssertions = lib.filter (
    assertion: !assertion.condition
  ) globalDevToolAssertions;
  failedGlobalDevToolNames = lib.concatMapStringsSep "; " (
    assertion: assertion.name
  ) failedGlobalDevToolAssertions;
  report = builtins.toFile "home-manager-2605-migration-report.txt" ''
    Home Manager 26.05 migration check

    Effective values:
    - home-manager.users.brittonr.home.stateVersion = ${actualHomeStateVersion}
    - system.stateVersion = ${actualSystemStateVersion}
    - programs.neovim.withRuby = ${boolString neovimConfig.withRuby}
    - programs.neovim.withPython3 = ${boolString neovimConfig.withPython3}

    Assertions:
    ${lib.concatMapStringsSep "\n" (
      assertion: "- ${assertion.name}: ${if assertion.condition then "PASS" else "FAIL"}"
    ) assertions}
  '';
  palmReport = builtins.toFile "aspen3-input-palm-rejection-report.txt" ''
    aspen3 input palm rejection check

    Effective values:
    - input.touchpad.hostOverrides.aspen3.tap = ${boolString aspen3TouchpadTapOverride}
    - services.libinput.touchpad.tapping = ${boolString aspen3SystemTouchpadTapping}
    - wildcard multi-finger lisgd binding count = ${toString (builtins.length aspen3WildcardMultiFingerBindings)}

    Assertions:
    ${lib.concatMapStringsSep "\n" (
      assertion: "- ${assertion.name}: ${if assertion.condition then "PASS" else "FAIL"}"
    ) palmAssertions}
  '';
  cairnDevToolReport = builtins.toFile "brittonr-cairn-dev-tool-report.txt" ''
    brittonr Cairn dev tool check

    Assertions:
    ${lib.concatMapStringsSep "\n" (
      assertion: "- ${assertion.name}: ${if assertion.condition then "PASS" else "FAIL"}"
    ) cairnDevToolAssertions}
  '';
  octetDevToolReport = builtins.toFile "brittonr-octet-dev-tool-report.txt" ''
    brittonr Octet dev tool check

    Assertions:
    ${lib.concatMapStringsSep "\n" (
      assertion: "- ${assertion.name}: ${if assertion.condition then "PASS" else "FAIL"}"
    ) octetDevToolAssertions}
  '';
  globalDevToolReport = builtins.toFile "brittonr-global-dev-tool-report.txt" ''
    brittonr global dev tool check

    Assertions:
    ${lib.concatMapStringsSep "\n" (
      assertion: "- ${assertion.name}: ${if assertion.condition then "PASS" else "FAIL"}"
    ) globalDevToolAssertions}
  '';
in
{
  checks = lib.optionalAttrs (system == "x86_64-linux") {
    home-manager-2605-migration =
      if failedAssertions == [ ] then
        pkgs.runCommand "home-manager-2605-migration" { migrationReport = report; } ''
          cp "$migrationReport" "$out"
        ''
      else
        throw "home-manager-2605-migration failed: ${failedNames}";

    brittonr-cairn-dev-tool =
      if failedCairnDevToolAssertions == [ ] then
        pkgs.runCommand "brittonr-cairn-dev-tool" { inherit cairnDevToolReport; } ''
          cp "$cairnDevToolReport" "$out"
        ''
      else
        throw "brittonr-cairn-dev-tool failed: ${failedCairnDevToolNames}";

    brittonr-octet-dev-tool =
      if failedOctetDevToolAssertions == [ ] then
        pkgs.runCommand "brittonr-octet-dev-tool" { inherit octetDevToolReport; } ''
          cp "$octetDevToolReport" "$out"
        ''
      else
        throw "brittonr-octet-dev-tool failed: ${failedOctetDevToolNames}";

    brittonr-global-dev-tools =
      if failedGlobalDevToolAssertions == [ ] then
        pkgs.runCommand "brittonr-global-dev-tools" { inherit globalDevToolReport; } ''
          cp "$globalDevToolReport" "$out"
        ''
      else
        throw "brittonr-global-dev-tools failed: ${failedGlobalDevToolNames}";

    aspen3-input-palm-rejection =
      if failedPalmAssertions == [ ] then
        pkgs.runCommand "aspen3-input-palm-rejection"
          {
            inherit palmReport;
            niriActivation = aspen3NiriInstallActivationFile;
          }
          ''
            set -eu

            niri_config="$(${pkgs.gnused}/bin/sed -n 's|.*install .* \(/nix/store/[^ ]*-niri-config.kdl\) .*|\1|p' "$niriActivation")"
            if [ -z "$niri_config" ]; then
              echo "positive: aspen3 activation must install the generated Niri config" >&2
              exit 1
            fi
            if ! ${pkgs.gnugrep}/bin/grep -Eq '^[[:space:]]*dwt([[:space:]]|$)' "$niri_config"; then
              echo "positive: rendered aspen3 Niri config must keep disable-while-typing" >&2
              exit 1
            fi
            if ${pkgs.gnugrep}/bin/grep -Eq '^[[:space:]]*tap([[:space:]]|$)' "$niri_config"; then
              echo "negative: rendered aspen3 Niri config must not enable tap-to-click" >&2
              exit 1
            fi

            cp "$palmReport" "$out"
          ''
      else
        throw "aspen3-input-palm-rejection failed: ${failedPalmNames}";

    kache-wrapper-workspace-wrapper-bypass = kacheWrapperWorkspaceWrapperBypass;
    herdr-pueue-dashboard = herdrPueueDashboard;
    herdr-workflow-plugins = herdrWorkflowPlugins;
  };
}
