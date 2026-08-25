{ inputs, ... }:
let
  inherit (inputs) self;

  # Wasm plugin library for evaluating Nickel schema files.
  # Schemas are pre-evaluated here so service definitions (which lack
  # NixOS module args) can use the data for interface generation.
  wasm = import "${self}/lib/wasm.nix" {
    plugins = self.packages.x86_64-linux.wasm-plugins;
  };

  # Load a module's schema.ncl if it exists, or null.
  loadSchema =
    dir:
    let
      path = dir + "/schema.ncl";
    in
    if builtins.pathExists path then wasm.evalNickelFile path else null;

  # Common args passed to schema-driven modules.
  schemaArgs = dir: { schema = loadSchema dir; };

  module_definitions = {
    "buildbot" = import ./buildbot {
      inherit inputs;
      schema = loadSchema ./buildbot;
    };
    "tailscale" = import ./tailscale (schemaArgs ./tailscale);
    "tailscale-traefik" = import ./tailscale-traefik (schemaArgs ./tailscale-traefik);
    "iroh-ssh" = import ./iroh-ssh (schemaArgs ./iroh-ssh);
    "static-server" = import ./static-server (schemaArgs ./static-server);
    "prometheus" = import ./prometheus (schemaArgs ./prometheus);
    "grafana" = import ./grafana (schemaArgs ./grafana);
    "infinity" = import ./infinity (schemaArgs ./infinity);
    "loki" = import ./loki (schemaArgs ./loki);
    "vaultwarden" = import ./vaultwarden (schemaArgs ./vaultwarden);
    "homepage-dashboard" = import ./homepage-dashboard (schemaArgs ./homepage-dashboard);
    "cloudflare-tunnel" = import ./cloudflare-tunnel (schemaArgs ./cloudflare-tunnel);
    "calibre-server" = import ./calibre-server (schemaArgs ./calibre-server);
    "llm" = import ./llm (schemaArgs ./llm);
    "upmpdcli" = import ./upmpdcli (schemaArgs ./upmpdcli);
    "nix-gc" = import ./nix-gc ({ inherit inputs; } // schemaArgs ./nix-gc);
    "kache-nix-rust" = import ./kache-nix-rust (schemaArgs ./kache-nix-rust);
    "ollama" = import ./ollama (schemaArgs ./ollama);
    "open-notebook" = import ./open-notebook (schemaArgs ./open-notebook);
    "speaches" = import ./speaches (schemaArgs ./speaches);
    "sglang-diffusion" = import ./sglang-diffusion (schemaArgs ./sglang-diffusion);
    "lemonade" = import ./lemonade (schemaArgs ./lemonade);
    "mesh-llm" = import ./mesh-llm (schemaArgs ./mesh-llm);
    "radicle-ci-runner" = import ./radicle-ci-runner (schemaArgs ./radicle-ci-runner);
    "radicle-node" = import ./radicle-node (schemaArgs ./radicle-node);
    "radicle-seed-replica" = import ./radicle-seed-replica (schemaArgs ./radicle-seed-replica);
    "rustfs" = import ./rustfs (schemaArgs ./rustfs);
    "cloud-hypervisor-vm" = import ./cloud-hypervisor-vm (schemaArgs ./cloud-hypervisor-vm);
    "llm-agents" = import ./llm-agents (schemaArgs ./llm-agents);
    "home-manager-profiles" = import ./home-manager-profiles (schemaArgs ./home-manager-profiles);
    "harmonia" = import ./harmonia (schemaArgs ./harmonia);
    "hermes-gateway" = import ./hermes-gateway (schemaArgs ./hermes-gateway);
    "hister" = import ./hister (schemaArgs ./hister);
    "llamacpp-rpc" = import ./llamacpp-rpc (schemaArgs ./llamacpp-rpc);
    "llamacpp-server" = import ./llamacpp-server (schemaArgs ./llamacpp-server);
    "syncthing" = import ./syncthing (schemaArgs ./syncthing);
    "thunderbird" = import ./thunderbird (schemaArgs ./thunderbird);
    "tt-inference-server" = import ./tt-inference-server (schemaArgs ./tt-inference-server);
  };

  # NOTE: borgbackup-extras and matrix-synapse-cf live under modules/ but are
  # plain NixOS modules loaded via extraModules in inventory/services/, not
  # clan perInstance service definitions.  They are intentionally absent from
  # module_definitions above.

in
module_definitions
