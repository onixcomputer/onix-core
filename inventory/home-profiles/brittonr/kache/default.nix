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

  kachePackage = pkgs.kache;
  defaultKacheCacheDir = "/var/cache/kache-nix/user-brittonr";
  # Bake content-addressed toolchain store paths at Nix build time so every
  # rustc invocation avoids `command -v` / `readlink -f` subprocess forks.
  pinnedCcPath = "${pkgs.stdenv.cc}/bin/cc";
  pinnedMoldPath = "${pkgs.mold}/bin/mold";

  tomlFormat = pkgs.formats.toml { };

  cargoRustcWrapper = pkgs.writeShellApplication {
    name = cargoRustcWrapperBinaryName;
    runtimeInputs = [
      kachePackage
      pkgs.coreutils
      pkgs.mold
      pkgs.stdenv.cc
    ];
    text = ''
      if [ "$#" -lt 1 ]; then
        echo ${lib.escapeShellArg rustcWrapperMissingArgumentMessage} >&2
        exit 1
      fi

      real_rustc="$1"
      shift

      # Fast-path explicit bypass before resolving paths or checking the daemon.
      if [ "''${KACHE_DISABLED:-0}" = 1 ]; then
        exec "$real_rustc" "$@"
      fi

      resolve_path() {
        candidate="$1"

        if [ -z "$candidate" ]; then
          printf '%s' unset
          return 0
        fi

        # Store paths that are not symlinks are already canonical; avoid a fork.
        case "$candidate" in
          /nix/store/*)
            if [ ! -L "$candidate" ]; then
              printf '%s' "$candidate"
              return 0
            fi
            ;;
        esac

        if resolved="$(readlink -f "$candidate" 2>/dev/null)"; then
          printf '%s' "$resolved"
          return 0
        fi

        printf '%s' "$candidate"
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
      # Kache only enters wrapper mode for rustc-shaped argv, so pass
      # workspace-wrapper chains through before invoking Kache.
      if is_cargo_workspace_wrapper_chain; then
        exec "$real_rustc" "$@"
      fi

      # Zero-fork liveness check: when the managed kache-rustfs daemon is not
      # running, pass straight through to rustc instead of spawning an
      # unprivileged user daemon without S3 credentials or hitting a wedged store.
      kache_cache_dir="''${KACHE_CACHE_DIR:-${defaultKacheCacheDir}}"
      if [ "''${KACHE_LOCAL_ONLY:-0}" != 1 ] && [ ! -S "$kache_cache_dir/daemon.sock" ]; then
        exec "$real_rustc" "$@"
      fi

      case "$real_rustc" in
        /nix/store/*)
          if [ ! -L "$real_rustc" ]; then
            resolved_rustc="$real_rustc"
          else
            resolved_rustc="$(resolve_path "$real_rustc")"
          fi
          ;;
        *)
          resolved_rustc="$(resolve_path "$real_rustc")"
          ;;
      esac

      toolchain_salt="rustc=$resolved_rustc;cc=${pinnedCcPath};mold=${pinnedMoldPath}"
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
      pipelining = true;
      "rustc-wrapper" = lib.getExe cargoRustcWrapper;
      "target-dir" = targetDir;
    };
    # Line-tables-only keeps full file:line backtraces while cutting dev/test
    # compile time, link time, and .cargo-target / Kache disk footprint by ~50%.
    # Override per-invocation with CARGO_PROFILE_DEV_DEBUG=2 for full DWARF.
    profile = {
      dev.debug = "line-tables-only";
      test.debug = "line-tables-only";
    };
    target.x86_64-unknown-linux-gnu = {
      inherit linker;
      rustflags = builtins.concatMap (arg: [
        "-C"
        "link-arg=${arg}"
      ]) linkerArgs;
    };
    registries.crates-io.protocol = "sparse";
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
      pkgs.stdenv.cc
    ];
    file.".cargo/config.toml".source = cargoConfigFile;
    sessionVariables.KACHE_CONFIG = configPath;
    activation.backupCargoConfigBeforeTakeover = lib.hm.dag.entryBefore [
      "checkLinkTargets"
    ] backupCargoConfigScript;
  };
}
