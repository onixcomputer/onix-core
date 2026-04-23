# Desktop-local sccache profile.
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

  bytesPerKibibyte = 1024;
  kibibytesPerMebibyte = 1024;
  mebibytesPerGibibyte = 1024;

  inherit (profileData.cargo)
    ignoreServerIoError
    linker
    linkerArgs
    netRetry
    targetDir
    termQuiet
    ;
  inherit (profileData.sccache)
    basedirs
    cacheBudgetGiB
    cacheDir
    errorLog
    ;

  localCacheSizeBytes =
    cacheBudgetGiB * bytesPerKibibyte * kibibytesPerMebibyte * mebibytesPerGibibyte;

  wrappedSccacheBinaryName = "sccache";
  wrappedSccachePackageName = "sccache-wrapped";
  cargoRustcWrapperBinaryName = "cargo-rustc-sccache-wrapper";

  sccacheErrorLogVariableName = "SCCACHE_ERROR_LOG";
  sccacheIgnoreServerIoErrorVariableName = "SCCACHE_IGNORE_SERVER_IO_ERROR";

  rustcWrapperMissingArgumentMessage = "cargo-rustc-sccache-wrapper: expected rustc path as first argument";
  cacheTransportUnavailableMessage = "sccache-rustc-wrapper: cache transport unavailable, falling back to rustc";

  sccacheConnectionTimedOutMessage = "sccache: error: Connection to server timed out:";
  sccacheServerStartupFailedMessage = "sccache: error: Server startup failed:";
  sccacheStartupTimedOutMessage = "Timed out waiting for server startup.";
  sccacheAddressInUseMessage = "sccache: error: Address already in use";
  sccacheConnectOrStartFailureMessage = "failed to connect or start server";

  cacheTransportFailurePattern = lib.concatStringsSep "|" [
    "*${lib.escapeShellArg sccacheConnectionTimedOutMessage}*"
    "*${lib.escapeShellArg sccacheServerStartupFailedMessage}*"
    "*${lib.escapeShellArg sccacheStartupTimedOutMessage}*"
    "*${lib.escapeShellArg sccacheAddressInUseMessage}*"
    "*${lib.escapeShellArg sccacheConnectOrStartFailureMessage}*"
  ];

  wrappedSccache = pkgs.symlinkJoin {
    name = wrappedSccachePackageName;
    paths = [ pkgs.sccache ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/${wrappedSccacheBinaryName}" \
        --set ${sccacheErrorLogVariableName} ${errorLog} \
        --set ${sccacheIgnoreServerIoErrorVariableName} ${ignoreServerIoError}
    '';
  };

  cargoRustcWrapper = pkgs.writeShellApplication {
    name = cargoRustcWrapperBinaryName;
    runtimeInputs = [
      pkgs.coreutils
      wrappedSccache
    ];
    text = ''
      if [ "$#" -lt 1 ]; then
        echo ${lib.escapeShellArg rustcWrapperMissingArgumentMessage} >&2
        exit 1
      fi

      real_rustc="$1"
      shift

      stderr_file="$(mktemp)"

      trap 'rm -f "$stderr_file"' EXIT

      if sccache "$real_rustc" "$@" 2>"$stderr_file"; then
        cat "$stderr_file" >&2
        exit 0
      fi

      status="$?"
      stderr_text="$(<"$stderr_file")"

      cat "$stderr_file" >&2

      case "$stderr_text" in
        ${cacheTransportFailurePattern})
          echo ${lib.escapeShellArg cacheTransportUnavailableMessage} >&2
          exec "$real_rustc" "$@"
          ;;
      esac

      exit "$status"
    '';
  };

  cargoConfig = {
    build = {
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

  sccacheConfig = {
    inherit basedirs;
    cache.disk = {
      dir = cacheDir;
      size = localCacheSizeBytes;
    };
  };

  tomlFormat = pkgs.formats.toml { };
  cargoConfigFile = tomlFormat.generate "cargo-config.toml" cargoConfig;
  sccacheConfigFile = tomlFormat.generate "sccache-config.toml" sccacheConfig;

  backupCargoConfigScript = ''
    cargo_dir="$HOME/.cargo"
    cargo_config="$cargo_dir/config.toml"
    backup_config="$cargo_dir/config.toml.pre-sccache"
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
      wrappedSccache
      pkgs.mold
    ];
    file.".cargo/config.toml".source = cargoConfigFile;
    file.".local/bin/sccache".source = "${wrappedSccache}/bin/${wrappedSccacheBinaryName}";
    activation.backupCargoConfigBeforeTakeover = lib.hm.dag.entryBefore [
      "checkLinkTargets"
    ] backupCargoConfigScript;
  };

  xdg.configFile."sccache/config".source = sccacheConfigFile;
}
