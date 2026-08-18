## Context

The accepted boundary fixture installs six little-endian BF16 `[12,64]` input vectors and one retained `[12,64,64]` state. The accepted host-layout check proves these become six exact tiled `[32,64]` buffers and one exact tiled `[32,49152]` buffer. The production decode reader then interprets runtime arguments, selects 12 logical instances, gathers every state row from flat-strip pages, and extracts each input head row from the padded tiles. No accepted artifact currently binds those production source formulas or exact decode ABI vectors to the real fixture.

This change remains device-free. Metalium's CPU `convert_layout` helper is permitted. `MeshDevice::create_unit_mesh`, command queues, runtime state directories, kernel execution, owner-service changes, and physical device access are forbidden.

## Goals and success contract

The exact goal is a deterministic source-level proof that, for `G=1`, `L=1`, `S=64`, and `H=12`, ttWKV7's unchanged production decode-reader indexing over the accepted transformed real-weight buffers reconstructs all meaningful reader CB state and input values exactly, while production and validation share the exact reader/compute/writer runtime-argument builder.

Observable completion evidence requires:

- production and validation compile against one pure decode-ABI builder for all 18 reader, eight compute, and 12 writer arguments;
- the validator accepts only the exact 420,072-byte fixture and re-establishes the accepted six input-upload and retained-state upload identities before reader modeling;
- source-locked emulation covers all 12 instances, 1,536 state source pages, 144 input page/row selections, 3,360 individual 16-element face reads grouped into 1,680 paired row gathers, 49,152 state BF16 values, and 4,608 input BF16 values;
- independently constructed logical state tiles and input vectors match every meaningful emulated CB value and exact BF16 bit;
- runtime vectors, page/face trace, state payload, input payload, and a domain-separated combined identity are deterministic and locked;
- malformed fixtures, wrong ABI fields, invalid ranges, source-page stride changes, head-row changes, state transposition, payload truncation, missing arguments, and suffixes fail closed;
- the exact production reader source is pinned and continues to compile for Blackhole and Wormhole; production reader, compute, and writer kernels remain unchanged;
- historical host-layout, checkpoint-shape, architecture, and synthetic data-movement checks remain successful;
- the checkpoint and fixture enter only the cross-package check, not ttWKV7's runtime closure.

False completion includes checking only runtime-vector length, sampling heads or values, using the same gather implementation as both actual and expected, hashing transformed buffers without reading them through source pages/faces, treating padded heads as instances, inventing deterministic values for unspecified input-tile rows, changing the kernel to match the emulator, accepting a coherent but unpinned fixture, invoking a device, or describing source modeling as kernel or P150 correctness.

## Functional core and imperative shell

`ttwkv7-decode-abi.h` is a pure deterministic core. It accepts reviewed dimensions, explicit synthetic or production buffer addresses, and one contiguous instance range, validates bounds and products, and returns fixed-size reader, compute, and writer arrays. It performs no filesystem, environment, process, clock, logging, or device operation. The production runner uses it only for decode mode; the historical chunked path remains unchanged.

The validator's pure core accepts parsed BF16 artifacts, constructs host layouts through `ttwkv7-host-layout.h`, invokes Metalium's CPU tilizer, emulates the source-locked page and face reads, builds an independent logical oracle, compares complete meaningful payloads, and returns a receipt. Its thin shell validates one exact path argument, reads the bounded file, emits one JSON line, and maps failures to fixed statuses.

Unspecified rows 1 through 31 of decode input staging tiles are not hashed or assigned invented values. The evidence covers only row zero, where the reader writes the 64 logical values. Whether later compute operations are unaffected by stale values in unwritten rows is explicitly outside this source-mapping claim. Every state tile element is covered.

## Decode ABI authority

For synthetic nonzero addresses, the shared builder serializes:

- reader: `H, L, St, Ht, G, six input addresses, state address, L, 0, 0, 1, inst_start, inst_end`;
- compute: `St, G*H, L, Ht, 1, inst_start, inst_end, decode_pack`;
- writer: `output address, inst_start, inst_end, G*H, L, H, St, C/32, G*L, L, 1, 1`.

The validator locks a full `[0,12)` range and negative controls cover empty, reversed, out-of-bounds, first-instance, and final-instance boundaries. Production may partition the 12 instances across cores; physical grid selection and the actual partition are outside this device-free claim.

## Reader source model and independent oracle

The emulated source path follows the unchanged decode reader:

- state page `h*(St*St*32) + (it*32+r)*St + jt` for sequence zero;
- input page `ht*St+st`, where `ht=h/32` and source row `lh=h%32`;
- tiled-NFACES row access by left and right 16-element faces.

The emulator reads only from the accepted Metalium-tiled BF16 buffers and records every page, face, and destination selection in a domain-separated trace. The independent oracle never uses source pages or reader offsets: it builds each head's `[64,64]` state directly from logical `[head,row,column]` values, independently tiles it in top-left, top-right, bottom-left, bottom-right face order, and appends input values directly in `[head,input,dimension]` order. Equality therefore detects wrong state stride, head row, face, page, tensor order, or orientation.

## Portfolio-search registry

Search budget: four mechanism families, one fixture authority, one installed runner authority, one installed reader-source authority, one advisory review, two implementation rounds, and deterministic local checks. Serial lenses are correlated because isolated workers are unavailable. Allowed outcomes are `validated`, `blocked`, `exhausted`, or `user-decision-required`.

| family | mechanism | claim | state | blocker / next check |
|---|---|---|---|---|
| Physical reader capture | Run the exact real buffers through the P150 reader and capture CB output | Device reader correctness | blocked | Hardware authorization is exhausted; another device process is forbidden. |
| Kernel simulator | Execute production BRISC reader semantics without a device | Stronger executable source semantics | blocked | No reviewed simulator authority for these NoC/CB operations is packaged; adding one is equivalent to a larger validation project. |
| Shared device/host index header | Change the reader to call a host-readable index core | Direct source sharing | falsified | The accepted host-layout boundary requires production kernels to remain unchanged, and changing the kernel adds unnecessary architecture risk. |
| Shared ABI plus source-locked emulator and independent oracle | Share host runtime-vector construction, pin the unchanged compiled reader source, emulate its page/face formulas, and compare against direct logical tensors | Exact device-free real-fixture decode ABI and source-index mapping | validated | Complete positive, adversarial, source, closure, architecture, and deterministic receipt checks pass. |

## Risks and mitigations

- **The emulator drifts from the kernel**: pin the complete installed reader source identity, require exact reviewed formula sites, and fail any source change until evidence is re-reviewed.
- **The emulator agrees with itself**: expected payloads are constructed directly from logical fixture tensors without reader pages, face offsets, or source traces.
- **Runtime vectors are duplicated**: runner and validator use the same pure fixed-array builder; source checks reject the historical ad hoc decode vectors.
- **Stale input rows become fabricated evidence**: only destination row zero written by the reader is compared and hashed; unspecified rows and any later compute sensitivity to them remain explicit non-claims.
- **Padded heads are treated as recurrent heads**: instance range is exactly `[0,12)` while input storage remains 32 rows.
- **Changed bytes remain coherent**: exact whole-file BLAKE3 and accepted transformed-buffer BLAKE3 authorities reject them.
- **A no-device validator opens hardware**: source checks reject device headers and APIs, and the executable has no device-mode branch.
- **Evidence is overstated**: receipt non-claims distinguish source modeling from kernel execution and physical correctness.

## Non-claims

This change does not establish BRISC instruction execution, NoC transfer correctness, CB initialization outside meaningful rows, compute-kernel equations, writer-kernel execution, repaired-reader completion, Metalium device initialization, P150 correctness, full-layer or full-model parity, token generation through ttWKV7, serving, throughput, or latency. It does not authorize another hardware process.

## Validation evidence

The pre-change baseline passed with ttWKV7 package `/nix/store/wqqn11pfhfxnvj0fjl8ipcxcvs2h5b51-ttwkv7-unstable-2026-06-22`, host-layout check `/nix/store/si5fnm8bamakwyfwfqjf4km5fa945gx4-rwkv-ttwkv7-host-layout-check`, architecture check `/nix/store/b85dmwmfg7zjlszfihpa9bwxg9k04srz-ttwkv7-architecture-check`, checkpoint-shape diagnostic `S=64 H=12 Hpad=32 St=2 Ht=1 C=768 chunked_units=6`, and synthetic data-movement diagnostic `PASS`.

The final package is `/nix/store/z1j611i6c60rklwrzlilsa61ivjlnkxv-ttwkv7-unstable-2026-06-22`. Both validators compile with `-Wall -Wextra -Wpedantic -Werror`, and historical package/install checks pass. The final decode-reader cross-package check is `/nix/store/76y7srnjm6xj69dhc6gda4ijk52g5n33-rwkv-ttwkv7-decode-reader-check`. Its 2,716-byte receipt is byte-identical to a fresh direct run and has BLAKE3 `1b5a682b68999e9160f832920c1952218496afb5452456277ce48eb551b0f902`.

The exact reader runtime vector is `[12,1,2,1,1,4096,8192,12288,16384,20480,24576,28672,1,0,0,1,0,12]` with BLAKE3 `e1eb29d5f7771c31453b84dfc8976d2655fa3a22d9c4162b187692204a18d17b`. The compute vector is `[2,12,1,1,1,0,12,4]` with BLAKE3 `d40aade7cd0925462819a1a219de53ca415495ba184569db139b9be019056ae8`. The writer vector is `[32768,0,12,12,1,12,2,24,1,1,1,1]` with BLAKE3 `387b7f3c5b39372ff8ff97e1decb786f0981e55497ed8a5e3b1e49494ca65ecd`. Positive controls also prove that multi-token decode preserves historical reader/compute chunk count `1` while the writer receives the actual token count; zero, excessive, inconsistent, empty, reversed, and out-of-range configurations reject.

The validator re-establishes the six accepted input-upload identities and retained-state upload identity `a2966fb56eb97345c35c7710f222eac752d7d2f8f84eb0bf2a8e11e85ae466f7`. It covers logical instances `[0,12)`, all 1,536 state source pages, all 144 input page/row selections, 3,360 individual face reads grouped into 1,680 paired row gathers, all 49,152 state values, and all 4,608 input values. Every source page has each face exactly once; source alignment/remainder identities and destination offsets are checked.

The source-page/face trace BLAKE3 is `dcc74e1be512087c818aaed55c3a4847e5c366a0973ee85ab7ba998199fd7101`. The complete state payload BLAKE3 is `ab70bffef8633ac1740b71e0f09610d61fd20161458d9a65e0d4cb57892f12b5`; the complete written input payload BLAKE3 is `e21a26e0ad74e9f1a9e8a18c7cc22c2376d92548f17d961d8ff7309e12547122`; the domain-separated combined identity is `ced0aac7159bfe1d7416796d7ca205353384900120c9b4916ae4e8ca210ccad1`. Independent direct logical oracles match every BF16 bit. Changed state stride, head row, face order, state orientation, payload permutation, payload truncation, exact fixture bytes/order/length/path, and command vectors fail closed.

Production kernels remain byte-identical: decode reader BLAKE3 `221a9e9cb987902e99e4e50bfe5dce2d9f44a5252720b5d3dcbd13fbadb85fca`, decode compute BLAKE3 `bbda1f84aa2fcef7a946de76e0a0a03202e068c822f54b80c9cab5f4e13e35d0`, and writer BLAKE3 `80ecf2f848144aa1a693f6b3b854542d2fd752bed8c83d9cbce31bd16e261b74`. The dual-architecture output remains `/nix/store/b85dmwmfg7zjlszfihpa9bwxg9k04srz-ttwkv7-architecture-check`. Historical host-layout check `/nix/store/6hpdc5isg0nmv03pixhcfnpyhzmpgr6f-rwkv-ttwkv7-host-layout-check`, shape test, and synthetic data-movement self-test all pass.

Installed source identities are runner BLAKE3 `ba190bdfd18ced68e90c56d654178df8a7a27e09568075480a23e18d8bd69328` over 34,453 bytes, pure ABI header BLAKE3 `5d2d17353d4185f37b17ec490dfbcdf96419cec1ab3652ecdb6b80c7d410cec8` over 7,364 bytes, and validator BLAKE3 `5e32ef011e373d555972eec51a9bab9be546476410424259643a37a1e83a4b76` over 49,443 bytes. The runtime closure contains 68 paths and no RWKV layer harness, Goose checkpoint, safetensor, or boundary fixture; fixture bytes enter only the separate cross-package check.

Full `pre-commit run --all-files` passes. Clean detached-worktree Cairn validation plus proposal, design, and tasks gates report `valid: true`, `verdict: "PASS"`, and no issues. The advisory audit identified a risk of treating unwritten input rows as harmless compute inputs; the claim was narrowed so those rows and any later compute sensitivity remain explicit non-claims. The surviving portfolio candidate is validated. Hardware and simulator routes remain blocked, and changing the production reader was rejected. Cairn sync added the accepted requirement with receipt `c7d8f79952415fd314780487ceabf80643afd7ce8763627b1935424846f75c98`. No Tenstorrent device, owner service, runtime cache, Metalium device initialization, command queue, kernel execution, or hardware evidence path was accessed.
