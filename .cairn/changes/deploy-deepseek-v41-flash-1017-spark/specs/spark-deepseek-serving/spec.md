# DeepSeek-V4.1-Flash-1017 Spark serving Specification Delta

## ADDED Requirements

### Requirement: Spliced 1017 TP3 pack r[onix.spark.deepseek1017.pack]

The 1017 deployment MUST serve a TP3 pack spliced from the pinned native 1017 release
non-expert tensors, an EXL3 low-bit routed-expert body, and the native Engram shards,
and MUST NOT serve a pack whose Engram tables are missing.

#### Scenario: Pack is served

- GIVEN the spliced pack is present on all three nodes with its shard set and index
- WHEN the launcher starts
- THEN the served root path names the 1017 pack
- AND the previous pack remains on disk, unmodified, for rollback.

### Requirement: Cutover discipline r[onix.spark.deepseek1017.cutover]

The rollout MUST stop the previous containers before booting the new one on any node,
MUST boot the workers before the head, and MUST keep the previous containers
(stop, never remove) so rollback is a container start rather than a rebuild.

#### Scenario: Rollback stays available

- GIVEN the rollout has cut over to the 1017 pack
- WHEN the operator needs the previous model
- THEN `docker start vllm_dsv41` on the three nodes restores the recorded previous
  container identities without rebuilding weights or re-pulling images.

### Requirement: Served API surface r[onix.spark.deepseek1017.serving]

The head MUST serve the OpenAI-compatible API on `:8888` with the served name
`deepseek-v4.1-flash`, tensor parallelism 3 across the three Sparks, DSpark
speculative decoding, Engram on disk, and vision/tool/reasoning parsing enabled as
recorded in the change settings.

#### Scenario: Model listing identifies the 1017 pack

- GIVEN the new container is running on all three ranks
- WHEN `GET /v1/models` is queried on the head
- THEN the listed root names the 1017 pack directory
- AND the response is not served from the previous abliterated pack.

### Requirement: Observed verification r[onix.spark.deepseek1017.verification]

The rollout MUST record real completion evidence from the served 1017 model and MUST
NOT treat a running container or a model listing as proof of usable inference.

#### Scenario: Real completion from the 1017 pack

- GIVEN the 1017 deployment is up on all three ranks
- WHEN a chat completion asks for a deterministic arithmetic answer through `:8888`
- THEN the response contains the correct integer
- AND the observed response, usage and timings are retained in this change's evidence.
