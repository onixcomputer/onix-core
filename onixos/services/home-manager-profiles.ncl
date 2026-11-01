# onix-core home-manager-profiles service (modules/home-manager-profiles).
#
# Each instance applies profile directories <profiles_base_path>/<username>/
# <profile> to one user through Home Manager. Nickel cannot import modules
# or list directories, so this module emits the instance's settings as
# onix.homeManagerProfiles.<instance>; the adapter in the sidecar
# home-manager-profiles.nix turns them into exactly the home-manager
# definitions the Clan module writes.
fun onix =>
  let is_relative_path = fun path =>
    std.is_string path
    && path != ""
    && std.string.substring 0 1 path != "/"
    && !(std.array.elem ".." (std.string.split "/" path))
  in
  let is_profile_name = fun name => std.is_string name && std.string.is_match "^[A-Za-z0-9_][A-Za-z0-9_.-]*$" name in
  ({
    interface = {
      manifest = {
        name = "onix-core/home-manager-profiles",
        description = "Profile-based Home Manager configuration for a user.",
        categories = ["system", "home-manager"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "nixos",
            targets = ["nixos"],
            rationale = "Home Manager's NixOS module, configured through the sidecar adapter",
          },
          {
            namespace = "host",
            targets = ["onixos"],
            rationale = "OnixOS systemd hosts run the activation package Nix builds for the merged profiles",
          },
        ],
      },
      packages = ["bash"],
      host_packages = ["home-manager-activation"],
      roles.default = {
        username
          | doc "User the profiles apply to (home-manager.users.<username>). Required."
          | onix.UnixName
          | optional,
        profiles
          | doc "Profile directories under <profiles_base_path>/<username> to import."
          | Array (std.contract.from_predicate is_profile_name)
          | priority -5
          = [],
        home_state_version
          | doc "home.stateVersion; unset follows system.stateVersion (mkDefault)."
          | onix.NonEmptyString
          | optional,
        profiles_base_path
          | doc "Directory of per-user profile directories, relative to the onix-core flake root. inventory/core/default.nix injects ../home-profiles (inventory/home-profiles) into every Clan instance."
          | std.contract.from_predicate is_relative_path
          | priority -5
          = "inventory/home-profiles",
      },
    },

    impl = fun args =>
      let cfg = args.settings in
      let user_name =
        if std.record.has_field "username" cfg then
          cfg.username
        else
          std.fail_with "home-manager-profiles instance %{args.instance_name}: settings.username is required"
      in
      {
        output.nixos.onix.homeManagerProfiles."%{args.instance_name}" = {
          username = user_name,
          profiles = cfg.profiles,
          profilesBasePath = cfg.profiles_base_path,
          homeStateVersion = if std.record.has_field "home_state_version" cfg then cfg.home_state_version else null,
        },
        # Nix builds the merged profiles into one activation package (the index's
        # home-manager-activation); a host generation runs it once per user at
        # boot, before user sessions start, as Home Manager's NixOS module does.
        output.host = {
          # The activation package ends by realising its generation and adding GC
          # roots with `nix-store --realise … --add-root …`. A systemd host has no
          # Nix daemon and a read-only store, so the store cannot record validity;
          # the two operations reduce to "the path is in the store" and "link the
          # root", which this shim does.
          files."onixos/bin/nix-store" = {
            mode = "0755",
            text = m%"
              #!%{args.package_paths.bash}/bin/bash
              set -euo pipefail
              path=""
              root=""
              while [ $# -gt 0 ]; do
                case "$1" in
                  --realise) path="$2"; shift 2 ;;
                  --add-root) root="$2"; shift 2 ;;
                  *) shift ;;
                esac
              done
              if [ -n "$path" ]; then
                if [ ! -e "$path" ]; then
                  echo "nix-store: $path is not in the store" >&2
                  exit 1
                fi
                if [ -n "$root" ]; then
                  mkdir -p "$(dirname "$root")"
                  ln -sfn "$path" "$root"
                fi
                printf '%s\n' "$path"
              fi
            "%,
          },
          units."home-manager-%{user_name}.service" = {
            sections = {
              Unit = {
                Description = "Home Manager environment for %{user_name}",
                Before = "systemd-user-sessions.service",
                RequiresMountsFor = "/home/%{user_name}",
              },
              Service = {
                Type = "oneshot",
                User = user_name,
                Environment = [
                  "HOME=/home/%{user_name}",
                  "HOME_MANAGER_BACKUP_EXT=hm-bak",
                  "PATH=/etc/onixos/bin:/run/current-system/sw/bin:/usr/bin:/bin",
                ],
                ExecStart = "%{args.package_paths."home-manager-activation"}/activate",
                RemainAfterExit = "yes",
              },
            },
            wanted_by = ["multi-user.target"],
          },
        },
      },

    tests | not_exported =
      let run = fun instance overrides =>
        (
          impl (
            onix.testing.mock_args {
              service = "home-manager-profiles",
              role_name = 'default,
              settings = interface.roles.default & overrides,
              instance_name = instance,
              machine_name = "aspen2",
            }
          )
        ).output.nixos.onix.homeManagerProfiles."%{instance}"
      in
      [
        run "hm-server" { username = "brittonr", profiles = ["base", "dev"] } == { username = "brittonr", profiles = ["base", "dev"], profilesBasePath = "inventory/home-profiles", homeStateVersion = null },
        (run "hm-desktop" { username = "brittonr", home_state_version = "26.05" }).homeStateVersion == "26.05",
        (run "hm-empty" { username = "brittonr" }).profiles == [],
        is_relative_path "inventory/home-profiles",
        !(is_relative_path "/nix/store/x-source/inventory/home-profiles"),
        !(is_relative_path "inventory/../secrets"),
        is_profile_name "herdr",
        !(is_profile_name "../base"),
        !(is_profile_name "base/x"),
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
