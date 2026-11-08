# BorgBackup client: nightly borg job to the backup server.
#
# Port of clan-core's borgbackup service, client role (clanServices/borgbackup
# at clan-core 86d72f39), plus onix-core's modules/borgbackup-extras, which the
# Clan instance attaches to every client (extraModules). The extras' state
# folders, unmetered-network wait and exclude list are instance settings
# (onixos/instances/borgbackup.ncl).
#
# Every destination (the server, plus optional external `destinations`) gets
# services.borgbackup.jobs.<name> exactly as clan-core builds it. The
# per-machine artifact `borgbackup` (the Clan generator) holds the SSH key and
# the repokey passphrase, wired into BORG_RSH and encryption.passCommand.
#
# `state` holds the folder sets Clan collected in clan.core.state. Clan's
# backup-provider plumbing is not ported: the clan.core.state registry, its
# state-commands package, the pre/post-backup hook runners around every job
# and the borgbackup-create/list/restore helpers exist for the `clan backups`
# CLI. No onix-core state defines a backup or restore script, so on aspen2
# the hook runners were no-ops. Use borg-job-<name> and
# `systemctl start borgbackup-job-<name>` directly.
fun onix =>
  let shell_arg = fun word =>
    if std.string.is_match "^[A-Za-z0-9,._+:@%/-]+$" word then
      word
    else
      "'%{std.string.replace "'" "'\\''" word}'"
  in
  let shell_args = fun words => words |> std.array.map shell_arg |> std.string.join " " in
  let internal_rsh = "ssh -i __PATH__ -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=Yes" in
  let external_rsh = "%{internal_rsh} -o PasswordAuthentication=no" in
  # Job names end up in artifact_wiring option paths, which must be Nix
  # identifiers (no dots, no leading digit).
  let job_name_pattern = "^[a-zA-Z_][a-zA-Z0-9_-]*$" in
  let JobName = std.contract.from_predicate (fun value => std.is_string value && std.string.is_match job_name_pattern value) in
  let keys_match = fun pattern =>
    std.contract.from_predicate (fun value =>
      std.is_record value
      && (std.record.fields value |> std.array.all (fun key => std.string.is_match pattern key))
    )
  in
  let DestinationNames = keys_match job_name_pattern in
  let StateNames = keys_match "^[a-zA-Z0-9_-]+$" in
  let DestinationName = std.contract.from_predicate (fun value => std.is_string value && std.string.is_match "^[a-zA-Z0-9._-]+$" value) in
  let Destination = {
    name
      | doc "Name used by borgbackup-list and its borg-job-<name> wrapper; defaults to the attribute name."
      | DestinationName
      | optional,
    repo
      | doc "Borg repository to back up to."
      | onix.NonEmptyString,
    rsh
      | doc "BORG_RSH; defaults to ssh with the borgbackup key, accept-new host keys, IdentitiesOnly and no password logins."
      | onix.NonEmptyString
      | optional,
  }
  in
  let State = {
    folders
      | doc "Folders holding this state; all of them are backed up."
      | Array onix.Path,
  }
  in
  let sorted_fields = fun record => record |> std.record.fields |> std.array.sort std.string.compare in
  let unique = fun values =>
    values
    |> std.array.fold_left (fun kept value => if std.array.elem value kept then kept else kept @ [value]) []
  in
  # modules/borgbackup-extras; NetworkManager comes from the unit PATH.
  let unmetered_network_hook =
    m%"
      # Wait for unmetered network (bounded: 30 attempts × 60s = 30 min max).
      # If network never becomes available/unmetered, skip this backup run —
      # the next timer invocation will retry.
      network_ready=false
      for _attempt in $(seq 1 30); do
        if nm-online --quiet 2>/dev/null &&
           ! nmcli --terse --fields GENERAL.METERED dev show 2>/dev/null | grep --quiet "yes"; then
          network_ready=true
          break
        fi
        echo "Waiting for unmetered network... ($_attempt/30)"
        sleep 60
      done

      if [ "$network_ready" = "false" ]; then
        echo "Timed out waiting for unmetered network after 30 minutes, skipping backup"
        exit 0
      fi
    "%
    ++ "\n"
  in
  ({
    interface = {
      manifest = {
        name = "onix-core/borgbackup",
        description = "Nightly BorgBackup of machine state to the backup server.",
        categories = ["backup"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "nixos",
            targets = ["nixos"],
            rationale = "configures NixOS borgbackup jobs and their systemd units",
          },
          {
            namespace = "host",
            targets = ["onixos"],
            rationale = "runs the retained backup policy with placed credentials on systemd hosts",
          },
        ],
      },
      packages = ["networkmanager", "borgbackup", "openssh", "bash", "coreutils", "gnugrep", "systemd"],
      roles.client = {
        server
          | doc "Machine with the borgbackup server role (Clan: roles.server.machines); also the job name."
          | JobName,
        server_address
          | doc "Address that reaches the server (Clan server setting `address`); defaults to the server's machine name."
          | onix.NonEmptyString
          | optional,
        server_directory
          | doc "Repository root on the server (Clan server setting `directory`). The server keeps this client's repository in <server_directory>/<client> and changes into it for the client's key, so clients use borg@<server>:. and only the server role (not ported; aspen1 stays on Clan) reads this."
          | onix.Path
          | priority -5
          = "/var/lib/borgbackup",
        start_at
          | doc "When the backup runs (systemd OnCalendar)."
          | onix.NonEmptyString
          | priority -5
          = "*-*-* 01:00:00",
        destinations
          | doc "External destinations keyed by job name; a key equal to `server` replaces the server destination."
          | { _ : Destination }
          | DestinationNames
          | priority -5
          = {},
        exclude
          | doc "Paths and patterns excluded from every backup (borg --exclude-from); * is a wildcard."
          | Array String
          | priority -5
          = [],
        state
          | doc "Named folder sets to back up (the folders of Clan's clan.core.state entries). Without state there is no backup job."
          | { _ : State }
          | StateNames
          | priority -5
          = {},
        wait_for_unmetered_network
          | doc "Before each run, wait up to 30 minutes for NetworkManager to report an unmetered connection and skip the run otherwise (modules/borgbackup-extras). Needs NetworkManager."
          | Bool
          | priority -5
          = false,
      },
    },

    impl = fun args =>
      let cfg = args.settings in
      let server_host = if std.record.has_field "server_address" cfg then cfg.server_address else cfg.server in
      # clan-core: the server destination, then the external ones; an
      # external destination with the server's name replaces it.
      let internal =
        std.record.from_array [
          {
            field = cfg.server,
            value = { name = cfg.server, repo = "borg@%{server_host}:.", rsh = internal_rsh, wire_rsh = true },
          },
        ]
      in
      let external =
        cfg.destinations
        |> std.record.map (fun job_name dest =>
          {
            name = if std.record.has_field "name" dest then dest.name else job_name,
            repo = dest.repo,
            rsh = if std.record.has_field "rsh" dest then dest.rsh else external_rsh,
            wire_rsh = !(std.record.has_field "rsh" dest),
          }
        )
      in
      let all_destinations =
        (internal |> std.record.filter (fun job_name _dest => !(std.record.has_field job_name external)))
        & external
      in
      let job_names = sorted_fields all_destinations in
      let states =
        sorted_fields cfg.state
        |> std.array.map (fun state_name => { name = state_name, value = cfg.state."%{state_name}" })
      in
      let backup_paths = states |> std.array.flat_map (fun entry => entry.value.folders) |> unique in
      let job_config = fun job_name =>
        let dest = all_destinations."%{job_name}" in
        {
          services.borgbackup.jobs."%{job_name}" =
            {
              paths = backup_paths,
              exclude = cfg.exclude,
              repo = dest.repo,
              environment =
                { BORG_RELOCATED_REPO_ACCESS_IS_OK = "yes" }
                & (if dest.wire_rsh then {} else { BORG_RSH = dest.rsh }),
              compression = "auto,zstd",
              startAt = cfg.start_at,
              persistentTimer = true,
              encryption.mode = "repokey",
              prune.keep = { within = "1d", daily = 7, weekly = 4, monthly = 0 },
            }
            & (if cfg.wait_for_unmetered_network then { preHook = unmetered_network_hook } else {}),
          systemd.services."borgbackup-job-%{job_name}" =
            {
              # clan-core: let long backups and their hooks finish.
              serviceConfig = { TimeoutStartSec = "infinity", TimeoutStopSec = "infinity" },
            }
            & (if cfg.wait_for_unmetered_network then { path = [args.packages.networkmanager] } else {}),
        }
      in
      let wiring =
        job_names
        |> std.array.flat_map (fun job_name =>
          let dest = all_destinations."%{job_name}" in
          [
            onix.artifact_wiring {
              artifact = "borgbackup",
              file = "borgbackup.repokey",
              nixos_option = "services.borgbackup.jobs.%{job_name}.encryption.passCommand",
              value = "cat __PATH__",
            },
          ]
          @ (
            if dest.wire_rsh then
              [
                onix.artifact_wiring {
                  artifact = "borgbackup",
                  file = "borgbackup.ssh",
                  nixos_option = "services.borgbackup.jobs.%{job_name}.environment.BORG_RSH",
                  value = dest.rsh,
                },
              ]
            else
              []
          )
        )
      in
      let has_state = std.array.length states > 0 in
      let jobs = job_names |> std.array.fold_left (fun acc job_name => acc & job_config job_name) {} in
      {
        output =
          {
            nixos =
              { services.openssh.enable = true }
              & (if has_state then jobs else {}),
            artifact_wiring = if has_state then wiring else [],
          }
          & (
            # NixOS renders each job from services.borgbackup.jobs; a host
            # generation spells the same borg invocations, with the passphrase and
            # SSH key that the artifacts place under /run/artifacts/borgbackup.
            if !has_state then
              {}
            else
              let job_host = fun job_name =>
                let dest = all_destinations."%{job_name}" in
                let p = args.package_paths in
                let prefix = "%{args.machine_name}-%{job_name}" in
                let local_repo = std.string.is_match "^(/|\\.)" dest.repo || !(std.string.contains ":" dest.repo) in
                let environment = {
                  PATH = "%{p.borgbackup}/bin:%{p.openssh}/bin:%{p.networkmanager}/bin:%{p.coreutils}/bin:%{p.gnugrep}/bin",
                  BORG_REPO = dest.repo,
                  BORG_PASSCOMMAND = "%{p.coreutils}/bin/cat /run/artifacts/borgbackup/borgbackup.repokey",
                  BORG_RSH = std.string.replace "__PATH__" "/run/artifacts/borgbackup/borgbackup.ssh" dest.rsh,
                  BORG_RELOCATED_REPO_ACCESS_IS_OK = "yes",
                }
                in
                let exports = environment |> std.record.to_array |> std.array.map (fun entry => "export %{entry.field}=%{shell_arg entry.value}") |> std.string.join "\n" in
                {
                  files = {
                    "borgbackup/%{job_name}.exclude".text = std.string.join "\n" cfg.exclude ++ "\n",
                    "borgbackup/%{job_name}-command.sh" = {
                      mode = "0755",
                      text = m%"
                        #!%{p.bash}/bin/bash
                        %{exports}
                        exec %{p.borgbackup}/bin/borg "$@"
                      "%,
                    },
                    "borgbackup/%{job_name}.sh".text = m%"
                        set -euo pipefail
                        %{if cfg.wait_for_unmetered_network then unmetered_network_hook else ""}
                        archive=%{shell_arg prefix}-$(date +%Y-%m-%dT%H:%M:%S)
                        if ! borg list >/dev/null; then borg init --encryption repokey; fi
                        borg create --stats --compression auto,zstd --exclude-from /etc/borgbackup/%{job_name}.exclude "::$archive.failed" %{shell_args backup_paths}
                        borg rename "::$archive.failed" "$archive"
                        borg prune --list --glob-archives %{shell_arg (prefix ++ "*")} --keep-within 1d --keep-daily 7 --keep-weekly 4 --keep-monthly 0
                        borg compact
                      "%,
                  },
                  wrappers."borg-job-%{job_name}" = { source_file = "borgbackup/%{job_name}-command.sh", setuid = false },
                  units."borgbackup-job-%{job_name}.service" = {
                    sections = {
                      Unit = {
                        Description = "BorgBackup job %{job_name}",
                        RequiresMountsFor = std.string.join " " backup_paths,
                      },
                      Service = {
                        Type = "oneshot",
                        User = "root",
                        Group = "root",
                        Environment = environment |> std.record.to_array |> std.array.map (fun entry => "%{entry.field}=%{entry.value}"),
                        ExecStart = "%{p.systemd}/bin/systemd-inhibit --who=borgbackup --what=sleep --why='Scheduled backup' %{p.bash}/bin/bash /etc/borgbackup/%{job_name}.sh",
                        CPUSchedulingPolicy = "idle",
                        IOSchedulingClass = "idle",
                        PrivateTmp = "true",
                        ProtectSystem = "strict",
                        ReadWritePaths = ["/root/.config/borg", "/root/.cache/borg"] @ (if local_repo then [dest.repo] else []),
                        TimeoutStartSec = "infinity",
                        TimeoutStopSec = "infinity",
                      },
                    },
                  },
                  units."borgbackup-job-%{job_name}.timer" = {
                    sections = {
                      Unit = {
                        Description = "BorgBackup job %{job_name} timer",
                        After = "network-online.target",
                        Wants = "network-online.target",
                      },
                      Timer = { OnCalendar = cfg.start_at, Persistent = "true" },
                    },
                    wanted_by = ["timers.target"],
                  },
                }
              in
              {
                host =
                  {
                    packages = [args.package_paths.borgbackup],
                    tmpfiles = ["d /root/.config/borg 0700 root root -", "d /root/.cache/borg 0700 root root -"],
                  }
                  & (job_names |> std.array.map job_host |> std.array.fold_left (fun acc entry => acc & entry) {}),
              }
          )
          & onix.artifact_declaration {
            name = "borgbackup",
            files = {
              "borgbackup.ssh" = onix.artifact_file {},
              "borgbackup.ssh.pub" = onix.artifact_file { secret = false },
              "borgbackup.repokey" = onix.artifact_file {},
            },
            # Needs ssh-keygen and xkcdpass on PATH (Clan runtimeInputs).
            generator_script = m%"
              ssh-keygen -t ed25519 -N "" -C "" -f "$out"/borgbackup.ssh
              xkcdpass -n 6 -d - > "$out"/borgbackup.repokey
            "%,
            description = "BorgBackup SSH key and repository passphrase for %{args.machine_name}",
          },
      },

    tests | not_exported =
      let client = interface.roles.client in
      let run = fun overrides =>
        (
          impl (
            onix.testing.mock_args {
              service = "borgbackup",
              role_name = 'client,
              instance_name = "borgbackup",
              machine_name = "aspen2",
              settings = client & { server = "aspen1" } & overrides,
              packages = { networkmanager = "networkmanager-pkg" },
            }
          )
        ).output
      in
      # The aspen2 instance: borgbackup-extras' state folders and excludes.
      let extras = {
        state = {
          networkmanager.folders = ["/etc/NetworkManager"],
          system.folders = ["/home", "/var", "/root"],
        },
        exclude = ["*.pyc", "/var/log"],
      }
      in
      let more_state = run (extras & { state.db.folders = ["/var/backup/db", "/home"] }) in
      let offsite =
        run (
          extras
          & {
            destinations = {
              offsite = { repo = "ssh://borg@offsite.example/./aspen2" },
              aspen1 = { repo = "borg@backup.example:.", rsh = "ssh -p 2222" },
            },
          }
        )
      in
      [
        # Folders in state-name order, each once
        more_state.nixos.services.borgbackup.jobs.aspen1.paths == ["/var/backup/db", "/home", "/etc/NetworkManager", "/var", "/root"],
        # An explicit destination overrides the same-named server destination.
        offsite.nixos.services.borgbackup.jobs.aspen1.repo == "borg@backup.example:.",
        offsite.nixos.services.borgbackup.jobs.aspen1.environment.BORG_RSH == "ssh -p 2222",
        # No state: nothing to back up, no job
        (run {}).nixos == { services.openssh.enable = true },
        (run {}).artifact_wiring == [],
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
