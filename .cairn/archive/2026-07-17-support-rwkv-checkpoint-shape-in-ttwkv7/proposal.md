# Change: Support the pinned RWKV checkpoint shape in ttWKV7

## Why

The accepted RWKV checkpoint has head size 64 and 12 heads. The packaged ttWKV7 host still derives input head-tile rows with floor division by 32 and tilizes an unpadded `H x S` block, assumptions inherited from its default 32-head synthetic diagnostic. That host preparation cannot represent the exact checkpoint shape even though the production readers index individual heads within a padded head tile.

## What Changes

- Generalize ttWKV7 host input preparation to pad head rows to a complete 32-row tile while preserving only real heads as work instances.
- Use ceiling division for head-tile rows and two-instance chunked work groups so partial head tiles and odd instance counts cannot be silently dropped.
- Add strict pre-device shape and numeric argument validation plus an argument-free checkpoint-shape self-test that exercises Metalium layout conversion without opening a device.
- Keep the historical default `S=64`, `H=32` test/benchmark behavior and all fixed diagnostic wrappers unchanged.
- Install the patched host source with the package and reject floor-division, missing-padding, or floor-grouping source mutations offline.

## Impact

- Affected spec: `tenstorrent-native-runtime`
- Affected code: `pkgs/ttwkv7`
- Hardware boundary: no Tenstorrent process, owner-control action, Metalium device creation, or physical-correctness claim is authorized by this change.
