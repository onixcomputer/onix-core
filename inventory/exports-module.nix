# Extended exports module schema for cross-service discovery.
#
# The default clan-core exportsModule only defines a `networking` schema
# for VPN peer discovery. We extend it with a `serviceEndpoints` schema
# so monitoring services (Prometheus, Loki, Grafana) can discover each
# other's URLs without hardcoding hostnames or ports.
#
# Because `exportsModule` is typed as `deferredModule` with a `default`,
# providing our own definition replaces the default entirely. We must
# re-include the upstream networking schema here.
{ lib }:
{
  # ── Upstream networking schema (copied from clan-core top-level-interface.nix) ──
  options.networking = lib.mkOption {
    default = null;
    type = lib.types.nullOr (
      lib.types.submodule {
        options = {
          priority = lib.mkOption {
            type = lib.types.int;
            default = 1000;
            description = "Priority with which this network should be tried.";
          };
          module = lib.mkOption {
            type = lib.types.str;
            default = "clan_lib.network.direct";
            description = "The technology this network uses to connect to the target.";
          };
          peers = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule (
                { name, ... }:
                {
                  options = {
                    name = lib.mkOption {
                      type = lib.types.str;
                      default = name;
                    };
                    SSHOptions = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      default = [ ];
                    };
                    host = lib.mkOption {
                      description = "Host address of the peer.";
                      type = lib.types.attrTag {
                        plain = lib.mkOption {
                          type = lib.types.str;
                          description = "A plain value, which can be read directly from the config.";
                        };
                        var = lib.mkOption {
                          type = lib.types.submodule {
                            options = {
                              machine = lib.mkOption {
                                type = lib.types.str;
                                example = "jon";
                              };
                              generator = lib.mkOption {
                                type = lib.types.str;
                                example = "tor-ssh";
                              };
                              file = lib.mkOption {
                                type = lib.types.str;
                                example = "hostname";
                              };
                            };
                          };
                        };
                      };
                    };
                  };
                }
              )
            );
          };
        };
      }
    );
  };

  # ── Service endpoint discovery schema ──
  # Services export their endpoints here so other services can discover them.
  # Each entry is keyed by a logical service name (e.g. "prometheus", "loki").
  options.serviceEndpoints = lib.mkOption {
    default = { };
    description = "Service endpoints exported for cross-service discovery.";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          url = lib.mkOption {
            type = lib.types.str;
            description = "Full URL of the service endpoint (e.g. http://host:port).";
            example = "http://localhost:9090";
          };
          port = lib.mkOption {
            type = lib.types.port;
            description = "Port the service listens on.";
          };
        };
      }
    );
  };
}
