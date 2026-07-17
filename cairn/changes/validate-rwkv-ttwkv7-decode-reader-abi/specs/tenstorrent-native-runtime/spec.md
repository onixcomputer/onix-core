## ADDED Requirements

### Requirement: Real-weight ttWKV7 decode-reader ABI validation
r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_decode_reader_abi] Onix MUST provide a deterministic device-free cross-package check that binds the exact accepted real-weight BF16 host buffers to ttWKV7's production decode runtime ABI and unchanged reader source-page/tiled-face mapping without initializing a Metalium device.

#### Scenario: Production and validation share the decode ABI core
- GIVEN the accepted 12-head decode shape and one contiguous logical instance range
- WHEN reader, compute, and writer runtime arguments are constructed
- THEN production and validation compile against the same pure fixed-array decode ABI core
- AND the core rejects invalid dimensions, products, addresses, or ranges without filesystem, environment, process, network, clock, logging, or device operations

#### Scenario: Exact real host buffers enter reader validation
- GIVEN the package-installed boundary fixture and accepted host-layout identities
- WHEN decode-reader validation runs
- THEN it accepts only the exact whole-file fixture authority and reconstructs all six accepted tiled input buffers and the accepted tiled retained-state buffer
- AND every transformed BF16 identity matches the accepted host-layout boundary before reader indexing is modeled

#### Scenario: Complete retained state is gathered for 12 heads
- GIVEN the exact tiled `[32,49152]` retained-state buffer and logical instance range `[0,12)`
- WHEN the source-locked decode reader model applies production's flat-strip page and tiled-face formulas
- THEN all 1,536 state source pages, both 16-element face reads per row, and all 49,152 meaningful BF16 state values are covered exactly once in reader CB tile order
- AND an independent logical `[head,row,column]` tiled oracle matches every gathered bit without using reader source-page formulas

#### Scenario: Complete input vectors are gathered for 12 heads
- GIVEN the six exact tiled `[32,64]` input buffers with 12 logical and 20 padded head rows
- WHEN the source-locked decode reader model selects source pages and head rows
- THEN exactly 144 input page/row selections and 288 individual face reads reconstruct all 4,608 meaningful BF16 values in `[head,input,dimension]` order
- AND padded heads are never selected and unspecified destination rows 1 through 31 are neither fabricated nor included in passing evidence

#### Scenario: Decode source and receipt authorities are deterministic
- GIVEN the unchanged installed production reader source and the same pinned fixture
- WHEN validation runs repeatedly
- THEN the exact reader source identity, runtime vectors, source-page/face trace, state payload, input payload, and domain-separated combined identity are byte-identical
- AND the cross-package Nix check locks the receipt without adding the fixture or checkpoint to ttWKV7's runtime closure

#### Scenario: ABI, gather, fixture, or command is malformed
- GIVEN an invalid dimension, product, address, instance range, runtime field, state stride, head row, face selection, tensor order, state orientation, payload length, fixture byte, fixture length, missing argument, or extra suffix
- WHEN decode-reader validation runs
- THEN it returns nonzero and emits no passing receipt
- AND it does not sample, reorder, truncate, retry, fetch, substitute zero state, accept another fixture, change production kernels, or fall back to a hardware mode

#### Scenario: Existing boundaries remain stable
- GIVEN the new decode-reader ABI check
- WHEN package validation runs
- THEN historical host-layout, checkpoint-shape, synthetic data-movement, reader-alignment, and architecture checks continue to pass
- AND production reader, compute, and writer kernel sources remain unchanged and compile for Blackhole and Wormhole

#### Scenario: Decode-reader evidence remains narrowly scoped
- GIVEN the real-weight decode-reader ABI check passes
- WHEN integration progress is reported
- THEN the claim is limited to exact host runtime-vector construction and source-level page/face mapping of meaningful reader payloads for the pinned boundary
- AND no BRISC, NoC, CB initialization, compute, writer, P150, generation, serving, performance, or hardware authorization claim is inferred
