{
  description = "Onix Infrastructure";

  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    srvos = {
      url = "github:nix-community/srvos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    systems.url = "github:nix-systems/default";

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
      url = "git+https://git.clan.lol/clan/clan-core?ref=main&shallow=1";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
        disko.follows = "disko";
        sops-nix.follows = "sops-nix";
        systems.follows = "systems";
      };
    };
    wrappers = {
      url = "github:brittonr/wrappers";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    grub2-themes = {
      url = "github:vinceliuice/grub2-themes";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    buildbot-nix = {
      url = "github:nix-community/buildbot-nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
      };
    };
    upmpdcli = {
      url = "github:brittonr/upmpdcli";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pinenote-nixos = {
      url = "github:WeraPea/pinenote-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixdelta = {
      url = "github:adeci/nixdelta";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    niri = {
      url = "github:brittonr/niri";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wl-walls = {
      url = "github:brittonr/wl-walls";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nitrous = {
      url = "github:pinpox/nitrous";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
        systems.follows = "systems";
      };
    };

    # Nix with builtins.wasm support + nix ps (cherry-picked NixOS/nix#15380
    # and DeterminateSystems/nix-src#282 onto 2.33.3)
    nix-wasm = {
      url = "github:brittonr/nix/nix-ps-port";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };

    # Patched nickel-lang crates for wasm32-unknown-unknown (SourceIO trait)
    nickel-wasm-vendor = {
      url = "github:brittonr/nickel-wasm/wasm-vendor";
      flake = false;
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
    horizon = {
      url = "github:peters/horizon";
      flake = false;
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    drift = {
      url = "github:brittonr/drift";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        rust-overlay.follows = "rust-overlay";
      };
    };
    clankers = {
      url = "github:brittonr/clankers";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        rust-overlay.follows = "rust-overlay";
      };
    };
  };

  outputs =
    inputs@{ adios-flake, ... }:
    adios-flake.lib.mkFlake {
      inherit inputs;
      inherit (inputs) self;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      modules = [
        ./flake-outputs/checks.nix # machine builds, vars, packages, devShells
        ./flake-outputs/dev-env.nix # formatter, pre-commit, devShells, MCP
        ./flake-outputs/tools.nix # CLI tools (acl, vars, tags, merge-when-green, etc.)
      ];
      flake =
        (import ./flake-outputs/clan.nix {
          inherit (inputs) self;
          inherit inputs;
        })
        // (import ./flake-outputs/effects.nix { inherit inputs; });
    };
}
