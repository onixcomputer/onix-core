# Delta: Tenstorrent native runtime

## MODIFIED Requirements

### Requirement: Architecture-aligned ttWKV7 reader gathers

r[onix.tenstorrent.native_runtime.ttwkv7.reader_gather_alignment] Onix MUST make every ttWKV7 production-reader DRAM face-row gather satisfy the pinned architecture's read alignment with NoC-addressable scratch ownership while preserving exact ABI, tile contents, CB cadence, and Wormhole behavior.

#### Scenario: Blackhole gathers a face row
- GIVEN a 32-byte face row at either residue within a pinned 64-byte Blackhole DRAM-read block
- WHEN a production reader gathers that row
- THEN it reads one 64-byte-aligned DRAM block into 64-byte-aligned bounded worker-L1 scratch derived from a reader-private circular-buffer page
- AND it does not use a process-local stack or private-LDM object as the NoC destination
- AND it copies exactly the selected 32 bytes to the requested destination row after the read barrier

#### Scenario: Wormhole gathers a face row
- GIVEN the pinned 32-byte Wormhole DRAM-read contract
- WHEN a production reader gathers that row
- THEN it retains one direct asynchronous 32-byte read to the exact destination
- AND it does not reserve the Blackhole scratch page
- AND the existing outer barrier, CB order, and push cadence remain unchanged

#### Scenario: Alignment planning is validated without hardware
- GIVEN source face-row offsets from both row parities and both column faces
- WHEN compile-time alignment plans are evaluated for pinned Blackhole and Wormhole
- THEN aligned source offsets satisfy the architecture boundary, selected intervals remain in bounds, and aligned offset plus remainder reconstructs every source offset
- AND a 64-byte-aligned scratch interval remains inside its reserved tile-sized page
- AND invalid direct Blackhole 32-byte gathers, stack-backed NoC destinations, and missing scratch reservation are rejected by static checks

#### Scenario: Scratch ownership is validated without hardware
- GIVEN the patched production readers, their host circular-buffer allocation, and a negative stack-scratch fixture
- WHEN the source gate runs
- THEN both readers derive Blackhole scratch from one reserved CB22 write pointer
- AND the host allocates at least one tile-sized CB22 page in decode and chunked modes
- AND no kernel producer or consumer aliases CB22
- AND the negative stack-scratch fixture is rejected

#### Scenario: Both readers remain architecture compilable
- GIVEN the patched chunked and decode readers plus all diagnostic data-movement peers
- WHEN the offline architecture gate runs
- THEN every source compiles as the correct RISCV processor for pinned Blackhole and Wormhole
- AND no device is enumerated, initialized, opened, stopped, or contacted

#### Scenario: Offline checks pass
- GIVEN exact ABI fixtures, layout controls, writer checks, package checks, and host configuration
- WHEN the patch is validated
- THEN all existing positive and negative checks pass without relaxed comparison or changed runtime vectors
- AND no physical correctness, new hardware authorization, or broad P150 compatibility claim is made
