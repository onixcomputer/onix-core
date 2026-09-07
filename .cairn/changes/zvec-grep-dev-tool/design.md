# Design: Package zvec-grep as an Onix dev tool

## Context

zg is a local-first search layer that unifies ripgrep, BM25, and vector search. It ships as an npm package for Node 22 and provides a CLI, a local server, and an MCP endpoint. Onix dev environments need intent-driven search now. The Rust-native ranked layer in Animus is planned but not built.

The adoption boundary is explicit: zg stays an external, pinned dev tool. It does not enter the OnixResearch runtime stack, and its Node implementation is not vendored or rewritten.

## Decisions

### 1. Keep the Node tool external and pinned

**Choice:** Package `@zvec/zvec-grep` v0.2.1 at revision `309a66995809243d3274fa8b5bea63ab11dda1a0` through Nix with Node 22. Record the immutable revision in references.

**Rationale:** The tool is Apache-2.0 and maintained. Pinning gives repeatable behavior without forking or rewriting.

### 2. Make the tool a dev-shell surface

**Choice:** Expose zg through Onix dev tooling with typed Nickel configuration for workspace roots, exclusions, model choice, and local or remote embedding. Export runtime inputs as the tool requires.

**Rationale:** Configuration stays in the Onix-reviewed form. The tool never evaluates Nickel at runtime.

### 3. Keep exact search usable without an index

**Choice:** Preserve `zg query --rg` as a no-index exact path.

**Rationale:** Exact text search must not depend on indexing or an embedding model.

### 4. Expose agents to a loopback MCP endpoint

**Choice:** Where the environment supports it, serve the zg MCP endpoint on loopback with bearer authentication.

**Rationale:** Agent access follows the same local-server pattern the stack already uses for MCP clients.

### 5. Default to local embeddings

**Choice:** Local embedding models are the default. Remote embedding requires explicit workspace authorization.

**Rationale:** This matches the stack tenet of no silent data egress and the Basalt embedding-authorization policy surface.

## Alternatives Considered

### Vendor zg source into Onix packages

Rejected. Pinning the npm release is simpler than maintaining a vendored copy.

### Port zg to Rust now

Rejected. The Animus ranked adapter is not built. Porting before evidence creates a second unseen surface.

### Skip semantic search

Retained as the degraded mode. Removing it is not required; packaging is additive.

## Risks and Controls

- Node version drift: pin Node 22 in the package.
- Local model size: document download cost and allow rg-only use.
- Index staleness: rebuild is an explicit, documented operation.
- Endpoint exposure: the server binds loopback only and requires a bearer token.

## Non-Claims

This change does not prove relevance quality, embedding correctness, production service behavior, or release eligibility. The tool remains a dev-environment adoption, not a runtime stack component.
