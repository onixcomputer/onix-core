{
  description = "Onix Infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    clan-core.url = "git+https://git.clan.lol/adeci/clan-core?ref=adeci-unstable";
    wrappers = {
      url = "github:brittonr/wrappers";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wrappers-niri = {
      url = "github:turbio/wrappers/init-niri";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wrappers-waybar = {
      url = "github:turbio/wrappers/init-waybar";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pre-commit-hooks-nix = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    kdl2nix = {
      url = "git+file:/home/brittonr/git/kdl2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    snix = {
      url = "git+https://git.snix.dev/snix/snix";
      flake = false;
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.treefmt-nix.flakeModule
        ./parts/clan.nix
        ./parts/devshells.nix
        ./parts/formatter.nix
        ./parts/pre-commit.nix
        ./parts/sops-viz.nix
        ./parts/checks.nix
        ./parts/infrastructure.nix
        ./parts/snix.nix
        ./checks/flake-module.nix
      ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
    };
}
