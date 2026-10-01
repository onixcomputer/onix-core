## Context

Underclass runs on britton-desktop at `127.0.0.1:8080` and exposes `/v1/models`, `/v1/responses` and `/v1/chat/completions` behind a bearer proxy key. Its ADR 0010 says both upstreams accept both paths, but the live Codex backend rejects chat-shaped bodies: `Unsupported parameter: messages`, and non-streamed requests fail with `Stream must be set to true`. The pool currently holds only Codex accounts; the catalog also lists fallback Copilot entries with no enrolled account.

The fleet runs Mesh-LLM 0.72.2 with openai-endpoint 0.1.2. The plugin only declares an endpoint URL. The host probes `GET <url>/models` every 15 seconds without credentials, normalizes `/v1/responses` requests into chat completions, aliases output caps to `max_tokens`, and inserts `chat_template_kwargs` when a request carries reasoning options. The host also passes `MESH_LLM_PLUGIN_NAME` to each plugin and rejects any plugin whose initialize response reports another name. openai-endpoint hardcodes `openai-endpoint`, so every `extraEndpoints` entry fails with `Plugin '<name>' identified itself as 'openai-endpoint'`. Upstream's own README directs protected providers to a separately secured loopback gateway that handles authentication for discovery and inference.

## Decisions

### Decision: The Underclass module owns a loopback translating gateway

**Choice:** Add `pkgs/underclass-mesh-gateway`, a stdlib Python `ThreadingHTTPServer`, and run it from `modules/llm-agents/underclass.nix` when `underclassMeshGateway` is set. It binds `127.0.0.1:<underclassMeshPort>`, loads the existing per-machine `underclass/proxy-key` var through `LoadCredential`, and talks only to `services.underclass.bindAddress`. The unit uses `DynamicUser`, `IPAddressAllow=localhost`/`IPAddressDeny=any` and the sidecar's hardening. It wants, orders after and is `PartOf` `underclass.service`, so the documented Underclass restart after key rotation also refreshes the gateway's credential copy. Inventory shares one port binding between the gateway setting and the desktop's `extraEndpoints.underclass` URL.

**Rationale:** The key already belongs to the module that generates it, and `extraEndpoints` is defined as externally managed, so the generic mesh module stays unaware of Underclass. Both listen and upstream addresses are validated as IPv4 loopback before start. The Mesh-LLM API on each node is already an unauthenticated loopback surface, so the gateway adds no reachable surface beyond the mesh route itself. Stdlib Python follows the repo's existing loopback service pattern and needs no dependency lock.

### Decision: Translate to Responses; forward everything else unchanged

**Choice:** Map system, developer and user messages to Responses input messages; assistant text to `output_text`; assistant tool calls to `function_call` items; tool messages to `function_call_output`. Flatten chat-shaped `tools` and `tool_choice`, keep already-flat shapes that Mesh forwards from `/v1/responses` clients, map `reasoning_effort`, `response_format` and `verbosity`, and always request a stream. Answer `stream` and `stream_options` locally, returning either chat chunks or one aggregated completion. Drop only output caps and Mesh's llama.cpp reasoning switches. Pass every other field unchanged and relay Underclass error statuses and bodies unchanged.

**Rationale:** Codex rejects `max_output_tokens`, and the existing OMP Underclass provider already omits output caps for the same backend. Mesh inserts `chat_template_kwargs` for local templates; forwarding it would break every reasoning request. Fields such as `temperature`, `top_p`, `user` and `metadata` are rejected by Codex; forwarding them preserves the real error instead of silently changing request semantics.

### Decision: Derive conversation affinity for keyless clients

**Choice:** When a request carries neither `prompt_cache_key`, `promptCacheKey` nor a `session-id` header, the gateway sets `prompt_cache_key` to `mesh-` plus a hash of the translated conversation up to its first user message.

**Rationale:** Underclass routes keyless requests to the least-busy account (its ADR 0003), so each turn of a mesh conversation could land on another subscription, losing the prompt cache and spreading context across accounts. Every turn repeats its opening, so the hash stays stable across turns. Conversations that share an opening share an account, which costs nothing.

### Decision: Advertise only Codex-owned catalog entries

**Choice:** `/v1/models` returns Underclass entries whose `owned_by` is `underclass-codex`.

**Rationale:** Every enrolled account is Codex, and the Responses path is verified only for Codex. Copilot fallback entries have no account and no verified wire path; advertising them would publish mesh models that fail. The OMP Underclass provider applies the same boundary.

### Decision: Patch the plugin to report its configured name

**Choice:** Apply `patches/openai-endpoint-plugin-name.patch` to the pinned plugin build. It reports `MESH_LLM_PLUGIN_NAME` when set and otherwise keeps `openai-endpoint`.

**Rationale:** The host already provides the configured name and keys endpoint health and routing by plugin name, so one binary can serve several named entries. The mesh binary is byte-identical; only the plugin changes. The same failure applies to Aspen1's existing `extraEndpoints.spark` entry, so this patch also unblocks it once Aspen1 is updated.

## Risks / Trade-offs

- Every process that can reach a mesh node's loopback API can now spend the desktop's Codex subscriptions. The mesh remains invite-only and banked-reset redemption stays manual.
- Mesh-LLM normalizes Responses clients to chat completions before the gateway sees them. Responses-only features that the mesh drops, such as `previous_response_id` state, input function-call items and `text.format`, stay unavailable through the mesh; direct OMP use of `underclass/*` keeps the native Responses path.
- Output-token caps are not enforced for Underclass models, so `finish_reason: length` is not produced by caps.
- Changing the plugin changes the combined `mesh-llm` package path, so every node's sidecar restarts on its next deployment.
- Copilot models stay unadvertised until a Copilot account is enrolled and its wire path verified.

## Deployment

The desktop runs the lineage it is deployed from, not the working branch. The working branch is 22 commits ahead of that lineage and its uncommitted tree moves `nixpkgs` (a full desktop build from it would move to `26.11.20260924` and a new kernel). Following the omnibin deployment, the integration was carried onto a branch of the running lineage, `underclass-mesh-desktop` from `76fdacba`:

- `2948cb5a` carries the existing `underclass` vars for britton-desktop.
- `0348b2d3` adds the Underclass input and module, the llm-agents Underclass service, OMP provider and gateway, the mesh-llm research forwarder and named endpoints, the plugin patch, the desktop settings and the mesh fixture defaults. The lock change adds `underclass` and changes only `root`.

The generated `underclass`, gateway, sidecar and research-ingress units matched the running runtime and control overrides apart from store paths, so activation changed ownership rather than behavior. Generation 859 (`vghzgpfgdfb4qan5ydllqr7cmm97lm5k`, `configurationRevision` `0348b2d3`) was built from git, compared with generation 858, dry-activated, installed with `nix-env --set`, and switched under `systemd-run`. Immediately before the switch, the sidecar and research-ingress control overrides, the runtime `underclass` and gateway units and the manually linked OMP extension were removed. Underclass and the research ingress were already running, so the switch only started them nominally. They were restarted afterwards to load the generation's binaries, and restarting Underclass restarted the gateway through `PartOf`.

The switch exits 4 because of failures that predate this change: the `build-storage-zfs-properties` and `kache-nix-rust-cache-zfs-dataset` activation snippets hit the `datapool/kache-nix` quota, and `celld`, `celld-site`, `kiln-aspen-ci-host` and `collie-serve` were already crash-looping. Home Manager's retry of `pueued.service` fails as it did on 2026-09-25, because an unmanaged `pueued` holds `/run/user/1555/pueue.pid`. `kiln-aspen-canary-lattice` restarts on any repository change, because its prepare script imports a file from the flake source.

Rollback is `nix-env -p /nix/var/nix/profiles/system --rollback` followed by `switch-to-configuration switch` of generation 858. Generation 858 has no Underclass, gateway or research units, so rolling back removes them.

## Measured Verification

`verification.json` records the requests, responses, service identities and artifact paths.

- The package build ran 18 gateway tests. `mesh-llm-sidecars`, `llm-agents-omp-package-list` and `llm-agents-omp-smoke` passed.
- Only britton-desktop evaluates the gateway and the `underclass` plugin. The assertion rejects the gateway without a local pool.
- Direct gateway smoke against live Underclass returned text, streamed text with usage, two parallel tool calls, a tool-result follow-up, and the unchanged Codex 400 for `temperature`.
- Before the plugin patch, the sidecar logged `Plugin 'underclass' identified itself as 'openai-endpoint'`. After it, the `underclass` endpoint is healthy with eight Codex models.
- From Aspen2's own loopback Mesh-LLM API: model discovery, non-streaming and streaming chat, streamed parallel tool calls, a tool-result follow-up, reasoning effort with an output cap, `/v1/responses` non-streaming and streaming, and the Codex `temperature` rejection as HTTP 400.
- `underclass.service` and the research ingress kept their invocation IDs. The research ingress answered a real search after the sidecar restart.
- Generation 859 runs all four units from `/etc/systemd/system` with the generation's binaries, sops-managed secrets and a Home Manager-owned OMP link. No control or runtime override remains. From Aspen2, chat, streaming, tool-call and Responses requests succeeded after the deployment, and two keyless turns of one conversation produced `NewBinding` then `StickyHit` on the same account.
