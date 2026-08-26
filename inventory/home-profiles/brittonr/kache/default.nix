# Fleet Kache Cargo profile.
#
# The machine-level Clan service owns cache policy, the daemon, and credentials.
# This profile owns only Cargo integration and the unprivileged client wrapper.
{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  profileData = wasm.evalNickelFile ./lib/config.ncl;

  inherit (profileData.cargo)
    jobs
    linker
    linkerArgs
    netRetry
    targetDir
    termQuiet
    ;
  inherit (profileData.kache) configPath;

  cargoRustcWrapperBinaryName = "cargo-rustc-kache-wrapper";
  rustcWrapperMissingArgumentMessage = "cargo-rustc-kache-wrapper: expected rustc path as first argument";

  kachePackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.kache;

  tomlFormat = pkgs.formats.toml { };

  cargoRustcWrapper = pkgs.writeShellApplication {
    name = cargoRustcWrapperBinaryName;
    runtimeInputs = [
      kachePackage
      pkgs.coreutils
      pkgs.mold
    ];
    text = ''
      if [ "$#" -lt 1 ]; then
        echo ${lib.escapeShellArg rustcWrapperMissingArgumentMessage} >&2
        exit 1
      fi

      real_rustc="$1"
      shift

      resolve_path() {
        candidate="$1"

        if [ -z "$candidate" ]; then
          printf '%s' unset
          return 0
        fi

        if resolved="$(readlink -f "$candidate" 2>/dev/null)"; then
          printf '%s' "$resolved"
          return 0
        fi

        printf '%s' "$candidate"
      }

      resolve_command() {
        command_name="$1"

        if command_path="$(command -v "$command_name" 2>/dev/null)"; then
          resolve_path "$command_path"
          return 0
        fi

        printf '%s' unset
      }

      is_cargo_workspace_wrapper_chain() {
        workspace_wrapper="''${RUSTC_WORKSPACE_WRAPPER:-}"

        if [ -z "$workspace_wrapper" ]; then
          return 1
        fi

        [ "$(resolve_path "$real_rustc")" = "$(resolve_path "$workspace_wrapper")" ]
      }

      # Cargo chains build.rustc-wrapper before RUSTC_WORKSPACE_WRAPPER as:
      #   rustc-wrapper workspace-wrapper rustc ...
      # kache 0.6.0 only enters wrapper mode for rustc-shaped argv, so pass
      # workspace-wrapper chains through before invoking kache.
      if is_cargo_workspace_wrapper_chain; then
        exec "$real_rustc" "$@"
      fi

      toolchain_salt="rustc=$(resolve_path "$real_rustc");cc=$(resolve_command cc);mold=$(resolve_command mold)"
      user_salt="''${KACHE_KEY_SALT:-}"

      if [ -n "$user_salt" ]; then
        export KACHE_KEY_SALT="$toolchain_salt;user=$user_salt"
      else
        export KACHE_KEY_SALT="$toolchain_salt"
      fi

      export KACHE_CONFIG=${lib.escapeShellArg configPath}

      exec kache "$real_rustc" "$@"
    '';
  };

  cargoConfig = {
    build = {
      inherit jobs;
      "rustc-wrapper" = lib.getExe cargoRustcWrapper;
      "target-dir" = targetDir;
    };
    target.x86_64-unknown-linux-gnu = {
      inherit linker;
      rustflags = builtins.concatMap (arg: [
        "-C"
        "link-arg=${arg}"
      ]) linkerArgs;
    };
    net.retry = netRetry;
    net."git-fetch-with-cli" = true;
    term.quiet = termQuiet;
  };

  cargoConfigFile = tomlFormat.generate "cargo-config.toml" cargoConfig;

  backupCargoConfigScript = ''
    cargo_dir="$HOME/.cargo"
    cargo_config="$cargo_dir/config.toml"
    backup_config="$cargo_dir/config.toml.pre-kache"
    cargo_config_is_store_symlink=0

    if [ -L "$cargo_config" ]; then
      cargo_target="$(readlink "$cargo_config")"
      case "$cargo_target" in
        /nix/store/*)
          cargo_config_is_store_symlink=1
          ;;
      esac
    fi

    if [ "$cargo_config_is_store_symlink" -ne 1 ] && [ -e "$cargo_config" ]; then
      if [ -e "$backup_config" ]; then
        echo "Refusing to take over $cargo_config: backup $backup_config already exists." >&2
        exit 1
      fi

      mkdir -p "$cargo_dir"
      cp "$cargo_config" "$backup_config"
      rm -f "$cargo_config"
    fi
  '';
in
{
  home = {
    packages = [
      kachePackage
      pkgs.mold
    ];
    file.".cargo/config.toml".source = cargoConfigFile;
    sessionVariables.KACHE_CONFIG = configPath;
    activation.backupCargoConfigBeforeTakeover = lib.hm.dag.entryBefore [
      "checkLinkTargets"
    ] backupCargoConfigScript;
  };
}
