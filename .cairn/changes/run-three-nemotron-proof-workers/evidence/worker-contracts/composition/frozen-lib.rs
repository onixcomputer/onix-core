//! Trellis: composable verified-logic building blocks.
//!
//! Verus checks the contracts of functions inside `verus!` against their
//! implementations, subject to the stated preconditions and trusted boundaries.
//! This is not a whole-crate or downstream security guarantee: runtime-only
//! helpers and trusted sites have narrower claims documented in
//! `docs/proof-gap-sites.tsv`. Requirements are tracked by
//! [Tracey](https://tracey.bearcove.eu/) in `docs/requirements.md`.
//!
//! For normal `cargo build`, `vstd` erases ghost code (specs, proofs, requires,
//! ensures); Verus verification is a separate check.
//!
//! ## Modules
//!
//! - `access_mode` — access mode partial order: read/write/delete/full with no-escalation
//! - `append_entries_build` — Raft leader-side AppendEntries construction: prev_log, entries,
//!   batching
//! - `append_entries_check` — Raft AppendEntries consistency: prevLogIndex/prevLogTerm validation
//! - `acid` — ACID transaction proofs: atomicity, consistency, isolation, durability
//! - `arithmetic` — abs diff, saturating ops, checked mul
//! - `backoff` — exponential backoff with cap and jitter bounds
//! - `balance` — credit/debit with overflow protection and conservation proofs
//! - `ballot` — vote tracking for Raft elections with quorum intersection safety
//! - `barrier` — thread barrier: arrive, release on Nth arrival, generation counter
//! - `beam_link` — BEAM bidirectional links and exit-signal propagation
//! - `beam_mailbox` — BEAM FIFO mailboxes with selective receive and save-offset cursor
//! - `beam_monitor` — BEAM monitors, DOWN delivery, demonitor flush
//! - `beam_process` — BEAM process lifecycle and heap-isolation model
//! - `beam_registry` — BEAM name registry with bijective name↔pid mapping
//! - `beam_scheduler` — BEAM reduction-budget preemption and priority queue selection
//! - `beam_send` — BEAM asynchronous send: append-if-live, drop-if-dead
//! - `bitwise` — power-of-two, bit get/set/clear/toggle
//! - `batch` — write batch limit checking and flush decisions
//! - `bitfield` — multi-bit field extraction and insertion with round-trip proofs
//! - `btree_balance` — B-tree node balance: fill factor, split/merge triggers, redistribution
//! - `bitmap` — verified fixed-size bit set using bitwise ops
//! - `bloom` — Bloom filter with no-false-negatives proof
//! - `authorize` — three-factor authorization: subsumption × scope × mode
//! - `approval` — merge gating: approval counting, stale detection, CI checks
//! - `bounded_mpmc` — bounded MPMC queue: head/tail occupancy, enqueue/dequeue, slot generation,
//!   capacity conservation
//! - `bounded_peers` — bounded peer collection: capacity cap, self-exclusion, order preservation
//! - `bounded_range` — ranges with optional upper bound (None = unbounded)
//! - `buddy` — buddy system: block sizes, buddy addresses, coalescing, parent blocks
//! - `causal_order` — causal delivery and consistent snapshots
//! - `consistent_snapshot` — consistent cuts with lattice operations (join/meet) and message
//!   consistency
//! - `containment` — delegation containment: scope + mode + subsumption
//! - `ability_effect` — finite ability requirement admission, handler discharge, and sandbox
//!   attenuation
//! - `algebraic_effect` — finite algebraic-effect signatures, handler coverage, residual calls, and
//!   single-use continuation tokens
//! - `typed_durable_reference` — finite typed durable reference, unpersist, and migration admission
//! - `remote_computation` — finite remote computation dependency, ability, and resource admission
//! - `semantic_refactoring` — finite immutable name movement, compatible propagation, and
//!   unresolved-dependent admission
//! - `content_addressed_code` — finite content-addressed definition identity, dependency closure,
//!   and recursive group admission
//! - `consistent_hash` — consistent hash ring with complete coverage
//! - `consistency_history` — shared operation vocabulary for consistency-model predicates
//! - `consistency_object` — object-level sequential-consistency and linearizability predicates
//! - `consistency_refinement` — implication edges and availability-envelope metadata for
//!   consistency models
//! - `consistency_relations` — shared real-time, session, visibility, arbitration, and conflict
//!   relations
//! - `consistency_session` — session guarantees and causal-consistency predicates
//! - `consistency_transactional` — abstract transactional consistency predicates and refinement
//!   skeletons
//! - `crdt` — G-Counter, PN-Counter, LWW-Register with merge laws
//! - `cryptoshedding` — key-tree recoverability, shedding, subtree effects, rotation
//! - `bounds` — range predicates, clamping
//! - `cas` — compare-and-swap condition evaluation
//! - `cas_loop` — CAS retry loop modeling: success/failure, ABA detection via generation counters,
//!   retry bounds
//! - `chain` — chain hash integrity with append-preserves proof
//! - `choreography_global` — finite global choreography syntax, participants, and well-formedness
//! - `choreography_ownership` — normalized finite value ownership and atomic owner transfer
//! - `choreography_local` — finite local choreography syntax, branch lookup, and merge
//! - `choreography_projection` — projectability checks and endpoint projection
//! - `choreography_step` — one-step global/local reduction and projection alignment helpers
//! - `check_quorum` — leader liveness: step down when quorum contact lost
//! - `circuit_breaker` — three-state circuit breaker: closed/open/half-open
//! - `chunk` — ceiling-division chunk arithmetic, offset↔chunk mapping
//! - `client_routing` — Raft client request routing: accept/redirect/reject by node role
//! - `client_session` — Raft client session deduplication for exactly-once semantics (§8)
//! - `config_change` — Raft configuration change protocol FSM: stable↔joint transitions (§6)
//! - `collections` — sorted insert, binary search
//! - `commit_advance` — Raft commit index advancement with §5.4.2 current-term guard
//! - `commit_notify` — commit notification dispatch: newly committed ranges, proposal status
//! - `compaction_fence` — log compaction coordination with replication: safe compact index
//! - `constant_time_eq` — fixed-iteration XOR-fold comparison for 32-byte hashes
//! - `control_flow_graph` — basic block partitioning, leader identification, CFG edges, and
//!   dead-block detection
//! - `dominator_tree` — iterative dominator sets, immediate dominators, and dominance frontiers
//! - `loop_detection` — back-edge classification, loop bodies over reachability/dominator views,
//!   exit edges, and nesting
//! - `liveness_analysis` — backward live-in/live-out dataflow, fixed-point checking, and live-range
//!   projection
//! - `hir_attribute_parsing` — finite inert parser descriptors, policy admission, deterministic
//!   reasons, and early/late metadata agreement
//! - `rustc_metadata_identity` — finite crate-artifact identity, encoded-MIR, usage-mode, and
//!   bounded dependency-selection admission
//! - `register_allocation` — live-range overlap graphs, conflict-free register assignment, and
//!   deterministic spill fallback
//! - `stack_frame_layout` — aligned stack-slot placement, exact rounded frame sizing, and explicit
//!   safe-reuse checks over live ranges
//! - `track_caller_abi` — finite caller-location metadata, direct-call propagation, trait
//!   inheritance, reify-shim, and const/codegen trace admission
//! - `wasm_primitives` — exact Wasm value tags, `i32.add` stack discipline, typed local access,
//!   linear-memory bounds/grow semantics, control-label branch/return arity, unreachable-stack
//!   validation, control-frame stack-height restoration, finite `call_indirect` table/signature
//!   admission, and `br_table` target validation
//! - `wasm_runtime_bounds` — finite transition, fuel, segmentation, continuation,
//!   allocation-phase, growth-policy, and exact byte-schedule laws
//! - `r1cs_constraint` — bounded single-row R1CS shape, modular dot product, and satisfaction
//!   admission
//! - `r1cs_boolean` — bounded booleanity row encoding and satisfaction over an R1CS witness slot
//! - `r1cs_bit_decomposition` — bounded two-bit decomposition over boolean R1CS witness slots
//! - `r1cs_lookup` — bounded lookup-table membership over active R1CS witness/table prefixes
//! - `r1cs_gates` — bounded multiplication, addition, and constant gate adapters into R1CS rows
//! - `r1cs_system` — bounded multi-row R1CS system shape and shared-witness satisfaction admission
//! - `r1cs_public_inputs` — bounded public-input binding and R1CS statement satisfaction admission
//! - `dead_code_elimination` — dead instruction classification from side-effect tagging and
//!   live-out facts
//! - `debruijn` — de Bruijn shifting, substitution, and beta reduction with scope preservation
//! - `constant_folding` — constant-propagation lattice, exact fold semantics, and per-instruction
//!   transfer over the shared raw IR
//! - `ssa_construction` — iterated-dominance-frontier phi placement, SSA renaming, and phi
//!   elimination
//! - `spreadsheet_address` / `spreadsheet_formula` / `spreadsheet_dependency` /
//!   `spreadsheet_recalc` — finite spreadsheet address/range, formula, dependency, cycle, recalc,
//!   dirty-propagation, and error admission
//! - `ct_select` — branchless constant-time conditional selection for u64/u8
//! - `conversion` — checked narrowing (u32/u16/u8), sign conversion (i64↔u64)
//! - `cow` — copy-on-write decision logic, ref counting, snapshot isolation
//! - `delegation` — delegation chain validation: depth bounds, attenuation, Delegate gate
//! - `double_entry` — double-entry bookkeeping: balanced debits/credits, trial balance
//! - `distributed_lock` — distributed lock tokens, deadlines, expiry, backoff
//! - `drain` — drain-state admission protocol for graceful shutdown
//! - `drain_protocol` — double-check admission with recheck and notification
//! - `durable_history` — append-only durable event history with contiguous-prefix validation
//! - `durable_replay` — replay gating and durable effect deduplication
//! - `durable_resume` — checkpoint advancement and crash-recovery resume-point derivation
//! - `durable_terminal` — durable terminal outcomes and recovery status reproduction
//! - `epoch_reclaim` — epoch-based memory reclamation: pin/unpin, three-epoch cycling,
//!   safe-to-reclaim
//! - `election` — leader election state machine: transitions, tokens, timing
//! - `election_jitter` — deterministic per-node jitter via Knuth multiplicative hash
//! - `election_safety_proof` — system-level election safety: at most one leader per term
//! - `epoch` — lexicographic (term, index) comparison for Raft elections
//! - `escrow` — conditional value holding: fund, release, refund, dispute with conservation
//! - `eviction` — LRU eviction with protected entries
//! - `eviction_score` — multi-factor eviction scoring: weighted factors × priority × tier
//! - `fast_backtrack` — Raft accelerated log backtracking: skip conflicting terms in one RPC (§5.3)
//! - `fee` — proportional fee computation: basis points, tiered, conservation
//! - `fenced_distributed_lock` — lease, fencing-token, monotonic and CAS admission composition
//! - `fencing` — fencing tokens for stale-write rejection
//! - `fetch_add` — wrapping/saturating fetch-and-add, CAS refinement, and fetch-sub roundtrips
//! - `false_sharing` — cache-line identity, alignment, padding separation, object span, and
//!   equivalence with canonical tag/index decomposition
//! - `follower_read` — follower-side linearizable reads via leader commit confirmation
//! - `futex_state` — futex wait/wake state machine: idle/waiting/notified transitions
//! - `parking_lot_condvar_model` — finite condition-variable association and requeue semantics
//! - `parking_lot_contracts` — fairness, timeout, reentrant, Once, raw-lock, and deadlock contracts
//! - `parking_lot_core_model` — finite parking-lot key/queue/requeue model
//! - `parking_lot_raw_mutex` — compact raw-mutex locked/parked bit state machine
//! - `parking_lot_rwlock_model` — packed parking-lot-style RwLock state transitions
//! - `ghost_history` — ghost state for Raft inductive proofs: vote history, leader logs, entry
//!   provenance
//! - `glob` — glob pattern matching with `*` wildcards for capabilities
//! - `gpu_primitives` — finite GPU program shapes, launch/grid/block/thread checks, pitched/tensor
//!   memory-layout, coalesced memory, and shared-tile admission
//! - `gossip` — gossip infection bounds and convergence
//! - `hdl_ir` / `hdl_emit` / `hdl_adapters` / `hdl_validation` — finite HDL IR admission,
//!   deterministic Verilog/SystemVerilog emission, adapter refinement/emission planning, and
//!   validation evidence
//! - `expiration` — TTL calculation, lease/key expiration, time remaining
//! - `hash_bucket` — hash-to-bucket assignment, modular and power-of-two
//! - `hazard_pointer` — hazard pointer protocol: protect, unprotect, reclaim, no-use-after-free
//!   proof
//! - `heap_index` — binary heap index arithmetic: parent/child navigation, leaf detection,
//!   roundtrip proofs
//! - `install_snapshot` — snapshot trigger and commit advancement for log compaction
//! - `integer` — parity, alignment, log2, next-power-of-two
//! - `interval` — half-open interval contains, overlap, split, merge
//! - `joint_consensus` — dual-quorum membership changes with intersection proof
//! - `journal` — append-only transaction journal with running balances and seq num monotonicity
//! - `knowledge_graph` — finite KG terms, triples, properties, ontology constraints, provenance,
//!   alignment, query-shape, inference, embedding-index, and admission
//! - `kv_version` — KV entry version computation: create/update with saturation
//! - `layout_constraint` — tiling layout constraint resolution: satisfaction, clamping,
//!   conservation
//! - `leader_append_only` — leader log immutability invariant: only grows, never overwrites
//! - `leader_completeness` — committed entries survive elections (quorum intersection + epoch_ge)
//! - `leadership_transfer` — voluntary leadership transfer: catch-up, `TimeoutNow`, deadline
//! - `learner_change` — learner add/remove primitives: no quorum impact, idempotent ops
//! - `learner_readiness` — learner catch-up readiness for safe voter promotion
//! - `lease` — time-bounded leases with disjointness, renewal, revocation
//! - `lease_read` — lease-based linearizable reads with clock drift compensation
//! - `left_right` — left-right synchronization: wait-free readers, side toggle, quiescence,
//!   snapshot stability
//! - `ledger` — multi-account ledger: transfers, batch, fee routing, total conservation
//! - `settlement` — bilateral obligation netting: net positions, sum-to-zero, valid settlement
//! - `lock_ordering` — lock acquisition ordering for deadlock prevention: strict total order, cycle
//!   freedom
//! - `lsm_level` — LSM-tree level management: target sizing, compaction triggers, amplification
//! - `log` — append-only log with Log Matching Property
//! - `match_index` — per-follower matchIndex/nextIndex tracking with monotonicity
//! - `log_conflict` — log conflict resolution: find divergence, truncate, append leader entries
//! - `markov` — Markov chain prediction: transition counting, confidence thresholds
//! - `memory_order` — memory ordering lattice: Relaxed/Acquire/Release/AcqRel/SeqCst, fence
//!   composition, load/store validity
//! - `cache_hierarchy` — inclusive/exclusive/non-inclusive L1/L2 invariants, back-invalidation,
//!   capacity accounting, and snoop scope
//! - `directory_coherence` — single-line directory protocol with shared-bit vectors, targeted
//!   invalidations, exclusive-owner grants, eviction notifications, and MESI-compatible embedding
//! - `cache_prefetch` — architecturally invisible prefetch hints with MESI-compatible cache
//!   transitions and explicit dirty-victim writeback
//! - `mesi` — MESI cache coherence protocol: M/E/S/I states, processor read/write, bus snooping,
//!   system invariant preservation
//! - `moesi` — MOESI cache coherence protocol: Owned-state entry on remote read, dirty-owner
//!   exclusivity, dirty-data sourcing, eviction writeback, and MESI refinement outside Owned paths
//! - `merkle` — Merkle proof verification with hash axiom
//! - `monotonic` — advancement predicates for terms, commit indices
//! - `mpsc_bounds` — MPSC channel bounds: occupancy, capacity, send/receive, close/drain
//! - `nix_attrset` — Nix attribute set operations: merge, intersect, remove
//! - `nix_base32` — Nix custom Base32 encoding and decoding
//! - `nix_drv_serialize` — Nix ATerm escaping primitives and derivation structs
//! - `nix_fingerprint` — Nix derivation fingerprint construction and name validation
//! - `nix_hash_truncate` — Nix `compressHash` XOR-fold truncation
//! - `nix_store_path` — Nix store path computation composing base32, hash truncation, and
//!   fingerprints
//! - `nonce` — verified nonce issuance with uniqueness, monotonicity, and freshness proofs
//! - `noop_commit` — no-op entry for committing prior-term entries after election
//! - `node_classify` — node classification: voter/learner, leader/follower, batch with bounds
//! - `nix_closure` — Nix generic closure with fuel-based termination
//! - `nix_eval_closure_policy` — composite Nix evaluation closure admission policy
//! - `node_lifecycle` — node status FSM: Starting/Online/Degraded/Offline
//! - `nix_list` — Nix list builtins: elem, head, tail, `gen_list`, concat
//! - `nix_string` — Nix string operations: length, substring, replace
//! - `nix_version` — Nix version comparison with component classification
//! - `nickel_priority` — Nickel merge priority total order: Bottom < Neutral < Numeral(n) < Top
//! - `nickel_merge_split` — Nickel three-way record split: left-only, center, right-only
//! - `nickel_field_merge` — Nickel field-level merge resolution by priority
//! - `nickel_record_merge` — Nickel full record merge with identity and commutativity proofs
//! - `nickel_subtype` — Nickel gradual type subtyping: reflexivity, covariance, record-dict
//! - `nickel_polarity` — Nickel contract blame polarity: flip on domain, double-flip identity
//! - `nickel_pattern_coverage` — Nickel pattern completeness and overlap detection
//! - `option` — verified Option combinators
//! - `ordering` — min, max, median, sign, compare-and-swap
//! - `pattern` — wildcard and set-membership pattern matching for capabilities
//! - `page` — virtual address decomposition: frame number, offset, alignment
//! - `partition` — verified non-overlapping gap-free interval partitions
//! - `peer_spec` — peer specification parsing: `node_id@endpoint` format
//! - `permission` — Unix file permission bits: has/set/clear, umask
//! - `persistent_state` — Raft crash recovery: durable state, persist-before-respond, vote safety
//! - `pre_vote` — pre-vote protocol without term inflation for partitioned nodes
//! - `pre_vote_lease` — PreVote + CheckQuorum interaction: reject pre-votes when leader is active
//! - `pre_vote_tally` — pre-vote response tally: counting and quorum check for pre-election phase
//! - `pressure` — multi-threshold severity classification
//! - `priority_election` — priority-based leader election: delay, yield, candidate comparison
//! - `process_state` — process lifecycle state machine: transitions, terminal, schedulable
//! - `quota` — resource quota enforcement: remaining capacity, admission, consume/release,
//!   utilization
//! - `quorum` — majority threshold, quorum predicate, intersection theorem
//! - `raft_consensus_core` — finite Raft term, stale-message, vote, RequestVote, and
//!   election-safety primitives for the domain-primitives OpenSpec
//! - `raft_step` — Raft step decomposition for modular invariant proofs
//! - `raft_timing` — Raft timeout configuration validators with fail-fast composition
//! - `rate_limit` — integer token bucket rate limiting
//! - `rcu` — read-copy-update: grace periods, quiescent state detection, safe reclamation
//! - `read_index` — linearizable read confirmation via quorum heartbeat acks
//! - `ref_count` — reference counting: increment/decrement, weak upgrade, dealloc trigger
//! - `region` — address region arithmetic: contains, disjoint, adjacent, merge, split
//! - `replication_mode` — per-peer replication FSM: Probe → Replicate → Snapshot transitions
//! - `replication_pipeline` — flow control for pipelined `AppendEntries`
//! - `request_forward` — client request forwarding: follower-to-leader proxy with pending tracking
//! - `result` — verified Result combinators
//! - `ring_buffer` — verified FIFO queue with power-of-two capacity
//! - `store_buffer` — fixed-capacity store queue with youngest-match forwarding, FIFO drain, and
//!   fence-empty semantics
//! - `tlb_shootdown` — page-local TLB shootdown: initiator self-invalidation, pending-ack
//!   completion guard, stale-entry freshness, page isolation, and range lifting
//! - `rwlock` — read-write lock modes, mutual exclusion, reader/writer tokens
//! - `per_core_rwlock` — per-core reader aggregation, writer drain gating, and rwlock mode
//!   refinement
//! - `sequence` — monotonic ID generation with batch reservation and overflow protection
//! - `serialization_codec` — finite byte buffers, frames, length prefixes, schema/version,
//!   checksum-shape metadata, encoder/decoder shape predicates, and bounded round trips
//! - `scheme_logic` — finite reader spans, explicit interning, module linkage,
//!   contract/blame metadata, bytecode safety, cycle-safe values, and collection shapes
//! - `sequential` — sequential access detection, prefetch triggering
//! - `signal` — signal set algebra: add/remove/contains, union/intersect, deliverable
//! - `set_associative_lookup` — cache address decomposition and per-set tag lookup
//! - `surelock_deadlock` — surelock wait-edge rank and deadlock-freedom core theorem
//! - `surelock_id` — surelock lock records with stable monotonic lock identities
//! - `surelock_key` — surelock consumed-and-re-emitted key progression across levels
//! - `surelock_level` — surelock total level order, lock-after relation, and derived higher levels
//! - `surelock_lockset` — surelock same-level canonical lock-set preparation and caller-order
//!   mapping
//! - `snapshot_compaction` — Raft log compaction trigger: when to snapshot, prefix discard,
//!   metadata
//! - `spin_backoff` — spin-wait backoff: two-phase (spin then yield), exponential spin count
//! - `snapshot_integrity` — dual-hash snapshot verification with round-trip and tamper proofs
//! - `snapshot_transfer` — chunked snapshot streaming: validation, ordering, progress
//! - `state_machine_safety` — no two servers apply different entries at the same index
//! - `slab` — slab allocation: slot index/address, capacity, generation counters, handle packing
//! - `scope` — prefix-based scope coverage, compound scoping, optional constraints
//! - `sel4_asid` — finite ASID pool ownership: allocate, release, reuse, exhaustion
//! - `sel4_cap_rights` — seL4 rights-mask attenuation, masking laws, and operation gates
//! - `sel4_cdt` — capability derivation ancestry, subtree revoke, and leaf recycle
//! - `sel4_cspace` — guarded CSpace traversal with explicit depth accounting and exact slot
//!   resolution
//! - `sel4_endpoint` — endpoint sender/receiver rendezvous, queue cancellation, and badge transfer
//! - `sel4_fault_ipc` — structured fault encode/decode and handler-facing delivery
//! - `sel4_invocation` — abstract typed invocation decode over explicit capability contexts
//! - `sel4_invariants` — composed kernel-state invariants and a preservation matrix over the local
//!   seL4 models
//! - `sel4_notification` — badge accumulation, wait/poll consume semantics, and binding wakeups
//! - `sel4_reply` — reply-cap lifecycle, caller/callee pairing, and invalidate-on-cancel/revoke
//! - `sel4_irq` — IRQ handler binding, mask-aware delivery, and acknowledge consumption
//! - `sel4_tcb` — TCB state legality, blocking-object identity, and legal wake/restart/deactivate
//!   transitions
//! - `sel4_ready_queue` — per-priority ready queues, runnable/queued consistency, and
//!   highest-priority selection
//! - `sel4_untyped` — aligned contained child layouts plus revoke/reset reclaim of an untyped
//!   source
//! - `sel4_vspace` — aligned non-overlapping mappings, exact unmap, and rights restriction
//! - `semaphore` — counting semaphore: acquire/release, capacity bounds, conservation, binary mutex
//! - `seqlock` — sequence lock protocol: even/odd counter, valid read detection, writer versioning
//! - `shamir_field` — finite-field arithmetic modulo an explicit prime-sized modulus
//! - `shamir_poly` — polynomial evaluation for Shamir secret sharing
//! - `shamir_lagrange` — Lagrange basis functions and interpolation at zero
//! - `shamir_split` — share generation from a secret polynomial
//! - `shamir_reconstruct` — secret reconstruction from threshold shares
//! - `shamir_threshold` — threshold-completion witnesses for fewer-than-k shares
//! - `slice` — chunk count, prefix/suffix equality, all-equal, mismatch
//! - `subsumption` — variant subsumption DAG for capability authorization
//! - `term_authority` — step-down on higher term: adopt, revert to follower, clear vote
//! - `ticket_lock` — FIFO-fair ticket lock: take/release, waiter counting, mutual exclusion, queue
//!   position
//! - `tier` — hot/warm/cold tier classification with promote/demote
//! - `tiered_rate_limit` — global-first two-tier rate limiting with capacity invariant
//! - `tiling` — 2D rect non-overlap, containment, strip partitioning for layout engines
//! - `timeseries` — finite monotone timestamp indexes, aligned samples, windows, resample buckets,
//!   rolling aggregates, and gap reports
//! - `type_lattice` — type conversion reachability: reflexive, ANY top, STRING source
//! - `type_unification` — first-order type syntax, occurs check, substitution application and
//!   composition
//! - `token_timestamp` — UCAN token expiration, future rejection, refresh threshold
//! - `verification_frontier` — finite contract implication, type facts, slice certificates, arena
//!   provenance, progress budgets, external-reference admission, and outcome invariant bundles
//! - `proof::artifact::provenance` — finite proof-artifact identity, local-property boundary,
//!   non-claim, and downstream handoff-role admission
//! - `transfer` — value transfer validation: conservation, idempotency, status codes
//! - `trust_level` — trust resolution with block precedence and access control
//! - `two_phase` — two-phase commit decision: unanimity, abort safety
//! - `vector_clock` — causality tracking with partial order and merge lattice
//! - `view_change` — view-based reconfiguration: view monotonicity, leader rotation, quorum-gated
//!   transitions
//! - `quepaxa` — finite deterministic QuePaxa safety/admission primitives for proposal ordering,
//!   ISR transitions, abstract propagation, phase guards, fast path, and hedging metadata
//! - `quorum_cert` — quorum certificate: vote counting, QC ordering, commit rule via consecutive
//!   certificates
//! - `voter_set` — voter set promotion: add learner, replace node, quorum preservation
//! - `wal_recovery` — WAL crash recovery: replay range, idempotent replay, checkpoint advancement
//! - `wal_segment` — WAL segment management: contiguity, space, truncation safety, replay range
//! - `watermark` — bump allocation: remaining, fits, alloc, reset, non-overlap
//! - `write_buffer` — memtable flush thresholds, buffer swap, write amplification, flush counting
//! - `write_policy` — write-back/write-through dirty invariants, eviction, flush, read equivalence
//! - `block_cache` — cache slot states: insert, evict, mark-dirty, write-back, clock-hand sweep
//! - `cache_partition` — way-based cache partitioning: isolation, eviction containment, capacity,
//!   resize, single-partition equivalence
//! - `free_space_map` — bitmap free-space: alloc/free conservation, first-free, contiguous runs
//! - `page_checksum` — Fletcher-style checksum accumulation, pack/unpack roundtrip, torn-write
//!   detection
//! - `web_of_trust_attestation` — exact attestation payload bytes, signature binding, and
//!   active-window checks over issuer, subject, role, validity window, and sequence metadata
//! - `web_of_trust_chain` — simple active trust-edge chains over attestation-index witnesses
//! - `web_of_trust_principal` — canonical principal IDs as full 32-byte BLAKE3 digests with
//!   full-byte equality
//! - `web_of_trust_resolution` — rooted depth-bounded trust resolution with the empty-chain root
//!   base case
//! - `web_of_trust_policy` — threshold acceptance over distinct rooted-trusted introducers with
//!   explicit `k = 0` / `d = 0` rejection and repeated-final-hop filtering
//! - `ucan_ability` — string-based ability hierarchy with subsumption, glob matching, namespace
//!   isolation, and containment monotonicity
//! - `ucan_caveat` — composable attenuation constraints with conjunction satisfaction, containment
//!   monotonicity, intersection soundness/minimality, and delegation-only-adds
//! - `ucan_cid` — CIDv1 construction with determinism, version correctness, byte injectivity, and
//!   multihash round-trip
//! - `ucan_did` — did:key encode/decode with verified round-trip, injectivity, codec preservation,
//!   and varint framing
//! - `ucan_signature` — Ed25519 sign/verify primitives with verified round-trip, key-binding,
//!   message-binding, determinism, and length contracts
//! - `ucan_token` — UCAN token envelope with temporal validity, self-delegation rejection,
//!   attenuation monotonicity, and sound/complete validation pipeline
//! - `web_of_trust_revocation` — exact revocation payload bytes, signature binding, same-issuer,
//!   exact-payload, and family-target matching
//! - `witness` — witness replicas: vote without full log, heartbeat acks, role taxonomy
//! - `work_stealing` — work-stealing deque: push/pop/steal, size tracking, circular buffer index
//! - `zeroize` — verified memory scrubbing: write zero to every byte, idempotence, detection
//!
//! ### Memory allocator verification
//!
//! - `alloc_token` — allocation lifecycle FSM: free → allocated → freed, double-free prevention
//! - `size_class` — size class bucketing: power-of-two classes, waste bounds, monotonicity
//! - `free_list` — intrusive free list: LIFO push/pop, no-cycle (all-distinct), containment
//! - `split_coalesce` — buddy split/coalesce sequences: block conservation, recursive split trees
//! - `alloc_bitmap` — typed allocation bitmap: generational handles, double-free detection
//! - `arena` — arena allocation: bump alloc, collective free via generation reset
//! - `pool` — fixed-size object pool: slab + bitmap composition, slot alignment
//! - `segregated_free` — segregated free lists by size class: cross-class uniqueness
//! - `coalesce_policy` — immediate vs deferred coalescing: convergence, total preservation
//! - `fragmentation` — fragmentation metrics: external/internal bounds, can-satisfy

#![cfg_attr(not(verus_keep_ghost), feature(register_tool))]
#![register_tool(tigerstyle)]
#![cfg_attr(verus_keep_ghost, verifier::deprecated_postcondition_mut_ref_style(true))]

pub mod ability_effect;
pub mod access_mode;
pub mod acid;
pub mod algebraic;
pub mod algebraic_effect;
pub mod append_entries_build;
pub mod append_entries_check;
pub mod append_response;
pub mod approval;
pub mod arithmetic;
pub mod async_task_state;
pub mod authorize;
/// Verified finite backend-neutral builder handle and operation admission.
#[path = "builder_lower/identity.rs"]
pub mod backend_codegen_trace;
pub mod backend_frame_allocator;
pub mod backoff;
pub mod balance;
pub mod ballot;
pub mod barrier;
pub mod batch;
pub mod beam_link;
pub mod beam_mailbox;
pub mod beam_monitor;
pub mod beam_process;
pub mod beam_registry;
pub mod beam_scheduler;
pub mod beam_send;
pub mod bitfield;
pub mod bitmap;
pub mod bitwise;
pub mod bloom;
pub mod bounded_interval;
#[path = "bounded_modular_tree_fold/mod.rs"]
pub mod bounded_modular_tree_fold;
pub mod bounded_range;
pub mod btree_balance;
pub mod btree_delete;
pub mod btree_insert;
pub mod buddy;
pub mod causal_order;
pub mod concurrent_composition;
pub mod consensus_path;
/// Verified finite crash-fault consensus fast-path proofs.
#[path = "consensus_fast_path/identity.rs"]
pub mod consensus_fast_path;
pub mod consistency_history;
pub mod consistency_object;
pub mod consistency_refinement;
pub mod consistency_relations;
pub mod consistency_session;
pub mod consistency_transactional;
pub mod consistent_hash;
pub mod consistent_snapshot;
pub mod containment;
pub mod content_addressed_code;
pub mod remote_computation;
pub mod semantic_refactoring;
pub mod typed_durable_reference;

pub mod alloc_bitmap;
pub mod alloc_token;
pub mod arena;
pub mod block_cache;
pub mod blocking_bounded_channel;
pub mod bounded_mpmc;
pub mod bounded_peers;
pub mod bounds;
pub mod cache_coherent_memory_region;
pub mod cache_hierarchy;
pub mod cache_partition;
pub mod cache_prefetch;
pub mod calendar;
pub mod cas;
pub mod cas_loop;
pub mod chain;
pub mod chaoscontrol_coverage;
pub mod chaoscontrol_exploration_core;
pub mod chaoscontrol_fault_schedule;
pub mod chaoscontrol_fault_state;
pub mod chaoscontrol_frontier;
pub mod chaoscontrol_input_tree;
pub mod chaoscontrol_oracle;
pub mod chaoscontrol_scheduler;
pub mod check_quorum;
pub mod choreography_global;
pub mod choreography_local;
pub mod choreography_ownership;
pub mod choreography_projection;
pub mod choreography_step;
pub mod chunk;
pub mod circuit_breaker;
pub mod client_routing;
pub mod client_session;
pub mod coalesce_policy;
pub mod collections;
pub mod commit_advance;
pub mod commit_notify;
pub mod compaction_fence;
pub mod composite_outcome;
pub mod composite_receipt_envelope;
pub mod config_admission;
pub mod config_change;
pub mod config_default;
pub mod config_key;
pub mod config_override_precedence;
pub mod config_typed_value;
pub mod config_validation_decision;
pub mod constant_folding;
pub mod constant_time_eq;
pub mod constraint_admission;
pub mod constraint_assignment;
pub mod constraint_consistency;
pub mod constraint_domain;
pub mod constraint_propagation;
pub mod constraint_relation;
pub mod constraint_variable;
pub mod constraint_witness;
pub mod control_actuator_saturation;
pub mod control_deadband;
pub mod control_error_signal;
pub mod control_flow_graph;
pub mod control_hysteresis;
pub mod control_rate_limit;
pub mod control_safety_envelope;
pub mod control_setpoint;
pub mod conversion;
pub mod cost_tracker;
pub mod cow;
pub mod crash_safe_page_cache;
pub mod crdt;
pub mod cron_field;
pub mod cron_match;
pub mod cron_next;
pub mod cryptoshedding;
pub mod ct_select;
pub mod cycle_detect;
pub mod data_validation_admission;
pub mod data_validation_cross_field;
pub mod data_validation_enum_constraint;
pub mod data_validation_error_accumulation;
pub mod data_validation_field_presence;
pub mod data_validation_normalization_decision;
pub mod data_validation_range_constraint;
pub mod data_validation_schema_predicate;
pub mod dead_code_elimination;
pub mod deadline_queue;
pub mod debruijn;
pub mod delegation;
pub mod dependency_scheduler;
pub mod directory_coherence;
pub mod distributed_lock;
pub mod dominator_tree;
pub mod double_entry;
pub mod drain;
pub mod drain_protocol;
pub mod drop_guard;
pub mod ds_bounded_array;
pub mod ds_fifo_queue;
pub mod ds_key_value_map;
pub mod ds_priority_queue;
pub mod ds_ring_buffer;
pub mod ds_union_find;
pub mod durable_history;
pub mod durable_job_executor;
pub mod durable_replay;
pub mod durable_resume;
pub mod durable_terminal;
pub mod election;
pub mod election_init;
pub mod election_jitter;
pub mod election_safety_proof;
pub mod election_timer;
pub mod entry_type;
pub mod env_scrub;
pub mod epoch;
pub mod epoch_reclaim;
pub mod escrow;
pub mod eviction;
pub mod eviction_score;
pub mod exactly_once_ledger_transfer;
pub mod expiration;
pub mod fair_share;
pub mod false_sharing;
pub mod fast_backtrack;
pub mod feature_flag_gate;
pub mod feature_flag_rollout_bucket;
pub mod fee;
/// Verified finite fenced-attempt report admission with exact preservation.
#[path = "fenced_attempt/identity.rs"]
pub mod fenced_attempt_admission;
pub mod fenced_distributed_lock;
pub mod fencing;
pub mod fetch_add;
pub mod follower_commit;
pub mod follower_read;
pub mod follower_redirect;
pub mod forest;
pub mod fragmentation;
pub mod free_list;
pub mod free_space_map;
pub mod fs_path_admission;
pub mod fs_path_containment;
pub mod fs_path_extension_type;
pub mod fs_path_form;
pub mod fs_path_join_split;
pub mod fs_path_normalization;
pub mod fs_path_segment;
pub mod fs_path_traversal;
pub mod futex_state;
pub mod geom_admission;
pub mod geom_bounds;
pub mod geom_containment;
pub mod geom_grid_cell;
pub mod geom_intersection;
pub mod geom_orientation;
pub mod geom_point_vector;
pub mod geom_transform;
pub mod ghost_history;
pub mod gis_bounding_box;
pub mod gis_coordinate_envelope;
pub mod gis_linestring_topology;
pub mod gis_tile_index;
pub mod glob;
pub mod gossip;
pub mod gpu_primitives;
pub mod graph_adjacency;
pub mod graph_color;
pub mod graph_component_partition;
pub mod graph_frontier_cut;
pub mod graph_query_composition;
pub mod graph_reachability;
pub mod graph_shortest_path_envelope;
pub mod graph_topological_order;
pub mod hash_bucket;
pub mod hazard_pointer;
pub mod hdl_adapters;
pub mod hdl_emit;
pub mod hdl_ir;
pub mod hdl_validation;
pub mod heap_index;
/// Verified finite inert HIR attribute-policy admission.
#[path = "hir/attribute/parsing.rs"]
pub mod hir_attribute_parsing;
/// Verified finite owner-scoped AST-to-HIR identifier admission.
#[path = "frontend_lower/identity.rs"]
pub mod hir_id_lowering;
pub mod heartbeat;
pub mod hypervisor_dirty_log;
pub mod hypervisor_exit;
pub mod hypervisor_gpa;
pub mod hypervisor_interrupt;
pub mod hypervisor_memslot;
pub mod hypervisor_vcpu;
pub mod id_alias_map;
pub mod id_canonicalization;
pub mod id_collision_metadata;
pub mod id_identifier_envelope;
pub mod id_lookup_result;
pub mod id_namespace_scope;
pub mod id_registration_admission;
pub mod id_scoped_uniqueness;
pub mod index_query_pagination;
pub mod index_select;
pub mod install_snapshot;
pub mod instruction_selection;
pub mod integer;
pub mod integration_adapters;
pub mod interval;
pub mod job_cancel;
pub mod job_dag;
pub mod job_idempotency;
pub mod job_priority;
pub mod job_result;
pub mod job_retry;
pub mod job_slot;
pub mod job_state;
pub mod job_timeout;
pub mod joint_consensus;
pub mod journal;
pub mod knowledge_graph;
pub mod kv_version;
pub mod last_applied;
pub mod layout_constraint;
pub mod leader_append_only;
pub mod leader_completeness;
pub mod leader_completeness_ghost;
pub mod leadership_transfer;
pub mod learner_change;
pub mod learner_readiness;
pub mod lease;
pub mod lease_mutex;
pub mod lease_read;
pub mod ledger;
pub mod left_right;
pub mod linearizability;
pub mod linearizable_read_gate;
pub mod liveness_analysis;
pub mod lock_ordering;
pub mod log;
pub mod log_compaction;
pub mod log_conflict;
pub mod log_invariant_inductive;
pub mod loop_detection;
pub mod lsm_level;
pub mod markov;
pub mod match_index;
pub mod memory_order;
pub mod merkle;
pub mod mesi;
pub mod metric_admission;
pub mod metric_aggregate;
pub mod metric_alert;
pub mod metric_counter;
pub mod metric_gauge;
pub mod metric_histogram;
pub mod metric_id;
pub mod metric_labels;
pub mod metric_window;
/// Verified finite Rust-shaped MIR structural admission and CFG facts.
#[path = "mir_core/identity.rs"]
pub mod mir_core;
/// Verified finite lattice effects, convergence, and result inspection.
#[path = "finite_flow/identity.rs"]
pub mod mir_dataflow_framework;
/// Verified finite MIR destruction classification and replacement metadata.
#[path = "destruct_paths/identity.rs"]
pub mod mir_destruct;
/// Verified finite MIR visitor coverage, traversal, and shape preservation.
#[path = "mir_walk/identity.rs"]
pub mod mir_visitor_traversal;
/// Verified finite MIR phase, pass, validation, and artifact-state traces.
#[path = "mir_pass_pipeline/identity.rs"]
pub mod mir_pass_pipeline;
pub mod ml_batch_iterator;
pub mod ml_confusion_matrix;
pub mod ml_dataset_split;
pub mod ml_feature_normalization;
pub mod ml_inference_envelope;
pub mod ml_label_encoding;
pub mod ml_tensor_shape;
pub mod ml_top_k;
pub mod moesi;
pub mod monotonic;
pub mod mpsc_bounds;
pub mod mvcc;
pub mod net_checksum_shape;
pub mod net_endpoint_address;
pub mod net_header_field;
pub mod net_message_sequence;
pub mod net_packet_frame;
pub mod net_parser_admission;
pub mod net_payload_bound;
pub mod net_protocol_admission;
pub mod nickel_field_merge;
pub mod nickel_merge_split;
pub mod nickel_pattern_coverage;
pub mod nickel_polarity;
pub mod nickel_priority;
pub mod nickel_record_merge;
pub mod nickel_subtype;
pub mod nix_attrset;
pub mod nix_base32;
pub mod nix_closure;
pub mod nix_drv_serialize;
pub mod nix_eval_closure_policy;
pub mod nix_fingerprint;
pub mod nix_hash_truncate;
pub mod nix_list;
pub mod nix_store_path;
pub mod nix_string;
pub mod nix_version;
pub mod node_classify;
pub mod node_lifecycle;
pub mod nonce;
pub mod noop_commit;
pub mod numeric_affine_transform_discrete;
pub mod numeric_checked_arithmetic_envelope;
pub mod numeric_denominator_safe_ratio;
pub mod numeric_fixed_point_scale;
pub mod numeric_histogram_counter;
pub mod numeric_monotone_sequence;
pub mod numeric_prefix_sum;
pub mod numeric_quantized_threshold;
pub mod oneshot_channel;
pub mod opt_admission;
pub mod opt_bound;
pub mod opt_candidate_ranking;
pub mod opt_dominance;
pub mod opt_feasible_set;
pub mod opt_frontier;
pub mod opt_objective;
pub mod opt_optimum_witness;
pub mod option;
pub mod ordering;
pub mod page;
pub mod page_checksum;
pub mod parking_lot_condvar_model;
pub mod parking_lot_contracts;
#[path = "parking_lot_core_model/mod.rs"]
pub mod parking_lot_core_model;
#[path = "parking_lot_raw_mutex/mod.rs"]
pub mod parking_lot_raw_mutex;
pub mod parking_lot_rwlock_model;
pub mod parsing_format;
pub mod partition;
pub mod pattern;
pub mod paxos;
pub mod peer_spec;
pub mod per_core_rwlock;
pub mod permission;
pub mod persistent_state;
pub mod physics_collision_envelope;
pub mod physics_contact_manifold;
pub mod physics_energy_budget;
pub mod physics_integrator_step;
pub mod physics_momentum_budget;
pub mod physics_time_horizon;
pub mod physics_units;
pub mod physics_vector_bounds;
pub mod pointwise;
pub mod policy_action;
pub mod policy_authorization;
pub mod policy_conflict;
pub mod policy_decision_engine;
pub mod policy_delegation;
pub mod policy_grant_denial;
pub mod policy_principal;
pub mod policy_resource;
pub mod policy_rule;
pub mod pool;
pub mod pre_vote;
pub mod pre_vote_lease;
pub mod pre_vote_tally;
pub mod pressure;
pub mod priority_election;
pub mod priority_inversion;
pub mod probability_statistics;
pub mod process_state;
pub mod proof;
pub mod proof_gap_boundary_audit;
pub mod properties;
pub mod quepaxa;
pub mod query_cost;
pub mod quorum;
pub mod quorum_cert;
pub mod quota;
pub mod r1cs_bit_decomposition;
pub mod r1cs_boolean;
pub mod r1cs_constraint;
pub mod r1cs_gates;
pub mod r1cs_lookup;
pub mod r1cs_public_inputs;
pub mod r1cs_system;
pub mod raft_consensus_core;
pub mod raft_membership_manager;
pub mod raft_step;
pub mod raft_timing;
pub mod rate_limit;
pub mod rcu;
pub mod reachability;
pub mod read_index;
pub mod rect_grid_index;
pub mod ref_count;
pub mod region;
pub mod register_allocation;
pub mod replication_mode;
pub mod replication_pipeline;
pub mod request_forward;
pub mod resource_accounting;
pub mod result;
pub mod retry;
pub mod ring_buffer;
/// Verified finite rustc crate-artifact compatibility and selection.
#[path = "rustc/metadata/identity.rs"]
pub mod rustc_metadata_identity;
/// Verified finite concrete-item collection and unit partition admission.
#[path = "instance_partition/identity.rs"]
pub mod rustc_monomorphization;
pub mod rwlock;
/// Verified finite canonical parenthesized-tree parsing and serialization.
#[path = "paren_tree/identity.rs"]
pub mod s_expression;
pub mod safe_reclamation_domain;
pub mod safe_snapshot_replication;
pub mod scheduling_calendar;
#[path = "scheme_logic/identity.rs"]
pub mod scheme_logic;
pub mod scope;
pub mod segregated_free;
pub mod sel4_asid;
pub mod sel4_cap_rights;
pub mod sel4_cdt;
pub mod sel4_cspace;
pub mod sel4_endpoint;
pub mod sel4_fault_ipc;
pub mod sel4_invariants;
pub mod sel4_invocation;
pub mod sel4_invocation_step;
pub mod sel4_irq;
pub mod sel4_notification;
pub mod sel4_ready_queue;
pub mod sel4_reply;
pub mod sel4_tcb;
pub mod sel4_untyped;
pub mod sel4_vspace;
pub mod semaphore;
pub mod seq_fold;
pub mod seq_set;
pub mod seqlock;
pub mod sequence;
pub mod sequential;
pub mod serializable_txn_guard;
pub mod serialization_codec;
pub mod serialize_inj;
pub mod session_tree;
pub mod set_associative_lookup;
pub mod settlement;
pub mod shamir_field;
pub mod shamir_lagrange;
pub mod shamir_poly;
pub mod shamir_reconstruct;
pub mod shamir_split;
pub mod shamir_threshold;
pub mod shortest_path;
pub mod signal;
pub mod signal_processing;
pub mod size_class;
pub mod slab;
pub mod slice;
pub mod snapshot_compaction;
pub mod snapshot_integrity;
pub mod snapshot_isolation;
pub mod snapshot_transfer;
pub mod spin_backoff;
pub mod split_coalesce;
pub mod spreadsheet_address;
pub mod spreadsheet_dependency;
pub mod spreadsheet_formula;
pub mod spreadsheet_recalc;
pub mod ssa_construction;
pub mod stack_frame_layout;
pub mod state_machine_safety;
pub mod state_machine_workflow;
pub mod storage_index;
pub mod store_buffer;
pub mod subsumption;
pub mod surelock_deadlock;
pub mod surelock_id;
pub mod surelock_key;
pub mod surelock_level;
pub mod surelock_lockset;
pub mod table_relational;
pub mod task_waker;
pub mod tcp_state;
pub mod term_authority;
pub mod text_string;
pub mod ticket_lock;
pub mod tier;
pub mod tiered_rate_limit;
pub mod tiling;
pub mod timeseries;
pub mod tlb_shootdown;
pub mod token_timestamp;
/// Verified finite typed configuration normal forms and import policy.
#[path = "normal_input/identity.rs"]
pub mod total_config;
pub mod topo_sort;
/// Verified finite `#[track_caller]` ABI metadata and admission.
#[path = "track/caller/abi.rs"]
pub mod track_caller_abi;
pub mod trace_relation;
pub mod transfer;
pub mod trust_level;
pub mod two_phase;
pub mod two_phase_lock;
pub mod txn_dependency;
pub mod txn_isolation;
pub mod type_lattice;
pub mod type_unification;
pub mod typed_state;
#[path = "u24/mod.rs"]
pub mod u24;
pub mod ucan_ability;
/// Verified UCAN backend operation transcript admission.
pub mod ucan_backend_transcript;
/// Verified UCAN base64url-no-pad segment admission.
pub mod ucan_base64url;
/// Verified UCAN capability merge from multiple delegation paths.
pub mod ucan_capability_merge;
pub mod ucan_caveat;
/// Verified UCAN caveat evaluation transcript admission.
pub mod ucan_caveat_evaluation;
/// Verified UCAN opaque caveat identifier preservation.
pub mod ucan_caveat_preservation;
/// Verified UCAN parsed claims presence admission.
pub mod ucan_claims_presence;

pub mod ucan_compact;

pub mod ucan_chain;
pub mod ucan_cid;
/// Verified UCAN delegation depth budget.
pub mod ucan_delegation_depth;
pub mod ucan_did;
/// Verified parsed UCAN header field admission.
pub mod ucan_header;
/// Verified UCAN invocation and receipt model.
pub mod ucan_invocation;
/// Verified decoded UCAN JSON object byte admission.
pub mod ucan_json;
/// Verified UCAN parsed capability-list shape admission.
pub mod ucan_parsed_capability_shape;
/// Verified UCAN parsed caveat-payload admission.
pub mod ucan_parsed_caveat_payload;
/// Verified UCAN parsed caveat-list shape admission.
pub mod ucan_parsed_caveat_shape;
/// Verified UCAN parsed DID claim admission.
pub mod ucan_parsed_did_claim;
/// Verified bridge between UCAN did:key and web-of-trust principal fingerprints.
pub mod ucan_principal_link;
/// Verified UCAN proof-reference digest admission.
pub mod ucan_proof_reference;
/// Verified UCAN proof-reference collection admission.
pub mod ucan_proof_reference_collection;
/// Verified UCAN parsed proof-reference list-shape admission.
pub mod ucan_proof_reference_list_shape;
/// Verified UCAN proof-store result admission.
pub mod ucan_proof_store_result;
/// Verified UCAN proof traversal transcript primitives.
pub mod ucan_proof_traversal;
/// Verified UCAN replay-admission transcript admission.
pub mod ucan_replay_admission;
/// Verified UCAN revocation set checking and monotonicity.
pub mod ucan_revocation;
/// Verified UCAN revocation-check admission.
pub mod ucan_revocation_check;
/// Verified UCAN Ed25519 signature model and structural byte admission.
pub mod ucan_signature;
/// Verified UCAN time-bounded delegation composition.
pub mod ucan_temporal;
/// Verified UCAN parsed temporal-order admission.
pub mod ucan_temporal_order;
pub mod ucan_token;
pub mod ucan_verification_stage;
pub mod vector_clock;
pub mod verification_frontier;
pub mod verified_compiler_pipeline;
pub mod verified_lsm_ingest;
pub mod view_change;
pub mod vision_color_layout;
pub mod vision_color_transform_envelope;
pub mod vision_connected_components;
pub mod vision_convolution_window;
pub mod vision_detection_nms;
pub mod vision_image_buffer;
pub mod vision_image_pyramid;
pub mod vision_roi;
pub mod vote_tally;
pub mod voter_set;
pub mod wal_recovery;
pub mod wal_segment;
pub mod wasm_primitives;
#[path = "wasm_runtime_bounds/identity.rs"]
pub mod wasm_runtime_bounds;
pub mod watermark;
pub mod web_of_trust_attestation;
pub mod web_of_trust_chain;
pub mod web_of_trust_policy;
pub mod web_of_trust_principal;
pub mod web_of_trust_resolution;
pub mod web_of_trust_revocation;
pub mod web_of_trust_ucan_authorizer;
pub mod weighted_round_robin;
pub mod witness;
pub mod work_stealing;
pub mod write_buffer;
pub mod write_policy;
pub mod zeroize;
#[path = "zircon/channel.rs"]
pub mod zircon_channel;
#[path = "zircon/event.rs"]
pub mod zircon_event;
#[path = "zircon/fifo.rs"]
pub mod zircon_fifo;
#[path = "zircon/futex.rs"]
pub mod zircon_futex;
#[path = "zircon/handle.rs"]
pub mod zircon_handle;
#[path = "zircon/job.rs"]
pub mod zircon_job;
#[path = "zircon/port.rs"]
pub mod zircon_port;
#[path = "zircon/rights.rs"]
pub mod zircon_rights;
#[path = "zircon/socket.rs"]
pub mod zircon_socket;
#[path = "zircon/timer.rs"]
pub mod zircon_timer;
#[path = "zircon/wait.rs"]
pub mod zircon_wait;

// The executable Aeneas pilot stays in repository tooling. These references
// connect its checked shell and pure validator to the crate-level boundary.
// r[impl trellis.aeneas_cross_verifier.provider_consumption]
// r[impl trellis.aeneas_cross_verifier.exact_source]
// r[impl trellis.aeneas_cross_verifier.translation_manifest]
// r[impl trellis.aeneas_cross_verifier.feasibility]
// r[impl trellis.aeneas_cross_verifier.generated_boundary]
// r[impl trellis.aeneas_cross_verifier.theorem_map]
// r[impl trellis.aeneas_cross_verifier.theorem_adequacy]
// r[impl trellis.aeneas_cross_verifier.resource_budget]
// r[impl trellis.aeneas_cross_verifier.manifest]
// r[impl trellis.aeneas_cross_verifier.negative_evidence]
// r[impl trellis.aeneas_cross_verifier.claim_boundary]
// r[impl trellis.aeneas_cross_verifier.final_validation]
// The pinned Nix rail supplies the corresponding verification evidence.
// r[verify trellis.aeneas_cross_verifier.provider_consumption]
// r[verify trellis.aeneas_cross_verifier.exact_source]
// r[verify trellis.aeneas_cross_verifier.translation_manifest]
// r[verify trellis.aeneas_cross_verifier.feasibility]
// r[verify trellis.aeneas_cross_verifier.generated_boundary]
// r[verify trellis.aeneas_cross_verifier.theorem_map]
// r[verify trellis.aeneas_cross_verifier.theorem_adequacy]
// r[verify trellis.aeneas_cross_verifier.resource_budget]
// r[verify trellis.aeneas_cross_verifier.manifest]
// r[verify trellis.aeneas_cross_verifier.negative_evidence]
// r[verify trellis.aeneas_cross_verifier.claim_boundary]
// r[verify trellis.aeneas_cross_verifier.final_validation]

#[path = "../composition.rs"]
pub mod nemotron_composition;
