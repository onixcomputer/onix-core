# niks3 binary cache: uploader role.
#
# Port of the uploader role of onix-core's Clan niks3 service (modules/niks3):
# same settings, defaults and NixOS output, and the shared niks3-<instance>-api
# generator. The sidecar niks3.nix imports niks3's niks3-auto-upload NixOS
# module and adds niks3-hook and the no-op post-build hook to the package set.
# The server role (aspen1) is not ported.
#
# Where Nickel cannot follow Clan:
# - Clan reads the cache key from vars/shared/niks3-<instance>-storage/
#   signing-key-public/value. That artifact belongs to this module's server
#   role, and OnixOS passes a module only the public values declared by modules
#   evaluated before it, so the key is the setting trusted_public_key.
# - Clan gates the queue metric on services.prometheus.exporters.node.enable;
#   queue_metrics carries that machine fact.
# - The drain guard and the metric writer run as unit scripts (preStart and
#   script with `path`) instead of separate store scripts.
fun onix =>
  let nixlib = import "../lib/nixos.ncl" in
  let uploader_group = "niks3-uploaders" in
  let queue_database = "/var/lib/niks3-hook/upload-queue.db" in
  let queue_metric_directory = "/var/lib/prometheus-node-exporter-text-files" in
  let queue_metric_file = "%{queue_metric_directory}/niks3-upload-queue.prom" in
  let queue_metric_interval = "60s" in
  let shell_quote = fun value => "'%{std.string.replace "'" "'\\''" value}'" in
  let guard_script = fun urls =>
    let probes =
      urls
      |> std.array.map (fun url =>
        "curl --fail --silent --show-error --max-time 3 --output /dev/null %{shell_quote url}"
      )
    in
    std.string.join "\n" (["set -eu"] @ probes)
  in
  let queue_metric_script = fun node =>
    m%%"
      set -o errexit -o nounset -o pipefail
      count=0
      if test -f %%{shell_quote queue_database}; then
        count="$(sqlite3 -readonly %%{shell_quote queue_database} 'select count(*) from upload_queue;')"
      fi
      temporary_file="$(mktemp %%{shell_quote "%{queue_metric_directory}/.niks3-upload-queue.XXXXXX"})"
      trap 'rm -f "$temporary_file"' EXIT HUP INT TERM
      {
        echo '# HELP onix_niks3_upload_queue_paths Durable store paths waiting for maintenance upload.'
        echo '# TYPE onix_niks3_upload_queue_paths gauge'
        printf 'onix_niks3_upload_queue_paths{node="%s"} %s\n' %%{shell_quote node} "$count"
      } > "$temporary_file"
      chmod 0644 "$temporary_file"
      mv "$temporary_file" %%{shell_quote queue_metric_file}
    "%%
  in
  ({
    interface = {
      manifest = {
        name = "onix-core/niks3",
        description = "Tailnet-only niks3 Nix binary cache: crash-safe post-build uploader.",
        categories = ["nix", "cache"],
      },
      portability = {
        status = 'platform_specific,
        requires.typed_namespaces = ["artifacts", "artifact_wiring"],
        platform_leaves = [
          {
            namespace = "nixos",
            targets = ["nixos"],
            rationale = "niks3-auto-upload, nix.conf and systemd units are NixOS services",
          },
        ],
      },
      packages = [
        "onix-core-niks3-hook",
        "onix-core-niks3-post-build-upload-disabled",
        "curl",
        "sqlite",
      ],
      roles.uploader = {
        server_url
          | doc "Private niks3 upload endpoint."
          | onix.Url
          | priority -5
          = "http://127.0.0.1:39400",
        automatic_uploads
          | doc "Activate the post-build queue and socket automatically."
          | Bool
          | priority -5
          = false,
        maintenance_marker
          | doc "Runtime marker required for guarded manual drains."
          | onix.Path
          | priority -5
          = "/run/niks3-maintenance-window",
        maintenance_guard_urls
          | doc "Health URLs that must pass before manual drain startup."
          | Array onix.Url
          | priority -5
          = [],
        batch_size
          | doc "Store paths per upload batch."
          | onix.PositiveInteger
          | priority -5
          = 50,
        idle_exit_timeout_seconds
          | doc "Idle exit timeout; zero keeps the daemon resident."
          | onix.NonNegativeInteger
          | priority -5
          = 0,
        max_concurrent_uploads
          | doc "Bounded concurrent upload count."
          | onix.PositiveInteger
          | priority -5
          = 8,
        verify_s3_integrity
          | doc "Verify RustFS objects before skipping uploads."
          | Bool
          | priority -5
          = true,
        trusted_public_key
          | doc "Public signing key of the cache (the niks3 server's niks3-<instance>-storage/signing-key-public). Unset: no extra trusted key, as in Clan before the key exists."
          | onix.NixPublicKey
          | optional,
        queue_metrics
          | doc "The machine runs the Prometheus node exporter: export the durable upload-queue depth through its textfile collector (Clan: services.prometheus.exporters.node.enable)."
          | Bool
          | priority -5
          = true,
      },
    },

    impl = fun args =>
      let cfg = args.settings in
      let manual = !cfg.automatic_uploads in
      let api_artifact = "niks3-%{args.instance_name}-api" in
      let base = {
        assertions = [
          {
            assertion = cfg.automatic_uploads || cfg.maintenance_guard_urls != [],
            message = "niks3 manual uploader mode requires maintenanceGuardUrls",
          },
        ],
        users.groups."%{uploader_group}" = {},
        nix.settings =
          {
            extra-substituters = [cfg.server_url],
            extra-trusted-public-keys =
              if std.record.has_field "trusted_public_key" cfg then [cfg.trusted_public_key] else [],
          }
          & (
            if manual then
              { post-build-hook = nixlib.mk_force args.packages.onix-core-niks3-post-build-upload-disabled }
            else
              {}
          ),
        services.niks3-auto-upload = {
          enable = true,
          package = args.packages.onix-core-niks3-hook,
          serverUrl = cfg.server_url,
          batchSize = cfg.batch_size,
          idleExitTimeout = cfg.idle_exit_timeout_seconds,
          maxConcurrentUploads = cfg.max_concurrent_uploads,
          verifyS3Integrity = cfg.verify_s3_integrity,
        },
      }
      in
      let manual_drain = {
        systemd.sockets.niks3-auto-upload.wantedBy = nixlib.mk_force [],
        systemd.services.niks3-auto-upload = {
          unitConfig.ConditionPathExists = cfg.maintenance_marker,
          path = [args.packages.curl],
          preStart = guard_script cfg.maintenance_guard_urls,
          serviceConfig.TimeoutStopSec = "30s",
        },
      }
      in
      let queue_metric = {
        services.prometheus.exporters.node.extraFlags = ["--collector.textfile.directory=%{queue_metric_directory}"],
        systemd.tmpfiles.rules = ["d %{queue_metric_directory} 0755 root root - -"],
        systemd.services.niks3-queue-metrics = {
          description = "Export durable niks3 queue depth",
          path = [args.packages.sqlite],
          script = queue_metric_script args.machine_name,
          serviceConfig = {
            Type = "oneshot",
            NoNewPrivileges = true,
            PrivateTmp = true,
            ProtectHome = true,
            ProtectSystem = "strict",
            ReadWritePaths = [queue_metric_directory],
            CapabilityBoundingSet = "",
            LockPersonality = true,
            RestrictAddressFamilies = ["AF_UNIX"],
          },
        },
        systemd.timers.niks3-queue-metrics = {
          description = "Refresh durable niks3 queue depth",
          wantedBy = ["timers.target"],
          timerConfig = {
            OnBootSec = queue_metric_interval,
            OnUnitActiveSec = queue_metric_interval,
            Unit = "niks3-queue-metrics.service",
          },
        },
      }
      in
      {
        output =
          {
            nixos =
              base
              & (if manual then manual_drain else {})
              & (if cfg.queue_metrics then queue_metric else {}),
            artifact_wiring = [
              onix.artifact_wiring {
                artifact = api_artifact,
                file = "api-token",
                nixos_option = "services.niks3-auto-upload.authTokenFile",
              },
            ],
          }
          & onix.artifact_declaration {
            name = api_artifact,
            shared = true,
            files."api-token" = onix.artifact_file { owner = "root", group = uploader_group, mode = "0440" },
            generator_script = m%"
              openssl rand -hex 32 > "$out/api-token"
            "%,
            description = "niks3 API token for the %{args.instance_name} cache uploaders",
          },
      },

    tests | not_exported =
      let defaults = interface.roles.uploader in
      let test_packages = {
        onix-core-niks3-hook = "hook-pkg",
        onix-core-niks3-post-build-upload-disabled = "noop-hook-pkg",
        curl = "curl-pkg",
        sqlite = "sqlite-pkg",
      }
      in
      let guards = ["http://100.100.103.95:39000/health", "http://100.100.103.95:39200/__celld/health"] in
      let aspen2 = {
        server_url = "http://100.100.103.95:39400",
        maintenance_guard_urls = guards,
        batch_size = 1,
        max_concurrent_uploads = 1,
        trusted_public_key = "onix-niks3-1:1Vg2qs7firQQJ/08DpDIXVBY41v6gPbHuwQlqr7EoQU=",
      }
      in
      let run = fun overrides =>
        (
          impl (
            onix.testing.mock_args {
              service = "niks3",
              role_name = 'uploader,
              settings = defaults & overrides,
              instance_name = "nix-cache",
              machine_name = "aspen2",
              packages = test_packages,
            }
          )
        ).output
      in
      let manual = run aspen2 in
      let automatic = run (aspen2 & { automatic_uploads = true }) in
      let without_key = run { maintenance_guard_urls = guards } in
      let without_metrics = run (aspen2 & { queue_metrics = false }) in
      let unit = manual.nixos.systemd.services.niks3-auto-upload in
      let api = manual.artifacts."niks3-nix-cache-api" in
      let wiring = std.array.first manual.artifact_wiring in
      [
        defaults.server_url == "http://127.0.0.1:39400",
        defaults.batch_size == 50,
        defaults.max_concurrent_uploads == 8,
        !defaults.automatic_uploads,
        manual.nixos.services.niks3-auto-upload.package == "hook-pkg",
        manual.nixos.services.niks3-auto-upload.batchSize == 1,
        manual.nixos.services.niks3-auto-upload.idleExitTimeout == 0,
        manual.nixos.services.niks3-auto-upload.verifyS3Integrity,
        manual.nixos.nix.settings.extra-substituters == ["http://100.100.103.95:39400"],
        manual.nixos.nix.settings.extra-trusted-public-keys == ["onix-niks3-1:1Vg2qs7firQQJ/08DpDIXVBY41v6gPbHuwQlqr7EoQU="],
        without_key.nixos.nix.settings.extra-trusted-public-keys == [],
        # Manual drains: no post-build queueing, no socket at boot, guarded start.
        manual.nixos.nix.settings.post-build-hook.content == "noop-hook-pkg",
        manual.nixos.nix.settings.post-build-hook.priority == 50,
        manual.nixos.systemd.sockets.niks3-auto-upload.wantedBy.content == [],
        unit.unitConfig.ConditionPathExists == "/run/niks3-maintenance-window",
        unit.serviceConfig.TimeoutStopSec == "30s",
        unit.path == ["curl-pkg"],
        std.string.contains "--max-time 3 --output /dev/null 'http://100.100.103.95:39200/__celld/health'" unit.preStart,
        !(std.record.has_field "post-build-hook" automatic.nixos.nix.settings),
        !(std.record.has_field "niks3-auto-upload" automatic.nixos.systemd.services),
        !(std.record.has_field "sockets" automatic.nixos.systemd),
        (std.array.first manual.nixos.assertions).assertion,
        !(std.array.first (run {}).nixos.assertions).assertion,
        # Queue metric through the node exporter's textfile collector.
        manual.nixos.services.prometheus.exporters.node.extraFlags == ["--collector.textfile.directory=/var/lib/prometheus-node-exporter-text-files"],
        manual.nixos.systemd.tmpfiles.rules == ["d /var/lib/prometheus-node-exporter-text-files 0755 root root - -"],
        manual.nixos.systemd.timers.niks3-queue-metrics.timerConfig.OnUnitActiveSec == "60s",
        manual.nixos.systemd.services.niks3-queue-metrics.path == ["sqlite-pkg"],
        std.string.contains "%s\\n' 'aspen2' \"$count\"" manual.nixos.systemd.services.niks3-queue-metrics.script,
        !(std.record.has_field "prometheus" without_metrics.nixos.services),
        !(std.record.has_field "niks3-queue-metrics" without_metrics.nixos.systemd.services),
        !(std.record.has_field "timers" without_metrics.nixos.systemd),
        # Shared API token, readable by the uploader group.
        manual.nixos.users.groups."niks3-uploaders" == {},
        api.shared,
        api.files."api-token".secret,
        api.files."api-token".owner == "root",
        api.files."api-token".group == "niks3-uploaders",
        api.files."api-token".mode == "0440",
        std.string.contains "openssl rand -hex 32 > \"$out/api-token\"" api.generator_script,
        wiring.artifact == "niks3-nix-cache-api",
        wiring.nixos_option == "services.niks3-auto-upload.authTokenFile",
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
