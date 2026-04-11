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
    "static-server" = import ./static-server (schemaArgs ./static-server);
    "prometheus" = import ./prometheus (schemaArgs ./prometheus);
    "grafana" = import ./grafana (schemaArgs ./grafana);
    "loki" = import ./loki (schemaArgs ./loki);
    "vaultwarden" = import ./vaultwarden (schemaArgs ./vaultwarden);
    "homepage-dashboard" = import ./homepage-dashboard (schemaArgs ./homepage-dashboard);
    "cloudflare-tunnel" = import ./cloudflare-tunnel (schemaArgs ./cloudflare-tunnel);
    "calibre-server" = import ./calibre-server (schemaArgs ./calibre-server);
    "llm" = import ./llm (schemaArgs ./llm);
    "upmpdcli" = import ./upmpdcli (schemaArgs ./upmpdcli);
    "nix-gc" = import ./nix-gc (schemaArgs ./nix-gc);
    "ollama" = import ./ollama (schemaArgs ./ollama);
    "open-notebook" = import ./open-notebook (schemaArgs ./open-notebook);
    "lemonade" = import ./lemonade (schemaArgs ./lemonade);
    "clankers" = import ./clankers (schemaArgs ./clankers);
    "cloud-hypervisor-vm" = import ./cloud-hypervisor-vm (schemaArgs ./cloud-hypervisor-vm);
    "llm-agents" = import ./llm-agents (schemaArgs ./llm-agents);
    "home-manager-profiles" = import ./home-manager-profiles (schemaArgs ./home-manager-profiles);
    "harmonia" = import ./harmonia (schemaArgs ./harmonia);
    "llamacpp-rpc" = import ./llamacpp-rpc (schemaArgs ./llamacpp-rpc);
    "syncthing" = import ./syncthing (schemaArgs ./syncthing);
  };

  # NOTE: borgbackup-extras and matrix-synapse-cf live under modules/ but are
  # plain NixOS modules loaded via extraModules in inventory/services/, not
  # clan perInstance service definitions.  They are intentionally absent from
  # module_definitions above.

in
module_definitions
