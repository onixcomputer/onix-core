# Shared host-producer package selection for system and per-user profiles.
# The policy is applied only while producing the OnixOS host package closures;
# it does not modify the source NixOS/Home Manager configurations.
{ lib }:
let
  # Check both pname and derivation name: aliases such as emacs-pgtk can share
  # a pname with other variants while retaining their actual package name.
  packageNames =
    package:
    lib.filter builtins.isString [
      (package.pname or null)
      (package.name or null)
      (lib.getName package)
    ];
  matchesName =
    package: selectedName:
    lib.any (
      candidate:
      candidate == selectedName
      || lib.hasPrefix "${selectedName}-" candidate
      || lib.hasPrefix "${selectedName}_" candidate
    ) (packageNames package);

  # Nix daemon/client, cache, garbage-collection, and build-farm tools. This is
  # an explicit list rather than a `nix*` prefix so that nix-ld remains useful.
  nixRoleDrops = [
    "nix"
    "nix-info"
    "nix-index"
    "comma"
    "nix-output-monitor"
    "nixfmt-rs"
    "nix-eval-jobs"
    "nix-fast-build"
    "nix-build"
    "nix-build-farm"
    "nix-buildfarm"
    "nix-daemon"
    "nix-serve"
    "nix-collect-garbage"
    "nix-optimise"
    "nix-cleanup-gcroots"
    "nixpkgs-review"
    "nix-prefetch"
    "nix-prefetch-git"
    "nix-prefetch-github"
    "nixos-generators"
    "nh"
    "nix-search-tv"
    "deadnix"
    "statix"
    "dix"
    "nvd"
    "flake-edit"
    "nurl"
    "nil"
    "nix-init"
    "terranix"
    "nixdelta"
    "devenv"
    "clan"
    "clan-cli"
    "home-manager"
    "attic-client"
    "cachix"
    "hydra"
    "buildbot"
    "buildbot-worker"
  ];

  # NixOS manager entry points are not native host tools. Selecting from the
  # configured package list instead of system.path also avoids its generated
  # NixOS profile scripts and postBuild behavior.
  nixosManagerDrops = [
    "nixos-rebuild"
    "nixos-rebuild-ng"
    "nixos-generate-config"
    "nixos-install"
    "nixos-install-tools"
    "nixos-enter"
    "nixos-option"
    "nixos-container"
    "nixos-version"
    "nixos-build-vms"
    "nix-build-farm-wait-worker-address"
  ];

  # Clan's NixOS backup provider installs generated wrappers that refer to its
  # NixOS secret paths and control-plane helpers. The native host supplies its
  # own borg-job command wrappers, so do not expose the old generated ones.
  clanManagerDrops = [
    "borgbackup-create"
    "borgbackup-list"
    "borgbackup-restore"
    "state-commands"
  ];
  clanManagerPrefixes = [
    "borg-job-"
    "borgbackup-job-"
  ];

  # Dropping the desktop services must also remove their top-level commands
  # from the native system and user profiles. Keep client libraries needed by
  # retained programs; this is not a transitive dependency ban.
  desktopStackDrops = [
    "xorg-server"
    "xwayland"
    "lightdm"
    "lightdm-gtk-greeter"
    "pipewire"
    "wireplumber"
    "accountsservice"
  ];

  # The specifically approved heavy GUI/development applications; dependencies
  # (including libraries and useful command-line tools) are not filtered.
  heavyApplicationDrops = [
    "ghidra"
    "kicad"
    "kicad-small"
    "emacs-pgtk"
    "emacs-pgtk-nativecomp"
    "imhex"
    "radare2"
    "warp-terminal"
    "kooha"
    "openscad"
    "openscad-unstable"
  ];

  # These names intentionally remain even though they begin with "nix" or
  # "nixos": nix-ld is required for FHS binaries, and facter is useful hardware
  # inventory rather than a Nix daemon/client or system manager.
  retainedSpecialCases = [
    "nix-ld"
    "ld-library-path"
    "facter"
    "nixos-facter"
  ];

  dropNames =
    nixRoleDrops ++ nixosManagerDrops ++ clanManagerDrops ++ desktopStackDrops ++ heavyApplicationDrops;
  isClanManagerPackage =
    package:
    lib.any (candidate: lib.any (prefix: lib.hasPrefix prefix candidate) clanManagerPrefixes) (
      packageNames package
    );
  keepPackage =
    package:
    lib.any (matchesName package) retainedSpecialCases
    || (!(lib.any (matchesName package) dropNames) && !(isClanManagerPackage package));
in
{
  inherit keepPackage;
  keepPackages = packages: lib.filter keepPackage packages;
}
