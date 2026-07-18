# Design: terminal device-4 evidence

## Success contract

The change is complete when a device-free, deterministic check proves from immutable package-owned evidence that:

- pueue task 25 invoked the archived argument-free runbook once and returned status 1;
- the single physical child process itself returned status 0 without timeout, retry, or reconnect;
- one device open, one response connection, 24 accepted canonical request/response pairs, and 24 committed workloads occurred;
- calls are ordered across token indices 2 and 3 and layers 0 through 11;
- all request and response BF16 payload values are finite;
- each second-token request carries the exact prior accepted post-state for its layer, establishing 12 byte-exact continuity edges;
- every numerical comparison reports `passed` under the declared NMSE ceiling and physical/oracle rankings select token 2;
- the classifier outcome remains `passed` with complete artifacts and no safety issues;
- both postflight board samples are healthy, ownership is restored, HTTP health is 200, and the rollback unit is inactive;
- the enclosing orchestration status remains 1 because archived runbook line 286 expected absent obsolete field `session_call_count`, while the accepted schema stores `core.session.call_count = 24` and `core.session.same_layer_state_continuity_count = 12`; and
- no additional hardware execution occurs.

False completion includes treating pueue failure as physical-process failure, hiding the post-process mismatch, changing immutable bytes, accepting truncated or contaminated framing, ignoring response request identity, inferring continuity from counts alone, or upgrading the evidence to exact parity or a wholly device-executed model.

## Evidence boundary

`pkgs/rwkv-ttwkv7-persistent-passed-evidence/fixtures/ttwkv7-persistent-device-4/` contains 72 files: 71 manifest-bound artifacts plus `fixture-manifest.tsv`. It omits the generated Metalium cache because the transcript, source identities, runtime vectors, server diagnostics, Inspector logs, and receipts are sufficient and materially smaller.

The immutable fixture manifest is 6,541 bytes with BLAKE3 `731a43dcab29614b72616388352246b42f2dfdea7f02b3160902c1f804bad010`. The copied run artifacts remain byte-identical. `postprocess-diagnostic.json`, `pueue-task.json`, and the two ordered frame-hash lists are explicitly derived indexing aids; they do not replace the raw runbook, pueue log, transcript, or receipts. Key fixture authorities are:

- classification: `0da071d132ea15953004e2e80488984b25650f5227d2ccb7682cc0fc77c7a68d`;
- process receipt: `83d78b2697c37d4887c531b7403539121779ec52ebb0c5fab4343ee97a7a7d39`;
- host receipt: `4d68f5607de77b82252e556c948ef4934d9a99c3fa69a0bdc7811049108e7749`;
- core receipt: `271c7f38c9a952024c176d35134e63b4919a24b4996fbf4f23febf2f802445a5`;
- server summary: `f615c0ac4e8a35fac66b4589b1161a26fb14ef65987184b00291a25954022bb0`;
- 4,981,056-byte transcript: `0469e5603660f8a06e2c6d4cc0ac6af48b57a413c02fd243708ad4084940cf47`;
- post-process diagnostic: `32076225425643b19f5071116695307b9c5209ca23df79035d7905bd0d891d20`; and
- pueue task log: `4194a4f12476edeb29699df1cfa292a033c224f6cbe1396cef72b4798be81f1f`.

The generated 727-byte terminal receipt has BLAKE3 `48ea004ea7e082d562f8189b48cc7600936b12761f675630eba8d3f9187d0709`. The checker source BLAKE3 is `fd403c3fb10ed4c2821704a6f8a7a977d2beb3add603643503816e538eefd43b`. The dedicated check is exposed as `rwkv-ttwkv7-persistent-device-4-evidence` and builds at `/nix/store/lkdrbzi9wwk44n8jr2yqk1aaqgwycan5-rwkv-ttwkv7-persistent-device-4-passed-evidence`.

In addition to locking the complete transcript, the Nix check independently recomputes BLAKE3 for each of the 24 request and 24 response frames and compares them with the ordered host/server authorities.

## Independent validation lenses

### Binary framing lens

The Rust core walks all 24 length-prefixed request/response pairs without scanning for magic, verifies exact schema/order/dimensions/sequence authority, checks each response's reviewed request identity, rejects duplicates and trailing bytes, and checks 1,290,240 finite request plus 1,198,080 finite response BF16 values.

### Recurrent continuity lens

For each of 12 layers, the checker compares the 49,152-value BF16 post-state from its token-2 response against the exact pre-state bytes in its token-3 request. Counts or receipt prose cannot substitute for these byte comparisons.

### Independent runtime lens

Inspector records independently show one initialized mesh and 24 `InFlight` to `Committed` workload transitions, destructions, and instances of each production reader, compute, and writer kernel. The server summary independently records one device open, one response connection, 24 calls, 24 enqueues, and a closed terminal state.

### Safety and orchestration lens

Classification, process, session, pueue, owner, health, rollback, and board artifacts are checked separately. The verifier preserves physical process status 0 and orchestration status 1 rather than collapsing them into one result.

## Claims and non-claims

This evidence establishes successful hybrid host/device execution of the production ttWKV7 operation across two model tokens and all 12 layers, including accepted recurrent state continuity and matching greedy token identity. Host normalization, projections, residuals, channel mix, and language-model head remain FP32. It does not establish exact BF16 parity, a fully device-resident RWKV layer or model, serving, throughput, latency, or general compatibility across P150 systems.
