# Proposal: Package zvec-grep as an Onix dev tool

## Why

Onix dev environments have no local-first semantic search tool for agent and human workflows. ripgrep covers exact text search. It cannot answer intent questions such as "where is the authentication flow" with ranked, source-linked evidence.

The reviewed project is zvec-grep at `github.com/zvec-ai/zvec-grep` revision `309a66995809243d3274fa8b5bea63ab11dda1a0` (v0.2.1), Apache-2.0. It unifies ripgrep, BM25, and vector search behind one local-first interface with CLI and agent integrations. It is a Node 22 npm package. Onix should adopt it as a pinned external dev tool while the Rust-native ranked layer matures in Animus.

The tool stays local by default. Remote embeddings send data off the machine only with explicit workspace authorization.

## What Changes

- Package `@zvec/zvec-grep` v0.2.1 at revision `309a66995809243d3274fa8b5bea63ab11dda1a0` in the Onix dev-environment tooling with Node 22. r[onix.zvec_grep.packaging]
- Add typed configuration for workspace roots, exclusions, embedded models, and local or remote embedding. r[onix.zvec_grep.config]
- Enable agent access through a local Streamable HTTP MCP endpoint with bearer authentication, loopback only. r[onix.zvec_grep.agent]
- Keep data local by default. Remote embeddings require explicit workspace authorization. r[onix.zvec_grep.privacy]
- Record the reference revision and license in repository references. r[onix.zvec_grep.reference]
- Add packaging, configuration, smoke, and privacy verification. r[onix.zvec_grep.verification]

## Impact

- **Files**: Onix dev-tooling package for zg, typed configuration, agent-integration wiring, and focused checks.
- **Risk**: Node 22 version drift and local model download size can delay first use. rg-only smoke works without an index.
- **Non-goals**: Do not port zg internals to Rust. Do not replace pi native grep tooling or the Animus ranked layer.
- **Testing**: Assert the packaged binary runs, positional rg queries work without an index, configuration validates, the MCP endpoint binds loopback, and remote embedding is denied without a grant.

## Affected Specs

- `zvec-grep-dev-tool`: packaging, configuration, agent access, privacy, reference, and verification.
