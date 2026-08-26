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
let ornith_35b_bf16 = {
  checkpoint = "deepreinforce-ai/Ornith-1.0-35B-GGUF:BF16",
  recipe = "llamacpp",
  size = 69.38,
}
in
let ornith_9b_q8_model = "user.Ornith-1.0-9B-Q8_0" in
let ornith_35b_q4_model = "user.Ornith-1.0-35B-Q4_K_M" in
let ornith_35b_q8_model = "user.Ornith-1.0-35B-Q8_0" in
let ornith_35b_bf16_model = "user.Ornith-1.0-35B-BF16" in
let radicle_node_address = "100.100.103.95" in
let radicle_desktop_replica_address = "100.110.43.11" in
let radicle_aspen3_replica_address = "100.108.13.4" in
let mesh_openai_endpoint_url = "http://127.0.0.1:13305/v1" in
let mesh_desktop_openai_endpoint_url = "http://127.0.0.1:8000/v1" in
let mesh_aspen1_address = radicle_node_address in
let mesh_aspen2_address = "100.125.64.121" in
let mesh_aspen3_address = radicle_aspen3_replica_address in
let mesh_desktop_address = radicle_desktop_replica_address in
let radicle_node_port = 8776 in
let radicle_replica_state_quota_gib = 64 in
let radicle_desktop_replica_node_fingerprint = "SHA256:JHQTPqoMr4kLqBsrAPSRNXUuzETiHAoiKBM/VWftmEg" in
let radicle_aspen3_replica_node_fingerprint = "SHA256:TEuGqHuV/3kGZzGiqUGCkCYG8ITfhV3TvJUjddv8fb0" in
let radicle_http_port = 8080 in
let radicle_https_origin_port = 8081 in
let radicle_pilot_rid = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo" in
let artifact_auth_rid = "rad:z4JGYYW7WsesXUq7MXVdx16Fawu2f" in
let execution_graph_rid = "rad:z2oYsb9jGTyp68BKYhzpivY1eK58a" in
let choregraph_rid = "rad:zL2ncTUeASVYwcoGkEXv9JKgGbAF" in
let durable_file_publication_rid = "rad:z3tAR4For7qw8ZirkJzoDw1VNDDLM" in
let koiterminal_rid = "rad:z2JQ8ihZZ6wraULQPzFWMh25B29rZ" in
let radicle_private_pilot_rid = "rad:z3t9ykR1HfG9UkyKoQQg5ikkzrTxg" in
let radicle_seaglass_rid = "rad:z3xXXCQXCTquvAawh41YYs8yC8xmk" in
let radicle_hardened_wasmtime_rid = "rad:z3hRCegTsS8jpJVgxYfb9psEzxHpG" in
let radicle_source_rids = [
  radicle_pilot_rid,
  artifact_auth_rid,
  execution_graph_rid,
  choregraph_rid,
  durable_file_publication_rid,
  koiterminal_rid,
]
in
let radicle_private_source_rids = [
  radicle_private_pilot_rid,
  radicle_seaglass_rid,
  radicle_hardened_wasmtime_rid,
]
in
let radicle_production_seed_node_id = "z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8" in
let radicle_reviewed_commit = "29dac88ecded94457572db3fdfaaaab95fa91525" in
let radicle_ci_policy_blake3 = "091e57f4409f79db14465ccc26e730bf1181209fe45c28d7dd1259393e93f740" in
let radicle_ci_bot_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHwhn4nbFZOQxnyj+fRvABe+jU9IOVWY/bPx1PxA3utr" in
let radicle_ci_bot_node_id = "z6MknopLULJensBT5KGkC8h9KaHTNY5muZ9UffqroErX7Rni" in
let radicle_ci_bot_fingerprint = "SHA256:U4XxEymH9bpdWtN3Yl7ugkOn+Io1OrQ6H2UjkZC9Rg0" in
let radicle_delegates = [
  "did:key:z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx",
  "did:key:z6MkjCqx5ksRqcDeNeuEnz53udbUHebRLHhddCxecWJu9koE",
  "did:key:z6MkmkA6sEzzMffaWqKEKJcDh8LjAzgrJLrTNi971KN3X6sh",
]
in
let radicle_backup_target_host = "britton-desktop" in
let radicle_backup_target_address = "100.110.43.11" in
let radicle_backup_target_failure_domain = "britton-desktop-workstation" in
let radicle_backup_repository_path = "/var/lib/radicle-backup" in
let radicle_backup_dataset = "datapool/radicle-backup" in
let radicle_backup_dataset_quota_gib = 256 in
let radicle_backup_retention_daily = 7 in
let radicle_backup_retention_weekly = 4 in
let radicle_backup_schedule = "Sun *-*-* 03:15:00" in
let bookshelf_address = "100.110.43.11" in
let bookshelf_port = 39300 in
let bookshelf_restart_delay_seconds = 5 in
let bookshelf_source_dir = "/datapool/bookshelf/source" in
let bookshelf_library_dir = "/datapool/bookshelf/library" in
let rustfs_api_port = 39000 in
let rustfs_console_port = 39001 in
let rustfs_topology_wait_timeout_seconds = 120 in
let rustfs_aspen1_address = "100.100.103.95" in
let rustfs_aspen3_address = "100.108.13.4" in
let rustfs_britton_desktop_address = "100.110.43.11" in
let rustfs_aspen1_data_dir = "/var/lib/rustfs-cluster" in
let rustfs_aspen3_data_dir = "/mnt/usb4-nvme/rustfs-cluster" in
let rustfs_britton_desktop_data_dir = "/datapool/rustfs-cluster" in
let rustfs_cluster_endpoints = [
  "http://%{rustfs_aspen1_address}:%{rustfs_api_port}%{rustfs_aspen1_data_dir}",
  "http://%{rustfs_aspen3_address}:%{rustfs_api_port}%{rustfs_aspen3_data_dir}",
  "http://%{rustfs_britton_desktop_address}:%{rustfs_api_port}%{rustfs_britton_desktop_data_dir}",
]
in
let rustfs_cluster_settings = fun bind_address data_dir =>
  {
    mode = "distributed",
    dataDir = data_dir,
    bindAddress = bind_address,
    apiPort = rustfs_api_port,
    consolePort = rustfs_console_port,
    enableConsole = true,
    openFirewall = true,
    firewallInterface = "tailscale0",
    clusterEndpoints = rustfs_cluster_endpoints,
    topologyWaitMode = "bounded",
    topologyWaitTimeoutSeconds = rustfs_topology_wait_timeout_seconds,
  }
in
let celld_public_port = 39200 in
let celld_internal_port = 39201 in
let celld_bucket_name = "onix-celld-lab" in
let celld_region = "us-east-1" in
let celld_access_key_id = "celld-lab" in
let celld_state_dir = "/var/lib/celld-lab" in
let celld_lease_ttl_milliseconds = 10000 in
let celld_restart_delay_seconds = 10 in
let celld_shutdown_drain_milliseconds = 25000 in
let celld_fleet_settings = fun bind_address provision_storage =>
  {
    stateDir = celld_state_dir,
    bindAddress = bind_address,
    storageEndpoint = "http://%{bind_address}:%{rustfs_api_port}",
    bucketName = celld_bucket_name,
    region = celld_region,
    accessKeyId = celld_access_key_id,
    publicPort = celld_public_port,
    internalPort = celld_internal_port,
    openFirewall = true,
    firewallInterface = "tailscale0",
    provisionStorage = provision_storage,
    rustfsAdminGenerator = "rustfs-rustfs-cluster",
    deployCounter = true,
    leaseTtlMilliseconds = celld_lease_ttl_milliseconds,
    restartDelaySeconds = celld_restart_delay_seconds,
    shutdownDrainMilliseconds = celld_shutdown_drain_milliseconds,
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

    # r[impl onix.rustfs_cluster.composition]
    "rustfs-cluster" = {
      module = { name = "rustfs", input = "self" },
      roles.server.machines = {
        aspen1.settings = rustfs_cluster_settings rustfs_aspen1_address rustfs_aspen1_data_dir,
        aspen3.settings = rustfs_cluster_settings rustfs_aspen3_address rustfs_aspen3_data_dir,
        britton-desktop.settings = rustfs_cluster_settings rustfs_britton_desktop_address rustfs_britton_desktop_data_dir,
      },
    },

    # r[impl onix.celld_rustfs.composition]
    "celld-lab" = {
      module = { name = "celld", input = "self" },
      roles.server.machines = {
        aspen1.settings = celld_fleet_settings rustfs_aspen1_address true,
        aspen3.settings = celld_fleet_settings rustfs_aspen3_address false,
        britton-desktop.settings = celld_fleet_settings rustfs_britton_desktop_address false,
      },
    },

    # r[impl onix.bookshelf.storage]
    # r[impl onix.bookshelf.network]
    "bookshelf-private" = {
      module = { name = "bookshelf", input = "self" },
      roles.server.machines.britton-desktop.settings = {
        sourceDir = bookshelf_source_dir,
        libraryDir = bookshelf_library_dir,
        bindAddress = bookshelf_address,
        port = bookshelf_port,
        siteUrl = "http://%{bookshelf_address}:%{bookshelf_port}",
        readOnly = false,
        openFirewall = true,
        firewallInterface = "tailscale0",
        restartDelaySeconds = bookshelf_restart_delay_seconds,
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
        tags."dgx-spark" = {},
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
              public = false,
            },
            wiki = {
              port = 3000,
              subdomain = "wiki",
              public = false,
            },
          },
          additionalSubdomains = ["ci"],
          tailscaleSSH = true,
          tailscaleExitNode = false,
          traefikDashboard = true,
          securityHeaders = true,
          dnsPropagationCheck = false,
        },
      },
    },

    "iroh-ssh-aspen3" = {
      module = { name = "iroh-ssh", input = "self" },
      roles.peer.machines.aspen3 = {},
    },

    "iroh-ssh-britton-desktop" = {
      module = { name = "iroh-ssh", input = "self" },
      roles.peer.machines.britton-desktop = {},
    },

    "iroh-ssh-bonsai" = {
      module = { name = "iroh-ssh", input = "self" },
      roles.peer.machines.bonsai = {},
    },

    "iroh-ssh-dgx-spark" = {
      module = { name = "iroh-ssh", input = "self" },
      roles.peer.tags."dgx-spark" = {},
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
            "git.onix.computer" = "http://127.0.0.1:%{radicle_https_origin_port}",
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

    # r[impl onix.aspen1.deepseek.serving]
    # r[impl onix.aspen1.deepseek.exclusivity]
    # DeepSeek-V4-Flash-0731 needs ~114 GiB resident on aspen1, so the
    # Lemonade service (Ornith + kokoro) is removed from this host.
    "deepseek-v4-flash-aspen1" = {
      module = { name = "llamacpp-server", input = "self" },
      roles.server.machines.aspen1.settings = {
        backend = "rocm-dspark",
        host = "0.0.0.0",
        port = 13305,
        modelRepo = "unsloth/DeepSeek-V4-Flash-0731-GGUF",
        modelFile = "UD-IQ3_XXS/DeepSeek-V4-Flash-0731-UD-IQ3_XXS-00001-of-00004.gguf",
        extraModelFiles = [
          "UD-IQ3_XXS/DeepSeek-V4-Flash-0731-UD-IQ3_XXS-00002-of-00004.gguf",
          "UD-IQ3_XXS/DeepSeek-V4-Flash-0731-UD-IQ3_XXS-00003-of-00004.gguf",
          "UD-IQ3_XXS/DeepSeek-V4-Flash-0731-UD-IQ3_XXS-00004-of-00004.gguf",
        ],
        # Ready-made drafters fail on the pinned runtime (unknown arch or
        # no_vocab tokenizer metadata), so the draft is converted from the
        # official checkpoint by the deepseek-v4-dspark-draft package.
        draftModelSource = "package",
        draftModelFile = "DeepSeek-V4-Flash-0731-DSpark-llamacpp-MXFP4-Q8_0.gguf",
        modelAlias = "DeepSeek-V4-Flash-0731",
        contextSize = 8192,
        parallelSlots = 1,
        cacheTypeK = "q8_0",
        cacheTypeV = "q8_0",
        flashAttention = true,
        gpuPerformanceLock = true,
        noMmap = false,
        extraArgs = [
          "-ngld",
          "all",
          "--fit",
          "off",
          "--spec-type",
          "draft-dspark",
          "--spec-draft-n-max",
          "3",
          "-ctkd",
          "q8_0",
          "-ctvd",
          "q8_0",
          "--load-mode",
          "dio",
          "--no-ui",
        ],
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
        customModels = {
          "Ornith-1.0-9B-Q8_0" = ornith_9b_q8,
          "Ornith-1.0-35B-Q4_K_M" = ornith_35b_q4,
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
        # r[onix.aspen3.ornith.model]
        models = ["user.Qwen3.6-35B-A3B", "user.VibeThinker-3B", "Whisper-Large-v3-Turbo", ornith_9b_q8_model, ornith_35b_q4_model],
        contextSize = 131072,
        globalTimeout = 0,
        extraArgs = "--no-mmap -fa on --cache-type-k q8_0 --cache-type-v q8_0 -b 8192 -ub 4096 -np 1",
      },
    },

    # r[impl onix.radicle_node.hosting]
    "radicle-forge-bootstrap" = {
      module = { name = "radicle-node", input = "self" },
      roles.default.machines.aspen1.settings = {
        expectedHost = "aspen1",
        deploymentTarget = "root@aspen1.local",
        expectedNodeFingerprint = "SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE",
        alias = "aspen1-radicle",
        failureDomain = "aspen-primary-site",
        monitoringRequired = true,
        nodeListenAddress = radicle_node_address,
        nodeListenPort = radicle_node_port,
        nodeFirewallInterface = "tailscale0",
        externalAddress = "%{radicle_node_address}:%{radicle_node_port}",
        seedRepositories = radicle_source_rids,
        privateSeedRepositories = radicle_private_source_rids,
        httpdEnabled = true,
        httpListenAddress = "127.0.0.1",
        httpListenPort = radicle_http_port,
        httpsEnabled = true,
        httpsServerName = "git.onix.computer",
        httpsTransport = "cloudflare-tunnel",
        httpsOriginListenAddress = "127.0.0.1",
        httpsOriginListenPort = radicle_https_origin_port,
        httpsGitRepositories = radicle_source_rids,
        backupEnabled = true,
        backupTargetHost = radicle_backup_target_host,
        backupTargetAddress = radicle_backup_target_address,
        backupTargetFailureDomain = radicle_backup_target_failure_domain,
        backupRepositoryPath = radicle_backup_repository_path,
        backupDataset = radicle_backup_dataset,
        backupDatasetQuotaGiB = radicle_backup_dataset_quota_gib,
        backupRetentionDaily = radicle_backup_retention_daily,
        backupRetentionWeekly = radicle_backup_retention_weekly,
        backupManifestAlgorithm = "blake3",
        minimumSignedRefsFeature = "parent",
        pinnedRepositories = [],
      },
    },

    # r[impl onix.radicle_ci.configuration]
    "radicle-forge-ci" = {
      module = { name = "radicle-ci-runner", input = "self" },
      roles.default.machines.aspen1.settings = {
        expectedHost = "aspen1",
        deploymentTarget = "root@aspen1.local",
        rid = radicle_pilot_rid,
        signedRefsFeature = "parent",
        productionSeedNodeId = radicle_production_seed_node_id,
        productionSeedAddress = "%{radicle_node_address}:%{radicle_node_port}",
        reviewedCommit = radicle_reviewed_commit,
        policyBlake3 = radicle_ci_policy_blake3,
        checkName = "onix/ci/v1",
        expectedBotPublicKey = radicle_ci_bot_public_key,
        expectedBotNodeId = radicle_ci_bot_node_id,
        expectedBotFingerprint = radicle_ci_bot_fingerprint,
        delegates = radicle_delegates,
        cargoTomlBlake3 = "20ff51e3f2c5f9b230e05b797b5dbb1029e738d5f84d25cecce02d49c2d3427e",
        cargoLockBlake3 = "79c9e70b6cd874aad8e55beb6b4242b47efc24ab344cad4ad1c42a4c3b31cd60",
        flakeNixBlake3 = "ef1b58422af1f9918554d7a0f78c6c657eded6ac64545e4c6fb3c6e1d7ba9e86",
        flakeLockBlake3 = "8f16f066737c44b0447f9bd86b89dca822183909d90563c097765f098e5abae4",
      },
    },

    # r[impl onix.radicle_replica.deployment]
    "radicle-forge-secondary-seed" = {
      module = { name = "radicle-seed-replica", input = "self" },
      roles.default.machines.britton-desktop.settings = {
        expectedHost = "britton-desktop",
        deploymentTarget = "root@%{radicle_desktop_replica_address}",
        expectedNodeFingerprint = radicle_desktop_replica_node_fingerprint,
        alias = "britton-desktop-radicle",
        failureDomain = "britton-desktop-workstation",
        monitoringRequired = true,
        nodeListenAddress = radicle_desktop_replica_address,
        nodeListenPort = radicle_node_port,
        nodeFirewallInterface = "tailscale0",
        externalAddress = "%{radicle_desktop_replica_address}:%{radicle_node_port}",
        seedRepositories = radicle_source_rids,
        privateSeedRepositories = radicle_private_source_rids,
        stateDirectory = "/var/lib/radicle",
        stateDataset = "datapool/radicle-seed",
        stateQuotaGiB = radicle_replica_state_quota_gib,
        minimumSignedRefsFeature = "parent",
      },
    },

    # r[impl onix.radicle_replica.deployment]
    # r[impl onix.radicle_replica.identity_distinct]
    "radicle-forge-aspen3-seed" = {
      module = { name = "radicle-seed-replica", input = "self" },
      roles.default.machines.aspen3.settings = {
        expectedHost = "aspen3",
        deploymentTarget = "root@aspen3",
        expectedNodeFingerprint = radicle_aspen3_replica_node_fingerprint,
        alias = "aspen3-radicle",
        failureDomain = "aspen3-mobile-workstation",
        monitoringRequired = true,
        nodeListenAddress = radicle_aspen3_replica_address,
        nodeListenPort = radicle_node_port,
        nodeFirewallInterface = "tailscale0",
        externalAddress = "%{radicle_aspen3_replica_address}:%{radicle_node_port}",
        seedRepositories = radicle_source_rids,
        privateSeedRepositories = radicle_private_source_rids,
        stateDirectory = "/var/lib/radicle",
        stateDataset = "zroot/radicle-seed",
        stateQuotaGiB = radicle_replica_state_quota_gib,
        minimumSignedRefsFeature = "parent",
      },
    },

    "radicle-forge-backup" = {
      module = { name = "borgbackup", input = "clan-core" },
      roles = {
        server.machines."%{radicle_backup_target_host}".settings = {
          address = radicle_backup_target_address,
          directory = radicle_backup_repository_path,
        },
        client.machines.aspen1.settings.startAt = radicle_backup_schedule,
      },
    },

    "mesh-llm-private-inference" = {
      module = { name = "mesh-llm", input = "self" },
      roles.default.machines = {
        aspen1.settings = {
          mode = "seed",
          endpointUrl = mesh_openai_endpoint_url,
          meshBindAddress = mesh_aspen1_address,
          backendUnit = "llamacpp-server-deepseek-v4-flash-aspen1.service",
        },
        aspen2.settings = {
          mode = "joiner",
          endpointUrl = mesh_openai_endpoint_url,
          meshBindAddress = mesh_aspen2_address,
          backendUnit = "lemonade.service",
        },
        aspen3.settings = {
          mode = "joiner",
          endpointUrl = mesh_openai_endpoint_url,
          meshBindAddress = mesh_aspen3_address,
          backendUnit = "lemonade.service",
        },
        britton-desktop.settings = {
          mode = "joiner",
          endpointUrl = mesh_desktop_openai_endpoint_url,
          meshBindAddress = mesh_desktop_address,
          backendUnit = "qwen38-p150x2.service",
        },
      },
    },

    "mesh-llm-dgx-spark" = {
      module = { name = "mesh-llm", input = "self" },
      roles.default = {
        tags."dgx-spark" = {},
        settings = {
          mode = "joiner",
          endpointUrl = mesh_openai_endpoint_url,
          meshBindInterface = "tailscale0",
        },
      },
    },

    "llm-agents" = {
      module = { name = "llm-agents", input = "self" },
      roles.default = {
        tags."llm-client" = {},
        settings.packages = ["pi", "openspec", "hermes-agent"],
      },
    },

    "qwen-code-agents" = {
      module = { name = "llm-agents", input = "self" },
      roles.default = {
        tags."qwen-code-client" = {},
        settings.packages = ["qwen-code"],
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

    "hister-desktop" = {
      module = { name = "hister", input = "self" },
      roles.server.machines.britton-desktop.settings = {
        port = 4433,
        bindAddress = "127.0.0.1",
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
