# Proposal: Port ttWKV7 SFPU setup to Blackhole

## Why

The packaged ttWKV7 command now selects one visible P150 correctly, but its first Blackhole JIT compilation fails before WKV execution because the custom constant-tile generator calls the Wormhole-only `math::set_addr_mod_base()` primitive directly. The pinned Metalium runtime already exposes architecture-specific SFPU start and finish helpers with different Wormhole and Blackhole implementations.

## What changes

- Patch the pinned ttWKV7 constant-tile generator to use Metalium's architecture-selected SFPU start and finish helpers.
- Preserve the upstream algorithm, kernel loop, data formats, and CPU-oracle comparison.
- Add package checks that require the portable helper pair and reject the direct Wormhole-only primitive.
- Deploy the reviewed package and run one bounded single-device P150 CPU-oracle test with the owner service isolated and restored.

## Boundaries

A successful package build proves source patching and package layout. A successful Blackhole JIT compile proves only compiler compatibility. P150 support is claimed only if the bounded ttWKV7 test executes the WKV kernel and passes its CPU-oracle comparison; no performance or P150x2 claim follows.
