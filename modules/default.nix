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
    "buildbot" = import ./buildbot { inherit inputs; };
    "tailscale" = import ./tailscale;
    "tailscale-traefik" = import ./tailscale-traefik;
    "static-server" = import ./static-server (schemaArgs ./static-server);
    "prometheus" = import ./prometheus;
    "grafana" = import ./grafana;
    "loki" = import ./loki;
    "vaultwarden" = import ./vaultwarden (schemaArgs ./vaultwarden);
    "homepage-dashboard" = import ./homepage-dashboard (schemaArgs ./homepage-dashboard);
    "cloudflare-tunnel" = import ./cloudflare-tunnel (schemaArgs ./cloudflare-tunnel);
    "calibre-server" = import ./calibre-server;
    "llm" = import ./llm;
    "upmpdcli" = import ./upmpdcli (schemaArgs ./upmpdcli);
    "nix-gc" = import ./nix-gc (schemaArgs ./nix-gc);
    "ollama" = import ./ollama;
    "clankers" = import ./clankers;
    "cloud-hypervisor-vm" = import ./cloud-hypervisor-vm;
    "iroh-ssh" = import ./iroh-ssh (schemaArgs ./iroh-ssh);
    "llm-agents" = import ./llm-agents;
    "home-manager-profiles" = import ./home-manager-profiles;
    "harmonia" = import ./harmonia (schemaArgs ./harmonia);
    "llamacpp-rpc" = import ./llamacpp-rpc;
    "syncthing" = import ./syncthing (schemaArgs ./syncthing);
  };

  # NOTE: borgbackup-extras and matrix-synapse-cf live under modules/ but are
  # plain NixOS modules loaded via extraModules in inventory/services/, not
  # clan perInstance service definitions.  They are intentionally absent from
  # module_definitions above.

in
module_definitions
