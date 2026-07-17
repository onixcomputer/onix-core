# Proposal: Add device-free RWKV lab session receipts

## Why

The current ttWKV7 diagnostic workflow duplicates exact package, kernel, device, owner, timeout, attempt, evidence, restoration, and claim boundaries across large one-shot shell scripts. That preserved safety for isolated measurements, but it makes each device-free review expensive and lets classification rules drift between runs. The exhausted aligned-reader session also demonstrated that a terminal timeout can preserve useful partial evidence without satisfying correctness.

A reusable lab boundary should make the immutable plan and terminal classification deterministic before another physical run is considered. This change must not create a hardware executor or weaken the requirement for a fresh reviewed lifecycle change.

## What Changes

- Add a typed Nickel contract and example manifest for bounded RWKV lab sessions.
- Add a Rust `rwkv-lab` tool whose pure core validates exported manifests, derives deterministic BLAKE3 plan identifiers, and classifies saved evidence.
- Distinguish `not_run`, `blocked`, `passed`, `failed`, `partial_diagnostic`, and `unsafe` outcomes from explicit counters, process results, required artifacts, success markers, restoration, and board-health evidence.
- Add positive and negative unit and package tests for malformed plans, attempt-budget violations, plan mismatches, incomplete evidence, false success, and failed restoration.
- Expose only plan inspection and evidence classification. Do not execute a manifest command, isolate an owner, select a device, or initialize Metalium.

## Non-Goals

- No Tenstorrent device access, service stop, owner mutation, probe invocation, or automatic retry.
- No claim that the repaired aligned readers complete on a P150.
- No replacement for a fresh reviewed runbook and lifecycle package before future physical execution.
- No one-layer RWKV model or token generation in this slice.
