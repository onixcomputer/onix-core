## Context

Open Notebook bootstrap currently treats one `credentials` setting as both declarative provider metadata and secret transport. `builtins.toJSON` serializes the complete record, including optional `apiKey`, into the text of a Nix-built generator. The generator later writes a Clan secret file, but the earlier store materialization has already crossed the secret boundary.

## Decisions

### 1. Keep secret values out of Nix evaluation

**Choice:** The schema will allow only non-secret credential identity, provider, modality, endpoint, model, and default-selection metadata. API keys and equivalent secret payloads will come from a Clan prompt or deployed opaque credential JSON file read by the runtime generator.

**Rationale:** A Nix value interpolated into a derivation cannot be made secret after the fact. Runtime secret files preserve the existing Clan distribution boundary.

### 2. Reject legacy inline secrets explicitly

**Choice:** Module evaluation will detect secret-bearing fields such as `apiKey` and fail with a migration diagnostic rather than silently dropping or serializing them.

**Rationale:** Silent omission could deploy an unusable service, while continued compatibility would preserve the leak.

### 3. Assemble bootstrap material in the imperative shell

**Choice:** Pure helpers will validate and normalize non-secret metadata. A thin generator/runtime shell will read the deployed secret file, combine it with metadata in a protected runtime path, and invoke bootstrap without placing secret bytes in command lines, environment values, or store files.

**Rationale:** This keeps deterministic configuration logic testable while confining secret I/O to the intended runtime boundary.

### 4. Prove absence as well as runtime success

**Choice:** Checks will evaluate a sentinel secret configuration and assert that sentinel bytes are absent from derivation scripts and closures. Separate runtime tests will show that a deployed secret reaches the bootstrap request.

**Rationale:** A happy-path bootstrap test alone cannot detect an earlier store leak.

## Risks / Trade-offs

- Inline configurations become intentionally incompatible and need migration documentation.
- Secret JSON shape must be validated without echoing secret content in diagnostics.
- Store scans prove absence for the tested derivations, not every external consumer of the same secret.
