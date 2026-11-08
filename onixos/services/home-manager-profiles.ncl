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
            rationale = "The host producer builds filtered Home Manager profile and activation artifacts; target activation runs without Nix",
          },
        ],
      },
      packages = ["bash", "coreutils", "systemd"],
      host_packages = ["home-manager-activation", "home-manager-profile"],
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
        # The host producer builds the same filtered Home Manager package set
        # into both artifacts: activation retains config/unit activation, while
        # profile is installed at the NixOS useUserPackages path before
        # activation. Repeated profile instances for one user deliberately emit
        # identical user-keyed HostOutput fields.
        output.host = {
          # NixOS normally links this buildEnv at
          # /etc/profiles/per-user/<user>. Install that already-built closure
          # directly; do not claim packages were installed by activation alone.
          files."onixos/home-manager-profile.sh" = {
            mode = "0755",
            text = m%"
              #!%{args.package_paths.bash}/bin/bash
              set -euo pipefail
              profile="$1"
              user="$2"
              profile_root="/etc/profiles/per-user"
              target="$profile_root/$user"
              if [[ ! -d "$profile/bin" ]]; then
                echo "Home Manager executable profile is unavailable: $profile" >&2
                exit 1
              fi
              %{args.package_paths.coreutils}/bin/mkdir -p "$profile_root"
              if [[ -e "$target" && ! -L "$target" ]]; then
                echo "Refusing to replace unmanaged Home Manager profile path: $target" >&2
                exit 1
              fi
              if [[ -L "$target" ]]; then
                current="$(%{args.package_paths.coreutils}/bin/readlink "$target")"
                if [[ "$current" == "$profile" ]]; then
                  exit 0
                fi
                case "$current" in
                  /nix/store/*) ;;
                  *)
                    echo "Refusing to replace non-store Home Manager profile link: $target -> $current" >&2
                    exit 1
                    ;;
                esac
              fi
              temporary="$profile_root/.${user}.onixos-$$"
              trap '"%{args.package_paths.coreutils}/bin/rm" -f "$temporary"' EXIT
              %{args.package_paths.coreutils}/bin/ln -s "$profile" "$temporary"
              %{args.package_paths.coreutils}/bin/mv -Tf "$temporary" "$target"
              trap - EXIT
            "%,
          },
          # The host producer supplies a Nix-command-free activation artifact retaining
          # the complete Home Manager generation payload.
          files."onixos/home-manager-activate.sh" = {
            mode = "0755",
            text = m%"
              #!%{args.package_paths.bash}/bin/bash
              set -euo pipefail
              package="$1"
              state="$HOME/.local/state/onixos/home-manager"
              %{args.package_paths.coreutils}/bin/mkdir -p "$state"
              export newGenPath="$package"
              export hmStatePath="${XDG_STATE_HOME:-$HOME/.local/state}/home-manager"
              export hmDataPath="${XDG_DATA_HOME:-$HOME/.local/share}/home-manager"
              # The producer drops Home Manager's setupVars, which locates the Nix
              # profile and GC roots. This host keeps neither, so those globals are
              # defined and empty; activation still reports them under set -u.
              export genProfilePath="" newGenGcPath="" currentGenGcPath="" legacyGenGcPath=""
              # This OnixOS pointer tracks old managed home-files only; it is
              # not a Nix profile or garbage-collection root.
              if old_generation="$(%{args.package_paths.coreutils}/bin/readlink -e "$state/current-generation")"; then
                if [[ -d "$old_generation/home-files" ]]; then
                  export oldGenPath="$old_generation"
                fi
              fi
              "$package/activate" --driver-version 1
              temporary="$state/.current-generation-$$"
              trap '"%{args.package_paths.coreutils}/bin/rm" -f "$temporary"' EXIT
              %{args.package_paths.coreutils}/bin/ln -s "$package" "$temporary"
              %{args.package_paths.coreutils}/bin/mv -Tf "$temporary" "$state/current-generation"
              trap - EXIT
            "%,
          },
          units."home-manager-profile-%{user_name}.service" = {
            sections = {
              Unit = {
                Description = "Install Home Manager package profile for %{user_name}",
                Before = "home-manager-%{user_name}.service",
                RequiresMountsFor = "/nix/store",
              },
              Service = {
                Type = "oneshot",
                User = "root",
                ExecStart = "/etc/onixos/home-manager-profile.sh %{args.package_paths."home-manager-profile"} %{user_name}",
                RemainAfterExit = "yes",
              },
            },
            wanted_by = ["multi-user.target"],
          },
          units."home-manager-%{user_name}.service" = {
            sections = {
              Unit = {
                Description = "Home Manager environment for %{user_name}",
                Before = "systemd-user-sessions.service",
                Requires = "home-manager-profile-%{user_name}.service",
                After = "home-manager-profile-%{user_name}.service",
                RequiresMountsFor = "/home/%{user_name} /nix/store",
              },
              Service = {
                X-StopIfChanged = "false",
                Type = "oneshot",
                User = user_name,
                Environment = ["HOME=/home/%{user_name}", "HOME_MANAGER_BACKUP_EXT=hm-bak", "QT_QPA_PLATFORM=offscreen"],
                ExecStart = "/etc/onixos/home-manager-activate.sh %{args.package_paths."home-manager-activation"}",
                RemainAfterExit = "yes",
                SyslogIdentifier = "hm-activate-%{user_name}",
                TimeoutStartSec = "5m",
              },
            },
            wanted_by = ["multi-user.target"],
          },
          user_units."systemd-tmpfiles-setup.service" = {
            sections = {
              Unit = {
                Description = "Create User Files and Directories",
                Documentation = "man:tmpfiles.d(5) man:systemd-tmpfiles(8)",
                DefaultDependencies = "no",
                Conflicts = "shutdown.target",
                Before = "basic.target shutdown.target",
                RefuseManualStop = "yes",
              },
              Service = {
                Type = "oneshot",
                RemainAfterExit = "yes",
                ExecStart = "%{args.package_paths.systemd}/bin/systemd-tmpfiles --user --create --remove --boot",
                SuccessExitStatus = "DATAERR",
              },
            },
            wanted_by = ["basic.target"],
          },
          user_units."systemd-tmpfiles-clean.service" = {
            sections = {
              Unit = {
                Description = "Cleanup of User's Temporary Files and Directories",
                Documentation = "man:tmpfiles.d(5) man:systemd-tmpfiles(8)",
                DefaultDependencies = "no",
                Conflicts = "shutdown.target",
                Before = "basic.target shutdown.target",
              },
              Service = {
                Type = "oneshot",
                ExecStart = "%{args.package_paths.systemd}/bin/systemd-tmpfiles --user --clean",
                SuccessExitStatus = "DATAERR",
                IOSchedulingClass = "idle",
                Slice = "background.slice",
              },
            },
          },
          user_units."systemd-tmpfiles-clean.timer" = {
            sections = {
              Unit = {
                Description = "Daily Cleanup of User's Temporary Directories",
                Documentation = "man:tmpfiles.d(5) man:systemd-tmpfiles(8)",
              },
              Timer = { OnStartupSec = "5min", OnUnitActiveSec = "1d" },
            },
            wanted_by = ["timers.target"],
          },
          user_units."capsule@.target" = {
            sections = {
              Unit = {
                Description = "Main Capsule Target for %i",
                Documentation = "man:systemd.special(7)",
                Requires = "basic.target",
                After = "basic.target",
                AllowIsolate = "yes",
              },
            },
          },
          units."capsule.slice" = {
            sections = {
              Unit = {
                Description = "Capsule Slice",
                Documentation = "man:systemd.special(7)",
                Before = "slices.target",
              },
            },
          },
          units."capsule@.service" = {
            sections = {
              Unit = {
                Description = "Capsule Service Manager for %i",
                Documentation = "man:capsule@.service(5)",
                After = "dbus.service systemd-oomd.service",
              },
              Service = {
                User = "c-%i",
                DynamicUser = "yes",
                Type = "notify-reload",
                ExecStart = "%{args.package_paths.systemd}/lib/systemd/systemd --user --unit=capsule@%i.target",
                Environment = ["HOME=/var/lib/capsules/%i", "XDG_RUNTIME_DIR=/run/capsules/%i"],
                StateDirectory = "capsules/%i",
                RuntimeDirectory = "capsules/%i",
                LogExtraFields = "CAPSULE=%i",
                Slice = "capsule.slice",
                ReloadSignal = "RTMIN+25",
                KillMode = "mixed",
                Delegate = ["pids", "memory", "cpu"],
                DelegateSubgroup = "init.scope",
                TasksMax = "infinity",
                TimeoutStopSec = "120s",
                KeyringMode = "inherit",
                OOMScoreAdjust = "100",
                MemoryPressureWatch = "skip",
              },
            },
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
