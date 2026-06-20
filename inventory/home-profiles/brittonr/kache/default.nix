# Desktop-local kache pilot profile.
#
# Keep typed data in ./lib/ so root-level .nix files stay real HM modules.
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
  inherit (profileData.kache)
    cacheBudgetGiB
    cacheDir
    daemonIdleTimeoutSecs
    daemonLogFilter
    daemonRestartDelay
    daemonService
    localOnly
    ;

  localCacheSize = "${toString cacheBudgetGiB}GiB";

  cargoRustcWrapperBinaryName = "cargo-rustc-kache-wrapper";
  rustcWrapperMissingArgumentMessage = "cargo-rustc-kache-wrapper: expected rustc path as first argument";

  kachePackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.kache;

  tomlFormat = pkgs.formats.toml { };

  kacheConfig = {
    cache = {
      local_store = cacheDir;
      local_max_size = localCacheSize;
      local_only = localOnly;
      daemon_idle_timeout_secs = daemonIdleTimeoutSecs;
    };
  };

  kacheConfigFile = tomlFormat.generate "kache-config.toml" kacheConfig;

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

      toolchain_salt="rustc=$(resolve_path "$real_rustc");cc=$(resolve_command cc);mold=$(resolve_command mold)"
      user_salt="''${KACHE_KEY_SALT:-}"

      if [ -n "$user_salt" ]; then
        export KACHE_KEY_SALT="$toolchain_salt;user=$user_salt"
      else
        export KACHE_KEY_SALT="$toolchain_salt"
      fi

      export KACHE_CONFIG=${lib.escapeShellArg kacheConfigFile}
      export KACHE_CACHE_DIR=${lib.escapeShellArg cacheDir}
      export KACHE_LOCAL_ONLY=${if localOnly then "1" else "0"}

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
    activation.backupCargoConfigBeforeTakeover = lib.hm.dag.entryBefore [
      "checkLinkTargets"
    ] backupCargoConfigScript;
  };

  systemd.user.services.kache = lib.mkIf daemonService {
    Unit = {
      Description = "kache build cache daemon";
      After = [ "default.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${lib.getExe kachePackage} daemon run";
      Restart = "on-failure";
      RestartSec = daemonRestartDelay;
      Environment = [
        "KACHE_CACHE_DIR=${cacheDir}"
        "KACHE_CONFIG=${kacheConfigFile}"
        "KACHE_DAEMON_IDLE_TIMEOUT=${toString daemonIdleTimeoutSecs}"
        "KACHE_LOCAL_ONLY=${if localOnly then "1" else "0"}"
        "KACHE_LOG=${daemonLogFilter}"
      ];
    };

    Install.WantedBy = [ "default.target" ];
  };

  xdg.configFile."kache/config.toml".source = kacheConfigFile;
}
