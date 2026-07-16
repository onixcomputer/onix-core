# tenstorrent-native-runtime Delta

## ADDED Requirements

### Requirement: ttWKV7 single-device topology isolation
r[onix.tenstorrent.native_runtime.ttwkv7.single_device_topology] The packaged ttWKV7 command MUST clear any inherited `TT_MESH_GRAPH_DESC_PATH` before TT-Metal device creation so its unit mesh is derived from the operator-selected visible device rather than the host's linked-card topology.

#### Scenario: Host exports a linked-card mesh descriptor
- GIVEN a Tenstorrent host exports the P150x2 mesh graph descriptor
- WHEN an operator invokes packaged ttWKV7 with one physical card selected through `TT_VISIBLE_DEVICES`
- THEN the wrapper removes the inherited mesh descriptor before launching the executable
- AND TT-Metal is not asked to map the two-card graph onto the one-card visible topology

#### Scenario: Wrapper topology isolation regresses
- GIVEN the generated ttWKV7 wrapper
- WHEN package validation inspects its environment mutations
- THEN validation fails if the wrapper does not explicitly unset `TT_MESH_GRAPH_DESC_PATH`
- AND validation fails if the wrapper exports a replacement mesh descriptor value
