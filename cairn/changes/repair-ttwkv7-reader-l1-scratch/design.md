# Design: Repair ttWKV7 reader L1 scratch

## Goal and Success Evidence

Make the Blackhole aligned 64-byte gather target actual NoC-addressable worker L1 rather than BRISC private stack/LDM. Success requires both production readers to derive scratch from a reserved CB22 write pointer, align it within one tile-sized page, preserve the selected 32-byte copy, compile for pinned Blackhole and Wormhole, and pass a negative source fixture that reintroduces stack scratch.

## Root-Cause Evidence

The exhausted process reached the first decode reader and timed out after workload commit. The compiled ELF's `_start` prologue reserves 304 stack bytes and computes a 64-byte-aligned local address with `addi a5,sp,191; andi s7,a5,-64`. Generated NoC issue sequences write `s7` as the local destination. The same ELF places `__stack_base`, `.data`, and `.bss` at `0xffb00ce0`, which TT-Metal names local data memory. Alignment therefore did not make the object worker L1 or a valid NoC destination.

Pinned TT-Metal kernels handling misaligned reads reserve a scratch CB and use `get_write_ptr()` as the destination. This is the relevant ownership distinction; the old source-level `alignas(64)` check was insufficient.

## Functional Core and Imperative Shell

`aligned_l1_scratch_address(address)` is the pure core: it rounds a worker-L1 address up to the architecture's power-of-two DRAM-read alignment. The readers are the thin shell: on Blackhole only, reserve one page from CB22 once, obtain its write pointer, align it, and pass it to the existing gather helper.

## Scratch Ownership and Bounds

The host already allocates CB22 with tile-sized pages in both paths: two pages for decode and at least 32 pages for chunked execution. No reader, compute kernel, or writer produces, consumes, waits on, pushes, or pops CB22. One reserved page can therefore remain reader-private for the kernel lifetime.

The page is 2048 bytes. Rounding its start upward by at most one alignment minus one and issuing one 64-byte read consumes at most 127 bytes, so the transfer remains inside that page. The scratch page is never pushed and cannot enter compute cadence.

## Architecture Boundary

Blackhole keeps the existing aligned source address, one 64-byte read, barrier, and exact 32-byte selected copy. Wormhole keeps the existing direct asynchronous 32-byte read and does not execute the reserve/get-write-pointer branch.

## Validation and Non-Claims

The architecture gate compiles all reviewed data-movement peers for both architectures, checks the host CB22 allocation, accepts the corrected reader sources, and rejects fixtures with a local `dram_read_scratch` array or a missing CB reservation. Package build and formatting remain device-free. No second hardware process is permitted by this change.

## Device-Free Completion Evidence

The pre-change architecture and package builds passed from cache. After the repair, the dual-architecture gate rebuilt both production readers and all reviewed peers and produced `/nix/store/b85dmwmfg7zjlszfihpa9bwxg9k04srz-ttwkv7-architecture-check`. The composed package and its install checks, including positive reader checks plus direct-gather, cadence-drift, stack-scratch, and missing-reservation negative fixtures, produced `/nix/store/9ci0570g2yh2cc5m8li1qw8bq4gp0fa4-ttwkv7-unstable-2026-06-22`.

Focused pre-commit checks passed `deadnix`, `statix`, and `treefmt`. Cairn validation from a clean detached worktree reported `valid: true`; the concurrent primary worktree remains globally blocked only by the unrelated placeholder `add-private-mesh-llm-sidecars` change. No device was enumerated, opened, stopped, or contacted.
