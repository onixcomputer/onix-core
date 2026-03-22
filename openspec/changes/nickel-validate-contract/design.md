## Context

Nickel contracts provide structural and type validation that Nix cannot express. The wasm plugin already evaluates Nickel code inside Nix evaluation. The missing piece: applying a Nickel contract to a Nix-originated value without rewriting the value in Nickel.

This change depends on the `nix_to_nickel` conversion function from `nickel-eval-args`. Both changes add Nix→Nickel value conversion; this one additionally loads a contract from a `.ncl` file and applies it.

## Goals / Non-Goals

**Goals:**
- `validateNickel`: take a Nix attrset `{ contract = <path>; value = <any>; }`, apply the Nickel contract to the converted value, return the original Nix value on success or fail with the contract error message
- Wrapper in `lib/wasm.nix`: `validateNickel { contract = ./schema.ncl; value = myAttrset; }`
- Contract errors include the Nickel blame message (expected type, field path, etc.)
- Flake checks for passing validation, failing validation (type mismatch, missing field, custom contract)

**Non-Goals:**
- Transforming or coercing the value — validation only, the original Nix value passes through unchanged
- Inline contract strings (only file-based contracts) — keeps the contract in a reviewable `.ncl` file
- Partial validation / warning mode — fail hard or pass

## Decisions

**Return the original Nix value, not the round-tripped one.** The Nix value is converted to Nickel for contract checking, but the return value is the original Nix `Value` passed in. This avoids lossy round-trips (e.g., derivation references, string contexts) and makes `validateNickel` a pure validation gate that doesn't alter the data flowing through.

**Contract file evaluates to a record contract.** The `.ncl` file at the `contract` path must evaluate to a Nickel record that acts as a contract (via Nickel's structural typing). The plugin evaluates the contract file, converts the Nix value to a Nickel term, merges the value with the contract record (which triggers contract checking), then calls `eval_full_for_export` to force all contracts. If evaluation succeeds, the original Nix value is returned. If a contract violation occurs, the Nickel blame error is forwarded via `nix_wasm_rust::panic`.

```nickel
# Example contract file: contracts/traefik-routes.ncl
{
  http | {
    routers | { _ : {
      rule | std.string.NonEmpty,
      service | std.string.NonEmpty,
      entryPoints | Array std.string.NonEmpty,
    }},
  }
}
```

**Merge-based contract application.** Nickel applies contracts through record merging — merging a value with a contract-annotated record checks the contracts. The plugin constructs a Nickel program that merges the converted value with the loaded contract:

```nickel
(<contract-file>) & (<converted-value>)
```

This uses Nickel's standard contract-checking semantics without requiring access to internal contract application APIs.

**Shared `nix_to_nickel` with eval-args change.** The Nix-to-Nickel conversion function is identical. If `nickel-eval-args` lands first, this change reuses it. If implemented independently, the same function is written and later deduplicated.

## Risks / Trade-offs

**Contract error messages may be opaque.** Nickel blame errors reference Nickel-internal source positions, which won't map to meaningful locations for the user (since the "source" is a synthetic merge expression). Mitigation: prefix the panic message with the contract file path and a note that the Nix value failed validation.

**Nix values with no Nickel equivalent.** Nix derivations, functions, and string-with-context can't be converted to Nickel. The plugin will skip unconvertible fields with a warning, or fail if the top-level value is unconvertible. In practice, validation targets are data attrsets — not derivation trees.

**Performance on large values.** The Nix value is walked twice: once to convert to Nickel, once during contract evaluation. For large configs this doubles the work. Acceptable because validation is opt-in and applied to specific subtrees, not entire NixOS configs.
