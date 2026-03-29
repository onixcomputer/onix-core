## 1. Foundation — Contract infrastructure and common types

- [x] 1.1 Create `inventory/services/settings-contracts.ncl` with file header, common type contracts (`Port`, `NonNeg`, `Duration`), and empty registry record
- [x] 1.2 Import settings-contracts.ncl from `inventory/services/contracts.ncl` and wire the registry into `extra_role_errors` of `mkRefValidator` so settings are validated per-role
- [x] 1.3 Verify the pipeline works end-to-end: `ncl export inventory/services/services.ncl` passes with empty registry, and a deliberately wrong type triggers a failure

## 2. Networking service contracts

- [x] 2.1 Add contracts for `tailscale` peer role (`enableSSH | Bool`, `exitNode | Bool`, `enableHostAliases | Bool`)
- [x] 2.2 Add contracts for `tailscale-traefik` server role (`domain | String`, `email | String`, `services | { _ : Dyn }`, `tailscaleSSH | Bool`, port-bearing fields)
- [x] 2.3 Add contracts for `cloudflare-tunnel` default role (`tunnelName | String`, `ingress | { _ : String }`)
- [x] 2.4 Add contracts for `iroh-ssh` peer role (`sshPort | Port`)

## 3. Monitoring service contracts

- [x] 3.1 Add contracts for `prometheus` server role (`enableAutoDiscovery | Bool`, `discoveryMethod | String`, `port | Port`, `retentionTime | String`, deep config as `Dyn`)
- [x] 3.2 Add contracts for `prometheus` exporter role (`exporterType | String`, `port | Port`, `enabledCollectors | Array String` where applicable)
- [x] 3.3 Add contracts for `grafana` server role (`enablePrometheusIntegration | Bool`, `settings | Dyn`)
- [x] 3.4 Add contracts for `loki` server role (`enablePromtail | Bool`, `configuration | Dyn`, `promtailConfig | Dyn`)

## 4. LLM and AI service contracts

- [x] 4.1 Add contracts for `llm` server role (`serviceType | String`, `port | Port`, `host | String`, `enableGPU | Bool`, `models | Array String`)
- [x] 4.2 Add contracts for `llm` client role (`clientType | String`, `extraPackages | Array String`)
- [x] 4.3 Add contracts for `ollama` default role (`host | String`, `models | Array String`)
- [x] 4.4 Add contracts for `llamacpp-rpc` worker role (`bindAddress | String`, `port | Port`, `enableCache | Bool`)
- [x] 4.5 Add contracts for `llamacpp-rpc` server role (`host | String`, `port | Port`, `model | { repo | String, file | String }`, `rpcWorkers | Array String`, `gpuLayers | Number`, `flashAttention | Bool`, `contextSize | Number`)
- [x] 4.6 Add contracts for `llm-agents` default role (`packages | Array String`)

## 5. Web service contracts

- [x] 5.1 Add contracts for `homepage-dashboard` server role (`listenPort | Port`, `allowedHosts | String`, `settings | Dyn`, `widgets | Dyn`)
- [x] 5.2 Add contracts for `static-server` server role (`port | Port`, `directory | String`, `createTestPage | Bool`, `serviceSuffix | String`, `isPublic | Bool`, `domain | String`, `subdomain | String`)
- [x] 5.3 Add contracts for `vaultwarden` server role (empty/minimal — instance has no settings)
- [x] 5.4 Add contracts for `harmonia` server role (`port | Port`, `priority | Number`)
- [x] 5.5 Add contracts for `buildbot` master and worker roles (master: `domain | String`, `useHTTPS | Bool`, `buildSystems | Array String`, `admins | Array String`; worker: `workers | Number`)
- [x] 5.6 Add contracts for `calibre-server` server role (`libraries | Array String`, `host | String`, `port | Port`, `user | String`, `group | String`)

## 6. Infrastructure service contracts

- [x] 6.1 Add contracts for `nix-gc` default role (`retentionDays | Number`, `schedule | String`, `optimizeStore | Bool`, `autoOptimise | Bool`)
- [x] 6.2 Add contracts for `syncthing` peer role (`user | String`, `dataDir | String`, `openFirewall | Bool`)
- [x] 6.3 Add contracts for `home-manager-profiles` default role (`username | String`, `profiles | Array String`)
- [x] 6.4 Add contracts for `borgbackup` server role (`directory | String`) and client role (no settings)

## 7. Validation and documentation

- [x] 7.1 Run `ncl export inventory/services/services.ncl` and verify all current instances pass with the full contract set
- [x] 7.2 Test with deliberate typos in 3+ services to confirm errors are caught and messages are clear
- [x] 7.3 Add header documentation to `settings-contracts.ncl` explaining the open-record strategy and maintenance workflow
