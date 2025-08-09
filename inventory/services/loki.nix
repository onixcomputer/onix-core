_: {
  instances = {
    # Loki log aggregation server
    "loki-blr" = {
      module.name = "loki";
      module.input = "self";
      roles.server = {
        tags."monitoring" = { };
        settings = {
          enablePromtail = true;

          # Direct Loki configuration using freeform options
          configuration = {
            auth_enabled = false;

            server = {
              http_listen_port = 3100;
              grpc_listen_port = 9096;
            };

            common = {
              instance_addr = "127.0.0.1";
              path_prefix = "/var/lib/loki";
              storage = {
                filesystem = {
                  chunks_directory = "/var/lib/loki/chunks";
                  rules_directory = "/var/lib/loki/rules";
                };
              };
              replication_factor = 1;
              ring = {
                kvstore = {
                  store = "inmemory";
                };
              };
            };

            schema_config = {
              configs = [
                {
                  from = "2020-10-24";
                  store = "tsdb";
                  object_store = "filesystem";
                  schema = "v13";
                  index = {
                    prefix = "index_";
                    period = "24h";
                  };
                }
              ];
            };

            ruler = {
              alertmanager_url = "http://localhost:9093";
            };

            limits_config = {
              retention_period = "30d";
              reject_old_samples = true;
              reject_old_samples_max_age = "168h";
              ingestion_rate_mb = 10;
              ingestion_burst_size_mb = 20;
              per_stream_rate_limit = "5MB";
              per_stream_rate_limit_burst = "20MB";
            };

            compactor = {
              working_directory = "/var/lib/loki/compactor";
              retention_enabled = true;
              delete_request_store = "filesystem";
            };

            querier = {
              max_concurrent = 20;
            };
          };

          # Additional promtail configuration
          promtailConfig = {
            scrape_configs = [
              {
                job_name = "varlogs";
                static_configs = [
                  {
                    targets = [ "localhost" ];
                    labels = {
                      job = "varlogs";
                      __path__ = "/var/log/*.log";
                    };
                  }
                ];
              }
            ];
          };
        };
      };
    };

    # Promtail log collector (for non-monitoring machines)
    "blr-promtail-collector" = {
      module.name = "loki";
      module.input = "self";
      roles.promtail = {
        tags."blr-logs" = { };
        settings = {
          # Point to the Loki server on britton-desktop
          lokiUrl = "http://loki.blr.dev:3100";


          # Additional log sources
          additionalScrapeConfigs = [
            {
              job_name = "varlogs";
              static_configs = [
                {
                  targets = [ "localhost" ];
                  labels = {
                    job = "varlogs";
                    __path__ = "/var/log/*.log";
                  };
                }
              ];
            }
          ];
        };
      };
    };
  };
}
