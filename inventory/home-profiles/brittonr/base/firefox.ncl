# Firefox performance tuning — source of truth.
#
# Cache sizes, connection limits, DNS TTLs, and UI preferences.
# Maps to about:config keys via the Nix consumer.
#
# Consumed by: firefox.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/firefox.ncl
#   3. Commit .ncl
let Positive =
  std.contract.from_validator (match {
    value if std.is_number value && value > 0 => 'Ok,
    _ => 'Error { message = "must be a positive number" },
  }
  )
in

let NonNeg =
  std.contract.from_validator (match {
    value if std.is_number value && value >= 0 => 'Ok,
    _ => 'Error { message = "must be a non-negative number" },
  }
  )
in

{
  ui | { density | doc "0=normal, 1=compact, 2=touch" | NonNeg } = {
    density = 1,
  },

  cache
    | {
      canvasItems | doc "Max accelerated canvas cache items" | Positive,
      canvasSize | doc "Max accelerated canvas cache size (KB)" | Positive,
    }
    = {
      canvasItems = 8192,
      canvasSize = 1024,
    },

  dns
    | {
      cacheEntries | doc "Max DNS cache entries" | Positive,
      cacheExpiration | doc "DNS cache TTL (seconds)" | Positive,
    }
    = {
      cacheEntries = 10000,
      cacheExpiration = 86400,
    },

  network
    | {
      maxConnections | doc "Global HTTP connection limit" | Positive,
      maxPersistentPerServer | doc "Keep-alive connections per server" | Positive,
      maxUrgentStartExcessivePerHost | doc "Urgent request overflow per host" | Positive,
      speculativeParallelLimit | doc "Speculative connection limit" | NonNeg,
    }
    = {
      maxConnections = 1800,
      maxPersistentPerServer = 10,
      maxUrgentStartExcessivePerHost = 5,
      speculativeParallelLimit = 20,
    },

  privacy
    | {
      cookieBannerMode | doc "0=off, 1=reject-only, 2=reject-or-accept" | NonNeg,
    }
    = {
      cookieBannerMode = 2,
    },
}
