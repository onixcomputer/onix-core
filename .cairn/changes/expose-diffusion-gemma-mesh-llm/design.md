## Context

The fleet uses Mesh-LLM 0.72.2 and openai-endpoint 0.1.2. Aspen1 is the private seed and britton-desktop is an existing joiner with a loopback API on port 9337. Before this change, the seed's runtime override read /etc/mesh-llm-dsv41/config.toml: its primary plugin pointed at port 13305, and a second plugin named spark pointed at the existing port 18999 forwarder. That forwarder answers /v1/models with deepseek-v4.1-flash.

## Decisions

### Decision: Preserve both provider declarations in authoritative configuration

**Choice:** Set Aspen1's endpointUrl to http://127.0.0.1:8000/v1 and backendUnit to docker-diffusion-gemma.service. Add default-empty extraEndpoints using the existing record schema convention, preserving spark at http://127.0.0.1:18999/v1. Keep the seed mode, transport address, state directory, ports, bootstrap model, package versions and other hosts' settings unchanged.

**Rationale:** Registering only the new primary endpoint would discard the existing Spark declaration. Both declarations use the existing OpenAI endpoint plugin; no new traffic proxy or model alias is introduced. Every endpoint must retain the loopback boundary, and an extra endpoint cannot shadow the reserved primary name. The existing mesh check now protects the new backend ownership and rejects primary-endpoint shadowing.

### Decision: Activate one persistent sidecar and retire the superseded override

**Choice:** GC-root the selected Nix service bundle at /nix/var/nix/profiles/diffusion-gemma. Install its mesh unit under /etc/systemd/system.control, add the boot want under /etc/systemd/system.attached, and retain the unchanged model units and Qwen mask. Hash-check and remove the obsolete runtime ExecStart drop-in before restarting only the mesh sidecar. Remove its old TOML only after successful peer inference.

**Rationale:** The original host unit outranks attached units, and the runtime drop-in would override a replacement unit's ExecStart. The generated configuration preserves both provider declarations, so that mutable duplicate is obsolete. The model unit files were byte-compared before activation; no whole-host switch or immutable-store modification occurred. The separate merge_proxy.py and externally managed Spark forwarder were not modified.

## Operating State

- Existing desktop mesh API: `http://127.0.0.1:9337/v1`; request model `diffusiongemma`.
- Seed unit: `mesh-llm-mesh-llm-private-inference.service`. Restart only that unit for mesh configuration changes; DiffusionGemma and its structured frontend are independent running services.
- Persistent unit bundle: `/nix/store/c472s2rqqz2qr40w55s17hq9px0p8bbn-aspen1-diffusion-gemma-units`, rooted by the profile above.
- Direct backend, structured frontend, mesh API and console remain bound to loopback ports 8000, 8001, 9337 and 3131. Mesh transport remains on the existing private `100.100.103.95:47916/UDP` address.
- Future scoped deployments must advance the profile. A deliberate whole-host cutover must reconcile these control/attached overrides because they can outrank newly generated ordinary units.
- Omit unsupported diffusion sampling controls such as `temperature` and `seed`; requests containing them retain the backend's HTTP 400. Native seeded-canvas initialization uses `vllm_xargs`, not the conventional sampling seed.
- `/v1/systemone` on the structured frontend remains private and is not a separate mesh model route. Native read-only canvas requests with label log probabilities work through the mesh's chat-completions endpoint.

## Measured Verification

`verification.json` records the exact requests, responses, service identities and compiled provider configuration.

- The existing desktop peer discovered `diffusiongemma`; no previously advertised model IDs disappeared.
- Non-streaming HTTP 200: “The capital of France is Paris.”
- Streaming HTTP 200: “The capital of Japan is Tokyo.” with a completed `[DONE]` event.
- Read-only seeded canvas HTTP 200: requested label token log probabilities were returned. The vLLM fingerprint matches the deployed DiffusionGemma runtime.
- An unsupported temperature request returned the original HTTP 400 instead of silently changing its semantics.
- Aspen1's model backend, structured frontend, music service and Docker daemon retained their prior invocation IDs. The desktop's mesh and Qwen services also retained theirs. Qwen on Aspen1 stayed masked.
- The Spark provider declaration and healthy direct forwarder were preserved. This is not a claim that DeepSeek was newly advertised through the mesh; its ID was absent from the desktop catalog both before and after this change.
- The scoped Nix service bundle and existing mesh-llm-sidecars check passed. Inventory-tag warnings already present in repository evaluation remain outside this change.

## OMP Model Discovery Follow-up

The desktop's OMP provider previously contained a fixed four-model list. Replace that list in `~/.omp/agent/models.yml` with `discovery.type: openai-models-list` and a 5000 ms probe timeout, retaining `http://127.0.0.1:9337/v1` and its existing compatibility settings. The ignored legacy `models.json` has the same discovery declaration so a future legacy migration cannot restore the stale list.

Add `mesh/**` to `enabledModels` without changing the existing entries or default role. A single `mesh/*` does not include model IDs containing another slash, such as `unsloth/Qwen3-0.6B-GGUF:Q4_K_M`.

The global extension `~/.omp/agent/extensions/mesh-models.ts` invokes OMP's native `refreshDiscoverableProviders(["mesh"], "online")` at session startup and every 30 seconds. It uses the managed extension timer, which contains callback failures and is cleared on session shutdown. Discovery alone would reuse OMP's 24-hour cache. No separate sync service, alternate model registry, or inference proxy is added.

### Runtime and compiler correction

Installed OMP 18.1.19 retained removed models from its warm cache after successful discovery. The repository already pinned OMP 18.2.4, whose upstream registry replaces both cached and runtime-discovered membership, including a successful empty catalog. Use that upstream fix; no local registry patch is retained.

OMP 18.2 requires Bun >=1.4. The old module override forced Bun 1.3.13 and failed the package's own smoke test with a CommonJS function-wrapper error. Remove the obsolete override and use the pinned upstream package's matched Bun 1.4.2 compiler and runtime. The unrelated repository Bun pin is unchanged.

Activate `/nix/store/bb9446mm6qbvngc0s028hy05p42xbzxc-omp-18.2.4` in the desktop user's Nix profile, without a whole-host activation. The user profile roots the package and precedes the older system executable. Future upgrades must update or remove that user-profile entry when reconciling it with a deliberate system deployment.

### Freshness and verification

- Existing OMP processes need one restart to load the new executable and global extension.
- New sessions start an online refresh; initial cached rows can remain visible until that background refresh settles. Subsequent membership changes converge on the 30-second refresh cadence while Mesh is reachable.
- A failed request keeps the last usable catalog. A successful empty response removes all Mesh models. Recovery discovers the new catalog without restarting the session.
- Standalone `omp models mesh` uses OMP's cache; `omp models refresh mesh` requests an immediate online refresh.
- Real desktop RPC discovery matched all nine live Mesh IDs, including `diffusiongemma` and the slash-containing bootstrap ID. The default remained `zai/glm-5.3`.
- A real isolated OMP process against a controlled loopback catalog verified warm-cache replacement, periodic addition/removal, HTTP 503 fallback, an empty catalog, and recovery. An unrelated provider remained available throughout.
- Desktop mesh and Qwen services retained their invocation IDs. Only OMP user configuration and its executable selection changed.

The `omp_model_discovery` section of `verification.json` records the before/after evidence and package identity.
