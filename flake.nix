{
  description = "Onix Infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    clan-core = {
      url = "git+https://git.clan.lol/adeci/clan-core?ref=adeci-unstable";
      inputs.home-manager.follows = "home-manager";
    };
    wrappers = {
      url = "github:Lassulus/wrappers";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wrappers-waybar = {
      url = "github:turbio/wrappers/init-waybar";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Dev inputs moved to dev/flake.nix for lazy evaluation
    # treefmt-nix and pre-commit-hooks-nix are only fetched for dev outputs
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    grub2-themes = {
      url = "github:vinceliuice/grub2-themes";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    grafana-dashboards = {
      url = "github:onixcomputer/grafana-dashboards";
    };
    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    devblog.url = "github:adeci/devblog";
    buildbot-nix = {
      url = "github:nix-community/buildbot-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-avf = {
      url = "github:nix-community/nixos-avf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    adeci-nixvim = {
      url = "github:adeci/nixvim-config";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    upmpdcli = {
      url = "path:/home/brittonr/git/upmpdcli";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    radicle-nix-adapter = {
      url = "git+https://radicle.defelo.de/zhSTd5vZ9K8aqtLecgSU5zDAZaS8.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      # Enable debug mode for nix repl inspection: nix repl .#debug
      debug = true;

      imports = [
        # Enable partitions for lazy input fetching
        inputs.flake-parts.flakeModules.partitions

        # Core parts (always evaluated)
        ./parts/clan.nix
        ./parts/lib.nix
        ./parts/flake-modules.nix
      ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      # Partition dev outputs so dev inputs are only fetched when needed
      # Building nixosConfigurations won't fetch treefmt-nix, pre-commit-hooks, etc.
      partitionedAttrs = {
        checks = "dev";
        devShells = "dev";
        formatter = "dev";
        packages = "dev";
        # Custom transposed outputs
        analysisTools = "dev";
        clanTools = "dev";
      };

      partitions.dev = {
        extraInputsFlake = ./dev;
        module = ./dev/flake-module.nix;
      };
    };
}
