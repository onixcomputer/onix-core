# kache Nix Rust changebot pilot

`../changebot` is the first opt-in example for the Nix-owned kache Rust build path. The example lives in `examples/kache-nix-rust/changebot-crane-pilot.nix` and wraps the existing changebot Crane package without editing the sibling repository.

## Run the wrapped example locally

The kache wrapper library is onixpkgs' `lib.kacheNixRust`, and the kache package comes from onixpkgs:

```nix
let
  onixpkgs = builtins.getFlake "git+ssh://git@github.com/OnixResearch/onixpkgs.git";
  changebot = builtins.getFlake "path:/home/brittonr/git/changebot";
  system = builtins.currentSystem;
  pkgs = import onixpkgs.inputs.nixpkgs { inherit system; };
in
import /home/brittonr/git/onix-core/examples/kache-nix-rust/changebot-crane-pilot.nix {
  inherit pkgs;
  inherit (onixpkgs.lib) kacheNixRust;
  onixPackages = onixpkgs.packages.${system};
  changebotPackage = changebot.packages.${system}.default;
}
```

The enabled example sets `RUSTC_WRAPPER` to the Nix-owned kache wrapper and `KACHE_NIX_CACHE_DIR` to `/var/cache/kache-nix`. On `britton-desktop`, that path is a dedicated `datapool/kache-nix` ZFS dataset on the 4TB NVMe; the `kache-nix-rust-britton-desktop` service instance creates the machine-owned directory and exposes only that path through `nix.settings.extra-sandbox-paths`.

## Validation evidence

Focused checks in onix-core cover the machine wiring and the example:

```sh
nix build \
  .#checks.x86_64-linux.kache-nix-rust-sandbox-settings \
  .#checks.x86_64-linux.kache-nix-rust-changebot-example \
  --no-link -L
```

onixpkgs runs the wrapper contract as `checks.x86_64-linux.kache-nix-rust-wrapper-contract`. It proves positive and negative paths:

- enabled wrapper invokes kache and records rustc, cache directory, and key-salt telemetry;
- `KACHE_NIX_DISABLED=1` bypasses kache explicitly;
- missing cache access fails with an actionable diagnostic;
- wrapped toolchain output keeps `rustdoc` available.

The changebot example check proves enabling the example injects the wrapper and disabling it leaves `RUSTC_WRAPPER` unset.

Local changebot evidence on 2026-06-29:

- unwrapped package: `/nix/store/8ga83nk40axgqnvwqnf3y539nj8gs4cd-remora-0.1.0`;
- wrapped package: `/nix/store/svzkn7ic3ahs6awkx6n0xjz3jqy9hfyd-remora-0.1.0`;
- `remora --help` output matched between both packages.

That proves the selected example can build through the wrapper without changing CLI behavior. Broader rollout should wait for repeated edit/build timing and cache-hit data on at least one more Rust package shape.

## Rollback and cleanup

To roll back machine support, remove or disable the `kache-nix-rust-britton-desktop` service instance in `inventory/services/services.ncl` and rebuild the machine. To roll back one derivation, import the changebot example with `enableKache = false` or stop using the example expression.

After rollback, the only mutable state to clean is the machine-owned pilot cache:

```sh
sudo rm -rf /var/cache/kache-nix
```

Do not remove `/home/brittonr/.cache/kache`; that is user-level interactive Cargo state and is intentionally separate from the Nix-builder pilot.
