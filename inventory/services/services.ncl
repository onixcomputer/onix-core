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
          enableAlloy = true,
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
          additionalFileScrapes = [
            { name = "varlogs", path = "/var/log/*.log", labels = { job = "varlogs" } },
          ],
        },
      },
    },

    # ========== LLM & AI ==========

    "open-notebook-embeddings" = {
      module = { name = "infinity", input = "self" },
      roles.default.machines.britton-desktop.settings = {
        device = "cpu",
        engine = "torch",
        modelId = "BAAI/bge-m3",
        servedModelName = "bge-m3",
      },
    },

    "open-notebook-speech" = {
      module = { name = "speaches", input = "self" },
      roles.default.machines.britton-desktop.settings = {
        models = [
          "Systran/faster-whisper-large-v3",
          "speaches-ai/Kokoro-82M-v1.0-ONNX",
        ],
        modelAliases = {
          "tts-1" = "speaches-ai/Kokoro-82M-v1.0-ONNX",
          "tts-1-hd" = "speaches-ai/Kokoro-82M-v1.0-ONNX",
          "whisper-1" = "Systran/faster-whisper-large-v3",
        },
      },
    },

    "open-notebook" = {
      module = { name = "open-notebook", input = "self" },
      roles.server.machines.britton-desktop.settings = {
        credentials = [
          {
            name = "aspen-router",
            provider = "openai_compatible",
            modalities = ["language"],
            baseUrl = "http://aspen2:4000/v1",
            models = [
              { name = "user.Qwopus-27B", modelType = "language" },
              { name = "user.Qwopus-27B-v3", modelType = "language" },
              { name = "Qwen3.5-27B.Q8_0.gguf", modelType = "language" },
            ],
          },
          {
            name = "local-embeddings",
            provider = "openai_compatible",
            modalities = ["embedding"],
            baseUrl = "http://127.0.0.1:7997",
            models = [
              { name = "bge-m3", modelType = "embedding" },
            ],
          },
          {
            name = "local-speech",
            provider = "openai_compatible",
            modalities = ["speech_to_text", "text_to_speech"],
            baseUrl = "http://127.0.0.1:8001/v1",
            models = [
              { name = "Systran/faster-whisper-large-v3", modelType = "speech_to_text" },
              { name = "speaches-ai/Kokoro-82M-v1.0-ONNX", modelType = "text_to_speech" },
            ],
          },
        ],
        defaultModels = {
          default_chat_model = { credential = "aspen-router", name = "user.Qwopus-27B-v3" },
          default_embedding_model = { credential = "local-embeddings", name = "bge-m3" },
          default_speech_to_text_model = { credential = "local-speech", name = "Systran/faster-whisper-large-v3" },
          default_text_to_speech_model = { credential = "local-speech", name = "speaches-ai/Kokoro-82M-v1.0-ONNX" },
          default_transformation_model = { credential = "aspen-router", name = "user.Qwopus-27B-v3" },
          large_context_model = { credential = "aspen-router", name = "user.Qwopus-27B-v3" },
          default_tools_model = { credential = "aspen-router", name = "Qwen3.5-27B.Q8_0.gguf" },
        },
      },
    },

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

    clankers = {
      module = { name = "clankers", input = "self" },
      roles = {
        router.machines.aspen2.settings = {
          listenAddr = "0.0.0.0",
          listenPort = 4000,
          useOAuth = true,
          oauthRecords = [
            { provider = "anthropic", account = "claude1" },
            { provider = "anthropic", account = "claude2" },
            { provider = "anthropic", account = "claude3", active = true },
            { provider = "openai-codex", account = "default", active = true },
          ],
          localProviders = [
            {
              name = "aspen1",
              apiBase = "http://aspen1.local:13305/v1",
              models = ["user.Qwopus-27B", "user.Qwopus-27B-v3"],
            },
            {
              name = "aspen2-local",
              apiBase = "http://127.0.0.1:13305/v1",
              models = ["user.Qwen3.6-35B-A3B"],
            },
          ],
        },
        daemon.machines.aspen2.settings = {
          apiBase = "http://127.0.0.1:4000",
          allowAll = true,
          emailAuth = true,
          schedules = [
            {
              name = "test-email",
              kind = "interval",
              interval = 120,
              maxFires = 3,
              prompt = "Send a short test email to b@robitzs.ch with subject 'Clankers test' and body 'Test email sent at current time'. Use the send_email tool.",
            },
          ],
        },
        daemon.machines.britton-desktop.settings = {
          apiBase = "http://aspen2:4000",
          allowAll = true,
        },
      },
    },

    "lemonade-aspen1" = {
      module = { name = "lemonade", input = "self" },
      roles.default.machines.aspen1.settings = {
        # Keep the existing single-host Lemonade Qwopus path as a fallback while
        # we add the larger distributed llama.cpp RPC deployment below.
        backend = "rocm",
        customModels = {
          "Qwopus-27B" = {
            checkpoint = "Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-GGUF:Q4_K_M",
            recipe = "llamacpp",
            size = 16.5,
          },
          "Qwopus-27B-v3" = {
            checkpoint = "Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-GGUF:Q4_K_M",
            recipe = "llamacpp",
            size = 16.5,
          },
        },
        models = ["user.Qwopus-27B", "user.Qwopus-27B-v3", "kokoro-v1"],
        contextSize = 131072,
        extraArgs = "--no-mmap -fa on --cache-type-k q8_0 --cache-type-v q8_0 -b 4096",
      },
    },

    "lemonade-aspen2" = {
      module = { name = "lemonade", input = "self" },
      roles.default.machines.aspen2.settings = {
        backend = "rocm",
        customModels = {
          "Qwen3.6-35B-A3B" = {
            checkpoint = "unsloth/Qwen3.6-35B-A3B-GGUF:Q8_0",
            recipe = "llamacpp",
            size = 35,
          },
        },
        models = ["user.Qwen3.6-35B-A3B", "Whisper-Large-v3-Turbo"],
        contextSize = 131072,
        globalTimeout = 0,
        extraArgs = "--no-mmap -fa on --cache-type-k q8_0 --cache-type-v q8_0 -b 8192 -ub 4096 -np 1",
      },
    },

    # Distributed Qwopus-27B Q8_0 via llama.cpp RPC — disabled to free
    # aspen2's GPU for models served by lemonade above.
    # "qwopus-rpc" = {
    #   module = { name = "llamacpp-rpc", input = "self" },
    #   roles = {
    #     worker.machines.aspen2.settings = {
    #       bindAddress = "0.0.0.0",
    #       port = 50052,
    #       enableCache = true,
    #     },
    #     server.machines.aspen1.settings = {
    #       host = "0.0.0.0",
    #       port = 8081,
    #       model = {
    #         repo = "Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-GGUF",
    #         file = "Qwen3.5-27B.Q8_0.gguf",
    #       },
    #       rpcWorkers = ["10.10.10.2:50052"],
    #       gpuLayers = 999,
    #       flashAttention = true,
    #       contextSize = 131072,
    #       noMmap = true,
    #       extraArgs = [],
    #     },
    #   },
    # },

    "llm-agents" = {
      module = { name = "llm-agents", input = "self" },
      roles.default = {
        tags."llm-client" = {},
        settings.packages = ["pi", "openspec", "qwen-code", "hermes-agent"],
      },
    },

    "hermes-matrix-gateway" = {
      module = { name = "hermes-gateway", input = "self" },
      roles.default.machines.britton-desktop.settings = {
        user = "brittonr",
        group = "users",
        userHome = "/home/brittonr",
        hermesHome = "/home/brittonr/.hermes",
        workingDirectory = "/home/brittonr/git/onix-core",
        homeserver = "https://matrix.onix.computer",
        allowedUsers = ["@brittonr:onix.computer"],
        requireMention = true,
        autoThread = true,
        reactions = true,
        enableEncryption = true,
        acceptInsecureLibolm = true,
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
