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
let ornith_9b_q8 = {
  checkpoint = "deepreinforce-ai/Ornith-1.0-9B-GGUF:Q8_0",
  recipe = "llamacpp",
  size = 9.53,
}
in
let ornith_35b_q4 = {
  checkpoint = "deepreinforce-ai/Ornith-1.0-35B-GGUF:Q4_K_M",
  recipe = "llamacpp",
  size = 21.17,
}
in
let ornith_35b_q8 = {
  checkpoint = "deepreinforce-ai/Ornith-1.0-35B-GGUF:Q8_0",
  recipe = "llamacpp",
  size = 36.9,
}
in
let ornith_9b_q8_model = "user.Ornith-1.0-9B-Q8_0" in
let ornith_35b_q4_model = "user.Ornith-1.0-35B-Q4_K_M" in
let ornith_35b_q8_model = "user.Ornith-1.0-35B-Q8_0" in
let krea2_sglang_port = 30000 in
let krea2_sglang_gpu_count = 1 in
let krea2_sglang_lowest_prefetch = "0.0" in
let krea2_turbo_smoke_steps = 8 in
let krea2_turbo_guidance_scale = 0.0 in
let krea2_turbo_flow_shift = 1.15 in
let krea2_turbo_smoke_pixels = 512 in
let krea2_turbo_sdcpp_args = "--diffusion-fa --offload-to-cpu --vae-tiling" in
# Declared for run-krea2-on-aspen3; intentionally not registered in
# lemonade-aspen3 customModels/models until the direct Aspen3 smoke passes.
let krea2_turbo_sd_cpp = {
  checkpoints = {
    main = "vantagewithai/Krea-2-Turbo-GGUF:krea2_turbo-Q4_K_M.gguf",
    text_encoder = "Comfy-Org/Krea-2:text_encoders/qwen3vl_4b_fp8_scaled.safetensors",
    vae = "Comfy-Org/Krea-2:vae/qwen_image_vae.safetensors",
  },
  recipe = "sd-cpp",
  labels = ["image"],
  imageDefaults = {
    steps = krea2_turbo_smoke_steps,
    cfg_scale = krea2_turbo_guidance_scale,
    width = krea2_turbo_smoke_pixels,
    height = krea2_turbo_smoke_pixels,
    sampling_method = "euler",
    flow_shift = krea2_turbo_flow_shift,
  },
  recipeOptions = {
    sdcpp_args = krea2_turbo_sdcpp_args,
  },
}
in

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

    "kache-nix-rust-britton-desktop" = {
      module = { name = "kache-nix-rust", input = "self" },
      roles.default.machines.britton-desktop.settings = {
        enable = true,
        cacheDir = "/var/cache/kache-nix",
        exposeSandboxPath = true,
        zfsDataset = "datapool/kache-nix",
        keySalt = "changebot-crane-pilot-v1",
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

    "krea2-britton-desktop" = {
      module = { name = "sglang-diffusion", input = "self" },
      roles.default.machines.britton-desktop.settings = {
        port = krea2_sglang_port,
        modelPath = "krea/Krea-2-Turbo",
        numGpus = krea2_sglang_gpu_count,
        gpuPassthrough = "nixos-nvidia",
        conflictingUnits = ["llamacpp-server-vibethinker-britton-desktop.service"],
        extraArgs = [
          "--dit-layerwise-offload",
          "--dit-offload-prefetch-size",
          krea2_sglang_lowest_prefetch,
          "--text-encoder-cpu-offload",
          "--vae-cpu-offload",
        ],
      },
    },

    "lemonade-aspen1" = {
      module = { name = "lemonade", input = "self" },
      roles.default.machines.aspen1.settings = {
        backend = "rocm",
        customModels = {
          "Ornith-1.0-9B-Q8_0" = ornith_9b_q8,
        },
        models = ["kokoro-v1", ornith_9b_q8_model],
        contextSize = 131072,
        clusterRpcClient = true,
        extraArgs = "--no-mmap -fa on --cache-type-k q8_0 --cache-type-v q8_0 -b 4096",
      },
    },

    "lemonade-aspen2" = {
      module = { name = "lemonade", input = "self" },
      roles.default.machines.aspen2.settings = {
        backend = "rocm",
        customModels = {
          "Ornith-1.0-9B-Q8_0" = ornith_9b_q8,
          "Ornith-1.0-35B-Q4_K_M" = ornith_35b_q4,
          "Qwen3.6-35B-A3B" = {
            checkpoint = "unsloth/Qwen3.6-35B-A3B-GGUF:Q8_0",
            recipe = "llamacpp",
            size = 35,
          },
        },
        models = ["user.Qwen3.6-35B-A3B", "Whisper-Large-v3-Turbo", ornith_9b_q8_model, ornith_35b_q4_model],
        contextSize = 131072,
        globalTimeout = 0,
        clusterRpcWorker = true,
        extraArgs = "--no-mmap -fa on --cache-type-k q8_0 --cache-type-v q8_0 -b 8192 -ub 4096 -np 1",
      },
    },

    "lemonade-aspen3" = {
      module = { name = "lemonade", input = "self" },
      roles.default.machines.aspen3.settings = {
        backend = "rocm",
        sdCppBackend = "rocm",
        sdCppUseNixBackend = true,
        customModels = {
          "Ornith-1.0-9B-Q8_0" = ornith_9b_q8,
          "Ornith-1.0-35B-Q8_0" = ornith_35b_q8,
          "Qwen3.6-35B-A3B" = {
            checkpoint = "unsloth/Qwen3.6-35B-A3B-GGUF:Q8_0",
            recipe = "llamacpp",
            size = 35,
          },
          "VibeThinker-3B" = {
            checkpoint = "prithivMLmods/VibeThinker-3B-GGUF:Q8_0",
            recipe = "llamacpp",
            size = 3,
          },
        },
        models = ["user.Qwen3.6-35B-A3B", "user.VibeThinker-3B", "Whisper-Large-v3-Turbo", ornith_9b_q8_model, ornith_35b_q8_model],
        contextSize = 131072,
        globalTimeout = 0,
        extraArgs = "--no-mmap -fa on --cache-type-k q8_0 --cache-type-v q8_0 -b 8192 -ub 4096 -np 1",
      },
    },

    "vibethinker-britton-desktop" = {
      module = { name = "llamacpp-server", input = "self" },
      roles.server.machines.britton-desktop.settings = {
        backend = "cuda",
        modelRepo = "prithivMLmods/VibeThinker-3B-GGUF",
        modelFile = "VibeThinker-3B.Q8_0.gguf",
        modelAlias = "VibeThinker-3B",
        contextSize = 131072,
        gpuLayers = 999,
        batchSize = 8192,
        ubatchSize = 4096,
        parallelSlots = 1,
        cacheTypeK = "q8_0",
        cacheTypeV = "q8_0",
      },
    },

    "llm-agents" = {
      module = { name = "llm-agents", input = "self" },
      roles.default = {
        tags."llm-client" = {},
        settings.packages = ["pi", "openspec", "qwen-code", "hermes-agent"],
      },
    },

    "thunderbird-desktop" = {
      module = { name = "thunderbird", input = "self" },
      roles.default.machines.britton-desktop.settings = {
        user = "brittonr",
        group = "users",
        userHome = "/home/brittonr",
        profileName = "onix",
        fullName = "Britton Richardson",
        fastmailLabel = "Fastmail",
        gmailLabel = "Gmail",
        gmailAuthMethod = "oauth2",
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
        allowedUsers = [
          "@brittonr:onix.computer",
          "@brittonr_:matrix.org",
        ],
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
