{
  description = "Host-verified Aspen UMA core and x86_64 UEFI probe";

  inputs = {
    octet.url = "git+ssh://git@github.com/OnixResearch/octet.git?rev=f39ab155170f32ffc6408782d20c0d488137c995";
    nixpkgs.follows = "octet/nixpkgs";
  };

  outputs =
    {
      nixpkgs,
      octet,
      ...
    }:
    let
      system = "x86_64-linux";
      uefiTarget = "x86_64-unknown-uefi";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ octet.inputs.rust-overlay.overlays.default ];
      };
      toolchain = (pkgs.rust-bin.fromRustupToolchainFile "${octet}/rust-toolchain.toml").override {
        targets = [ uefiTarget ];
      };
      craneLib = (octet.inputs.crane.mkLib pkgs).overrideToolchain toolchain;
      cargoVendorDir = craneLib.vendorCargoDeps { cargoLock = ./Cargo.lock; };
      # The adapter must compile on the host. Only the UEFI entry uses target cfg.
      hostScope = "--workspace --all-targets --all-features";
      source = pkgs.lib.cleanSourceWith {
        src = ./.;
        filter =
          path: _type:
          let
            name = builtins.baseNameOf path;
          in
          !(builtins.elem name [
            "target"
            ".git"
            ".jj"
            "result"
          ]);
      };
      runCargo =
        name: commands: install:
        pkgs.runCommand name
          {
            nativeBuildInputs = [
              toolchain
              pkgs.stdenv.cc
            ];
          }
          ''
            export HOME="$TMPDIR/home"
            export CARGO_HOME="$TMPDIR/cargo-home"
            mkdir -p "$HOME" "$CARGO_HOME"
            cp ${cargoVendorDir}/config.toml "$CARGO_HOME/config.toml"
            cp -R ${source} source
            chmod -R u+w source
            cd source
            ${commands}
            ${install}
          '';
      uefi =
        runCargo "aspen-uma-helper-uefi"
          ''
            cargo build --offline --locked --release --all-features --target ${uefiTarget} --bin uma-probe
          ''
          ''
            mkdir -p "$out/bin"
            cp target/${uefiTarget}/release/uma-probe.efi "$out/bin/uma-probe.efi"
            install -Dm444 ${source}/third-party/r-efi-AUTHORS "$out/share/licenses/aspen-uma-helper/r-efi-AUTHORS"
          '';
      octetHook = pkgs.writeShellApplication {
        name = "octet-deny-all";
        runtimeInputs = [
          toolchain
          pkgs.stdenv.cc
          octet.packages.${system}.cargo-octet
        ];
        text = ''
          export OCTET_PRECOMMIT_USE_INSTALLED=true
          exec ${octet}/hooks/octet-deny-all.sh "$@"
        '';
      };
      octetCheck =
        (octet.lib.mkConsumerCheck {
          inherit system;
          src = source;
          cargoLock = ./Cargo.lock;
          # mkConsumerCheck supplies --workspace when the package list is empty.
          cargoExtraArgs = "--all-targets --all-features --locked --offline";
          nativeBuildInputs = [ pkgs.stdenv.cc ];
        }).overrideAttrs
          (_: {
            # Both compiler warnings and the full pinned Octet catalog are errors.
            RUSTFLAGS = "-D warnings";
            DYLINT_RUSTFLAGS = "-D warnings";
          });
    in
    {
      packages.${system} = {
        default = uefi;
        uma-probe = uefi;
      };
      apps.${system}.octet-deny-all = {
        type = "app";
        program = "${octetHook}/bin/octet-deny-all";
        meta.description = "Run the official pinned Octet deny-all hook";
      };
      checks.${system} = {
        core-tests = runCargo "aspen-uma-helper-core-tests" ''
          cargo test --offline --locked ${hostScope}
          cargo test --offline --locked --workspace --doc --all-features
        '' ''touch "$out"'';
        clippy = runCargo "aspen-uma-helper-clippy" ''
          cargo clippy --offline --locked ${hostScope} -- -D warnings
          cargo clippy --offline --locked --workspace --bins --all-features --target ${uefiTarget} -- -D warnings
        '' ''touch "$out"'';
        uefi-build = uefi;
        uefi-smoke = import ./vm-check.nix {
          inherit pkgs source;
          probe = uefi;
        };
        octet-deny-all = octetCheck;
      };
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          toolchain
          pkgs.stdenv.cc
          pkgs.pre-commit
          octet.packages.${system}.cargo-octet
        ];
        RUSTFLAGS = "-D warnings";
        DYLINT_RUSTFLAGS = "-D warnings";
      };
      formatter.${system} = pkgs.nixfmt;
    };
}
