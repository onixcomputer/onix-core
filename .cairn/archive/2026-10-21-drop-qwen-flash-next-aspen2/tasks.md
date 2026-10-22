## Phase 1: Implementation

- [x] [serial] Remove the `qwen38-flash-next-aspen2` instance and its token vars, and give the `aspen2` sidecar `endpointUrl = null` without a backend unit. r[onix.aspen2.qwen_flash.serving] r[onix.mesh_llm.sidecar.research_only]
- [x] [serial] Make the Mesh-LLM `endpointUrl` nullable, render no OpenAI endpoint plugin for null, and reject a backend on a node without an endpoint. r[onix.mesh_llm.sidecar]
- [x] [serial] Update the Mesh-LLM checks for the research-only `aspen2` node and add module fixtures for both cases. r[onix.mesh_llm.validation]

## Phase 2: Verification and deployment

- [x] [serial] Run the Mesh-LLM checks, confirm the other machines' toplevels are unchanged, deploy `aspen2`, and confirm no failed units, a sidecar with peers, and a research query answered through the mesh. r[onix.mesh_llm.sidecar.research_only]
