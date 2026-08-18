## Context

`aspen3` runs Lemonade backed by a Nix-built llama.cpp ROCm/RPC package. The originally configured `user.Ornith-1.0-35B-Q8_0` model downloaded successfully and matched the Hugging Face linked size, but generated only repeated `/` tokens. The same behavior occurred through Lemonade chat, OpenAI completions, recommended sampling settings, `enable_thinking = false`, and a CPU-only `llama-cli` run. That points at the Q8 GGUF/runtime path rather than prompt formatting or ROCm offload.

The `Ornith-1.0-35B-Q4_K_M` GGUF from the same repository generated a correct answer on the same host and current service after being pulled.

## Decisions

### 1. Serve Q4_K_M for Aspen3's 35B Ornith endpoint

**Choice:** Register and pull `Ornith-1.0-35B-Q4_K_M` on `aspen3` and remove the Q8 model from the served model list.

**Rationale:** Q4_K_M is live-validated on the target machine while Q8 produces syntactically valid but semantically broken responses. Keeping Q8 registered would let clients accidentally select the bad endpoint.

### 2. Keep the llama.cpp b9859 package update

**Choice:** Pin the custom ROCm/RPC package to upstream llama.cpp `b9859` and update the RPC worker alias to handle upstream's `ggml-rpc-server` rename.

**Rationale:** Although b9859 alone did not fix Q8, it is the latest available runtime and matches the model card's requirement for recent serving software. The alias keeps the existing module surface stable for RPC worker users.

### 3. Preserve 9B Q8 as a fallback

**Choice:** Keep `Ornith-1.0-9B-Q8_0` in the `aspen3` model list.

**Rationale:** The 9B Q8 endpoint had already passed a live response probe and remains useful for fast/light tasks.

## Risks

- Q4_K_M is lower precision than Q8. The trade-off is acceptable because the Q8 artifact currently produces unusable output under llama.cpp.
- Updating the shared llama.cpp package can affect other Lemonade and RPC deployments on their next deploy. The package build and `aspen3` deployment exercise the primary local use path.
