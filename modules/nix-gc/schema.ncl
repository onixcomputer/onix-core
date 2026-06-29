# nix-gc settings schema — single source of truth.
#
# Consumed by:
#   - Nix module (default.nix) via mk-settings.nix for interface and defaults
#   - settings-contracts.ncl for inventory validation
{
  default = {
    retentionDays = {
      type = "number",
      default = 30,
      description = "Delete generations older than this many days",
    },
    schedule = {
      type = "string",
      default = "weekly",
      description = "When to run GC (systemd calendar format)",
    },
    useFastGc = {
      type = "bool",
      default = true,
      description = "Use Mic92 fast-nix-gc services instead of stock nix.gc/nix.optimise timers",
    },
    ensureFree = {
      type = "nullable_string",
      default = null,
      description = "Free space target for fast-nix-gc, e.g. 50G or 20%",
    },
    keepRecent = {
      type = "nullable_string",
      default = null,
      description = "Keep paths registered within this recent window, e.g. 1d",
    },
    noVacuum = {
      type = "bool",
      default = false,
      description = "Skip fast-nix-gc SQLite VACUUM after deletion",
    },
    gcRootsDirs = {
      type = "array_string",
      default = [],
      description = "Extra directories to scan for GC roots",
    },
    extraArgs = {
      type = "array_string",
      default = [],
      description = "Additional arguments passed to fast-nix-gc",
    },
    optimizeStore = {
      type = "bool",
      default = true,
      description = "Enable automatic store optimization (hard-link deduplication)",
    },
    autoOptimise = {
      type = "bool",
      default = true,
      description = "Optimize during each build (slight overhead, continuous benefit)",
    },
    optimizeSchedule = {
      type = "array_string",
      default = ["04:00"],
      description = "When to run full store optimization",
    },
  },
}
