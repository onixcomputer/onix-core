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
