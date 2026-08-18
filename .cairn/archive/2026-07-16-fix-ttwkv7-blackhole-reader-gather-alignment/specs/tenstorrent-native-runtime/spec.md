# Delta: Tenstorrent native runtime

## ADDED Requirements

### Requirement: Architecture-aligned ttWKV7 reader gathers

r[onix.tenstorrent.native_runtime.ttwkv7.reader_gather_alignment] Onix MUST make every ttWKV7 production-reader DRAM face-row gather satisfy the pinned architecture's read alignment while preserving exact ABI, tile contents, CB cadence, and Wormhole behavior.

#### Scenario: Blackhole gathers a face row
- GIVEN a 32-byte face row at either residue within a pinned 64-byte Blackhole DRAM-read block
- WHEN a production reader gathers that row
- THEN it reads one 64-byte-aligned DRAM block into 64-byte-aligned bounded L1 scratch
- AND copies exactly the selected 32 bytes to the requested destination row after the read barrier

#### Scenario: Wormhole gathers a face row
- GIVEN the pinned 32-byte Wormhole DRAM-read contract
- WHEN a production reader gathers that row
- THEN it retains one direct asynchronous 32-byte read to the exact destination
- AND the existing outer barrier, CB order, and push cadence remain unchanged

#### Scenario: Alignment planning is validated without hardware
- GIVEN source face-row offsets from both row parities and both column faces
- WHEN compile-time alignment plans are evaluated for pinned Blackhole and Wormhole
- THEN aligned source offsets satisfy the architecture boundary, selected intervals remain in bounds, and aligned offset plus remainder reconstructs every source offset
- AND invalid direct Blackhole 32-byte reader gathers are rejected by static checks

#### Scenario: Both readers remain architecture compilable
- GIVEN the patched chunked and decode readers plus all diagnostic data-movement peers
- WHEN the offline architecture gate runs
- THEN every source compiles as the correct RISCV processor for pinned Blackhole and Wormhole
- AND no device is enumerated, initialized, opened, stopped, or contacted

#### Scenario: Offline checks pass
- GIVEN exact ABI fixtures, layout controls, writer checks, package checks, and host configuration
- WHEN the patch is validated
- THEN all existing positive and negative checks pass without relaxed comparison or changed runtime vectors
- AND no physical correctness or broad P150 compatibility claim is made
