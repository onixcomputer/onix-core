## Context

Aspen1 serves Lemonade on `127.0.0.1:13305` and delegates llama.cpp work to Aspen2 over the existing RPC lane. `britton-desktop` serves VibeThinker through llama.cpp on the same local port. Mesh-LLM's openai-endpoint plugin can advertise either endpoint without duplicating those authoritative model weights.

Mesh-LLM private meshes are created by an originator at runtime. The originator's invite token is exposed by its loopback `/api/status` response and encodes the node's reachable QUIC endpoint. Mesh-LLM does not accept an operator-selected seed token or token file. A joining node must receive the emitted token through `--join`.

## Decisions

### 1. Preserve inference runtimes and use CPU sidecars

**Choice:** Package the generic x86_64 Linux Mesh-LLM bundle and openai-endpoint plugin, and configure the plugin for `http://127.0.0.1:13305/v1` on each node.

**Rationale:** The sidecar routes to existing servers and does not compete for GPU memory or bypass Aspen1's Aspen2 RPC worker.

### 2. Use an explicit private LAN transport

**Choice:** Run with `--mesh-discovery-mode mdns`, `--headless`, an explicit Tailscale `--bind-ip`, and a fixed UDP `--bind-port`. Do not pass `--publish`, `--auto`, or `--listen-all`.

**Rationale:** Upstream documents mDNS mode as disabling Nostr discovery, public iroh relays, and raw public STUN. Explicit Tailscale addresses avoid ambiguous Docker/CNI interfaces while default HTTP binding keeps both API and management listeners on loopback.

### 3. Bootstrap in two phases

**Choice:** Deploy Aspen1 first as originator, read its invite token locally over SSH from `/api/status`, store that value in a Clan-managed prompt secret for the same service instance, then deploy `britton-desktop` as joiner.

**Rationale:** The token is runtime-derived and must not be fabricated or placed in the Nix store. A generated Clan secret provides encrypted repository persistence and deployment-time credentials. The joiner fails closed when the credential is missing, empty, or still contains the stock SOPS placeholder.

### 4. Keep state and privileges isolated

**Choice:** Run each sidecar with a dedicated unprivileged `mesh-llm` system user, a private systemd state directory, `LoadCredential` for the join token, and service hardening. Generate the non-secret TOML config in the Nix store.

**Rationale:** Mesh-LLM needs persistent node identity under `$HOME/.mesh-llm`, but the sidecar does not need root or GPU device access. A static service user also permits Mesh's downloaded native shared libraries to be mapped on NixOS; systemd's id-mapped `DynamicUser` state directory caused those mappings to fail during live validation. Only the join token is secret.

### 5. Make assignment scope executable evidence

**Choice:** Add a focused flake check that asserts the expected seed and joiner units and asserts the unit is absent from Aspen2 and Aspen3.

**Rationale:** The primary rollout risk is accidentally advertising RPC workers or unrelated inference nodes. Negative scope checks make that constraint reviewable and repeatable.

### 6. Activate the plugin-aware runtime surface in v0.72.2 with bounded CPU resources

**Choice:** Invoke Mesh-LLM's root runtime option surface with its smallest catalog model, `Qwen3-0.6B-Q4_K_M`, constrained to a 512-token context. Keep GPU devices inaccessible through systemd `PrivateDevices`.

**Rationale:** In v0.72.2, explicit `serve` exits when no native startup model is configured, while the root runtime's model-less passive proxy lists only gossiped native models and does not route its own healthy plugin endpoints. A startup model activates the full plugin-aware API proxy. The generic Linux release and device isolation keep this compatibility model on CPU; the bounded context reduced measured steady-state RSS on Aspen1 from about 2.5 GiB at the upstream 32K context to about 545 MiB. The existing Lemonade and VibeThinker endpoints remain authoritative for their advertised models, and `client` mode remains unsuitable because it creates an ephemeral node key on every restart.

## Risks / Trade-offs

- Nix auto-patching changes the upstream executable bytes, invalidating its embedded release attestation. The selected unrestricted private mesh does not require attested releases, and upstream permits startup in this state.
- The upstream CLI accepts the join token only as an argument. `LoadCredential` keeps it out of the Nix store and unit definition, but root or the service user can inspect the live argv.
- Mesh-LLM v0.72.2 requires a small CPU activation model because explicit `serve` rejects plugin-only startup and the model-less passive proxy omits local plugin routing. This adds a bounded extra model to mesh inventory and about 545 MiB measured RSS on Aspen1. A future upgrade must remove the compatibility model after upstream's passive proxy routes plugin endpoints.
- The invite token embeds Aspen1's selected endpoint. Changing Aspen1's node identity, bind address, or mesh port requires capturing and redeploying a fresh token.
- If the join attempt temporarily fails, Mesh-LLM continues standalone by upstream design. Live validation must therefore compare `mesh_id` and peer membership rather than relying only on systemd activity.
- Mesh HTTP APIs remain loopback-only. Consumers must use a local sidecar or an explicit authenticated tunnel rather than direct LAN access.
