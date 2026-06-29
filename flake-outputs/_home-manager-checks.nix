# Focused Home Manager migration checks.
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
  actualHomeStateVersion = desktopHome.home.stateVersion;
  actualSystemStateVersion = desktopConfig.system.stateVersion;
  neovimConfig = desktopHome.programs.neovim;
  cargoConfigSource = desktopHome.home.file.".cargo/config.toml".source;

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

  failedAssertions = lib.filter (assertion: !assertion.condition) assertions;
  failedNames = lib.concatMapStringsSep "; " (assertion: assertion.name) failedAssertions;
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

    kache-wrapper-workspace-wrapper-bypass = kacheWrapperWorkspaceWrapperBypass;
  };
}
