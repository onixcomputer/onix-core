# Verify unrestricted Trellis Nix version comparison

## Why

The public comparator accepts byte vectors, but its ordinary executable/spec connection covers only a finite subset with single-digit numeric components. Other inputs enter a trusted fallback with only a normalized-result guarantee. The current source saturates oversized numbers, omits Nix's special `pre` ordering and can fail to advance over non-alphabetic component bytes.

## Outcome

Run a bounded actual pinned Nemotron attempt against isolated current inputs, then independently integrate a full-byte-domain Nix comparison specification and verified implementation. Preserve accepted inputs and meaningful algebraic contracts; remove the fallback rather than hiding it behind another admission gate.

## Scope

Trellis comparison implementation and active proof consumers, meaningful runtime regressions, current requirements and source-derived trust accounting. Compare against pinned actual Nix behavior and record limitations of the evaluator's byte-string representation. No compatibility shims, new trust, arbitrary numeric limits, extra allocation or recursive runtime scans.

## Operations

Use the existing pinned loopback-only Spark launcher through authenticated SSH. Record and temporarily stop the original three-rank DeepSeek service, use one replica, then restore the exact original containers and prove a real completion. Preserve unrelated work and historical evidence. No permanent Spark configuration change or training.
