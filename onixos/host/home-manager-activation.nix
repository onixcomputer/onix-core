# Build the Nix-command-free Home Manager activation artifact for the native host.
# Keep the upstream generation payload intact; only replace the pinned
# activation-init bootstrap that expects a writable Nix profile/daemon.
{ pkgs, activationPackage }:
let
  inherit (pkgs) lib;
  nixEnvPathSuffix = ":$(${pkgs.coreutils}/bin/dirname $(${pkgs.coreutils}/bin/readlink -m $(type -p nix-env)))";
  replacements = [
    {
      from = "# Verify that we can connect to the Nix store and/or daemon. This will\n# also create the necessary directories in profiles and gcroots.";
      to = "# The host producer installs the Home Manager package profile.";
    }
    {
      from = "_iVerbose \"Sanity checking Nix\"";
      to = "_iVerbose \"Using the host-installed Home Manager profile\"";
    }
    {
      from = "nix-build --quiet --expr '{}' --no-out-link";
      to = "";
    }
    {
      from = "# Also make sure that the Nix profiles path is created.";
      to = "# The host-installed profile is ready before activation.";
    }
    {
      from = "nix-env -q > /dev/null 2>&1 || true";
      to = "";
    }
    {
      from = "migrateProfile\nsetupVars";
      to = "";
    }
    {
      from = "_i 'Using Nix version: %s' \"$(nix-env --version)\"";
      to = "_i 'Home Manager activation uses the host-installed profile'";
    }
    {
      from = nixEnvPathSuffix;
      to = "";
    }
  ];
  replaceArgs =
    replacement:
    "--replace-fail ${lib.escapeShellArg replacement.from} ${lib.escapeShellArg replacement.to}";
  replaceCommand = lib.concatMapStringsSep " " replaceArgs replacements;
in
pkgs.runCommand "onixos-home-manager-activation"
  {
    nativeBuildInputs = [ pkgs.coreutils ];
  }
  ''
    mkdir -p "$out"
    cp -a ${activationPackage}/. "$out/"
    # The store payload preserves read-only directory modes. Make only the
    # copied entrypoint and its parent directories writable for this rewrite.
    chmod u+w "$out" "$out/bin" "$out/activate"
    if [ "$(readlink "$out/bin/home-manager-generation")" != "${activationPackage}/activate" ]; then
      echo "unexpected Home Manager generation entrypoint symlink" >&2
      exit 1
    fi
    ln -sfn ../activate "$out/bin/home-manager-generation"
    substituteInPlace "$out/activate" ${replaceCommand}
  ''
