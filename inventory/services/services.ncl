# Service inventory — source of truth for data-only service instances.
#
# Defines service instances, their module bindings, role targets
# (tags and machines), and settings.
# Validated by Nickel contracts at export time.
#
# Services needing Nix paths (extraModules) have their data here
# and a thin .nix stub that adds the path. The loader merges them.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/services/services.ncl
#   3. Contracts check module names, tags, machine refs — typos fail immediately
#   4. Commit .ncl
#
let { Services, ValidateRefs, ValidateSettings, .. } = import "contracts.ncl" in
let prom_rules = import "prometheus-rules.ncl" in

{
  instances = {

    # ========== Core Infrastructure ==========

    sshd = {
      module.name = "sshd",
      roles = {
        server.tags.nixos = {},
        client = {
          tags.nixos = {},
          settings.certificate.searchDomains = ["local"],
        },
      },
    },

    "store-maintenance" = {
      module = { name = "nix-gc", input = "self" },
      roles.default = {
        tags.nixos = {},
        settings = {
          retentionDays = 30,
          schedule = "weekly",
          optimizeStore = true,
          autoOptimise = true,
        },
      },
    },

    # ========== Networking ==========

    "br-tailnet" = {
      module = { name = "tailscale", input = "self" },
      roles.peer = {
        tags."tailnet-brittonr" = {},
        settings = {
          enableSSH = true,
          exitNode = false,
          enableHostAliases = true,
        },
      },
    },

    "tailscale-traefik-desktop" = {
      module = { name = "tailscale-traefik", input = "self" },
      roles.server = {
        tags."traefik-desktop" = {},
        settings = {
          domain = "onix.computer",
          email = "admin@onix.computer",
          services = {
            homepage = {
              subdomain = "home",
              public = false,
            },
            test = {
              port = 8888,
              subdomain = "test",
              public = true,
            },
            demo = {
              port = 8889,
              subdomain = "demo",
              public = false,
            },
            wiki = {
              port = 3000,
              subdomain = "wiki",
              public = false,
            },
          },
          tailscaleSSH = true,
          tailscaleExitNode = false,
          traefikDashboard = true,
          securityHeaders = true,
          dnsPropagationCheck = false,
        },
      },
    },

    "cloudflare-brittonr" = {
      module = { name = "cloudflare-tunnel", input = "self" },
      roles.default.machines.aspen1 = {
        settings = {
          tunnelName = "aspen1-services",
          ingress = {
            "vault.robitzs.ch" = "http://localhost:8222",
            "auth.robitzs.ch" = "http://localhost:9081",
            "buildbot.blr.dev" = "http://localhost:80",
            "matrix.onix.computer" = "http://localhost:80",
            "onix.computer" = "http://localhost:80",
          },
        },
      },
    },

    "iroh-ssh" = {
      module = { name = "iroh-ssh", input = "self" },
      roles.peer = {
        tags."tailnet-brittonr" = {},
        machines."utm-vm" = {},
        settings.sshPort = 22,
      },
    },

    # ========== Monitoring ==========

    monitoring = {
      module = { name = "prometheus", input = "self" },
      roles = {
        server = {
          tags.monitoring = {},
          settings = {
            enableAutoDiscovery = true,
            discoveryMethod = "tailscale",
            port = 9090,
            globalConfig = {
              scrape_interval = "15s",
              evaluation_interval = "15s",
            },
            retentionTime = "30d",
            additionalScrapeConfigs = [
              {
                job_name = "prometheus",
                static_configs = [
                  { targets = ["localhost:9090"] },
                ],
              },
            ],
            rules = prom_rules,
          },
        },
        exporter = {
          tags.prometheus = {},
          settings = {
            exporterType = "node",
            port = 9100,
            enabledCollectors = [
              "systemd",
              "processes",
              "mountstats",
              "meminfo",
              "loadavg",
              "filesystem",
              "cpu",
              "hwmon",
              "cpufreq",
              "powersupplyclass",
              "rapl",
            ],
          },
        },
      },
    },

    "systemd-monitoring" = {
      module = { name = "prometheus", input = "self" },
      roles.exporter = {
        tags.prometheus = {},
        settings = {
          exporterType = "systemd",
          port = 9558,
        },
      },
    },

    grafana = {
      module = { name = "grafana", input = "self" },
      roles.server = {
        tags.monitoring = {},
        settings = {
          enablePrometheusIntegration = true,
          settings = {
            server = {
              http_addr = "0.0.0.0",
              http_port = 3000,
              domain = "grafana.local",
              root_url = "https://%(domain)s/",
              enable_gzip = true,
            },
            security.admin_user = "admin",
            analytics = {
              reporting_enabled = false,
              check_for_updates = false,
            },
            users = {
              allow_sign_up = false,
              default_theme = "dark",
            },
            feature_toggles.enable = "publicDashboards",
            database = {
              type = "sqlite3",
              path = "/var/lib/grafana/data/grafana.db",
            },
          },
        },
      },
    },

    "loki-blr" = {
      module = { name = "loki", input = "self" },
      roles.server = {
        tags.monitoring = {},
        settings = {
          enablePromtail = true,
          configuration = {
            auth_enabled = false,
            server = {
              http_listen_port = 3100,
              grpc_listen_port = 9096,
            },
            common = {
              instance_addr = "127.0.0.1",
              path_prefix = "/var/lib/loki",
              storage.filesystem = {
                chunks_directory = "/var/lib/loki/chunks",
                rules_directory = "/var/lib/loki/rules",
              },
              replication_factor = 1,
              ring.kvstore.store = "inmemory",
            },
            schema_config.configs = [
              {
                from = "2020-10-24",
                store = "tsdb",
                object_store = "filesystem",
                schema = "v13",
                index = {
                  prefix = "index_",
                  period = "24h",
                },
              },
            ],
            ruler.alertmanager_url = "http://localhost:9093",
            limits_config = {
              retention_period = "30d",
              reject_old_samples = true,
              reject_old_samples_max_age = "168h",
              ingestion_rate_mb = 10,
              ingestion_burst_size_mb = 20,
              per_stream_rate_limit = "5MB",
              per_stream_rate_limit_burst = "20MB",
            },
            compactor = {
              working_directory = "/var/lib/loki/compactor",
              retention_enabled = true,
              delete_request_store = "filesystem",
            },
            querier.max_concurrent = 20,
          },
          promtailConfig.scrape_configs = [
            {
              job_name = "varlogs",
              static_configs = [
                {
                  targets = ["localhost"],
                  labels = {
                    job = "varlogs",
                    __path__ = "/var/log/*.log",
                  },
                },
              ],
            },
          ],
        },
      },
    },

    # ========== LLM & AI ==========

    llm = {
      module = { name = "llm", input = "self" },
      roles = {
        server = {
          tags.llm = {},
          settings = {
            serviceType = "ollama",
            port = 11434,
            host = "0.0.0.0",
            enableGPU = true,
            models = ["qwen3.5:9b"],
            model = null,
          },
        },
        client = {
          tags."llm-client" = {},
          settings = {
            clientType = "ollama",
            extraPackages = ["curl", "jq"],
          },
        },
      },
    },

    # clankers — disabled until API keys are configured
    # clankers = {
    #   module = { name = "clankers", input = "self" },
    #   roles = {
    #     router.machines."britton-desktop".settings = {
    #       listenAddr = "0.0.0.0",
    #       listenPort = 4000,
    #       useOAuth = true,
    #     },
    #     daemon.machines."britton-desktop".settings = {
    #       apiBase = "http://127.0.0.1:4000",
    #       allowAll = true,
    #     },
    #   },
    # },

    ollama = {
      module = { name = "ollama", input = "self" },
      roles.default.machines.aspen2.settings = {
        host = "0.0.0.0",
        models = ["qwen3.5:122b"],
      },
    },

    "llm-agents" = {
      module = { name = "llm-agents", input = "self" },
      roles.default = {
        tags."llm-client" = {},
        settings.packages = ["pi", "openspec", "qwen-code"],
      },
    },

    "llamacpp-cluster" = {
      module = { name = "llamacpp-rpc", input = "self" },
      roles = {
        worker = {
          tags."llamacpp-worker" = {},
          settings = {
            bindAddress = "0.0.0.0",
            port = 50052,
            enableCache = true,
          },
        },
        server = {
          tags."llamacpp-server" = {},
          settings = {
            host = "0.0.0.0",
            port = 8081,
            model = {
              repo = "unsloth/gpt-oss-20b-GGUF",
              file = "gpt-oss-20b-F16.gguf",
            },
            rpcWorkers = ["10.10.10.2:50052"],
            gpuLayers = 999,
            flashAttention = true,
            contextSize = 8192,
            noMmap = true,
            extraArgs = [],
          },
        },
      },
    },

    # ========== Web Services ==========

    "homepage-dashboard" = {
      module = { name = "homepage-dashboard", input = "self" },
      roles.server = {
        tags."homepage-server" = {},
        settings = {
          listenPort = 8082,
          allowedHosts = "localhost:8082,home.blr.dev",
          settings = {
            title = "Onix Services",
            theme = "dark",
            color = "slate",
            background = {
              image = "",
              blur = "sm",
              saturate = 50,
              brightness = 50,
              opacity = 50,
            },
          },
          widgets = [
            {
              search = {
                provider = "duckduckgo",
                target = "_blank",
              },
            },
            {
              datetime = {
                text_size = "lg",
                format = {
                  dateStyle = "long",
                  timeStyle = "short",
                  hour12 = false,
                },
              },
            },
          ],
        },
      },
    },

    "static-server-test" = {
      module = { name = "static-server", input = "self" },
      roles.server = {
        tags."static-test" = {},
        settings = {
          port = 8888,
          directory = "/var/www/test",
          createTestPage = true,
          testPageTitle = "Tailscale-Traefik Public Mode Test",
          serviceSuffix = "test",
          isPublic = true,
          domain = "blr.dev",
          subdomain = "test",
          testPageContent = "",
        },
      },
    },

    "static-server-demo" = {
      module = { name = "static-server", input = "self" },
      roles.server = {
        tags."static-demo" = {},
        settings = {
          port = 8889,
          directory = "/var/www/demo",
          createTestPage = true,
          testPageTitle = "Private Demo Server (Tailscale Only)",
          serviceSuffix = "demo",
          isPublic = false,
          domain = "blr.dev",
          subdomain = "demo",
          testPageContent = "",
        },
      },
    },

    calibre = {
      module = { name = "calibre-server", input = "self" },
      roles.server.machines.britton-desktop.settings = {
        libraries = ["/home/brittonr/Calibre Library"],
        host = "0.0.0.0",
        port = 6767,
        user = "brittonr",
        group = "brittonr",
      },
    },

    "brittonr-vault" = {
      module = { name = "vaultwarden", input = "self" },
      roles.server.machines.aspen1 = {},
    },

    harmonia = {
      module = { name = "harmonia", input = "self" },
      roles.server.machines.aspen1.settings = {
        port = 5000,
        priority = 30,
      },
    },

    buildbot = {
      module = { name = "buildbot", input = "self" },
      roles = {
        master.machines.aspen1.settings = {
          domain = "buildbot.blr.dev",
          useHTTPS = true,
          buildSystems = [
            "x86_64-linux",
            "aarch64-darwin",
            "aarch64-linux",
          ],
          admins = ["brittonr"],
          evalWorkerCount = 8,
          evalMaxMemorySize = 4096,
          outputsPath = "/var/www/buildbot/nix-outputs/",
          ntfyUrl = "https://ntfy.sh/onix-buildbot",
          workerName = "aspen1",
          workerCores = 16,
          github = {
            appId = 3086395,
            oauthId = "Ov23livGR1RdLhArTbJI",
            topic = "buildbot-nix-brittonr",
          },
          effectsSecrets."github:onixcomputer/onix-core" = true,
        },
        worker.machines.aspen1.settings.workers = 16,
      },
    },

    # ========== Media ==========

    upmpdcli = {
      module = { name = "upmpdcli", input = "self" },
      roles.server.tags.media = {},
    },

    syncthing = {
      module = { name = "syncthing", input = "self" },
      roles.peer = {
        tags.syncthing = {},
        settings = {
          user = "brittonr",
          dataDir = "/home/brittonr",
          openFirewall = true,
        },
      },
    },

    # ========== Cloud Hypervisor VMs (disabled — blocks britton-desktop deploys) ==========

    # chv-dev1 = {
    #   module = { name = "cloud-hypervisor-vm", input = "self" },
    #   roles.host.machines.britton-desktop.settings = {
    #     guestMachine = "chv-dev1",
    #     cpus = 4,
    #     memory = 4096,
    #     diskPath = "/var/lib/cloud-hypervisor/chv-dev1.img",
    #     tapInterface = "tap-chv-dev1",
    #     macAddress = "52:54:00:c0:ff:01",
    #     guestIp = "172.16.0.10",
    #   },
    # },

    # chv-dev2 = {
    #   module = { name = "cloud-hypervisor-vm", input = "self" },
    #   roles.host.machines.britton-desktop.settings = {
    #     guestMachine = "chv-dev2",
    #     cpus = 2,
    #     memory = 2048,
    #     diskPath = "/var/lib/cloud-hypervisor/chv-dev2.img",
    #     tapInterface = "tap-chv-dev2",
    #     macAddress = "52:54:00:c0:ff:02",
    #     guestIp = "172.16.0.11",
    #   },
    # },

    # chv-dev3 = {
    #   module = { name = "cloud-hypervisor-vm", input = "self" },
    #   roles.host.machines.britton-desktop.settings = {
    #     guestMachine = "chv-dev3",
    #     cpus = 2,
    #     memory = 2048,
    #     diskPath = "/var/lib/cloud-hypervisor/chv-dev3.img",
    #     tapInterface = "tap-chv-dev3",
    #     macAddress = "52:54:00:c0:ff:03",
    #     guestIp = "172.16.0.12",
    #   },
    # },

    # ========== Upstream clan-core services ==========
    # (borgbackup and matrix-synapse have extraModules stubs in .nix)

    borgbackup = {
      module = { name = "borgbackup", input = "clan-core" },
      roles = {
        server.machines.aspen1.settings.directory = "/var/lib/borg",
        client.tags.backup = {},
      },
    },

    matrix-synapse = {
      module = { name = "matrix-synapse", input = "clan-core" },
      roles.default.machines.aspen1.settings = {
        server_tld = "onix.computer",
        app_domain = "matrix.onix.computer",
        acmeEmail = "admin@onix.computer",
        users.brittonr.admin = true,
      },
    },
  },
} | Services | ValidateRefs | ValidateSettings
