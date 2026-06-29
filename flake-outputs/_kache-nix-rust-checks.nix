# Focused checks for the Nix-owned kache Rust build pilot.
{
  self,
  pkgs,
  lib,
  system,
  ...
}:
let
  expectedCacheDir = "/var/cache/kache-nix";
  expectedCacheDevice = "datapool/kache-nix";
  forbiddenUserCacheDir = "/home/brittonr/.cache/kache";
  pilotKeySalt = "changebot-crane-pilot-v1";
  missingCacheDiagnostic = "cache directory is not writable";

  fakeKache = pkgs.writeShellApplication {
    name = "kache";
    text = ''
      if [ -n "''${KACHE_NIX_TRACE:-}" ]; then
        {
          printf 'fake_kache_invoked=true\n'
          printf 'argv=%s\n' "$*"
          printf 'KACHE_KEY_SALT=%s\n' "''${KACHE_KEY_SALT:-}"
          printf 'KACHE_CACHE_DIR=%s\n' "''${KACHE_CACHE_DIR:-}"
        } >> "$KACHE_NIX_TRACE"
      fi
      exec "$@"
    '';
  };

  kacheLib = import ../lib/kache-nix-rust.nix {
    inherit lib pkgs;
    kachePackage = fakeKache;
  };

  cargoWrapper = kacheLib.mkCargoRustcWrapper {
    name = "checked-kache-cargo-rustc-wrapper";
    cacheDir = expectedCacheDir;
    keySalt = pilotKeySalt;
  };

  wrappedRust = kacheLib.mkWrappedRustPackage {
    name = "checked-kache-rust";
    rust = pkgs.rustc;
    cacheDir = expectedCacheDir;
    keySalt = pilotKeySalt;
  };

  fakeChangebotPackage = pkgs.runCommand "fake-changebot-crane-package" { } ''
    mkdir -p "$out"
    printf 'RUSTC_WRAPPER=%s\n' "''${RUSTC_WRAPPER-}" > "$out/env"
    printf 'KACHE_NIX_CACHE_DIR=%s\n' "''${KACHE_NIX_CACHE_DIR-}" >> "$out/env"
  '';

  wrappedChangebotExample = import ../examples/kache-nix-rust/changebot-crane-pilot.nix {
    inherit pkgs lib;
    onixPackages = {
      kache = fakeKache;
    };
    changebotPackage = fakeChangebotPackage;
    cacheDir = expectedCacheDir;
    keySalt = pilotKeySalt;
  };

  unwrappedChangebotExample = import ../examples/kache-nix-rust/changebot-crane-pilot.nix {
    inherit pkgs lib;
    onixPackages = {
      kache = fakeKache;
    };
    changebotPackage = fakeChangebotPackage;
    enableKache = false;
    cacheDir = expectedCacheDir;
    keySalt = pilotKeySalt;
  };

  desktopConfig = self.nixosConfigurations.britton-desktop.config;
  cacheFilesystem = desktopConfig.fileSystems.${expectedCacheDir} or null;
  sandboxPathsRaw = desktopConfig.nix.settings.extra-sandbox-paths or [ ];
  sandboxPaths = if builtins.isList sandboxPathsRaw then sandboxPathsRaw else [ sandboxPathsRaw ];
  tmpfilesRules = desktopConfig.systemd.tmpfiles.rules or [ ];
in
{
  checks = lib.optionalAttrs (system == "x86_64-linux") {
    kache-nix-rust-wrapper-contract = pkgs.runCommand "kache-nix-rust-wrapper-contract" { } ''
      set -eu

      wrapper=${lib.getExe cargoWrapper}
      rustc=${pkgs.rustc}/bin/rustc
      cache_dir="$PWD/cache"
      trace="$PWD/kache.trace"

      KACHE_NIX_DISABLED=1 KACHE_NIX_TRACE="$PWD/disabled.trace" "$wrapper" "$rustc" -vV > "$PWD/disabled-rustc-version.txt"
      if [ -s "$PWD/disabled.trace" ]; then
        echo "negative: disabled mode should not invoke kache" >&2
        exit 1
      fi

      if "$wrapper" "$rustc" -vV > "$PWD/missing-cache.stdout" 2> "$PWD/missing-cache.stderr"; then
        echo "negative: missing cache directory unexpectedly succeeded" >&2
        exit 1
      fi
      if ! ${pkgs.gnugrep}/bin/grep -Fq ${lib.escapeShellArg missingCacheDiagnostic} "$PWD/missing-cache.stderr"; then
        echo "negative: missing cache directory did not produce the expected diagnostic" >&2
        cat "$PWD/missing-cache.stderr" >&2
        exit 1
      fi

      mkdir -p "$cache_dir"
      KACHE_NIX_CACHE_DIR="$cache_dir" KACHE_NIX_TRACE="$trace" "$wrapper" "$rustc" -vV > "$PWD/wrapped-rustc-version.txt"
      if ! ${pkgs.gnugrep}/bin/grep -Fq 'fake_kache_invoked=true' "$trace"; then
        echo "positive: wrapper did not invoke kache" >&2
        cat "$trace" >&2
        exit 1
      fi
      if ! ${pkgs.gnugrep}/bin/grep -Fq "argv=$rustc -vV" "$trace"; then
        echo "positive: wrapper did not pass the real rustc path and original argv to kache" >&2
        cat "$trace" >&2
        exit 1
      fi
      if ! ${pkgs.gnugrep}/bin/grep -Fq 'operator=${pilotKeySalt}' "$trace"; then
        echo "positive: wrapper did not include the operator key salt" >&2
        cat "$trace" >&2
        exit 1
      fi
      if ! ${pkgs.gnugrep}/bin/grep -Fq "KACHE_CACHE_DIR=$cache_dir" "$trace"; then
        echo "positive: wrapper did not export the runtime cache directory" >&2
        cat "$trace" >&2
        exit 1
      fi

      wrapped_rust_trace="$PWD/wrapped-rust.trace"
      KACHE_NIX_CACHE_DIR="$cache_dir" KACHE_NIX_TRACE="$wrapped_rust_trace" ${wrappedRust}/bin/rustc -vV > "$PWD/wrapped-package-rustc-version.txt"
      if ! ${pkgs.gnugrep}/bin/grep -Fq 'fake_kache_invoked=true' "$wrapped_rust_trace"; then
        echo "positive: wrapped rust package did not invoke kache" >&2
        cat "$wrapped_rust_trace" >&2
        exit 1
      fi
      if [ ! -x ${wrappedRust}/bin/rustdoc ]; then
        echo "positive: wrapped rust package must preserve rustdoc compatibility" >&2
        exit 1
      fi

      touch "$out"
    '';

    kache-nix-rust-sandbox-settings = pkgs.runCommand "kache-nix-rust-sandbox-settings" { } ''
      ${lib.optionalString (!(lib.elem expectedCacheDir sandboxPaths)) ''
        echo "positive: ${expectedCacheDir} is missing from nix.settings.extra-sandbox-paths" >&2
        exit 1
      ''}
      ${lib.optionalString (lib.elem forbiddenUserCacheDir sandboxPaths) ''
        echo "negative: user cache path ${forbiddenUserCacheDir} must not be exposed to Nix builders" >&2
        exit 1
      ''}
      ${lib.optionalString (cacheFilesystem == null) ''
        echo "positive: ${expectedCacheDir} must be a declared filesystem on the 4TB datapool" >&2
        exit 1
      ''}
      ${lib.optionalString
        (cacheFilesystem != null && ((cacheFilesystem.device or "") != expectedCacheDevice))
        ''
          echo "positive: ${expectedCacheDir} must be backed by ${expectedCacheDevice}" >&2
          echo "actual device: ${cacheFilesystem.device or "<missing>"}" >&2
          exit 1
        ''
      }
      ${lib.optionalString
        (cacheFilesystem != null && !(lib.elem "nofail" (cacheFilesystem.options or [ ])))
        ''
          echo "negative: ${expectedCacheDir} must use nofail so a missing cache dataset cannot block boot" >&2
          exit 1
        ''
      }
      ${lib.optionalString (!(lib.any (rule: lib.hasInfix expectedCacheDir rule) tmpfilesRules)) ''
        echo "positive: ${expectedCacheDir} tmpfiles rule is missing" >&2
        exit 1
      ''}
      touch "$out"
    '';

    kache-nix-rust-changebot-example = pkgs.runCommand "kache-nix-rust-changebot-example" { } ''
      set -eu

      if ! ${pkgs.gnugrep}/bin/grep -Fq 'changebot-kache-rustc-wrapper' ${wrappedChangebotExample}/env; then
        echo "positive: changebot example did not inject the kache rustc wrapper" >&2
        cat ${wrappedChangebotExample}/env >&2
        exit 1
      fi
      if ! ${pkgs.gnugrep}/bin/grep -Fxq 'KACHE_NIX_CACHE_DIR=${expectedCacheDir}' ${wrappedChangebotExample}/env; then
        echo "positive: changebot example did not set the machine-owned cache dir" >&2
        cat ${wrappedChangebotExample}/env >&2
        exit 1
      fi
      if ! ${pkgs.gnugrep}/bin/grep -Fxq 'RUSTC_WRAPPER=' ${unwrappedChangebotExample}/env; then
        echo "negative: disabled changebot example should leave RUSTC_WRAPPER unset" >&2
        cat ${unwrappedChangebotExample}/env >&2
        exit 1
      fi

      touch "$out"
    '';
  };
}
