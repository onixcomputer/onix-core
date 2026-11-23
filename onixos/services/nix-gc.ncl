# Automatic Nix store garbage collection and store optimisation.
#
# Port of onix-core's Clan nix-gc service (modules/nix-gc): same settings,
# defaults and NixOS output. Mic92's fast-nix-gc NixOS module comes from the
# sidecar nix-gc.nix; use_fast_gc = false falls back to the stock nix.gc and
# nix.optimise timers. Both run at idle priority.
fun onix =>
  let nixos = import "../lib/nixos.ncl" in
  let idle_priority = fun unit =>
    {
      systemd.services."%{unit}".serviceConfig = {
        CPUSchedulingPolicy = nixos.mk_force "idle",
        IOSchedulingClass = "idle",
        Nice = 19,
      },
    }
  in
  ({
    interface = {
      manifest = {
        name = "onix-core/nix-gc",
        description = "Automatic Nix store garbage collection and optimisation.",
        categories = ["nix", "maintenance"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "nixos",
            targets = ["nixos"],
            rationale = "Nix daemon garbage collection and optimisation are NixOS services",
          },
        ],
      },
      roles.default = {
        retention_days
          | doc "Delete generations older than this many days."
          | onix.PositiveInteger
          | priority -5
          = 30,
        schedule
          | doc "When to collect garbage (systemd calendar format)."
          | onix.NonEmptyString
          | priority -5
          = "weekly",
        use_fast_gc
          | doc "Use Mic92's fast-nix-gc services instead of the stock nix.gc and nix.optimise timers."
          | Bool
          | priority -5
          = true,
        ensure_free
          | doc "Free-space target for fast-nix-gc, e.g. 50G or 20%."
          | onix.NonEmptyString
          | optional,
        keep_recent
          | doc "Keep paths registered within this window, e.g. 1d."
          | onix.NonEmptyString
          | optional,
        no_vacuum
          | doc "Skip fast-nix-gc's SQLite VACUUM after deletion."
          | Bool
          | priority -5
          = false,
        gc_roots_dirs
          | doc "Extra directories to scan for GC roots."
          | Array onix.NonEmptyString
          | priority -5
          = [],
        extra_args
          | doc "Additional arguments passed to fast-nix-gc."
          | Array String
          | priority -5
          = [],
        optimize_store
          | doc "Run full store optimisation (hard-link deduplication) on a schedule."
          | Bool
          | priority -5
          = true,
        auto_optimise
          | doc "Optimise during each build."
          | Bool
          | priority -5
          = true,
        optimize_schedule
          | doc "When to run full store optimisation (systemd calendar format)."
          | Array onix.NonEmptyString
          | priority -5
          = ["04:00"],
      },
    },

    impl = fun args =>
      let cfg = args.settings in
      let delete_older_than = "%{std.to_string cfg.retention_days}d" in
      let or_null = fun field => if std.record.has_field field cfg then cfg."%{field}" else null in
      let fast =
        {
          services.fast-nix-gc = {
            enable = true,
            automatic = true,
            dates = cfg.schedule,
            deleteOlderThan = delete_older_than,
            ensureFree = or_null "ensure_free",
            keepRecent = or_null "keep_recent",
            noVacuum = cfg.no_vacuum,
            gcRootsDirs = cfg.gc_roots_dirs,
            extraArgs = cfg.extra_args,
          },
          services.fast-nix-optimise = {
            enable = cfg.optimize_store,
            automatic = cfg.optimize_store,
            dates = cfg.optimize_schedule,
          },
          nix.gc.automatic = nixos.mk_force false,
          nix.optimise.automatic = nixos.mk_force false,
        }
        & idle_priority "fast-nix-gc"
        & (if cfg.optimize_store then idle_priority "fast-nix-optimise" else {})
      in
      let stock =
        {
          nix.gc = {
            automatic = true,
            dates = cfg.schedule,
            options = "--delete-older-than %{delete_older_than}",
          },
          nix.optimise = if cfg.optimize_store then { automatic = true, dates = cfg.optimize_schedule } else {},
        }
        & idle_priority "nix-gc"
      in
      {
        output.nixos =
          { nix.settings.auto-optimise-store = cfg.auto_optimise }
          & (if cfg.use_fast_gc then fast else stock),
      },

    tests | not_exported =
      let defaults = interface.roles.default in
      let run = fun overrides =>
        (impl (onix.testing.mock_args { service = "nix-gc", role_name = 'default, settings = defaults & overrides })).output.nixos
      in
      let fast = run {} in
      let stock = run { use_fast_gc = false, optimize_store = false } in
      [
        fast.services.fast-nix-gc.deleteOlderThan == "30d",
        fast.services.fast-nix-gc.ensureFree == null,
        (run { ensure_free = "50G" }).services.fast-nix-gc.ensureFree == "50G",
        # fast-nix-gc replaces the stock timers.
        fast.nix.gc.automatic.content == false,
        fast.systemd.services.fast-nix-optimise.serviceConfig.Nice == 19,
        !(std.record.has_field "fast-nix-optimise" (run { optimize_store = false }).systemd.services),
        stock.nix.gc.options == "--delete-older-than 30d",
        !(std.record.has_field "services" stock),
        stock.nix.optimise == {},
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
