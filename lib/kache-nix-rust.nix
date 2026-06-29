# Nix-owned kache wrappers for sandboxed Rust builds.
{
  lib,
  pkgs,
  kachePackage,
}:
let
  defaultCacheDir = "/var/cache/kache-nix";
  defaultKeySalt = "";
  defaultCargoWrapperName = "kache-nix-cargo-rustc-wrapper";
  defaultRustcWrapperName = "kache-nix-rustc-wrapper";
  wrappedRustPackageName = "kache-nix-rust";
  missingCacheExitCode = 78;
  unavailableCommandMarker = "unset";
  cacheDirectoryEnv = "KACHE_NIX_CACHE_DIR";
  disabledEnv = "KACHE_NIX_DISABLED";
  traceEnv = "KACHE_NIX_TRACE";
  cacheMissingMessage = "kache-nix-rust: cache directory is not writable; create it and expose it through nix.settings.extra-sandbox-paths or set KACHE_NIX_DISABLED=1";

  shellPrelude =
    {
      cacheDir,
      keySalt,
      requireCacheDir,
    }:
    ''
      cache_dir="''${${cacheDirectoryEnv}:-${lib.escapeShellArg cacheDir}}"
      operator_salt=${lib.escapeShellArg keySalt}
      require_cache_dir="${if requireCacheDir then "true" else "false"}"
      missing_cache_exit_code="${toString missingCacheExitCode}"
      unavailable_command_marker="${unavailableCommandMarker}"

      resolve_path() {
        candidate="$1"

        if [ -z "$candidate" ]; then
          printf '%s' "$unavailable_command_marker"
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

        printf '%s' "$unavailable_command_marker"
      }

      ensure_cache_dir() {
        if [ "$require_cache_dir" != true ]; then
          return 0
        fi

        if [ -d "$cache_dir" ] && [ -w "$cache_dir" ]; then
          return 0
        fi

        echo ${lib.escapeShellArg cacheMissingMessage} >&2
        echo "kache-nix-rust: cache_dir=$cache_dir" >&2
        exit "$missing_cache_exit_code"
      }

      export_cache_environment() {
        real_rustc_for_salt="$1"
        existing_salt="''${KACHE_KEY_SALT:-}"
        toolchain_salt="rustc=$(resolve_path "$real_rustc_for_salt");cc=$(resolve_command cc);mold=$(resolve_command mold)"

        if [ -n "$operator_salt" ]; then
          toolchain_salt="$toolchain_salt;operator=$operator_salt"
        fi

        if [ -n "$existing_salt" ]; then
          export KACHE_KEY_SALT="$toolchain_salt;user=$existing_salt"
        else
          export KACHE_KEY_SALT="$toolchain_salt"
        fi

        export KACHE_CACHE_DIR="$cache_dir"
        export KACHE_LOCAL_ONLY=1
      }

      trace_wrapper() {
        if [ -n "''${${traceEnv}:-}" ]; then
          {
            printf 'real_rustc=%s\n' "$1"
            printf 'cache_dir=%s\n' "$cache_dir"
            printf 'KACHE_KEY_SALT=%s\n' "''${KACHE_KEY_SALT:-}"
            printf 'argv='
            shift
            printf '%s' "$*"
            printf '\n'
          } >> "''${${traceEnv}}"
        fi
      }
    '';

  mkCargoRustcWrapper =
    {
      name ? defaultCargoWrapperName,
      cacheDir ? defaultCacheDir,
      keySalt ? defaultKeySalt,
      requireCacheDir ? true,
    }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        kachePackage
        pkgs.coreutils
      ];
      text = ''
        if [ "''${${disabledEnv}:-}" = "1" ]; then
          if [ "$#" -lt 1 ]; then
            echo "${name}: expected rustc path as first argument" >&2
            exit 1
          fi
          real_rustc="$1"
          shift
          exec "$real_rustc" "$@"
        fi

        if [ "$#" -lt 1 ]; then
          echo "${name}: expected rustc path as first argument" >&2
          exit 1
        fi

        real_rustc="$1"
        shift

        ${shellPrelude { inherit cacheDir keySalt requireCacheDir; }}

        ensure_cache_dir
        export_cache_environment "$real_rustc"
        trace_wrapper "$real_rustc" "$real_rustc" "$@"
        exec kache "$real_rustc" "$@"
      '';
    };

  mkRustcWrapper =
    {
      name ? defaultRustcWrapperName,
      realRustc,
      cacheDir ? defaultCacheDir,
      keySalt ? defaultKeySalt,
      requireCacheDir ? true,
    }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        kachePackage
        pkgs.coreutils
      ];
      text = ''
        real_rustc=${lib.escapeShellArg realRustc}

        if [ "''${${disabledEnv}:-}" = "1" ]; then
          exec "$real_rustc" "$@"
        fi

        ${shellPrelude { inherit cacheDir keySalt requireCacheDir; }}

        ensure_cache_dir
        export_cache_environment "$real_rustc"
        trace_wrapper "$real_rustc" "$real_rustc" "$@"
        exec kache "$real_rustc" "$@"
      '';
    };

  mkWrappedRustPackage =
    {
      name ? wrappedRustPackageName,
      rust ? pkgs.rustc,
      realRustc ? "${rust}/bin/rustc",
      rustdoc ? "${rust}/bin/rustdoc",
      cacheDir ? defaultCacheDir,
      keySalt ? defaultKeySalt,
      requireCacheDir ? true,
    }:
    let
      rustcWrapper = mkRustcWrapper {
        inherit
          cacheDir
          keySalt
          realRustc
          requireCacheDir
          ;
        name = "${name}-rustc";
      };
      optionalToolNames = [
        "cargo"
        "clippy-driver"
        "rustfmt"
      ];
      linkOptionalTool = toolName: ''
        if [ -x ${rust}/bin/${toolName} ]; then
          ln -s ${rust}/bin/${toolName} "$out/bin/${toolName}"
        fi
      '';
    in
    pkgs.runCommand name { } ''
      mkdir -p "$out/bin"
      ln -s ${rustcWrapper}/bin/${name}-rustc "$out/bin/rustc"
      if [ -x ${lib.escapeShellArg rustdoc} ]; then
        ln -s ${lib.escapeShellArg rustdoc} "$out/bin/rustdoc"
      fi
      ${lib.concatMapStringsSep "\n" linkOptionalTool optionalToolNames}
    '';

in
{
  inherit
    defaultCacheDir
    missingCacheExitCode
    mkCargoRustcWrapper
    mkRustcWrapper
    mkWrappedRustPackage
    ;
}
