{
  description = "Onix Infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    adios-flake.url = "github:Mic92/adios-flake";

    # Kept as a top-level input so upstream dependencies that use
    # flake-parts all share a single copy via follows.
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    clan-core = {
      url = "git+https://git.clan.lol/adeci/clan-core?ref=adeci-unstable";
      inputs = {
        home-manager.follows = "home-manager";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
      };
    };
    wrappers = {
      url = "git+file:///home/brittonr/git/wrappers";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    grub2-themes = {
      url = "github:vinceliuice/grub2-themes";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mcp-servers-nix = {
      url = "github:natsukium/mcp-servers-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    devblog = {
      url = "github:adeci/devblog";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
      };
    };
    buildbot-nix = {
      url = "github:nix-community/buildbot-nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
      };
    };
    nixos-avf = {
      url = "github:nix-community/nixos-avf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    adeci-nixvim = {
      url = "github:adeci/nixvim-config";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixvim.follows = "nixvim";
        treefmt-nix.follows = "treefmt-nix";
      };
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
    upmpdcli = {
      url = "github:brittonr/upmpdcli";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    radicle-nix-adapter = {
      url = "git+https://radicle.defelo.de/zhSTd5vZ9K8aqtLecgSU5zDAZaS8.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pinenote-nixos = {
      url = "github:WeraPea/pinenote-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    clonadic = {
      url = "path:/home/brittonr/git/clonadic";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    niri = {
      url = "github:brittonr/niri";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
      };
    };

    # Dev tooling inputs (previously in dev/flake.nix partition)
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pre-commit-hooks-nix = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mics-skills = {
      url = "github:Mic92/mics-skills";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
      };
    };
  };

  outputs =
    inputs@{ adios-flake, self, ... }:
    let
      inherit (inputs.nixpkgs) lib;

      # Import modules directly
      modules = import "${self}/modules/default.nix" { inherit inputs; };

      # Build clan using standalone API (system-agnostic)
      clanModule = inputs.clan-core.lib.clan {
        specialArgs = {
          inherit inputs;
          wrappers = inputs.wrappers.wrapperModules;
        };
        inherit self;
        meta.name = "Onix";
        inherit modules;
        inventory = import "${self}/inventory" { inherit inputs; };

        exportsModule = import "${self}/inventory/exports-module.nix" { inherit lib; };
      };
    in
    adios-flake.lib.mkFlake {
      inherit inputs self;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      modules = [
        # Dev environment (formatter, pre-commit, devShells, MCP servers)
        ./parts/dev-env.nix

        # Checks
        ./parts/checks.nix
        ./parts/machine-checks.nix
        ./parts/vm-checks.nix

        # Analysis and infrastructure tools
        ./parts/sops-viz.nix
        ./parts/cloud-cli.nix

        # Workflow tools
        ./parts/merge-when-green.nix
        ./parts/nix-eval-warnings.nix
        ./parts/iroh-ssh.nix
        ./parts/claude-md.nix

        # TUI tools
        ./parts/tuicr.nix

        # Dev CLI tools
        ./parts/tracey.nix
        ./parts/ccusage.nix
        ./parts/abp.nix

        # Package management
        ./parts/updater.nix
      ];
      flake = {
        # Clan outputs
        inherit (clanModule.config)
          nixosConfigurations
          darwinConfigurations
          clanInternals
          ;
        clan = clanModule.config;

        # Shared library utilities
        lib = {
          machines = {
            names = builtins.attrNames (import ./inventory/core/machines.nix { });
            hasTag =
              machine: tag:
              let
                machinesDef = import ./inventory/core/machines.nix { };
              in
              builtins.elem tag (machinesDef.${machine}.tags or [ ]);
          };
          tags = {
            all =
              let
                tagDir = ./inventory/tags;
                contents = builtins.readDir tagDir;
                nixFiles = builtins.filter (name: builtins.match ".*\\.nix" name != null && name != "default.nix") (
                  builtins.attrNames contents
                );
              in
              map (name: builtins.replaceStrings [ ".nix" ] [ "" ] name) nixFiles;
          };
          roster = {
            users =
              let
                roster = import ./inventory/core/roster.nix { };
              in
              builtins.attrNames roster;
          };
          opentofu = import ./lib/opentofu/default.nix;
          terranix = import ./lib/opentofu/terranix.nix;
          opentofuTesting = {
            pure = import ./lib/opentofu/test-pure.nix;
            integration = import ./lib/opentofu/test-integration.nix;
            system = import ./lib/opentofu/test-system.nix;
            executionTests = import ./lib/opentofu/terraform-execution-tests.nix;
            examples = {
              simple = import ./lib/opentofu/examples/simple-terranix-example.nix;
            };
          };
          terranixTesting = import ./lib/terranix-testing;
          inherit inputs;
        };

        # NixOS modules for downstream consumers
        nixosModules.default = ./nixosModules/default.nix;
      };
    };
}
