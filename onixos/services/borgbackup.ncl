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
        ],
      },
      packages = ["networkmanager"],
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
      let aspen2 = run (extras & { wait_for_unmetered_network = true }) in
      let no_wait = run extras in
      let job = aspen2.nixos.services.borgbackup.jobs.aspen1 in
      let unit = aspen2.nixos.systemd.services."borgbackup-job-aspen1" in
      let wired = fun output option =>
        output.artifact_wiring |> std.array.filter (fun entry => entry.nixos_option == option)
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
      let artifact = aspen2.artifacts.borgbackup in
      [
        # clan-core client defaults
        client.start_at == "*-*-* 01:00:00",
        client.exclude == [],
        client.state == {},
        client.destinations == {},
        client.server_directory == "/var/lib/borgbackup",
        !client.wait_for_unmetered_network,
        # The job clan-core builds from the server and the state folders
        job.repo == "borg@aspen1:.",
        job.paths == ["/etc/NetworkManager", "/home", "/var", "/root"],
        job.exclude == ["*.pyc", "/var/log"],
        job.startAt == "*-*-* 01:00:00",
        job.persistentTimer,
        job.compression == "auto,zstd",
        job.encryption == { mode = "repokey" },
        job.prune.keep == { within = "1d", daily = 7, weekly = 4, monthly = 0 },
        job.environment == { BORG_RELOCATED_REPO_ACCESS_IS_OK = "yes" },
        (run (extras & { server_address = "10.10.10.1" })).nixos.services.borgbackup.jobs.aspen1.repo == "borg@10.10.10.1:.",
        # Key and passphrase reach borg through the artifact paths
        (std.array.first (wired aspen2 "services.borgbackup.jobs.aspen1.environment.BORG_RSH")).value == "ssh -i __PATH__ -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=Yes",
        (std.array.first (wired aspen2 "services.borgbackup.jobs.aspen1.environment.BORG_RSH")).file == "borgbackup.ssh",
        (std.array.first (wired aspen2 "services.borgbackup.jobs.aspen1.encryption.passCommand")).value == "cat __PATH__",
        (std.array.first (wired aspen2 "services.borgbackup.jobs.aspen1.encryption.passCommand")).file == "borgbackup.repokey",
        # borgbackup-extras: wait for an unmetered NetworkManager connection
        std.string.contains "if nm-online --quiet 2>/dev/null &&" job.preHook,
        std.string.contains "! nmcli --terse --fields GENERAL.METERED dev show" job.preHook,
        unit.path == ["networkmanager-pkg"],
        !(std.record.has_field "preHook" no_wait.nixos.services.borgbackup.jobs.aspen1),
        !(std.record.has_field "path" no_wait.nixos.systemd.services."borgbackup-job-aspen1"),
        # No start or stop timeout
        unit.serviceConfig == { TimeoutStartSec = "infinity", TimeoutStopSec = "infinity" },
        # Folders in state-name order, each once
        more_state.nixos.services.borgbackup.jobs.aspen1.paths == ["/var/backup/db", "/home", "/etc/NetworkManager", "/var", "/root"],
        # External destinations
        offsite.nixos.services.borgbackup.jobs.offsite.repo == "ssh://borg@offsite.example/./aspen2",
        (std.array.first (wired offsite "services.borgbackup.jobs.offsite.environment.BORG_RSH")).value == "ssh -i __PATH__ -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=Yes -o PasswordAuthentication=no",
        offsite.nixos.services.borgbackup.jobs.aspen1.repo == "borg@backup.example:.",
        offsite.nixos.services.borgbackup.jobs.aspen1.environment.BORG_RSH == "ssh -p 2222",
        wired offsite "services.borgbackup.jobs.aspen1.environment.BORG_RSH" == [],
        # No state: nothing to back up, no job
        (run {}).nixos == { services.openssh.enable = true },
        (run {}).artifact_wiring == [],
        aspen2.nixos.services.openssh.enable,
        # Per-machine artifact named like the Clan generator
        !(std.record.has_field "shared" artifact),
        artifact.files."borgbackup.ssh".secret,
        artifact.files."borgbackup.repokey".secret,
        artifact.files."borgbackup.repokey".mode == "0400",
        !artifact.files."borgbackup.ssh.pub".secret,
        std.string.contains "ssh-keygen -t ed25519 -N \"\" -C \"\" -f \"$out\"/borgbackup.ssh" artifact.generator_script,
        std.string.contains "xkcdpass -n 6 -d -" artifact.generator_script,
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
