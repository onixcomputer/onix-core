# Design: Drop Qwen3.8 Flash Next from aspen2

## Context

`aspen2` runs a Mesh-LLM joiner that routes to its Qwen3.8 Flash Next unit
and also provides the mesh's arXiv corpus and a Laya instance through the
research plugin. The Qwen unit fails to allocate 65,159 MiB on a host with
62 GiB of memory. The Mesh-LLM module requires every node to advertise a
loopback OpenAI endpoint owned by a backend unit or an external owner.

## Decisions

### Decision: Remove the instance rather than mask it

**Choice:** Delete the `qwen38-flash-next-aspen2` instance and its token vars.

**Rationale:** `aspen1` masks its Qwen because DiffusionGemma may give the GPU
back. `aspen2` cannot load this model at all, so a retained definition would
only keep a model download path and a gated token that nothing uses.

### Decision: Make the Mesh-LLM OpenAI endpoint optional

**Choice:** `endpointUrl` becomes nullable. A null endpoint renders no
`openai-endpoint` plugin, and such a node must not declare `backendUnit` or
external ownership. A non-null endpoint keeps the owned-backend assertion.

**Rationale:** `aspen2` must stay in the mesh for research. Pointing its
endpoint at a dead port, or declaring an external owner that does not exist,
would misdescribe the node.

## Risks / Trade-offs

- The sidecar on `aspen2` runs with only the research plugin. The deploy
  verifies its peers and a research query through another node.
- Restoring inference on `aspen2` needs a model that fits its memory and a
  new change.
