{
  description = "Onix Infrastructure";

  nixConfig = {
    extra-substituters = [
      "https://devenv.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Experimental DGX machine lifecycle from cachix/devenv#3073.
    # Keep this exact canary separate from the default development shell.
    devenv-machines = {
      url = "github:cachix/devenv/6e61f6a12f730b81228f70ee2487320fdbb1e2fc";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix = {
      url = "github:onixcomputer/nix";
      # The fork still carries packaging/patches/0001-Fix-uncaught_exceptions-...
      # (boostorg/context 58832123) and injects it as the first boost patch,
      # so any nixpkgs that also applies the 0921b9f (BOOST_NOINLINE) and
      # 58832123 pair for boost 1.88-1.92 breaks the patch sequence and boost
      # cannot build. release-26.05 gained that pair in b5e044308f12
      # (2026-08-02) and builds boost 1.89.0, so the channel tip is not safe.
      # Pin the immutable build-4193 snapshot the fork was already locked to
      # instead of the moving channels.nixos.org tarball, so `nix flake
      # update` cannot silently advance into the broken zone. When the fork
      # drops its local patch, resolve the current channel tip with the
      # multiverse and pin that commit here:
      #   nix eval --raw github:fzakaria/nixpkgs-multiverse#multiverse.x86_64-linux.releaseTips."26.05".rev
      # (see AGENTS.md "Flake evaluation").
      inputs.nixpkgs.url = "https://releases.nixos.org/nixos/26.05/nixos-26.05.4193.a50de1b7d8a5/nixexprs.tar.xz";
      inputs.flake-parts.follows = "flake-parts";
    };

    onix-wasm = {
      url = "github:onixcomputer/onix-wasm";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    srvos = {
      url = "github:nix-community/srvos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-facter-modules.url = "github:nix-community/nixos-facter-modules";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fast-nix-gc = {
      url = "github:Mic92/fast-nix-gc";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
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
        treefmt-nix.follows = "treefmt-nix";
      };
    };
    niks3 = {
      url = "github:Mic92/niks3/v1.8.0";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        treefmt-nix.follows = "treefmt-nix";
      };
    };
    hercules-ci-effects = {
      url = "github:hercules-ci/hercules-ci-effects";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
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
    multiverse.url = "github:fzakaria/nixpkgs-multiverse";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixdelta = {
      url = "github:adeci/nixdelta";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    dgx-spark = {
      url = "github:graham33/nixos-dgx-spark";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        disko.follows = "disko";
        pre-commit-hooks.follows = "pre-commit-hooks-nix";
      };
    };
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
    noctalia-plugins = {
      url = "github:Mic92/noctalia-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nitrous = {
      url = "github:pinpox/nitrous";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mercury-cli = {
      url = "github:MercuryTechnologies/mercury-cli";
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
    tenstorrent-nix = {
      url = "git+ssh://git@github.com/OnixResearch/tenstorrent.nix.git";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        treefmt-nix.follows = "treefmt-nix";
        systems.follows = "systems";
      };
    };
    tt-kmd = {
      url = "github:tenstorrent/tt-kmd/ttkmd-2.10.0";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-parts.follows = "flake-parts";
        systems.follows = "systems";
      };
    };

    # Dev tooling inputs (previously in dev/flake.nix partition)
    brittonpi = {
      url = "git+ssh://git@github.com/brittonr/pi.git";
      flake = false;
    };
    cairn = {
      url = "git+ssh://git@github.com/OnixResearch/cairn.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixfmt-rs = {
      url = "github:Mic92/nixfmt-rs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };
    pre-commit-hooks-nix = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mics-skills = {
      url = "github:Mic92/mics-skills";
      inputs = {
        nixpkgs.follows = "nixpkgs";
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
    ki-editor = {
      url = "github:ki-editor/ki-editor";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        rust-overlay.follows = "rust-overlay";
      };
    };
    tigerstyle = {
      url = "github:onixresearch/octet";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        rust-overlay.follows = "rust-overlay";
      };
    };

    kiln = {
      url = "git+https://seed.radicle.garden/z2wsvXm5S2sJGvuV1k5JHiwi1PbKE.git?rev=ccf6c64e8cba1d77299eab1386788426fa63e43e";
      inputs.octet.follows = "tigerstyle";
    };
    kiln-canary = {
      url = "git+https://seed.radicle.garden/z2wsvXm5S2sJGvuV1k5JHiwi1PbKE.git?rev=69c0a6ac454d7291e4aed12fd72a6f2c31636e76";
      inputs.octet.follows = "tigerstyle";
    };
    kiln-ci-legacy = {
      url = "git+https://seed.radicle.garden/z2wsvXm5S2sJGvuV1k5JHiwi1PbKE.git?rev=8821e9adf15ad28838025bfbdd2e09c8d76fe5db";
    };
    lattice = {
      url = "git+ssh://git@github.com/OnixResearch/lattice.git?rev=c513d94d89e901ffa56ae67f375f973e55958e42";
      inputs.octet.follows = "tigerstyle";
    };
    musnix = {
      url = "github:musnix/musnix";
      inputs.nixpkgs.follows = "nixpkgs";
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
        ./flake-outputs/ttwkv7.nix # Unfree standalone TT-Metalium operator package
      ];
      flake =
        (import ./flake-outputs/clan.nix {
          inherit (inputs) self;
          inherit inputs;
        })
        // (import ./flake-outputs/effects.nix { inherit inputs; });
    };
}
